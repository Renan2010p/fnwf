#!/bin/bash
# build-ps2.sh — Build FNWF for PlayStation 2
#
# Prerequisites:
#   1. Install ps2dev toolchain: https://github.com/ps2dev/ps2dev
#   2. Export environment variables:
#      export PS2DEV=/usr/local/ps2dev
#      export PS2SDK=$PS2DEV/ps2sdk
#      export PATH=$PS2DEV/bin:$PATH
#   3. Build SDL 1.2 for PS2:
#      cd $PS2SDK/ports
#      # Or use ps2sdk-ports: https://github.com/ps2dev/ps2sdk-ports
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

# Clean
rm -rf builddir-ps2

# Configure with PS2 cross file
meson setup builddir-ps2 \
    --cross-file cross/ps2.ini \
    --wipe 2>/dev/null || \
meson setup builddir-ps2 \
    --cross-file cross/ps2.ini

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
