#!/usr/bin/env bash
# Builds the WebAssembly bundle.
#
# Requires the Emscripten-free toolchain:
#   rustup target add wasm32-unknown-unknown
#   cargo install wasm-bindgen-cli --version <same as wasm-bindgen in Cargo.lock>
#
# Output: web/pkg/ (JS glue + .wasm). Serve the repository root, e.g.:
#   python3 -m http.server 8000
# then open http://localhost:8000/
set -euo pipefail
cd "$(dirname "$0")/.."

if ! command -v wasm-bindgen >/dev/null 2>&1; then
  echo "error: 'wasm-bindgen' CLI not found." >&2
  echo "Install it with: cargo install wasm-bindgen-cli" >&2
  echo "(the version must match the wasm-bindgen crate in Cargo.lock)" >&2
  exit 1
fi

rustup target add wasm32-unknown-unknown
cargo build -p fnwf --release --target wasm32-unknown-unknown

wasm-bindgen \
  --target web \
  --no-typescript \
  --out-dir web/pkg \
  target/wasm32-unknown-unknown/release/fnwf_app.wasm

echo "Built web/pkg. Serve the repository root and open http://localhost:8000/"
