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

    # Patch out thread requirement check (PS2 has no pthreads)
    sed -i 's/message_error("ERROR: Threads are needed/message(STATUS "Threads check skipped/' \
        cmake/macros.cmake

    cmake -B build -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_TOOLCHAIN_FILE="${SCRIPT_DIR}/cross/ps2-cmake-toolchain.cmake" \
        -DCMAKE_INSTALL_PREFIX="${PREFIX}" \
        -DCMAKE_POLICY_VERSION_MINIMUM=3.5
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

    # Find the ELF and verify
    ELF=$(find "${BUILD_DIR}/game" -name 'fnwf' -o -name 'fnwf.elf' | head -1)
    if [ -n "${ELF}" ]; then
        echo "=== ELF verification ==="
        echo "File: ${ELF}"
        file "${ELF}" 2>/dev/null || true
        mips64r5900el-ps2-elf-readelf -h "${ELF}" 2>/dev/null | grep -E "Entry|Machine|Type" || true
        mips64r5900el-ps2-elf-nm "${ELF}" 2>/dev/null | grep -E "__start|main|SDL_main" || true
        mips64r5900el-ps2-elf-readelf -l "${ELF}" 2>/dev/null || true
        echo ""
    fi

    # Package
    mkdir -p "${OUTPUT_DIR}"

    # Create ISO disc structure
    DISC_DIR="${BUILD_DIR}/disc"
    rm -rf "${DISC_DIR}"
    mkdir -p "${DISC_DIR}"

    # SYSTEM.CNF for PS2 disc boot
    cat > "${DISC_DIR}/SYSTEM.CNF" << 'EOF'
BOOT2 = cdrom0:\FNWF.ELF;1
VER = 1.00
VMODE = NTSC
EOF

    # Copy ELF as FNWF.ELF (PS2 convention: uppercase, 8.3)
    cp "${BUILD_DIR}/game/fnwf.elf" "${DISC_DIR}/FNWF.ELF" 2>/dev/null || \
    cp "${BUILD_DIR}/game/fnwf" "${DISC_DIR}/FNWF.ELF"

    # Copy assets directory
    cp -r "${SCRIPT_DIR}/assets" "${DISC_DIR}/assets"

    # Generate ISO9660 disc image
    echo "=== Creating PS2 ISO ==="
    genisoimage -iso-level 2 -J -joliet-long \
        -o "${OUTPUT_DIR}/fnwf-ps2.iso" \
        -V "FNWF" \
        "${DISC_DIR}"
    echo "=== ISO created ==="
    ls -la "${OUTPUT_DIR}/fnwf-ps2.iso"

    # Also keep raw ELF
    cp "${BUILD_DIR}/game/fnwf.elf" "${OUTPUT_DIR}/fnwf.elf" 2>/dev/null || \
    cp "${BUILD_DIR}/game/fnwf" "${OUTPUT_DIR}/fnwf.elf"

    echo "=== PS2 build complete ==="
    echo "ISO:   ${OUTPUT_DIR}/fnwf-ps2.iso"
    echo "ELF:   ${OUTPUT_DIR}/fnwf.elf"
    echo ""
    echo "To run on PCSX2:"
    echo "  1. CDVD > ISO Selector > Browse > select fnwf-ps2.iso"
    echo "  2. System > Boot CDVD (full)"
    echo ""
    echo "To run on real PS2:"
    echo "  1. Burn fnwf-ps2.iso to DVD-R"
    echo "  2. Boot with FreeMCBoot or modchip"
}

build_sdl2_ps2
build_game_ps2
