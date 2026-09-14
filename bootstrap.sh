#!/usr/bin/env bash
# bootstrap.sh — Download and build SDL2 + deps from source (static)
# Run once before building: ./bootstrap.sh
set -euo pipefail

PREFIX="$(pwd)/deps"
SRC="$(pwd)/build_deps"
JOBS="${JOBS:-$(nproc 2>/dev/null || echo 4)}"

mkdir -p "$PREFIX" "$SRC"

download() {
    local name="$1" url="$2" hash="$3"
    local file="$SRC/$name.tar.gz"
    if [ ! -f "$file" ]; then
        echo "=== Downloading $name ==="
        curl -sL -o "$file" "$url"
    fi
    echo "=== Extracting $name ==="
    tar xzf "$file" -C "$SRC"
}

build_sdl2() {
    local ver="2.30.8"
    download "SDL2-$ver" \
        "https://github.com/libsdl-org/SDL/releases/download/release-$ver/SDL2-$ver.tar.gz" \
        ""

    echo "=== Building SDL2 $ver ==="
    cd "$SRC/SDL2-$ver"
    cmake -B build -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX="$PREFIX" \
        -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
        -DSDL_SHARED=OFF -DSDL_STATIC=ON \
        -DSDL_TEST=OFF -DSDL_TESTS=OFF \
        -DSDL_EXAMPLES=OFF -DSDL_FRAMEWORK=OFF \
        -DSDL_AUDIO=ON -DSDL_VIDEO=ON -DSDL_RENDER=ON \
        -DSDL_OPENGLES=OFF -DSDL_VULKAN=OFF -DSDL_METAL=OFF \
        -DSDL_OFFSCREEN=OFF -DSDL_UNIX_CONSOLE_BUILD=OFF \
        -DSDL_LIBC=ON -DSDL_SYSTEM_ICONV=OFF \
        -DSDL_HIDAPI=OFF -DSDL_JOYSTICK=OFF -DSDL_HAPTIC=OFF \
        -DSDL_SENSOR=OFF -DSDL_POWER=ON -DSDL_FILESYSTEM=ON \
        -DSDL_THREADS=ON -DSDL_TIMERS=ON -DSDL_FILE=ON \
        -DSDL_CPUINFO=ON -DSDL_ASSEMBLY=ON
    cmake --build build -j "$JOBS"
    cmake --install build
    cd /
}

build_ttf() {
    local ver="2.22.0"
    download "SDL2_ttf-$ver" \
        "https://github.com/libsdl-org/SDL_ttf/releases/download/release-$ver/SDL2_ttf-$ver.tar.gz" \
        ""

    echo "=== Building SDL2_ttf $ver ==="
    cd "$SRC/SDL2_ttf-$ver"
    cmake -B build -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX="$PREFIX" \
        -DCMAKE_PREFIX_PATH="$PREFIX" \
        -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
        -DSDL2TTF_VENDORED=ON \
        -DSDL2TTF_SAMPLES=OFF \
        -DBUILD_SHARED_LIBS=OFF
    cmake --build build -j "$JOBS"
    cmake --install build
    cd /
}

build_image() {
    local ver="2.8.2"
    download "SDL2_image-$ver" \
        "https://github.com/libsdl-org/SDL_image/releases/download/release-$ver/SDL2_image-$ver.tar.gz" \
        ""

    echo "=== Building SDL2_image $ver ==="
    cd "$SRC/SDL2_image-$ver"
    cmake -B build -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX="$PREFIX" \
        -DCMAKE_PREFIX_PATH="$PREFIX" \
        -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
        -DSDL2IMAGE_VENDORED=ON \
        -DSDL2IMAGE_SAMPLES=OFF \
        -DSDL2IMAGE_PNG=ON -DSDL2IMAGE_JPG=ON -DSDL2IMAGE_BMP=ON \
        -DBUILD_SHARED_LIBS=OFF
    cmake --build build -j "$JOBS"
    cmake --install build
    cd /
}

build_mixer() {
    local ver="2.8.0"
    download "SDL2_mixer-$ver" \
        "https://github.com/libsdl-org/SDL_mixer/releases/download/release-$ver/SDL2_mixer-$ver.tar.gz" \
        ""

    echo "=== Building SDL2_mixer $ver ==="
    cd "$SRC/SDL2_mixer-$ver"
    if [ ! -d external/ogg ]; then
        echo "=== Downloading libogg for SDL2_mixer ==="
        git clone --depth 1 https://github.com/xiph/ogg.git external/ogg
    fi
    cmake -B build -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX="$PREFIX" \
        -DCMAKE_PREFIX_PATH="$PREFIX" \
        -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
        -DSDL2MIXER_VENDORED=ON \
        -DSDL2MIXER_SAMPLES=OFF \
        -DSDL2MIXER_OGG=ON -DSDL2MIXER_MP3=ON -DSDL2MIXER_FLAC=OFF -DSDL2MIXER_OPUS=OFF \
        -DSDL2MIXER_MOD=OFF -DSDL2MIXER_MID=OFF -DSDL2MIXER_WAV=ON -DSDL2MIXER_CMD=OFF \
        -DBUILD_SHARED_LIBS=OFF
    cmake --build build -j "$JOBS"
    cmake --install build
    cd /
}

build_sdl2
build_ttf
build_image
build_mixer

echo ""
echo "=== All dependencies built in: $PREFIX ==="
echo "=== Build the game with: ==="
echo "  export PKG_CONFIG_PATH=\"$PREFIX/lib/pkgconfig:\$PKG_CONFIG_PATH\""
echo "  meson setup build --buildtype=release"
echo "  meson compile -C build"
