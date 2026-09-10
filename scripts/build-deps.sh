#!/bin/bash
set -e

JOBS=$(nproc)
SDL2VER="2.30.12"
SDL2_TTF_VER="2.24.0"
SDL2_IMAGE_VER="2.8.8"
SDL2_MIXER_VER="2.8.1"
SRCDIR="/tmp/fnwf-build"
SYSROOT="/tmp/fnwf-sysroot"

rm -rf "$SRCDIR" "$SYSROOT"
mkdir -p "$SRCDIR" "$SYSROOT"

download_sdl2() {
    local name="$1" ver="$2" repo="$3"
    if [ ! -d "$SRCDIR/$name-$ver" ]; then
        echo ">>> Downloading $name $ver"
        curl -sL "https://github.com/libsdl-org/$repo/releases/download/release-$ver/$name-$ver.tar.gz" \
            -o "$SRCDIR/$name-$ver.tar.gz"
        tar xzf "$SRCDIR/$name-$ver.tar.gz" -C "$SRCDIR"
    fi
}

build_sdl2_unix() {
    local arch="$1" cc="$2" sysroot="$3"
    echo "=== Building SDL2 for $arch ==="
    
    for pkg in "SDL2:$SDL2VER:SDL" "SDL2_ttf:$SDL2_TTF_VER:SDL_ttf" "SDL2_image:$SDL2_IMAGE_VER:SDL_image" "SDL2_mixer:$SDL2_MIXER_VER:SDL_mixer"; do
        IFS=: read -r name ver repo <<< "$pkg"
        download_sdl2 "$name" "$ver" "$repo"
        
        local bdir="$SRCDIR/${name}-${ver}/build-${arch}"
        mkdir -p "$bdir"
        
        echo ">>> Building $name for $arch"
        cd "$bdir"
        cmake .. \
            -DCMAKE_C_COMPILER="$cc" \
            -DCMAKE_SYSTEM_NAME=Linux \
            -DCMAKE_SYSTEM_PROCESSOR="$arch" \
            -DCMAKE_INSTALL_PREFIX="$sysroot" \
            -DCMAKE_BUILD_TYPE=Release \
            -DBUILD_SHARED_LIBS=OFF \
            -DSDL_STATIC=ON \
            -DSDL_SHARED=OFF \
            2>&1 | tail -1
        make -j"$JOBS" 2>&1 | tail -1
        make install 2>&1 | tail -1
        cd /
    done
}

build_sdl2_mingw() {
    echo "=== Building SDL2 for Windows x86_64 ==="
    local sysroot="$SYSROOT/windows-x86_64"
    local cc="x86_64-w64-mingw32-gcc"
    local cxx="x86_64-w64-mingw32-g++"
    
    for pkg in "SDL2:$SDL2VER:SDL" "SDL2_ttf:$SDL2_TTF_VER:SDL_ttf" "SDL2_image:$SDL2_IMAGE_VER:SDL_image" "SDL2_mixer:$SDL2_MIXER_VER:SDL_mixer"; do
        IFS=: read -r name ver repo <<< "$pkg"
        download_sdl2 "$name" "$ver" "$repo"
        
        local bdir="$SRCDIR/${name}-${ver}/build-win64"
        mkdir -p "$bdir"
        
        echo ">>> Building $name for Windows"
        cd "$bdir"
        cmake .. \
            -DCMAKE_C_COMPILER="$cc" \
            -DCMAKE_CXX_COMPILER="$cxx" \
            -DCMAKE_SYSTEM_NAME=Windows \
            -DCMAKE_SYSTEM_PROCESSOR=x86_64 \
            -DCMAKE_INSTALL_PREFIX="$sysroot" \
            -DCMAKE_BUILD_TYPE=Release \
            -DBUILD_SHARED_LIBS=OFF \
            -DSDL_STATIC=ON \
            -DSDL_SHARED=OFF \
            2>&1 | tail -1
        make -j"$JOBS" 2>&1 | tail -1
        make install 2>&1 | tail -1
        cd /
    done
}

build_sdl2_mingw

if [ "$(dpkg --print-architecture)" = "amd64" ]; then
    build_sdl2_unix "aarch64" "aarch64-linux-gnu-gcc" "$SYSROOT/linux-aarch64"
fi

echo ""
echo "=== Sysroots built ==="
du -sh "$SYSROOT"/*
echo ""
echo "Done! Run: ninja -C build-{target}"
