#!/usr/bin/env bash
# Builds a self-contained Linux AppImage for the current architecture.
#
#   dist/fnwf-<version>-<arch>.AppImage
#
# The AppDir bundles the binary, the assets and the non-system shared libraries
# needed at runtime (SDL2 and friends); glibc, the dynamic loader, OpenGL and
# X11/Wayland are intentionally taken from the host. appimagetool is downloaded
# on first use and cached under ~/.cache/fnwf.
set -euo pipefail
cd "$(dirname "$0")/.."

case "$(uname -m)" in
  x86_64|amd64) AI_ARCH=x86_64 ;;
  aarch64|arm64) AI_ARCH=aarch64 ;;
  *) AI_ARCH="$(uname -m)" ;;
esac

VERSION=$(sed -n 's/^version = "\(.*\)"/\1/p' Cargo.toml | head -1)
[ -n "${VERSION}" ] || VERSION="0.0.0"

echo "Building fnwf ${VERSION} AppImage (${AI_ARCH})"
cargo build --release -p fnwf
BIN="target/release/fnwf"

APPDIR="build/AppDir"
rm -rf "${APPDIR}"
mkdir -p "${APPDIR}/usr/bin" "${APPDIR}/usr/lib"
cp "${BIN}" "${APPDIR}/usr/bin/fnwf"
cp -r assets "${APPDIR}/assets"
cp assets/eser.png "${APPDIR}/fnwf.png"

cat > "${APPDIR}/fnwf.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=Five Nights With Friends
Comment=Classic Edition — written in Rust
Exec=fnwf
Icon=fnwf
Categories=Game;
Terminal=false
EOF

cat > "${APPDIR}/AppRun" <<'EOF'
#!/bin/sh
HERE="$(dirname "$(readlink -f "$0")")"
export LD_LIBRARY_PATH="$HERE/usr/lib:${LD_LIBRARY_PATH:-}"
cd "$HERE"
exec ./usr/bin/fnwf "$@"
EOF
chmod +x "${APPDIR}/AppRun"

# --- Bundle non-system libraries (recursive closure) ------------------------
EXCLUDE='ld-linux|libc\.so|libm\.so|libdl\.so|libpthread|librt\.so|libresolv|libnsl|libanl|libcrypt|libutil|libgcc_s|libstdc\+\+|libGL|libEGL|libGLX|libGLdispatch|libOpenGL|libX11|libxcb|libXau|libXdmcp|libwayland|libdrm|libselinux|libsystemd|libudev|libdbus|libglib|libgio|libgobject|libgmodule|libffi|libpcre'

copy_deps() {
  local target="$1"
  ldd "$target" 2>/dev/null | awk '/=>/ {print $3}' | while read -r lib; do
    [ -f "$lib" ] || continue
    local base
    base="$(basename "$lib")"
    if echo "$base" | grep -Eq "$EXCLUDE"; then
      continue
    fi
    if [ ! -f "${APPDIR}/usr/lib/${base}" ]; then
      cp "$lib" "${APPDIR}/usr/lib/${base}"
    fi
  done
}

copy_deps "${BIN}"
for _ in 1 2 3 4 5; do
  for lib in "${APPDIR}"/usr/lib/*.so*; do
    [ -f "$lib" ] || continue
    copy_deps "$lib"
  done
done
echo "Bundled libraries:"; ls "${APPDIR}/usr/lib" | sed 's/^/  /'

# --- appimagetool -----------------------------------------------------------
TOOL="${APPIMAGETOOL:-$HOME/.cache/fnwf/appimagetool-${AI_ARCH}.AppImage}"
if [ ! -x "${TOOL}" ]; then
  mkdir -p "$(dirname "${TOOL}")"
  echo "Downloading appimagetool..."
  curl -fsSL \
    "https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-${AI_ARCH}.AppImage" \
    -o "${TOOL}"
  chmod +x "${TOOL}"
fi

mkdir -p dist
OUT="dist/fnwf-${VERSION}-${AI_ARCH}.AppImage"
rm -f "${OUT}"
ARCH="${AI_ARCH}" "${TOOL}" --appimage-extract-and-run "${APPDIR}" "${OUT}"
echo "Wrote ${OUT}"
