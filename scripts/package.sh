#!/usr/bin/env bash
# Packages a release archive for the current platform.
#
#   dist/fnwf-<version>-<platform>.tar.gz   (Linux / macOS)
#   dist/fnwf-<version>-<platform>.zip      (Windows/MSYS2, with SDL2 DLLs)
#
# The archive contains the `fnwf` binary, the `assets/` folder, README and
# LICENSE, and a small launcher. The binary finds `assets/` next to itself, so
# the extracted folder is self-contained.
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION=$(sed -n 's/^version = "\(.*\)"/\1/p' Cargo.toml | head -1)
if [ -z "${VERSION}" ]; then
  VERSION="0.0.0"
fi

case "$(uname -s)" in
  Linux*)   OS=linux ;;
  Darwin*)  OS=macos ;;
  MINGW*|MSYS*|CYGWIN*) OS=windows ;;
  *)        OS=unknown ;;
esac
case "$(uname -m)" in
  x86_64|amd64) ARCH=x86_64 ;;
  aarch64|arm64) ARCH=aarch64 ;;
  *) ARCH="$(uname -m)" ;;
esac
PLATFORM="${OS}-${ARCH}"

echo "Packaging fnwf ${VERSION} for ${PLATFORM}"

cargo build --release -p fnwf

BIN="target/release/fnwf"
[ "${OS}" = "windows" ] && BIN="${BIN}.exe"

STAGE="dist/fnwf-${VERSION}-${PLATFORM}"
rm -rf "${STAGE}"
mkdir -p "${STAGE}"
cp "${BIN}" "${STAGE}/"
cp -r assets "${STAGE}/"
cp README.md LICENSE "${STAGE}/"
cp docs/PORTING.md "${STAGE}/PORTING.md" 2>/dev/null || true

if [ "${OS}" = "windows" ]; then
  # Bundle the MinGW SDL2 runtime DLLs so the archive runs without SDL2 installed.
  for dll in SDL2.dll SDL2_ttf.dll SDL2_image.dll SDL2_mixer.dll \
             libfreetype-6.dll libpng16-16.dll zlib1.dll; do
    for dir in /mingw64/bin /ucrt64/bin /clang64/bin; do
      if [ -f "${dir}/${dll}" ]; then
        cp "${dir}/${dll}" "${STAGE}/"
        break
      fi
    done
  done
  cat > "${STAGE}/run.bat" <<'EOF'
@echo off
"%~dp0fnwf.exe" %*
EOF
else
  cat > "${STAGE}/run.sh" <<'EOF'
#!/usr/bin/env bash
cd "$(dirname "$0")"
exec ./fnwf "$@"
EOF
  chmod +x "${STAGE}/run.sh"
fi

mkdir -p dist
if [ "${OS}" = "windows" ]; then
  (cd dist && zip -qr "fnwf-${VERSION}-${PLATFORM}.zip" "fnwf-${VERSION}-${PLATFORM}")
  ARTIFACT="dist/fnwf-${VERSION}-${PLATFORM}.zip"
else
  (cd dist && tar -czf "fnwf-${VERSION}-${PLATFORM}.tar.gz" "fnwf-${VERSION}-${PLATFORM}")
  ARTIFACT="dist/fnwf-${VERSION}-${PLATFORM}.tar.gz"
fi

rm -rf "${STAGE}"
echo "Wrote ${ARTIFACT}"
