ExternalContent
-------

Download, Configure, Build and Install external content all without polluting the global cache!

Synopsis
^^^^^^^^

.. parsed-literal::

  ExternalContent(
    `NAME` <name>
    [`TEMP_PATH` <path>]
    [`SOURCE_PATH` <path>]
    [`BINARY_PATH` <path>]
    [`INSTALL_PATH` <path>]

    [`SKIP_DOWNLOAD` | 
      [ [`DOWNLOAD_URL` <url> [`DOWNLOAD_FILE` <filename.extension>] [`DOWNLOAD_HASH` <type>:<hash>] ] ] |
      [ [`GIT_URL` <url> [`GIT_REF` <ref>] [`GIT_CLONE_OPTIONS` <option> [<option> [...]]] [`GIT_CHECKOUT_OPTIONS` <option> [<option> [...]]]]]
    ]

    [`SKIP_CONFIGURE` |
      [ `CONFIGURE_FUNCTION` <function-name>]
      [ `CONFIGURE_ARGS` <option> [<option> [...]]]
    ]
    
    [`SKIP_BUILD` |
      [ `BUILD_FUNCTION` <function-name>]
      [ `BUILD_ARGS` <option> [<option> [...]]]
    ]
    
    [`SKIP_INSTALL` |
      [ `INSTALL_FUNCTION` <function-name>]
      [ `INSTALL_ARGS` <option> [<option> [...]]]
    ]
  )

