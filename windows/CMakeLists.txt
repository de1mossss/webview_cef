# The Flutter tooling requires that developers have a version of Visual Studio
# installed that includes CMake 3.14 or later. You should not increase this
# version, as doing so will cause the plugin to fail to compile for some
# customers of the plugin.
cmake_minimum_required(VERSION 3.14)

# Project-level configuration.
set(PROJECT_NAME "webview_cef")
project(${PROJECT_NAME} LANGUAGES CXX)

# Download/extract CEF (official Spotify CDN build with headers + source)
include(${CMAKE_CURRENT_SOURCE_DIR}/../third/download.cmake)
prepare_prebuilt_files(${CMAKE_CURRENT_SOURCE_DIR}/../third/cef)

# Setup CEF cmake integration
set(CEF_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/../third/cef")
set(CMAKE_MODULE_PATH ${CMAKE_MODULE_PATH} "${CEF_ROOT}/cmake")
find_package(CEF REQUIRED)

# This value is used when generating builds using this plugin, so it must
# not be changed
set(PLUGIN_NAME "webview_cef_plugin")

# Any new source files that you add to the plugin should be added here.
list(APPEND PLUGIN_SOURCES
  "webview_cef_plugin.cpp"
  "webview_cef_plugin.h"
  "webview_cef_keyevent.h"
  "${CMAKE_CURRENT_LIST_DIR}/../common/webview_app.cc"
  "${CMAKE_CURRENT_LIST_DIR}/../common/webview_app.h"
  "${CMAKE_CURRENT_LIST_DIR}/../common/webview_handler.cc"
  "${CMAKE_CURRENT_LIST_DIR}/../common/webview_handler.h"
  "${CMAKE_CURRENT_LIST_DIR}/../common/webview_plugin.cc"
  "${CMAKE_CURRENT_LIST_DIR}/../common/webview_plugin.h"
  "${CMAKE_CURRENT_LIST_DIR}/../common/webview_value.cc"
  "${CMAKE_CURRENT_LIST_DIR}/../common/webview_value.h"
  "${CMAKE_CURRENT_LIST_DIR}/../common/webview_js_handler.cc"
  "${CMAKE_CURRENT_LIST_DIR}/../common/webview_js_handler.h"
  "${CMAKE_CURRENT_LIST_DIR}/../common/webview_cookieVisitor.cc"
  "${CMAKE_CURRENT_LIST_DIR}/../common/webview_cookieVisitor.h"
)

# Define the plugin library target. Its name must not be changed (see comment
# on PLUGIN_NAME above).
add_library(${PLUGIN_NAME} SHARED
  "include/webview_cef/webview_cef_plugin_c_api.h"
  "webview_cef_plugin_c_api.cpp"
  ${PLUGIN_SOURCES}
)

# Apply a standard set of build settings that are configured in the
# application-level CMakeLists.txt. This can be removed for plugins that want
# full control over build settings.
apply_standard_settings(${PLUGIN_NAME})

# Symbols are hidden by default to reduce the chance of accidental conflicts
# between plugins. This should not be removed; any symbols that should be
# exported should be explicitly exported with the FLUTTER_PLUGIN_EXPORT macro.
set_target_properties(${PLUGIN_NAME} PROPERTIES
  CXX_VISIBILITY_PRESET hidden)
target_compile_definitions(${PLUGIN_NAME} PRIVATE FLUTTER_PLUGIN_IMPL)

# Source include directories and library dependencies.
target_include_directories(${PLUGIN_NAME} INTERFACE
  "${CMAKE_CURRENT_SOURCE_DIR}/include")
target_include_directories(${PLUGIN_NAME} PRIVATE
  "${CEF_ROOT}"
  "${CMAKE_CURRENT_SOURCE_DIR}/../common")

#########################################cef#########################################

# Build libcef_dll_wrapper from source (official CEF package includes source)
ADD_LOGICAL_TARGET("libcef_lib" "${CEF_LIB_DEBUG}" "${CEF_LIB_RELEASE}")
SET_CEF_TARGET_OUT_DIR()

# Force /MD (dynamic runtime) to match Flutter. CEF cmake hardcodes /MT in
# compiler flags which causes LNK2038 "RuntimeLibrary mismatch" with Flutter.
# Replace /MT→/MD in all flag variables BEFORE add_subdirectory so that
# libcef_dll_wrapper inherits /MD.
if(MSVC)
  foreach(flag_var
      CMAKE_CXX_FLAGS CMAKE_CXX_FLAGS_DEBUG CMAKE_CXX_FLAGS_RELEASE
      CMAKE_CXX_FLAGS_MINSIZEREL CMAKE_CXX_FLAGS_RELWITHDEBINFO
      CMAKE_C_FLAGS CMAKE_C_FLAGS_DEBUG CMAKE_C_FLAGS_RELEASE
      CMAKE_C_FLAGS_MINSIZEREL CMAKE_C_FLAGS_RELWITHDEBINFO
      CEF_COMPILER_FLAGS CEF_COMPILER_FLAGS_DEBUG CEF_COMPILER_FLAGS_RELEASE)
    if(${flag_var})
      string(REPLACE "/MT" "/MD" ${flag_var} "${${flag_var}}")
    endif()
  endforeach()
endif()

add_subdirectory(${CEF_LIBCEF_DLL_WRAPPER_PATH} libcef_dll_wrapper)

add_dependencies(${PLUGIN_NAME} libcef_dll_wrapper)
target_link_libraries(${PLUGIN_NAME} PRIVATE flutter flutter_wrapper_plugin
  libcef_lib libcef_dll_wrapper ${CEF_STANDARD_LIBS})

#######################################cef end#######################################

# Collect CEF binary and resource files for bundling.
# Official CEF 130 layout: Debug/*.dll, Release/*.dll, Resources/*

set(cef_library_list "")

# Resources are the same for all build configurations.
foreach(FILE ${CEF_RESOURCE_FILES})
  if(IS_DIRECTORY "${CEF_RESOURCE_DIR}/${FILE}")
    list(APPEND cef_library_list "${CEF_RESOURCE_DIR}/${FILE}")
  else()
    list(APPEND cef_library_list "${CEF_RESOURCE_DIR}/${FILE}")
  endif()
endforeach()

# Binaries differ between Debug and Release. Use generator expressions so
# Visual Studio multi-config builds pick the right set.
foreach(FILE ${CEF_BINARY_FILES})
  list(APPEND cef_library_list "$<$<CONFIG:Debug>:${CEF_BINARY_DIR_DEBUG}/${FILE}>")
  list(APPEND cef_library_list "$<$<NOT:$<CONFIG:Debug>>:${CEF_BINARY_DIR_RELEASE}/${FILE}>")
endforeach()

# List of absolute paths to libraries that should be bundled with the plugin.
set(webview_cef_bundled_libraries
  ${cef_library_list}
  PARENT_SCOPE)
