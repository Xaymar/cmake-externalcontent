# Copyright 2026 Narta Xaymar Dirks <info@xaymar.com>
#
# Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
#
# 1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
#
# 2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
#
# 3. Neither the name of the copyright holder nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS “AS IS” AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

# ExternalContent is an attempt at solving the issues I have with FetchContent and ExternalProject:
# - Both pollute the parent cache with variables and aren't fully separated.
# - Both are considerably slower.
# - Anything that uses them ends up with poor performance too.

# Goals:
# - Never pollute the parent cache unless absolutely needed.

#!TODO: Add support for older CMake versions.
cmake_minimum_required(VERSION 4.2.0)

function(InitializeExternalContent)
endfunction()

macro(ExternalContent_ParseURL OUTPUT_VAR URL)
	# Parse the given url.
	string(REGEX
		MATCH "^(([^:/?#]+):)?(//([^/?#]*))?([^?#]*)(\\?([^#]*))?(#(.*))?"
		URL_MATCH
		"${URL}"
	)
	if(NOT "${URL}" STREQUAL "${URL_MATCH}")
		message(FATAL_ERROR "ExternalContent: Failed to parse URL '${URL}' completely. Only managed to parse '${URL_MATCH}'.")
	endif()

	set(${OUTPUT_VAR}_PROTOCOL_FULL ${CMAKE_MATCH_1})
	set(${OUTPUT_VAR}_PROTOCOL ${CMAKE_MATCH_2})
	set(${OUTPUT_VAR}_HOST_FULL ${CMAKE_MATCH_3})
	set(${OUTPUT_VAR}_HOST ${CMAKE_MATCH_4})
	set(${OUTPUT_VAR}_PATH ${CMAKE_MATCH_5})
	set(${OUTPUT_VAR}_QUERY_FULL ${CMAKE_MATCH_6})
	set(${OUTPUT_VAR}_QUERY ${CMAKE_MATCH_7})
	set(${OUTPUT_VAR}_FRAGMENT_FULL ${CMAKE_MATCH_8})
	set(${OUTPUT_VAR}_FRAGMENT ${CMAKE_MATCH_9})
endmacro()

macro(ExternalContent_ParsePath OUTPUT_VAR INPUT_VAR)
	cmake_path(GET "${INPUT_VAR}" FILENAME "${OUTPUT_VAR}_FILENAME")
	cmake_path(GET "${INPUT_VAR}" EXTENSION "${OUTPUT_VAR}_EXTENSION")
endmacro()

