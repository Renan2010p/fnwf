#!/bin/bash
set -e

BINARY="$1"
OUTDIR="$2"
VERSION="$3"
SOURCE="$4"
PLATFORM="${5:-linux-x86_64}"

RELEASE="fnwf-classic-v${VERSION}-${PLATFORM}"
PKGDIR="${OUTDIR}/${RELEASE}"

mkdir -p "${PKGDIR}"
cp "${BINARY}" "${PKGDIR}/fnwf"
cp "${SOURCE}/README.txt" "${PKGDIR}/"
[ -d "${SOURCE}/assets" ] && cp -r "${SOURCE}/assets" "${PKGDIR}/"

# Copy SDL2 shared libs for Windows builds
if [[ "$PLATFORM" == *"windows"* ]]; then
    for dll in SDL2.dll SDL2_ttf.dll SDL2_image.dll SDL2_mixer.dll \
               libfreetype-6.dll libpng16-16.dll zlib1.dll; do
        cp "/mingw64/bin/${dll}" "${PKGDIR}/" 2>/dev/null || true
    done
fi

cd "${OUTDIR}"
tar czf "${RELEASE}.tar.gz" "${RELEASE}"
rm -rf "${PKGDIR}"

echo "Package: ${OUTDIR}/${RELEASE}.tar.gz"
