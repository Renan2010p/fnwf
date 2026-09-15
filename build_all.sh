#!/usr/bin/env bash
# build_all.sh — Build for all supported platforms
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_BASE="${SCRIPT_DIR}/build"
RELEASE_DIR="${SCRIPT_DIR}/release"

usage() {
    echo "Usage: $0 [target]"
    echo "Targets:"
    echo "  linux      - Linux x86_64 (default)"
    echo "  linux-arm  - Linux ARM64"
    echo "  windows    - Windows x86_64 (MinGW)"
    echo "  macos      - macOS universal"
    echo "  web        - WebAssembly/Emscripten"
    echo "  all        - Build all platforms"
    exit 1
}

build_linux() {
    local arch="${1:-x86_64}"
    echo "=== Building for Linux ${arch} ==="
    local build_dir="${BUILD_BASE}/linux-${arch}"
    rm -rf "${build_dir}"
    meson setup "${build_dir}" --buildtype=release
    ninja -C "${build_dir}"
    echo "✓ Linux ${arch} built"
}

build_windows() {
    echo "=== Building for Windows x86_64 ==="
    local build_dir="${BUILD_BASE}/windows"
    rm -rf "${build_dir}"
    # Use MinGW-w64 cross-compile if available, otherwise native
    if command -v x86_64-w64-mingw32-gcc &>/dev/null; then
        meson setup "${build_dir}" --cross-file="${SCRIPT_DIR}/cross/mingw64.ini" --buildtype=release
    else
        echo "WARNING: MinGW not found, building natively"
        meson setup "${build_dir}" --buildtype=release
    fi
    ninja -C "${build_dir}"
    echo "✓ Windows built"
}

build_macos() {
    echo "=== Building for macOS ==="
    local build_dir="${BUILD_BASE}/macos"
    rm -rf "${build_dir}"
    meson setup "${build_dir}" --buildtype=release
    ninja -C "${build_dir}"
    echo "✓ macOS built"
}

build_web() {
    echo "=== Building for Web (WASM) ==="
    if ! command -v emcc &>/dev/null; then
        echo "ERROR: Emscripten not found. Install with: https://emscripten.org/"
        exit 1
    fi
    local build_dir="${BUILD_BASE}/web"
    rm -rf "${build_dir}"
    mkdir -p "${build_dir}"

    em++ \
        src/main.cpp src/engine/Engine.cpp \
        src/core/DrawUtils.cpp src/core/Localization.cpp \
        src/core/SaveManager.cpp src/core/SettingsManager.cpp \
        src/core/StateMachine.cpp src/core/StateRegistry.cpp \
        src/core/SoundManager.cpp src/core/Platform.cpp \
        src/core/InputManager.cpp \
        src/systems/Office.cpp src/systems/CameraSystem.cpp \
        src/systems/Doors.cpp src/systems/Animatronics.cpp \
        src/systems/Power.cpp src/systems/Jumpscare.cpp \
        src/game1/states/*.cpp \
        -std=c++23 -Isrc -O2 \
        -sUSE_SDL=2 -sUSE_SDL_TTF=2 -sUSE_SDL_IMAGE=2 -sUSE_SDL_MIXER=2 \
        -sSDL2_IMAGE_FORMATS='["png"]' \
        -sSDL2_MIXER_FORMATS='["ogg"]' \
        -sALLOW_MEMORY_GROWTH=1 \
        -sINITIAL_MEMORY=134217728 \
        -sFORCE_FILESYSTEM=1 \
        --preload-file assets \
        -lc++ -lc++abi \
        --shell-file web/shell.html \
        -o "${build_dir}/index.html"

    echo "✓ Web built"
}

package_linux() {
    local arch="${1:-x86_64}"
    local release="fnwf-classic-$(grep "version" meson.build | head -1 | sed "s/.*'\(.*\)'.*/\1/")-linux-${arch}"
    mkdir -p "${RELEASE_DIR}/${release}"
    cp "build/linux-${arch}/fnwf" "${RELEASE_DIR}/${release}/"
    cp -r assets "${RELEASE_DIR}/${release}/"
    chmod +x "${RELEASE_DIR}/${release}/fnwf"
    cd "${RELEASE_DIR}" && tar czf "${release}.tar.gz" "${release}"
    echo "✓ Packaged: ${RELEASE_DIR}/${release}.tar.gz"
}

package_windows() {
    local release="fnwf-classic-$(grep "version" meson.build | head -1 | sed "s/.*'\(.*\)'.*/\1/")-windows"
    mkdir -p "${RELEASE_DIR}/${release}"
    cp "build/windows/fnwf.exe" "${RELEASE_DIR}/${release}/"
    cp -r assets "${RELEASE_DIR}/${release}/"
    cd "${RELEASE_DIR}" && tar czf "${release}.tar.gz" "${release}"
    echo "✓ Packaged: ${RELEASE_DIR}/${release}.tar.gz"
}

package_macos() {
    local release="fnwf-classic-$(grep "version" meson.build | head -1 | sed "s/.*'\(.*\)'.*/\1/")-macos"
    mkdir -p "${RELEASE_DIR}/${release}"
    cp "build/macos/fnwf" "${RELEASE_DIR}/${release}/"
    cp -r assets "${RELEASE_DIR}/${release}/"
    cd "${RELEASE_DIR}" && tar czf "${release}.tar.gz" "${release}"
    echo "✓ Packaged: ${RELEASE_DIR}/${release}.tar.gz"
}

# Main
TARGET="${1:-all}"

case "${TARGET}" in
    linux)
        build_linux "x86_64"
        package_linux "x86_64"
        ;;
    linux-arm)
        build_linux "arm64"
        package_linux "arm64"
        ;;
    windows)
        build_windows
        package_windows
        ;;
    macos)
        build_macos
        package_macos
        ;;
    web)
        build_web
        ;;
    all)
        build_linux "x86_64"
        build_linux "arm64"
        build_windows
        build_macos
        build_web
        package_linux "x86_64"
        package_linux "arm64"
        package_windows
        package_macos
        ;;
    *)
        usage
        ;;
esac

echo ""
echo "=== Build complete ==="
echo "Output directory: ${RELEASE_DIR}"
ls -la "${RELEASE_DIR}"/*.tar.gz 2>/dev/null || true
