#!/usr/bin/env bash
# ── FNWF Release Packager ──
# Usage: ./package.sh [linux|windows|all]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/build"
RELEASE_DIR="$SCRIPT_DIR/release"
VERSION=$(grep "version" "$SCRIPT_DIR/meson.build" | head -1 | sed "s/.*'\(.*\)'.*/\1/")
PLATFORM="${1:-linux}"

log() { echo -e "\033[1;36m→ $1\033[0m"; }

# ── Ensure build exists ──
if [ ! -f "$BUILD_DIR/build.ninja" ]; then
  log "Configuring Meson build..."
  meson setup "$BUILD_DIR" --wipe 2>/dev/null || meson setup "$BUILD_DIR"
fi

log "Building fnwf v$VERSION..."
meson compile -C "$BUILD_DIR"

# ── Helper: package one platform ──
package_linux() {
  local DEST="$RELEASE_DIR/fnwf-linux"
  log "Packaging Linux release → $DEST"

  rm -rf "$DEST"
  mkdir -p "$DEST/bin"
  mkdir -p "$DEST/assets"

  cp "$BUILD_DIR/fnwf" "$DEST/bin/fnwf"
  chmod +x "$DEST/bin/fnwf"

  cp -r "$SCRIPT_DIR/assets/"* "$DEST/assets/" 2>/dev/null || true

  cat > "$DEST/run.sh" << 'RUNEOF'
#!/bin/bash
cd "$(dirname "$0")"
./bin/fnwf "$@"
RUNEOF
  chmod +x "$DEST/run.sh"

  cp "$SCRIPT_DIR/README.txt" "$DEST/"
  cp "$SCRIPT_DIR/LICENSE" "$DEST/" 2>/dev/null || true

  # Copy SDL2 shared libs if found
  for lib in libSDL2-2.0.so.0 libSDL2_ttf-2.0.so.0 libSDL2_image-2.0.so.0 libSDL2_mixer-2.0.so.0; do
    find /usr/lib /usr/lib64 /usr/local/lib -name "$lib*" 2>/dev/null | while read -r f; do
      cp -L "$f" "$DEST/bin/" 2>/dev/null || true
    done
  done

  # Create tarball
  cd "$RELEASE_DIR"
  tar -czf "fnwf-linux-v${VERSION}.tar.gz" "fnwf-linux"
  log "Created fnwf-linux-v${VERSION}.tar.gz"
}

package_windows() {
  local DEST="$RELEASE_DIR/fnwf-windows"
  log "Packaging Windows release → $DEST"

  rm -rf "$DEST"
  mkdir -p "$DEST/bin"
  mkdir -p "$DEST/assets"

  # Try to find cross-compiled binary or native Windows build
  if [ -f "$BUILD_DIR/fnwf.exe" ]; then
    cp "$BUILD_DIR/fnwf.exe" "$DEST/bin/fnwf.exe"
  elif command -v x86_64-w64-mingw32-g++ &>/dev/null; then
    log "Cross-compiling for Windows..."
    (
      cd "$SCRIPT_DIR"
      rm -rf build-win
      meson setup build-win --cross-file meson-cross-windows.ini 2>/dev/null && \
      meson compile -C build-win && \
      cp build-win/fnwf.exe "$DEST/bin/fnwf.exe"
    )
  else
    log "WARNING: No Windows binary found. Place fnwf.exe in $DEST/bin/"
    echo "To cross-compile, install mingw-w64 and create meson-cross-windows.ini"
  fi

  cp -r "$SCRIPT_DIR/assets/"* "$DEST/assets/" 2>/dev/null || true

  # Copy SDL2 DLLs from common locations
  for dll in SDL2.dll SDL2_ttf.dll SDL2_image.dll SDL2_mixer.dll; do
    find /usr/x86_64-w64-mingw32/lib /usr/lib/gcc/x86_64-w64-mingw32 \
         /mingw64/bin /c/msys64/mingw64/bin \
         -name "$dll" 2>/dev/null | while read -r f; do
      cp "$f" "$DEST/bin/" 2>/dev/null || true
    done
  done

  cat > "$DEST/run.bat" << 'RUNEOF'
@echo off
cd "%~dp0"
bin\fnwf.exe %*
RUNEOF

  cp "$SCRIPT_DIR/README.txt" "$DEST/"
  cp "$SCRIPT_DIR/LICENSE" "$DEST/" 2>/dev/null || true

  # Create zip
  cd "$RELEASE_DIR"
  if command -v zip &>/dev/null; then
    zip -r "fnwf-windows-v${VERSION}.zip" "fnwf-windows"
    log "Created fnwf-windows-v${VERSION}.zip"
  else
    log "Install 'zip' to create .zip archive, or manually zip $DEST"
  fi
}

# ── Main ──
mkdir -p "$RELEASE_DIR"

case "$PLATFORM" in
  linux)   package_linux ;;
  windows) package_windows ;;
  all)     package_linux; package_windows ;;
  *)       echo "Usage: $0 [linux|windows|all]"; exit 1 ;;
esac

log "Done!"
