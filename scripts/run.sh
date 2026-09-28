#!/usr/bin/env bash
# Run FNWF from the repository root so that ./assets resolves.
set -euo pipefail
cd "$(dirname "$0")/.."
exec cargo run --release -- "$@"
