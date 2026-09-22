#!/bin/sh
# build-ps2.sh — Build FNWF for PlayStation 2
#
# Prerequisites:
#   1. Install ps2dev toolchain: https://github.com/ps2dev/ps2dev
#   2. Export environment variables:
#      export PS2DEV=/usr/local/ps2dev
#      export PS2SDK=$PS2DEV/ps2sdk
#      export PATH=$PS2DEV/ee/bin:$PS2DEV/iop/bin:$PS2DEV/dvp/bin:$PS2SDK/bin:$PATH
#
# Usage:
#   ./build-ps2.sh          # Build ELF
#   ./build-ps2.sh --iso    # Build ISO image

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

# Check ps2dev
if [ -z "$PS2DEV" ]; then
    echo "ERROR: PS2DEV not set. Install ps2dev and run:"
    echo "  export PS2DEV=/usr/local/ps2dev"
    echo "  export PS2SDK=\$PS2DEV/ps2sdk"
    echo "  export PATH=\$PS2DEV/ee/bin:\$PATH"
    exit 1
fi

EE_BIN="${PS2DEV}/ee/bin"
PREFIX="mips64r5900el-ps2-elf"

echo "=== Building FNWF for PS2 ==="
echo "PS2DEV:  $PS2DEV"
echo "PS2SDK:  $PS2SDK"
echo "Compiler: ${EE_BIN}/${PREFIX}-gcc"

# Verify compiler exists
if [ ! -x "${EE_BIN}/${PREFIX}-gcc" ]; then
    echo "ERROR: Compiler not found at ${EE_BIN}/${PREFIX}-gcc"
    echo "Contents of ${EE_BIN}:"
    ls -la "${EE_BIN}/" 2>/dev/null || echo "(directory not found)"
    exit 1
fi

# Generate cross file with actual paths
CROSS_FILE="/tmp/ps2-cross-file.ini"
cat > "$CROSS_FILE" << EOF
[binaries]
c = '${EE_BIN}/${PREFIX}-gcc'
cpp = '${EE_BIN}/${PREFIX}-g++'
ar = '${EE_BIN}/${PREFIX}-ar'
strip = '${EE_BIN}/${PREFIX}-strip'
pkg-config = 'pkg-config'

[built-in options]
c_args = ['-D_EE', '-D__PS2__', '-DPS2', '-march=r5900', '-mabi=eabi', '-mno-abicalls', '-fno-pic', '-mgp32', '-mfp32', '-G0', '-fno-exceptions', '-fno-rtti', '-fno-strict-aliasing', '-O2', '-DNDEBUG', '-I${SCRIPT_DIR}/src/platform/ps2/compat', '-I${PS2SDK}/ee/include', '-I${PS2SDK}/common/include', '-I${PS2SDK}/ports/include', '-I${PS2SDK}/ports/include/SDL']
cpp_args = ['-D_EE', '-D__PS2__', '-DPS2', '-march=r5900', '-mabi=eabi', '-mno-abicalls', '-fno-pic', '-mgp32', '-mfp32', '-G0', '-fno-exceptions', '-fno-rtti', '-fno-strict-aliasing', '-std=c++17', '-O2', '-DNDEBUG', '-I${SCRIPT_DIR}/src/platform/ps2/compat', '-I${PS2SDK}/ee/include', '-I${PS2SDK}/common/include', '-I${PS2SDK}/ports/include', '-I${PS2SDK}/ports/include/SDL']
c_link_args = ['-march=r5900', '-mabi=eabi', '-mno-abicalls', '-fno-pic', '-mgp32', '-mfp32', '-G0', '-fno-lto', '-Wl,-melf32lr5900', '-L${PS2SDK}/ee/lib', '-L${PS2SDK}/common/lib', '-L${PS2SDK}/ports/lib', '-lsdl', '-lsdlmixer', '-lSDL_ttf', '-lfreetype', '-lpng', '-lz', '-logg', '-lvorbis', '-lvorbisfile', '-laudsrv', '-lpad', '-lm']
cpp_link_args = ['-march=r5900', '-mabi=eabi', '-mno-abicalls', '-fno-pic', '-mgp32', '-mfp32', '-G0', '-fno-lto', '-Wl,-melf32lr5900', '-L${PS2SDK}/ee/lib', '-L${PS2SDK}/common/lib', '-L${PS2SDK}/ports/lib', '-lsdl', '-lsdlmixer', '-lSDL_ttf', '-lfreetype', '-lpng', '-lz', '-logg', '-lvorbis', '-lvorbisfile', '-laudsrv', '-lpad', '-lm']

[properties]
needs_exe_wrapper = true

[host_machine]
system = 'ps2'
cpu_family = 'mips'
cpu = 'r5900'
endian = 'little'
EOF

# Clean
rm -rf builddir-ps2

# Configure with generated cross file
meson setup builddir-ps2 --cross-file "$CROSS_FILE" -Db_lto=false

# Build
ninja -C builddir-ps2

# Clean up cross file after build
rm -f "$CROSS_FILE"

echo ""
echo "=== Build complete ==="
echo "ELF: builddir-ps2/fnwf"
echo ""
echo "To test on PCSX2:"
echo "  pcsx2 builddir-ps2/fnwf"
echo ""
echo "To build ISO (needs mkisofs):"
echo "  mkdir -p iso/"
echo "  cp builddir-ps2/fnwf iso/"
echo "  mkisofs -o fnwf-ps2.iso -R iso/"

# Optionally build ISO
if [ "$1" = "--iso" ]; then
    echo "Building ISO..."
    mkdir -p iso/
    cp builddir-ps2/fnwf iso/
    mkisofs -o fnwf-ps2.iso -R iso/
    echo "ISO: fnwf-ps2.iso"
fi
