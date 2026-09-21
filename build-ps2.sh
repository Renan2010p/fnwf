#!/bin/bash
# build-ps2.sh — Build FNWF for PlayStation 2
#
# Prerequisites:
#   1. Install ps2dev toolchain: https://github.com/ps2dev/ps2dev
#   2. Export environment variables:
#      export PS2DEV=/usr/local/ps2dev
#      export PS2SDK=$PS2DEV/ps2sdk
#      export PATH=$PS2DEV/bin:$PATH
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
    echo "  export PATH=\$PS2DEV/bin:\$PATH"
    exit 1
fi

echo "=== Building FNWF for PS2 ==="
echo "PS2DEV:  $PS2DEV"
echo "PS2SDK:  $PS2SDK"

# Generate cross file with actual paths
CROSS_FILE=$(mktemp /tmp/ps2-cross-XXXXXX.ini)
cat > "$CROSS_FILE" << EOF
[binaries]
c = '${PS2DEV}/bin/mips64r5900-ee-gcc'
cpp = '${PS2DEV}/bin/mips64r5900-ee-g++'
ar = '${PS2DEV}/bin/mips64r5900-ee-ar'
strip = '${PS2DEV}/bin/mips64r5900-ee-strip'
pkgconfig = 'pkg-config'

[properties]
c_args = [
    '-D__PS2__',
    '-DPS2',
    '-march=r5900',
    '-mabi=eabi',
    '-mgp32',
    '-mfp32',
    '-G0',
    '-fno-exceptions',
    '-fno-rtti',
    '-fno-strict-aliasing',
    '-O2',
    '-DNDEBUG',
]
cpp_args = [
    '-D__PS2__',
    '-DPS2',
    '-march=r5900',
    '-mabi=eabi',
    '-mgp32',
    '-mfp32',
    '-G0',
    '-fno-exceptions',
    '-fno-rtti',
    '-fno-strict-aliasing',
    '-std=c++17',
    '-O2',
    '-DNDEBUG',
]
c_link_args = [
    '-march=r5900',
    '-mabi=eabi',
    '-mgp32',
    '-mfp32',
    '-G0',
    '-L${PS2SDK}/ee/lib',
    '-L${PS2SDK}/common/lib',
]
cpp_link_args = [
    '-march=r5900',
    '-mabi=eabi',
    '-mgp32',
    '-mfp32',
    '-G0',
    '-L${PS2SDK}/ee/lib',
    '-L${PS2SDK}/common/lib',
]

[host_machine]
system = 'ps2'
cpu_family = 'mips'
cpu = 'r5900'
endian = 'little'
EOF

# Clean
rm -rf builddir-ps2

# Configure with generated cross file
meson setup builddir-ps2 --cross-file "$CROSS_FILE"

rm -f "$CROSS_FILE"

# Build
ninja -C builddir-ps2

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
