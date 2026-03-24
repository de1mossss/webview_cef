if(CMAKE_SYSTEM_NAME STREQUAL "Linux")
    message(STATUS "[webview_cef] current system is Linux")
    if(CMAKE_HOST_SYSTEM_PROCESSOR STREQUAL "aarch64")
        set(cef_prebuilt_path "https://cef-builds.spotifycdn.com/cef_binary_130.1.2%2Bg48f3ef6%2Bchromium-130.0.6723.44_linuxarm64.tar.bz2")
        set(cef_prebuilt_version "cef_binary_130.1.2%2Bg48f3ef6%2Bchromium-130.0.6723.44_linuxarm64.tar.bz2")
        set(cef_prebuilt_ext ".tar.bz2")
    else()
        set(cef_prebuilt_path "https://cef-builds.spotifycdn.com/cef_binary_130.1.2%2Bg48f3ef6%2Bchromium-130.0.6723.44_linux64.tar.bz2")
        set(cef_prebuilt_version "cef_binary_130.1.2%2Bg48f3ef6%2Bchromium-130.0.6723.44_linux64.tar.bz2")
        set(cef_prebuilt_ext ".tar.bz2")
    endif()
elseif(CMAKE_SYSTEM_NAME STREQUAL "Windows")
    message(STATUS "[webview_cef] current system is Windows")
    set(cef_prebuilt_path "https://cef-builds.spotifycdn.com/cef_binary_130.1.2%2Bg48f3ef6%2Bchromium-130.0.6723.44_windows64.tar.bz2")
    set(cef_prebuilt_version "cef_binary_130.1.2%2Bg48f3ef6%2Bchromium-130.0.6723.44_windows64.tar.bz2")
    set(cef_prebuilt_ext ".tar.bz2")
endif()
set(cef_prebuilt_version_path "https://github.com/hlwhl/webview_cef/releases/download/prebuilt_cef_bin_linux/version.txt")


function(extract_file filename extract_dir)
    message(STATUS "[webview_cef] Extracting ${filename} to ${extract_dir} ...")

    set(temp_dir ${CMAKE_BINARY_DIR}/tmp_for_extract.dir)
    if(EXISTS ${temp_dir})
        file(REMOVE_RECURSE ${temp_dir})
    endif()
    file(MAKE_DIRECTORY ${temp_dir})

    # Use system tar on Linux for reliable .tar.bz2 extraction (cmake -E tar
    # can silently fail on large bzip2 archives depending on cmake build config)
    if(CMAKE_SYSTEM_NAME STREQUAL "Linux")
        execute_process(
            COMMAND tar xf "${filename}"
            WORKING_DIRECTORY ${temp_dir}
            RESULT_VARIABLE tar_result
        )
        if(NOT tar_result EQUAL 0)
            message(FATAL_ERROR "[webview_cef] tar extraction failed with code ${tar_result}")
        endif()
    else()
        execute_process(
            COMMAND ${CMAKE_COMMAND} -E tar xf "${filename}"
            WORKING_DIRECTORY ${temp_dir}
            RESULT_VARIABLE tar_result
        )
        if(NOT tar_result EQUAL 0)
            message(FATAL_ERROR "[webview_cef] cmake tar extraction failed with code ${tar_result}")
        endif()
    endif()

    # Find the single extracted subdirectory (e.g. cef_binary_130.../),
    # then copy its contents into extract_dir.
    file(GLOB contents "${temp_dir}/*")
    list(LENGTH contents n)
    if(NOT n EQUAL 1 OR NOT IS_DIRECTORY "${contents}")
        set(contents "${temp_dir}")
    endif()

    get_filename_component(contents ${contents} ABSOLUTE)

    # Use cp -a on Linux for reliable recursive copy; file(INSTALL) on others.
    if(CMAKE_SYSTEM_NAME STREQUAL "Linux")
        execute_process(
            COMMAND bash -c "cp -a '${contents}/'* '${extract_dir}/'"
            RESULT_VARIABLE cp_result
        )
        if(NOT cp_result EQUAL 0)
            message(FATAL_ERROR "[webview_cef] cp failed with code ${cp_result}")
        endif()
    else()
        file(INSTALL "${contents}/" DESTINATION ${extract_dir})
    endif()

    file(REMOVE_RECURSE ${temp_dir})
endfunction()

function(download_file url filename)
    message(STATUS "[webview_cef] Downloading CEF binaries (this may take a few minutes)...")
    file(DOWNLOAD ${url} ${filename} STATUS dl_status)
    list(GET dl_status 0 dl_code)
    if(NOT dl_code EQUAL 0)
        list(GET dl_status 1 dl_msg)
        message(FATAL_ERROR "[webview_cef] Download failed: ${dl_msg}")
    endif()
endfunction(download_file)

function(prepare_prebuilt_files filepath)
    set(need_download FALSE)

    if(NOT EXISTS ${filepath})
        message(STATUS "[webview_cef] No ${filepath} found, will download")
        set(need_download TRUE)
    else()
        if(NOT EXISTS ${filepath}/version.txt)
            message(STATUS "[webview_cef] No ${filepath}/version.txt found")
            set(need_download TRUE)
        else()
            file(READ ${filepath}/version.txt local_version)
            string(STRIP "${local_version}" local_version)
            if(local_version STREQUAL cef_prebuilt_version)
                message(STATUS "[webview_cef] CEF binaries up to date")
            else()
                set(need_download TRUE)
            endif()
        endif()
    endif()

    if(need_download)
        message(STATUS "[webview_cef] Downloading and extracting CEF binaries...")
        # Remove both old custom-zip dirs (lowercase) and official CEF dirs (capitalized)
        file(REMOVE_RECURSE
            ${filepath}/cmake ${filepath}/Debug ${filepath}/Release ${filepath}/Resources
            ${filepath}/include ${filepath}/libcef_dll ${filepath}/libcef_dll_wrapper
            ${filepath}/debug ${filepath}/release ${filepath}/resources)

        set(archive_file "${CMAKE_CURRENT_SOURCE_DIR}/prebuilt${cef_prebuilt_ext}")
        download_file(${cef_prebuilt_path} ${archive_file})
        file(MAKE_DIRECTORY ${filepath})
        extract_file(${archive_file} ${filepath})

        ## Needed for making it run on arm64 Linux (makes it check for arm64 or aarch64 instead of just arm64)
        if(CMAKE_SYSTEM_NAME STREQUAL "Linux")
            execute_process(
                COMMAND sed -i "s/\"\\\${CMAKE_HOST_SYSTEM_PROCESSOR}\" STREQUAL \"arm64\"/(\"\\\${CMAKE_HOST_SYSTEM_PROCESSOR}\" STREQUAL \"arm64\" OR \"\\\${CMAKE_HOST_SYSTEM_PROCESSOR}\" STREQUAL \"aarch64\")/" ${filepath}/cmake/cef_variables.cmake
                WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
            )
        endif()

        file(WRITE "${filepath}/version.txt" "${cef_prebuilt_version}")
        file(REMOVE_RECURSE ${archive_file})
    endif()
endfunction(prepare_prebuilt_files)
