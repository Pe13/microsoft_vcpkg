if(NOT _VCPKG_IOS_TOOLCHAIN)
    set(_VCPKG_IOS_TOOLCHAIN 1)

    if(POLICY CMP0056)
        cmake_policy(SET CMP0056 NEW)
    endif()
    if(POLICY CMP0066)
        cmake_policy(SET CMP0066 NEW)
    endif()
    if(POLICY CMP0067)
        cmake_policy(SET CMP0067 NEW)
    endif()
    if(POLICY CMP0137)
        cmake_policy(SET CMP0137 NEW)
    endif()
    list(APPEND CMAKE_TRY_COMPILE_PLATFORM_VARIABLES
        VCPKG_CRT_LINKAGE VCPKG_TARGET_ARCHITECTURE
        VCPKG_C_FLAGS VCPKG_CXX_FLAGS
        VCPKG_C_FLAGS_DEBUG VCPKG_CXX_FLAGS_DEBUG
        VCPKG_C_FLAGS_RELEASE VCPKG_CXX_FLAGS_RELEASE
        VCPKG_LINKER_FLAGS VCPKG_LINKER_FLAGS_RELEASE VCPKG_LINKER_FLAGS_DEBUG
    )

    # Set the CMAKE_SYSTEM_NAME for try_compile calls.
    set(CMAKE_SYSTEM_NAME iOS CACHE STRING "")

    macro(_vcpkg_setup_ios_arch arch)
        unset(_vcpkg_ios_system_processor)
        unset(_vcpkg_ios_sysroot)
        unset(_vcpkg_ios_target_architecture)

        if ("${arch}" STREQUAL "arm64")
            set(_vcpkg_ios_system_processor "aarch64")
            set(_vcpkg_ios_target_architecture "arm64")
        elseif("${arch}" STREQUAL "arm64_32")
            set(_vcpkg_ios_system_processor "aarch64")
            set(_vcpkg_ios_target_architecture "arm64_32")
        elseif("${arch}" STREQUAL "arm")
            set(_vcpkg_ios_system_processor "arm")
            set(_vcpkg_ios_target_architecture "armv7")
        elseif("${arch}" STREQUAL "armv7k")
            set(_vcpkg_ios_system_processor "arm")
            set(_vcpkg_ios_target_architecture "armv7k")
        elseif("${arch}" STREQUAL "x64")
            set(_vcpkg_ios_system_processor "x86_64")
            set(_vcpkg_ios_sysroot "iphonesimulator")
            set(_vcpkg_ios_target_architecture "x86_64")
        elseif("${arch}" STREQUAL "x86")
            set(_vcpkg_ios_system_processor "i386")
            set(_vcpkg_ios_sysroot "iphonesimulator")
            set(_vcpkg_ios_target_architecture "i386")
        else()
            message(FATAL_ERROR
                    "Unknown VCPKG_TARGET_ARCHITECTURE value provided for triplet ${VCPKG_TARGET_TRIPLET}: ${arch}")
        endif()
    endmacro()

    _vcpkg_setup_ios_arch("${VCPKG_TARGET_ARCHITECTURE}")
    if(_vcpkg_ios_system_processor AND NOT CMAKE_SYSTEM_PROCESSOR)
        set(CMAKE_SYSTEM_PROCESSOR ${_vcpkg_ios_system_processor})
    endif()

    if(CMAKE_HOST_SYSTEM_NAME STREQUAL "Linux")
        # 1. Discover iOS Sysroot (iPhoneOS.sdk)
        if(NOT DEFINED VCPKG_OSX_SYSROOT)
            if(DEFINED ENV{VCPKG_IOS_SDK_PATH} AND EXISTS "$ENV{VCPKG_IOS_SDK_PATH}")
                set(VCPKG_OSX_SYSROOT "$ENV{VCPKG_IOS_SDK_PATH}")
            elseif(DEFINED ENV{SDKROOT} AND EXISTS "$ENV{SDKROOT}")
                set(VCPKG_OSX_SYSROOT "$ENV{SDKROOT}")
            elseif(EXISTS "/home/pi/cctools/SDK/iPhoneOS.sdk")
                set(VCPKG_OSX_SYSROOT "/home/pi/cctools/SDK/iPhoneOS.sdk")
            elseif(EXISTS "/home/pi/cctools-port/usage_examples/ios_toolchain/target/SDK/iPhoneOS16.5.sdk")
                set(VCPKG_OSX_SYSROOT "/home/pi/cctools-port/usage_examples/ios_toolchain/target/SDK/iPhoneOS16.5.sdk")
            endif()
        endif()

        if(NOT VCPKG_OSX_SYSROOT OR NOT EXISTS "${VCPKG_OSX_SYSROOT}")
            message(FATAL_ERROR "Cross-compiling for iOS on Linux requires VCPKG_OSX_SYSROOT or environment variable VCPKG_IOS_SDK_PATH / SDKROOT pointing to a valid iPhoneOS.sdk directory.")
        endif()

        set(CMAKE_OSX_SYSROOT "${VCPKG_OSX_SYSROOT}" CACHE PATH "iOS SDK path" FORCE)

        # 2. Deployment target version
        if(NOT DEFINED VCPKG_OSX_DEPLOYMENT_TARGET)
            set(VCPKG_OSX_DEPLOYMENT_TARGET "14.0")
        endif()

        set(Z_VCPKG_IOS_TARGET_TRIPLE "${_vcpkg_ios_target_architecture}-apple-ios${VCPKG_OSX_DEPLOYMENT_TARGET}")

        # 3. Discover cctools-port Compilers and Binutils
        # Include /home/pi/cctools/bin in HINTS in case PATH is not exported
        set(Z_CCTOOLS_HINTS "/home/pi/cctools/bin" "/home/pi/cctools-port/usage_examples/ios_toolchain/target/bin")

        find_program(Z_VCPKG_C_COMPILER NAMES aarch64-apple-darwin-clang clang HINTS ${Z_CCTOOLS_HINTS} REQUIRED)
        find_program(Z_VCPKG_CXX_COMPILER NAMES aarch64-apple-darwin-clang++ clang++ HINTS ${Z_CCTOOLS_HINTS} REQUIRED)

        get_filename_component(Z_CCTOOLS_BIN_DIR "${Z_VCPKG_C_COMPILER}" DIRECTORY)
        if(COMMAND vcpkg_add_to_path)
            vcpkg_add_to_path("${Z_CCTOOLS_BIN_DIR}")
        endif()
        string(FIND "$ENV{PATH}" "${Z_CCTOOLS_BIN_DIR}" _path_idx)
        if(_path_idx EQUAL -1)
            set(ENV{PATH} "${Z_CCTOOLS_BIN_DIR}:$ENV{PATH}")
        endif()

        set(CMAKE_C_COMPILER "${Z_VCPKG_C_COMPILER}" CACHE FILEPATH "C Compiler" FORCE)
        set(CMAKE_CXX_COMPILER "${Z_VCPKG_CXX_COMPILER}" CACHE FILEPATH "C++ Compiler" FORCE)

        set(CMAKE_C_COMPILER_TARGET "${Z_VCPKG_IOS_TARGET_TRIPLE}")
        set(CMAKE_CXX_COMPILER_TARGET "${Z_VCPKG_IOS_TARGET_TRIPLE}")

        find_program(Z_VCPKG_AR NAMES aarch64-apple-darwin-ar HINTS ${Z_CCTOOLS_HINTS} REQUIRED)
        find_program(Z_VCPKG_RANLIB NAMES aarch64-apple-darwin-ranlib HINTS ${Z_CCTOOLS_HINTS} REQUIRED)
        find_program(Z_VCPKG_INSTALL_NAME_TOOL NAMES aarch64-apple-darwin-install_name_tool HINTS ${Z_CCTOOLS_HINTS} REQUIRED)
        find_program(Z_VCPKG_LIPO NAMES aarch64-apple-darwin-lipo HINTS ${Z_CCTOOLS_HINTS} REQUIRED)
        find_program(Z_VCPKG_LD NAMES aarch64-apple-darwin-ld HINTS ${Z_CCTOOLS_HINTS} REQUIRED)
        find_program(Z_VCPKG_STRIP NAMES aarch64-apple-darwin-strip HINTS ${Z_CCTOOLS_HINTS} REQUIRED)

        set(CMAKE_AR "${Z_VCPKG_AR}" CACHE FILEPATH "Archiver" FORCE)
        set(CMAKE_RANLIB "${Z_VCPKG_RANLIB}" CACHE FILEPATH "Ranlib" FORCE)
        set(CMAKE_INSTALL_NAME_TOOL "${Z_VCPKG_INSTALL_NAME_TOOL}" CACHE FILEPATH "Install Name Tool" FORCE)
        set(CMAKE_LIPO "${Z_VCPKG_LIPO}" CACHE FILEPATH "Lipo Tool" FORCE)
        set(CMAKE_LINKER "${Z_VCPKG_LD}" CACHE FILEPATH "Linker" FORCE)
        set(CMAKE_STRIP "${Z_VCPKG_STRIP}" CACHE FILEPATH "Strip Tool" FORCE)

        # 4. Target Flags Init
        set(Z_VCPKG_IOS_FLAGS "-target ${Z_VCPKG_IOS_TARGET_TRIPLE} -isysroot ${VCPKG_OSX_SYSROOT} -miphoneos-version-min=${VCPKG_OSX_DEPLOYMENT_TARGET} -fuse-ld=${Z_VCPKG_LD} -Qunused-arguments")

        string(APPEND CMAKE_C_FLAGS_INIT " ${Z_VCPKG_IOS_FLAGS} -fPIC ${VCPKG_C_FLAGS} ")
        string(APPEND CMAKE_CXX_FLAGS_INIT " ${Z_VCPKG_IOS_FLAGS} -fPIC ${VCPKG_CXX_FLAGS} ")
        string(APPEND CMAKE_C_FLAGS_DEBUG_INIT " ${VCPKG_C_FLAGS_DEBUG} ")
        string(APPEND CMAKE_CXX_FLAGS_DEBUG_INIT " ${VCPKG_CXX_FLAGS_DEBUG} ")
        string(APPEND CMAKE_C_FLAGS_RELEASE_INIT " ${VCPKG_C_FLAGS_RELEASE} ")
        string(APPEND CMAKE_CXX_FLAGS_RELEASE_INIT " ${VCPKG_CXX_FLAGS_RELEASE} ")

        string(APPEND CMAKE_MODULE_LINKER_FLAGS_INIT " ${Z_VCPKG_IOS_FLAGS} ${VCPKG_LINKER_FLAGS} ")
        string(APPEND CMAKE_SHARED_LINKER_FLAGS_INIT " ${Z_VCPKG_IOS_FLAGS} ${VCPKG_LINKER_FLAGS} ")
        string(APPEND CMAKE_EXE_LINKER_FLAGS_INIT " ${Z_VCPKG_IOS_FLAGS} ${VCPKG_LINKER_FLAGS} ")
        string(APPEND CMAKE_MODULE_LINKER_FLAGS_DEBUG_INIT " ${VCPKG_LINKER_FLAGS_DEBUG} ")
        string(APPEND CMAKE_SHARED_LINKER_FLAGS_DEBUG_INIT " ${VCPKG_LINKER_FLAGS_DEBUG} ")
        string(APPEND CMAKE_EXE_LINKER_FLAGS_DEBUG_INIT " ${VCPKG_LINKER_FLAGS_DEBUG} ")
        string(APPEND CMAKE_MODULE_LINKER_FLAGS_RELEASE_INIT " ${VCPKG_LINKER_FLAGS_RELEASE} ")
        string(APPEND CMAKE_SHARED_LINKER_FLAGS_RELEASE_INIT " ${VCPKG_LINKER_FLAGS_RELEASE} ")
        string(APPEND CMAKE_EXE_LINKER_FLAGS_RELEASE_INIT " ${VCPKG_LINKER_FLAGS_RELEASE} ")
    else()
        # If VCPKG_OSX_ARCHITECTURES or VCPKG_OSX_SYSROOT is set in the triplet, they will take priority
        set(CMAKE_OSX_ARCHITECTURES "${_vcpkg_ios_target_architecture}" CACHE STRING "Build architectures for iOS")
        if(_vcpkg_ios_sysroot)
            set(CMAKE_OSX_SYSROOT ${_vcpkg_ios_sysroot} CACHE STRING "iOS sysroot")
        endif()

        string(APPEND CMAKE_C_FLAGS_INIT " -fPIC ${VCPKG_C_FLAGS} ")
        string(APPEND CMAKE_CXX_FLAGS_INIT " -fPIC ${VCPKG_CXX_FLAGS} ")
        string(APPEND CMAKE_C_FLAGS_DEBUG_INIT " ${VCPKG_C_FLAGS_DEBUG} ")
        string(APPEND CMAKE_CXX_FLAGS_DEBUG_INIT " ${VCPKG_CXX_FLAGS_DEBUG} ")
        string(APPEND CMAKE_C_FLAGS_RELEASE_INIT " ${VCPKG_C_FLAGS_RELEASE} ")
        string(APPEND CMAKE_CXX_FLAGS_RELEASE_INIT " ${VCPKG_CXX_FLAGS_RELEASE} ")

        string(APPEND CMAKE_MODULE_LINKER_FLAGS_INIT " ${VCPKG_LINKER_FLAGS} ")
        string(APPEND CMAKE_SHARED_LINKER_FLAGS_INIT " ${VCPKG_LINKER_FLAGS} ")
        string(APPEND CMAKE_EXE_LINKER_FLAGS_INIT " ${VCPKG_LINKER_FLAGS} ")
        string(APPEND CMAKE_MODULE_LINKER_FLAGS_DEBUG_INIT " ${VCPKG_LINKER_FLAGS_DEBUG} ")
        string(APPEND CMAKE_SHARED_LINKER_FLAGS_DEBUG_INIT " ${VCPKG_LINKER_FLAGS_DEBUG} ")
        string(APPEND CMAKE_EXE_LINKER_FLAGS_DEBUG_INIT " ${VCPKG_LINKER_FLAGS_DEBUG} ")
        string(APPEND CMAKE_MODULE_LINKER_FLAGS_RELEASE_INIT " ${VCPKG_LINKER_FLAGS_RELEASE} ")
        string(APPEND CMAKE_SHARED_LINKER_FLAGS_RELEASE_INIT " ${VCPKG_LINKER_FLAGS_RELEASE} ")
        string(APPEND CMAKE_EXE_LINKER_FLAGS_RELEASE_INIT " ${VCPKG_LINKER_FLAGS_RELEASE} ")
    endif()
endif()
