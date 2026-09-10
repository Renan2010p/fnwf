#!/bin/bash
set -e

BINARY="$1"
OUTDIR="$2"
VERSION="$3"
SOURCE="$4"

RELEASE="fnwf-classic-v${VERSION}-linux-x86_64"
PKGDIR="${OUTDIR}/${RELEASE}"

mkdir -p "${PKGDIR}"
cp "${BINARY}" "${PKGDIR}/fnwf"
cp "${SOURCE}/README.txt" "${PKGDIR}/"
[ -d "${SOURCE}/assets" ] && cp -r "${SOURCE}/assets" "${PKGDIR}/"

cd "${OUTDIR}"
tar czf "${RELEASE}.tar.gz" "${RELEASE}"
rm -rf "${PKGDIR}"

echo "Package: ${OUTDIR}/${RELEASE}.tar.gz"
