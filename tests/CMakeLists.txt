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

# Tests for ExternalContent. Each test runs at configure time, so a successful
# configure means every test passed. Configure twice to also test that nothing
# is downloaded again when nothing changed.

cmake_minimum_required(VERSION 4.2.0)
project(ExternalContentTests LANGUAGES NONE)

include("${CMAKE_CURRENT_SOURCE_DIR}/../ExternalContent.cmake")

function(ExternalContentTest_Expect NAME PATH)
	if(NOT EXISTS "${PATH}")
		message(FATAL_ERROR "[Test: ${NAME}] Expected '${PATH}' to exist.")
	endif()
	message(STATUS "[Test: ${NAME}] Found '${PATH}'.")
endfunction()

# URL: Download an archive, verify its hash and extract it.
ExternalContent(
	NAME "url"
	DOWNLOAD_URL "https://github.com/madler/zlib/releases/download/v1.3.1/zlib-1.3.1.tar.gz"
	DOWNLOAD_HASH "SHA256;9a93b2b7dfdac77ceba5a558a580e74667dd6fede4585b91eefb60f03b72df23"
	SKIP_CONFIGURE
	SKIP_BUILD
	SKIP_INSTALL
)
ExternalContentTest_Expect("url" "${url_TEMP_PATH}/zlib-1.3.1.tar.gz")
ExternalContentTest_Expect("url" "${url_SOURCE_PATH}/zlib-1.3.1/zlib.h")

# Git: Clone a tag, then configure, build and install it as a CMake project.
ExternalContent(
	NAME "git"
	GIT_URL "https://github.com/madler/zlib.git"
	GIT_REF "v1.3.1"
	GIT_CLONE_OPTIONS --depth 1
	CONFIGURE_ARGS
		-DCMAKE_BUILD_TYPE=Release
		-DCMAKE_POLICY_VERSION_MINIMUM=3.5
)
ExternalContentTest_Expect("git" "${git_SOURCE_PATH}/.git")
ExternalContentTest_Expect("git" "${git_SOURCE_PATH}/zlib.h")
ExternalContentTest_Expect("git" "${git_BINARY_PATH}/CMakeCache.txt")
ExternalContentTest_Expect("git" "${git_INSTALL_PATH}/include/zlib.h")
