#!/bin/sh
# Build Five Nights With Friends for the current platform (Linux).
# Produces bin/fnwf-Linux
set -e
cd "$(dirname "$0")"
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release "$@"
cmake --build build -j
printf '\n==> binario: %s\n' "$(ls bin/fnwf-* 2>/dev/null | head -1 || echo 'bin/fnwf-<OS>')"
