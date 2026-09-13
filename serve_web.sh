#!/usr/bin/env bash
# serve_web.sh — Start HTTP server for FNWF web build (persistent)
# Usage: bash serve_web.sh [port]
set -euo pipefail

cd "$(dirname "$0")"
PORT="${1:-8080}"
DIR="build_web"

if [ ! -f "$DIR/fnwf.html" ]; then
    echo "Error: $DIR/fnwf.html not found. Run build_web.sh first."
    exit 1
fi

pkill -f "python3 -m http.server $PORT" 2>/dev/null || true
sleep 0.5

cd "$DIR"
echo "Serving FNWF on http://0.0.0.0:$PORT"
exec python3 -m http.server "$PORT" --bind 0.0.0.0