function(ExternalContent)
	if(TRUE) # Resolve dependencies
		# Dependency: Git
		find_package(Git QUIET)
	endif()

	if(TRUE) # Generate a UUID once for each fresh build to ensure that there's no collisions.
		if(NOT EXTERNALCONTENT_UUID)
			string(TIMESTAMP _EC_UUID_TS "%Y-%m-%dT%H:%M:%S" UTC)
			string(RANDOM LENGTH 64 _EC_UUID_RANDOM)
			string(UUID EXTERNALCONTENT_UUID
				NAMESPACE "00000000-0000-0000-0000-000000000000"
				NAME "${TIMESTAMP}-${RANDOM}"
				TYPE SHA1
				UPPER
			)
			set(CACHE{EXTERNALCONTENT_UUID}
				TYPE INTERNAL
				HELP "UUID for external content storage to prevent collisions."
				VALUE "${EXTERNALCONTENT_UUID}"
			)
		endif()
	endif()

	if(TRUE) # Parse and validate the arguments
		set(_EC_PREFIX "${CMAKE_BINARY_DIR}/ExternalContent.dir")
		set(_EC_TEMP_PATH "${_EC_PREFIX}/${EXTERNALCONTENT_UUID}/${_EC_NAME}.tmp")
		set(_EC_SOURCE_PATH "${_EC_PREFIX}/${EXTERNALCONTENT_UUID}/${_EC_NAME}.src")
		set(_EC_BINARY_PATH "${_EC_PREFIX}/${EXTERNALCONTENT_UUID}/${_EC_NAME}.bin")
		set(_EC_INSTALL_PATH "${_EC_PREFIX}/${EXTERNALCONTENT_UUID}/${_EC_NAME}.dist")

		set(__EC_FLAGS
			## Skip the download step entirely.
			"SKIP_DOWNLOAD"

			## Skip the configure step entirely.
			"SKIP_CONFIGURE"

			## Skip the patch step entirely.
			"SKIP_PATCH"

			## Skip the build step entirely.
			"SKIP_BUILD"

			## Skip the install step entirely.
			"SKIP_INSTALL"
		)
		set(__EC_PARAMS_SINGLE
			## What is this external content called?
			# Should be a unique name that also is a valid filesystem directory name.
			"NAME"

			## Where should we place the temporary files?
			#
			# Optional.
			"TEMP_PATH"

			## Where should we place the source files?
			# You can also specify this in combination with SKIP_DOWNLOAD to use existing files.
			#
			# Optional.
			"SOURCE_PATH"

			## Where should we place the binary files (if any)?
			#
			# Optional. Ignored if SKIP_BUILD is set.
			"BINARY_PATH"

			## Where should we place the installable files (if any)?
			#
			# Optional. Ignored if SKIP_INSTALL is set.
			"INSTALL_PATH"

			## (download) From which url should this be downloaded?
			# Required if no other method is provided.
			"DOWNLOAD_URL"

			## (download) What is the file called?
			# Optional, but required if the URL does not contain a file name.
			"DOWNLOAD_FILE"

			## (download) What is the expected hash of the download?
			# Should be in the format: (type);(hash)
			# See [https://cmake.org/cmake/help/latest/command/string.html#hash] for a list of valid hash types.
			#
			# Optional, but recommended.
			"DOWNLOAD_HASH"

			## (git) Git repository to clone.
			# Required if no other method is provided.
			"GIT_URL"

			## (git) Git reference to clone/checkout.
			# Required.
			"GIT_REF"

			## Provide a custom function for the configure step.
			# This function is expected to message(FATAL_ERROR) if an error occurs.
			#
			# Function Signature:
			#   function(my_custom_configure NAME SOURCE_PATH BINARY_PATH INSTALL_PATH)
			#     # ...
			#   endfunction()
			#
			# Optional.
			"CONFIGURE_FUNCTION"

			## Provide a custom function for the patch step.
			# This function is expected to message(FATAL_ERROR) if an error occurs.
			#
			# Function Signature:
			#   function(my_custom_patch NAME SOURCE_PATH BINARY_PATH INSTALL_PATH)
			#     # ...
			#   endfunction()
			#
			# Optional.
			"PATCH_FUNCTION"

			## Provide a custom function for the build step.
			# This function is expected to message(FATAL_ERROR) if an error occurs.
			#
			# Function Signature:
			#   function(my_custom_build NAME SOURCE_PATH BINARY_PATH INSTALL_PATH)
			#     # ...
			#   endfunction()
			#
			# Optional.
			"BUILD_FUNCTION"

			## Provide a custom function for the install step.
			# This function is expected to message(FATAL_ERROR) if an error occurs.
			#
			# Function Signature:
			#   function(my_custom_install NAME SOURCE_PATH BINARY_PATH INSTALL_PATH)
			#     # ...
			#   endfunction()
			#
			# Optional.
			"INSTALL_FUNCTION"
		)
		set(__EC_PARAMS_MULTI
			## (git) Additional options provided to the clone command line.
			# Optional. :)
			"GIT_CLONE_OPTIONS"

			## (git) Additional options provided to the checkout command line.
			# Optional. :)
			"GIT_CHECKOUT_OPTIONS"

			## Provide additional arguments for the configure step.
			# Only used by some build systems.
			#
			# Optional. Ignored if CONFIGURE_FUNCTION is set.
			"CONFIGURE_ARGS"

			## Provide additional arguments for the build step.
			# Only used by some build systems.
			#
			# Optional. Ignored if BUILD_FUNCTION is set.
			"BUILD_ARGS"

			## Provide additional arguments for the install step.
			# Only used by some build systems.
			#
			# Optional. Ignored if INSTALL_FUNCTION is set.
			"INSTALL_ARGS"
		)

		cmake_parse_arguments(PARSE_ARGV 0
			"_EC"
			"${__EC_FLAGS}"
			"${__EC_PARAMS_SINGLE}"
			"${__EC_PARAMS_MULTI}"
		)

		# Validate the NAME parameter
		string(LENGTH "${_EC_NAME}" _EC_NAME_LENGTH)
		if((NOT _EC_NAME) OR (_EC_NAME_LENGTH EQUAL 0))
			message(STATUS "${_EC_NAME} ${_EC_NAME_LENGTH}")
			message(FATAL_ERROR "[EC: ${_EC_NAME}] You must provide a NAME for the external content.")
		endif()

		# Ensure that we have some kind of source for the content.
		string(LENGTH _EC_SOURCE_PATH _EC_SOURCE_PATH_LENGTH)
		string(LENGTH _EC_DOWNLOAD_URL _EC_DOWNLOAD_URL_LENGTH)
		string(LENGTH _EC_GIT_URL _EC_GIT_URL_LENGTH)
		if(
			((NOT _EC_SOURCE_PATH) OR (_EC_SOURCE_PATH_LENGTH EQUAL 0))
		AND ((NOT _EC_DOWNLOAD_URL) OR (_EC_DOWNLOAD_URL_LENGTH EQUAL 0))
		AND ((NOT _EC_GIT_URL) OR (_EC_GIT_URL_LENGTH EQUAL 0)))
			message(FATAL_ERROR "[EC: ${_EC_NAME}] You must provide a source for the external content.")
		endif()

		# Ensure that there's always a path for things.
		string(LENGTH "${_EC_TEMP_PATH}" _EC_TEMP_PATH_LENGTH)
		if((NOT _EC_TEMP_PATH) OR (_EC_TEMP_PATH_LENGTH EQUAL 0))
			set(_EC_TEMP_PATH "${_EC_PREFIX}/${EXTERNALCONTENT_UUID}/${_EC_NAME}.tmp")
		endif()
		string(LENGTH "${_EC_SOURCE_PATH}" _EC_SOURCE_PATH_LENGTH)
		if((NOT _EC_SOURCE_PATH) OR (_EC_SOURCE_PATH_LENGTH EQUAL 0))
			set(_EC_SOURCE_PATH "${_EC_PREFIX}/${EXTERNALCONTENT_UUID}/${_EC_NAME}.src")
		endif()
		string(LENGTH "${_EC_BINARY_PATH}" _EC_BINARY_PATH_LENGTH)
		if((NOT _EC_BINARY_PATH) OR (_EC_BINARY_PATH_LENGTH EQUAL 0))
			set(_EC_BINARY_PATH "${_EC_PREFIX}/${EXTERNALCONTENT_UUID}/${_EC_NAME}.bin")
		endif()
		string(LENGTH "${_EC_INSTALL_PATH}" _EC_INSTALL_PATH_LENGTH)
		if((NOT _EC_INSTALL_PATH) OR (_EC_INSTALL_PATH_LENGTH EQUAL 0))
			set(_EC_INSTALL_PATH "${_EC_PREFIX}/${EXTERNALCONTENT_UUID}/${_EC_NAME}.dst")
		endif()

		# Validate the download URL
		if(_EC_DOWNLOAD_URL)
			ExternalContent_ParseURL(_EC_DOWNLOAD_URL "${_EC_DOWNLOAD_URL}")
			ExternalContent_ParsePath(_EC_DOWNLOAD "_EC_DOWNLOAD_URL_PATH")
			if(_EC_DOWNLOAD_FILE)
				ExternalContent_ParsePath(_EC_DOWNLOAD "_EC_DOWNLOAD_FILE")
			else()
				ExternalContent_ParsePath(_EC_DOWNLOAD "_EC_DOWNLOAD_URL_PATH")
			endif()

			# Set the object that is being used.
			set(_EC_DOWNLOAD_OBJECT "${_EC_TEMP_PATH}/${_EC_DOWNLOAD_FILENAME}")
		endif()

		# Validate the download hash.
		list(LENGTH _EC_DOWNLOAD_HASH _EC_DOWNLOAD_HASH_LENGTH)
		if(_EC_DOWNLOAD_HASH AND (_EC_DOWNLOAD_HASH_LENGTH GREATER 0))
			list(GET _EC_DOWNLOAD_HASH 0 _EC_DOWNLOAD_HASH_TYPE)
			list(GET _EC_DOWNLOAD_HASH 1 _EC_DOWNLOAD_HASH_HASH)
			string(TOLOWER "${_EC_DOWNLOAD_HASH_HASH}" _EC_DOWNLOAD_HASH_HASH)
		elseif(_EC_DOWNLOAD_HASH)
			message(WARNING "[EC: ${_EC_NAME}] DOWNLOAD_HASH set to invalid value '${_EC_DOWNLOAD_HASH}', ignoring.")
			unset(_EC_DOWNLOAD_HASH)
		endif()

		# Validate the git URL
		if(_EC_GIT_URL)
			ExternalContent_ParseURL(_EC_GIT_URL "${_EC_GIT_URL}")

			string(LENGTH _EC_GIT_REF _EC_GIT_REF_LENGTH)
			if(((NOT _EC_GIT_REF) OR (_EC_GIT_REF_LENGTH EQUAL 0)))
				message(FATAL_ERROR "[EC: ${_EC_NAME}] GIT_REF must be set when using git for sanity reasons.")
			endif()
		endif()
	endif()

	# Download and extract the content.
	set(_EC_DOWNLOAD_DIRTY OFF)
	if(NOT _EC_SKIP_DOWNLOAD)
		if(_EC_DOWNLOAD_URL) # download: Download the file and optionally verify the hash.
			# Check if the file actually differs (or is missing)
			if(EXISTS ${_EC_DOWNLOAD_OBJECT})
				if(_EC_DOWNLOAD_HASH)
					file(${_EC_DOWNLOAD_HASH_TYPE} ${_EC_DOWNLOAD_OBJECT} _EC_DOWNLOAD_OBJECT_HASH)
					if(NOT (_EC_DOWNLOAD_OBJECT_HASH STREQUAL _EC_DOWNLOAD_HASH_HASH)) # File hash differs.
						set(_EC_DOWNLOAD_DIRTY ON)
					endif()
				endif()
			else() # File is missing entirely.
				set(_EC_DOWNLOAD_DIRTY ON)
			endif()

			# Also consider things dirty if the source directory is missing.
			if(NOT EXISTS ${_EC_SOURCE_PATH})
				set(_EC_DOWNLOAD_DIRTY ON)
			endif()

			if(_EC_DOWNLOAD_DIRTY)
				message(STATUS "[EC: ${_EC_NAME}] Downloading '${_EC_DOWNLOAD_FILE}' from '${_EC_DOWNLOAD_URL}'...")

				# Download the new file.
				file(DOWNLOAD "${_EC_DOWNLOAD_URL}" "${_EC_DOWNLOAD_OBJECT}" SHOW_PROGRESS)

				# Verify the hash matches.
				if(_EC_DOWNLOAD_HASH)
					file(${_EC_DOWNLOAD_HASH_TYPE} ${_EC_DOWNLOAD_OBJECT} _EC_DOWNLOAD_OBJECT_HASH)
					if(NOT (_EC_DOWNLOAD_OBJECT_HASH STREQUAL _EC_DOWNLOAD_HASH_HASH)) # File hash differs.
						file(REMOVE "${_EC_DOWNLOAD_OBJECT}")
						message(FATAL_ERROR "[EC: ${_EC_NAME}] Downloaded file has hash '${_EC_DOWNLOAD_OBJECT_HASH}' but expected hash '${_EC_DOWNLOAD_HASH_HASH}'. Aborting.")
					endif()
				endif()

				# Remove the previously extracted content.
				if(EXISTS ${_EC_SOURCE_PATH})
					file(REMOVE_RECURSE "${_EC_SOURCE_PATH}")
				endif()

				# Extract the whole thing.
				file(ARCHIVE_EXTRACT
					INPUT "${_EC_DOWNLOAD_OBJECT}"
					DESTINATION "${_EC_SOURCE_PATH}"
					VERBOSE
				)
			else()
				message(STATUS "[EC: ${_EC_NAME}] Skipping download as nothing has changed.")
			endif()
		elseif(_EC_GIT_URL) # git: Clone or Checkout to the specific repository.
			set(_EC_GIT_CLONE_ARGS
				clone
				${_EC_GIT_CLONE_OPTIONS}
				-v
				"${_EC_GIT_URL}"
				"${_EC_SOURCE_PATH}"
			)
			set(_EC_GIT_CHECKOUT_ARGS
				checkout
				${_EC_GIT_CHECKOUT_OPTIONS}
				-f
				${_EC_GIT_REF}
			)

			# Hash the given options.
			string(SHA3_512 _EC_GIT_CLONE_ARGS_HASH "${_EC_SOURCE_PATH} ${_EC_GIT_CLONE_ARGS}")
			string(SHA3_512 _EC_GIT_CHECKOUT_ARGS_HASH "${_EC_SOURCE_PATH} ${_EC_GIT_CHECKOUT_ARGS}")

			# Ensure that the commands still match up.
			if(EXISTS "${_EC_TEMP_PATH}/git-clone.sha3")
				file(READ "${_EC_TEMP_PATH}/git-clone.sha3" _EC_DOWNLOAD_ARGS_HASH_CMP)
				if(NOT (_EC_DOWNLOAD_ARGS_HASH_CMP STREQUAL _EC_DOWNLOAD_ARGS_HASH))
					set(_EC_DOWNLOAD_CLONE_DIRTY ON)
					set(_EC_DOWNLOAD_DIRTY ON)
				endif()
			else()
				set(_EC_DOWNLOAD_CLONE_DIRTY ON)
				set(_EC_DOWNLOAD_DIRTY ON)
			endif()
			if(EXISTS "${_EC_TEMP_PATH}/git-checkout.sha3")
				file(READ "${_EC_TEMP_PATH}/git-checkout.sha3" _EC_DOWNLOAD_ARGS_HASH_CMP)
				if(NOT (_EC_DOWNLOAD_ARGS_HASH_CMP STREQUAL _EC_DOWNLOAD_ARGS_HASH))
					set(_EC_DOWNLOAD_DIRTY ON)
				endif()
			else()
				set(_EC_DOWNLOAD_DIRTY ON)
			endif()

			# Delete the directory if the clone args are dirty or if the directory isn't a git repository
			if((EXISTS "${_EC_SOURCE_PATH}") AND (_EC_DOWNLOAD_CLONE_DIRTY OR (NOT EXISTS "${_EC_SOURCE_PATH}/.git")))
				file(REMOVE_RECURSE "${_EC_SOURCE_PATH}")
				set(_EC_DOWNLOAD_DIRTY ON)
			endif()
			if(NOT EXISTS "${_EC_SOURCE_PATH}")
				# If the directory doesn't exist, we'll treat it as dirty and create it.
				set(_EC_DOWNLOAD_DIRTY ON)
				file(MAKE_DIRECTORY "${_EC_SOURCE_PATH}")
			endif()

			#!TODO: Reduce complex git commands?

			if(_EC_DOWNLOAD_DIRTY)
				# Do we need to clone or checkout?
				if(NOT EXISTS "${_EC_SOURCE_PATH}/.git")
					message(STATUS "[EC: ${_EC_NAME}] Cloning via git...")
					execute_process(
						COMMAND "${GIT_EXECUTABLE}" ${_EC_GIT_CLONE_ARGS}
						WORKING_DIRECTORY "${_EC_SOURCE_PATH}"
						COMMAND_ECHO STDOUT
					)
				else()
					message(STATUS "[EC: ${_EC_NAME}] Checking out via git...")
					execute_process(
						COMMAND "${GIT_EXECUTABLE}" ${_EC_GIT_CHECKOUT_ARGS}
						WORKING_DIRECTORY "${_EC_SOURCE_PATH}"
						COMMAND_ECHO STDOUT
					)
				endif()

				# Write the hash to the cache file.
				file(WRITE "${_EC_TEMP_PATH}/git-clone.sha3" "${_EC_GIT_CLONE_ARGS_HASH}")
				file(WRITE "${_EC_TEMP_PATH}/git-checkout.sha3" "${_EC_GIT_CHECKOUT_ARGS_HASH}")
			else()
				message(STATUS "[EC: ${_EC_NAME}] Skipping download as nothing has changed.")
			endif()
		else()
			message(FATAL_ERROR "[EC: ${_EC_NAME}] Unknown download type but SKIP_DOWNLOAD is not set.")
		endif()
	endif()

	set(_EC_PATCH_DIRTY ${_EC_DOWNLOAD_DIRTY})
	if(NOT _EC_SKIP_PATCH)
		if(_EC_PATCH_FUNCTION)
			cmake_language(EVAL CODE "${_EC_PATCH_FUNCTION}(\"${EC_TEMP_PATH}\" \"${_EC_SOURCE_PATH}\" \"${_EC_BINARY_PATH}\" \"${_EC_INSTALL_PATH}\")")
		endif()
	endif()

	# Configure
	set(_EC_CONFIGURE_DIRTY ${_EC_PATCH_DIRTY})
	if(NOT _EC_SKIP_CONFIGURE)
		if(_EC_CONFIGURE_FUNCTION)
			cmake_language(EVAL CODE "${_EC_CONFIGURE_FUNCTION}(\"${EC_TEMP_PATH}\" \"${_EC_SOURCE_PATH}\" \"${_EC_BINARY_PATH}\" \"${_EC_INSTALL_PATH}\")")
		elseif(EXISTS "${_EC_SOURCE_PATH}/CMakeLists.txt")
			# This is a CMake project.

			set(_EC_CMAKE_ARGS
				-S "${_EC_SOURCE_PATH}"
				-B "${_EC_BINARY_PATH}"
				-Wno-dev
				--no-warn-unused-cli
				--install-prefix "${_EC_INSTALL_PATH}"
				${_EC_CONFIGURE_ARGS}
			)

			# Hash the given options.
			string(SHA3_512 _EC_CONFIGURE_ARGS_HASH "${EC_TEMP_PATH} ${_EC_CMAKE_ARGS}")

			# Ensure we don't spawn useless sub-processes all the time.
			if(EXISTS "${_EC_BINARY_PATH}/CMakeCache.txt")
				if(EXISTS "${_EC_TEMP_PATH}/configure.sha3")
					file(READ "${_EC_TEMP_PATH}/configure.sha3" _EC_CONFIGURE_ARGS_HASH_CMP)
					if(NOT (_EC_CONFIGURE_ARGS_HASH_CMP STREQUAL _EC_CONFIGURE_ARGS_HASH))
						set(_EC_CONFIGURE_DIRTY ON)
					endif()
				endif()
			else()
				set(_EC_CONFIGURE_DIRTY ON)
			endif()

			# Configure & Generate
			if(_EC_CONFIGURE_DIRTY)
				execute_process(
					COMMAND "cmake" ${_EC_CMAKE_ARGS}
					WORKING_DIRECTORY "${_EC_SOURCE_PATH}"
					COMMAND_ECHO STDOUT
				)

				# Write the hash to the cache file.
				file(WRITE "${_EC_TEMP_PATH}/configure.sha3" "${_EC_CONFIGURE_ARGS_HASH}")
			else()
				message(STATUS "[EC: ${_EC_NAME}] Skipping configure as nothing has changed.")
			endif()
		else()
			message(FATAL_ERROR "[EC: ${_EC_NAME}] We don't know how to handle this build system yet. Consider using CONFIGURE_FUNCTION or SKIP_CONFIGURE.")
		endif()
	endif()

	# Build
	set(_EC_BUILD_DIRTY ${_EC_CONFIGURE_DIRTY})
	if(NOT _EC_SKIP_BUILD)
		if(_EC_BUILD_FUNCTION)
			cmake_language(EVAL CODE "${_EC_BUILD_FUNCTION}(\"${EC_TEMP_PATH}\" \"${_EC_SOURCE_PATH}\" \"${_EC_BINARY_PATH}\" \"${_EC_INSTALL_PATH}\")")
		elseif(EXISTS "${_EC_SOURCE_PATH}/CMakeLists.txt")
			# This is a CMake project.

			set(_EC_CMAKE_ARGS
				"--build" "${_EC_BINARY_PATH}"
				${_EC_BUILD_ARGS}
			)

			# Hash the given options.
			string(SHA3_512 _EC_BUILD_ARGS_HASH "${EC_TEMP_PATH} ${_EC_SOURCE_PATH} ${_EC_BINARY_PATH} ${_EC_INSTALL_PATH} ${_EC_CMAKE_ARGS}")

			# Ensure we don't spawn useless sub-processes all the time.
			if(EXISTS "${_EC_TEMP_PATH}/build.sha3")
				file(READ "${_EC_TEMP_PATH}/build.sha3" _EC_BUILD_ARGS_HASH_CMP)
				if(NOT (_EC_BUILD_ARGS_HASH_CMP STREQUAL _EC_BUILD_ARGS_HASH))
					set(_EC_BUILD_DIRTY ON)
				endif()
			else()
				set(_EC_BUILD_DIRTY ON)
			endif()

			# Build
			if(_EC_BUILD_DIRTY)
				execute_process(
					COMMAND "cmake" ${_EC_CMAKE_ARGS}
					WORKING_DIRECTORY "${_EC_BINARY_PATH}"
					COMMAND_ECHO STDOUT
				)

				# Write the hash to the cache file.
				file(WRITE "${_EC_TEMP_PATH}/build.sha3" "${_EC_BUILD_ARGS_HASH}")
			else()
				message(STATUS "[EC: ${_EC_NAME}] Skipping build as nothing has changed.")
			endif()
		else()
			message(FATAL_ERROR "[EC: ${_EC_NAME}] We don't know how to handle this build system yet. Consider using BUILD_FUNCTION or SKIP_BUILD.")
		endif()
	endif()

	# Install
	set(_EC_INSTALL_DIRTY ${_EC_CONFIGURE_DIRTY})
	if(NOT _EC_SKIP_INSTALL)
		if(_EC_INSTALL_FUNCTION)
			cmake_language(EVAL CODE "${_EC_INSTALL_FUNCTION}(\"${EC_TEMP_PATH}\" \"${_EC_SOURCE_PATH}\" \"${_EC_BINARY_PATH}\" \"${_EC_INSTALL_PATH}\")")
		elseif(EXISTS "${_EC_SOURCE_PATH}/CMakeLists.txt")
			# This is a CMake project.

			set(_EC_CMAKE_ARGS
				--install "${_EC_BINARY_PATH}"
				--prefix "${_EC_INSTALL_PATH}"
				${_EC_INSTALL_ARGS}
			)

			# Hash the given options.
			string(SHA3_512 _EC_INSTALL_ARGS_HASH "${EC_TEMP_PATH} ${_EC_SOURCE_PATH} ${_EC_BINARY_PATH} ${_EC_INSTALL_PATH} ${_EC_CMAKE_ARGS}")

			# Ensure we don't spawn useless sub-processes all the time.
			if(EXISTS "${_EC_TEMP_PATH}/install.sha3")
				file(READ "${_EC_TEMP_PATH}/install.sha3" _EC_INSTALL_ARGS_HASH_CMP)
				if(NOT (_EC_INSTALL_ARGS_HASH_CMP STREQUAL _EC_INSTALL_ARGS_HASH))
					set(_EC_INSTALL_DIRTY ON)
				endif()
			else()
				set(_EC_INSTALL_DIRTY ON)
			endif()

			# Install
			if(_EC_INSTALL_DIRTY)
				execute_process(
					COMMAND "cmake" ${_EC_CMAKE_ARGS}
					WORKING_DIRECTORY "${_EC_BINARY_PATH}"
					COMMAND_ECHO STDOUT
				)

				# Write the hash to the cache file.
				file(WRITE "${_EC_TEMP_PATH}/install.sha3" "${_EC_INSTALL_ARGS_HASH}")
			else()
				message(STATUS "[EC: ${_EC_NAME}] Skipping install as nothing has changed.")
			endif()
		else()
			message(FATAL_ERROR "[EC: ${_EC_NAME}] We don't know how to handle this install system yet. Consider using INSTALL_FUNCTION or SKIP_INSTALL.")
		endif()
	endif()

	set(${_EC_NAME}_SOURCE_PATH "${_EC_SOURCE_PATH}" PARENT_SCOPE)
	set(${_EC_NAME}_BINARY_PATH "${_EC_BINARY_PATH}" PARENT_SCOPE)
	set(${_EC_NAME}_INSTALL_PATH "${_EC_INSTALL_PATH}" PARENT_SCOPE)
endfunction()
