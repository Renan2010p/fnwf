#!/bin/bash
set -e

# PS2 Build Script for FNWF
# Uses SDL 1.2 with hardware acceleration flags

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Check environment
if [ -z "$PS2DEV" ]; then
    echo "ERROR: PS2DEV not set"
    exit 1
fi
if [ -z "$PS2SDK" ]; then
    PS2SDK="$PS2DEV/ps2sdk"
fi

export PATH="$PS2DEV/bin:$PS2DEV/ee/bin:$PATH"

echo "=== Building FNWF for PS2 ==="
echo "PS2DEV: $PS2DEV"
echo "PS2SDK: $PS2SDK"
echo "Compiler: $(which mips64r5900el-ps2-elf-gcc)"

# Create meson cross-file
cat > /tmp/ps2-cross-file.ini << CROSS
[binaries]
c = '$PS2DEV/ee/bin/mips64r5900el-ps2-elf-gcc'
cpp = '$PS2DEV/ee/bin/mips64r5900el-ps2-elf-g++'
ar = '$PS2DEV/ee/bin/mips64r5900el-ps2-elf-ar'
strip = '$PS2DEV/ee/bin/mips64r5900el-ps2-elf-strip'
pkg-config = 'pkg-config'

[built-in options]
c_args = ['-D_EE', '-D__PS2__', '-DPS2', '-G0', '-fno-exceptions', '-fno-rtti', '-fno-strict-aliasing', '-O2', '-DNDEBUG', '-I$SCRIPT_DIR/src/platform/ps2/compat', '-I$PS2SDK/ee/include', '-I$PS2SDK/common/include', '-I$PS2SDK/ports/include', '-I$PS2SDK/ports/include/SDL']
cpp_args = ['-D_EE', '-D__PS2__', '-DPS2', '-G0', '-fno-exceptions', '-fno-rtti', '-fno-strict-aliasing', '-std=c++17', '-O2', '-DNDEBUG', '-I$SCRIPT_DIR/src/platform/ps2/compat', '-I$PS2SDK/ee/include', '-I$PS2SDK/common/include', '-I$PS2SDK/ports/include', '-I$PS2SDK/ports/include/SDL']
c_link_args = ['-G0', '-Wl,-zmax-page-size=128', '-T$PS2SDK/ee/startup/linkfile', '-L$PS2SDK/ee/lib', '-L$PS2SDK/common/lib', '-L$PS2SDK/ports/lib', '-lsdl', '-lsdlmixer', '-lSDL_ttf', '-lSDL_image', '-lfreetype', '-lpng', '-lz', '-logg', '-lvorbis', '-lvorbisfile', '-laudsrv', '-lpad', '-lm']
cpp_link_args = ['-G0', '-Wl,-zmax-page-size=128', '-T$PS2SDK/ee/startup/linkfile', '-L$PS2SDK/ee/lib', '-L$PS2SDK/common/lib', '-L$PS2SDK/ports/lib', '-lsdl', '-lsdlmixer', '-lSDL_ttf', '-lSDL_image', '-lfreetype', '-lpng', '-lz', '-logg', '-lvorbis', '-lvorbisfile', '-laudsrv', '-lpad', '-lm']

[properties]
needs_exe_wrapper = true

[host_machine]
system = 'ps2'
cpu_family = 'mips'
cpu = 'r5900'
endian = 'little'
CROSS

# Setup build directory
rm -rf builddir-ps2
meson setup builddir-ps2 --cross-file /tmp/ps2-cross-file.ini -Db_lto=false

# Build
ninja -C builddir-ps2

# Copy assets
if [ -d "assets" ]; then
    cp -r assets builddir-ps2/
fi

# Create ELF copy
cp builddir-ps2/fnwf builddir-ps2/fnwf.elf

echo ""
echo "=== Build complete ==="
echo "ELF: builddir-ps2/fnwf"
echo ""
echo "To test on PCSX2:"
echo "  1. Enable Settings > Emulation > Enable Host Filesystem"
echo "  2. pcsx2 builddir-ps2/fnwf     (assets/ was copied next to the ELF)"
echo ""
echo "To build ISO (needs mkisofs):"
echo "  ./build-ps2.sh --iso"
