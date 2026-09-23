#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ -z "$PS2DEV" ]; then
    echo "ERROR: PS2DEV not set"
    exit 1
fi
if [ -z "$PS2SDK" ]; then
    PS2SDK="$PS2DEV/ps2sdk"
fi
if [ -z "$GSKIT" ]; then
    GSKIT="$PS2DEV/gsKit"
fi

export PATH="$PS2DEV/bin:$PS2DEV/ee/bin:$PATH"

echo "=== Building FNWF for PS2 ==="
echo "PS2DEV: $PS2DEV"
echo "PS2SDK: $PS2SDK"

# Create meson cross-file
cat > /tmp/ps2-cross-file.ini << CROSS
[binaries]
c = '$PS2DEV/ee/bin/mips64r5900el-ps2-elf-gcc'
cpp = '$PS2DEV/ee/bin/mips64r5900el-ps2-elf-g++'
ar = '$PS2DEV/ee/bin/mips64r5900el-ps2-elf-ar'
strip = '$PS2DEV/ee/bin/mips64r5900el-ps2-elf-strip'

[built-in options]
c_args = ['-D_EE', '-D__PS2__', '-DPS2', '-G0', '-fno-exceptions', '-fno-rtti', '-O2', '-DNDEBUG', '-I$SCRIPT_DIR/src/platform/ps2/compat', '-I$PS2SDK/ee/include', '-I$PS2SDK/common/include', '-I$PS2SDK/ports/include', '-I$PS2SDK/ports/include/SDL', '-I$GSKIT/include']
cpp_args = ['-D_EE', '-D__PS2__', '-DPS2', '-G0', '-fno-exceptions', '-fno-rtti', '-std=c++17', '-O2', '-DNDEBUG', '-I$SCRIPT_DIR/src/platform/ps2/compat', '-I$PS2SDK/ee/include', '-I$PS2SDK/common/include', '-I$PS2SDK/ports/include', '-I$PS2SDK/ports/include/SDL', '-I$GSKIT/include']
c_link_args = ['-G0', '-Wl,-zmax-page-size=128', '-T$PS2SDK/ee/startup/linkfile', '-L$PS2SDK/ee/lib', '-L$PS2SDK/common/lib', '-L$PS2SDK/ports/lib', '-L$GSKIT/lib', '-lsdl', '-lsdlmixer', '-lSDL_ttf', '-lSDL_image', '-lfreetype', '-lpng', '-lz', '-logg', '-lvorbis', '-lvorbisfile', '-laudsrv', '-lpad', '-lgskit', '-ldmakit', '-lm']
cpp_link_args = ['-G0', '-Wl,-zmax-page-size=128', '-T$PS2SDK/ee/startup/linkfile', '-L$PS2SDK/ee/lib', '-L$PS2SDK/common/lib', '-L$PS2SDK/ports/lib', '-L$GSKIT/lib', '-lsdl', '-lsdlmixer', '-lSDL_ttf', '-lSDL_image', '-lfreetype', '-lpng', '-lz', '-logg', '-lvorbis', '-lvorbisfile', '-laudsrv', '-lpad', '-lgskit', '-ldmakit', '-lm']

[properties]
needs_exe_wrapper = true

[host_machine]
system = 'ps2'
cpu_family = 'mips'
cpu = 'r5900'
endian = 'little'
CROSS

rm -rf builddir-ps2
meson setup builddir-ps2 --cross-file /tmp/ps2-cross-file.ini -Db_lto=false
ninja -C builddir-ps2

if [ -d "assets" ]; then
    cp -r assets builddir-ps2/
fi

cp builddir-ps2/fnwf builddir-ps2/fnwf.elf

echo ""
echo "=== Build complete ==="
echo "ELF: builddir-ps2/fnwf.elf"
echo ""
echo "To test on PCSX2:"
echo "  1. Enable Settings > Emulation > Enable Host Filesystem"
echo "  2. File > Run ELF... > builddir-ps2/fnwf.elf"
