#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint webview_cef.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'webview_cef'
  s.version          = '0.0.2'
  s.summary          = 'Flutter webview backed by CEF (Chromium Embedded Framework)'
  s.description      = <<-DESC
Flutter webview backed by CEF (Chromium Embedded Framework)
                       DESC
  s.homepage         = 'https://github.com/de1mossss/webview_cef'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'TesAI' => 'dev@tesai.io' }

  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'FlutterMacOS'
  s.vendored_frameworks = 'third/cef/Chromium Embedded Framework.framework'
  s.vendored_libraries = 'third/cef/libcef_dll_wrapper.a'

  $dir = File.dirname(__FILE__)
  $dir = $dir + "/third/cef/**"
  s.xcconfig = { "HEADER_SEARCH_PATHS" => $dir}

  s.platform = :osx, '11.0'
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'CLANG_CXX_LANGUAGE_STANDARD' => 'c++17',
    'EXCLUDED_ARCHS[sdk=macosx*]' => 'x86_64',
  }
  s.swift_version = '5.0'

  # Download CEF 130 macOS arm64 framework from Spotify CDN
  s.prepare_command = <<-SCRIPT
    CEF_URL="https://cef-builds.spotifycdn.com/cef_binary_130.1.2%2Bg48f3ef6%2Bchromium-130.0.6723.44_macosarm64_minimal.tar.bz2"
    CEF_DIR="third/cef"
    FW_DIR="${CEF_DIR}/Chromium Embedded Framework.framework"

    # Check if framework is fully set up (binary + top-level symlinks)
    if [ -f "${FW_DIR}/Versions/A/Chromium Embedded Framework" ] && [ -L "${FW_DIR}/Chromium Embedded Framework" ]; then
      echo "[webview_cef] CEF framework already present, skipping download"
      exit 0
    fi

    # If Versions/A exists but symlinks are missing, skip download but fix symlinks
    if [ -f "${FW_DIR}/Versions/A/Chromium Embedded Framework" ]; then
      echo "[webview_cef] CEF binary present but symlinks missing, fixing..."
    else
      echo "[webview_cef] Downloading CEF 130 macOS arm64 minimal..."
      curl -L -o /tmp/cef_macos.tar.bz2 "${CEF_URL}"

      echo "[webview_cef] Extracting..."
      mkdir -p /tmp/cef_macos_extract
      tar xf /tmp/cef_macos.tar.bz2 -C /tmp/cef_macos_extract

      CEF_SRC=$(ls -d /tmp/cef_macos_extract/cef_binary_*)
      SRC_FW="${CEF_SRC}/Release/Chromium Embedded Framework.framework"

      echo "[webview_cef] Creating deep bundle structure..."
      mkdir -p "${FW_DIR}/Versions/A"
      cp "${SRC_FW}/Chromium Embedded Framework" "${FW_DIR}/Versions/A/"
      cp -R "${SRC_FW}/Libraries" "${FW_DIR}/Versions/A/"
      cp -R "${SRC_FW}/Resources" "${FW_DIR}/Versions/A/"

      echo "[webview_cef] Cleaning up..."
      rm -rf /tmp/cef_macos.tar.bz2 /tmp/cef_macos_extract
    fi

    # Ensure symlinks (always, even if binary was already present)
    cd "${FW_DIR}/Versions" && ln -sf A Current
    cd "${FW_DIR}" && ln -sf "Versions/Current/Chromium Embedded Framework" "Chromium Embedded Framework"
    cd "${FW_DIR}" && ln -sf Versions/Current/Libraries Libraries
    cd "${FW_DIR}" && ln -sf Versions/Current/Resources Resources

    echo "[webview_cef] CEF framework ready"
  SCRIPT
end
