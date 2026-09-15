#!/usr/bin/env bash
# build_ps2.sh — Cross-compile FNWF for PlayStation 2
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="${SCRIPT_DIR}/build_ps2"
OUTPUT_DIR="${SCRIPT_DIR}/release_ps2"

# Verify ps2dev environment
if [ -z "${PS2DEV:-}" ]; then
    echo "ERROR: PS2DEV not set. Install ps2dev first:"
    echo "  git clone https://github.com/ps2dev/ps2dev.git"
    echo "  cd ps2dev && ./build-all.sh"
    exit 1
fi

if [ -z "${PS2SDK:-}" ]; then
    PS2SDK="${PS2DEV}/ps2sdk"
fi

echo "=== PS2 Build ==="
echo "PS2DEV: ${PS2DEV}"
echo "PS2SDK: ${PS2SDK}"

# Build SDL2 + deps for PS2 if not already built
build_sdl2_ps2() {
    local SDL2_VER="2.30.8"
    local SDL2_DIR="${BUILD_DIR}/SDL2-${SDL2_VER}"
    local PREFIX="${PS2SDK}/ports"

    if [ -f "${PREFIX}/lib/libSDL2.a" ]; then
        echo "=== SDL2 already installed for PS2 ==="
        return
    fi

    echo "=== Building SDL2 for PS2 ==="
    if [ ! -d "${SDL2_DIR}" ]; then
        mkdir -p "${BUILD_DIR}"
        curl -sL -o "${BUILD_DIR}/SDL2.tar.gz" \
            "https://github.com/libsdl-org/SDL/releases/download/release-${SDL2_VER}/SDL2-${SDL2_VER}.tar.gz"
        tar xzf "${BUILD_DIR}/SDL2.tar.gz" -C "${BUILD_DIR}"
    fi

    cd "${SDL2_DIR}"
    cmake -B build -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_TOOLCHAIN_FILE="${PS2SDK}/ps2dev.cmake" \
        -DCMAKE_INSTALL_PREFIX="${PREFIX}"
    cmake --build build
    cmake --install build
    cd "${SCRIPT_DIR}"
}

# Build game for PS2
build_game_ps2() {
    echo "=== Building FNWF for PS2 ==="

    # Set environment
    export PATH="${PS2DEV}/ee/bin:${PS2DEV}/bin:${PS2SDK}/bin:${PATH}"

    # Build with meson cross file
    rm -rf "${BUILD_DIR}/game"

    # Expand env vars in cross file for meson (it can't expand $VAR itself)
    cp "${SCRIPT_DIR}/cross/ps2.ini" "${BUILD_DIR}/ps2_cross.ini"
    sed -i "s|\\\$PS2SDK|${PS2SDK}|g" "${BUILD_DIR}/ps2_cross.ini"
    sed -i "s|\\\$PS2DEV|${PS2DEV}|g" "${BUILD_DIR}/ps2_cross.ini"

    meson setup "${BUILD_DIR}/game" \
        --cross-file "${BUILD_DIR}/ps2_cross.ini" \
        --wipe 2>/dev/null || \
    meson setup "${BUILD_DIR}/game" \
        --cross-file "${BUILD_DIR}/ps2_cross.ini"

    meson compile -C "${BUILD_DIR}/game"

    # Package
    mkdir -p "${OUTPUT_DIR}"
    cp "${BUILD_DIR}/game/fnwf.elf" "${OUTPUT_DIR}/" 2>/dev/null || \
    cp "${BUILD_DIR}/game/fnwf" "${OUTPUT_DIR}/fnwf.elf"

    echo "=== PS2 build complete ==="
    echo "Output: ${OUTPUT_DIR}/fnwf.elf"
    echo ""
    echo "To run on PS2:"
    echo "  1. Copy fnwf.elf to USB drive"
    echo "  2. Launch uLaunchELF on PS2 (FreeMcBoot)"
    echo "  3. Browse to USB and launch fnwf.elf"
    echo ""
    echo "To run on PCSX2:"
    echo "  1. Config > USB > Enable host filesystem"
    echo "  2. File > Boot ELF > select fnwf.elf"
}

build_sdl2_ps2
build_game_ps2
