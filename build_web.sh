#!/usr/bin/env bash
# build_web.sh — Build FNWF for WebAssembly using Emscripten
# Run from the project root: bash build_web.sh
set -euo pipefail

cd "$(dirname "$0")"

# Emscripten paths (Termux package)
export PATH="/data/data/com.termux/files/usr/opt/emscripten-binaryen/bin:/data/data/com.termux/files/usr/opt/emscripten-llvm/bin:/data/data/com.termux/files/usr/opt/emscripten:$PATH"
export EM_CONFIG="/data/data/com.termux/files/usr/opt/emscripten/.emscripten"

OUT_DIR="build_web"
mkdir -p "$OUT_DIR"

echo "=== FNWF Web Build ==="
echo "Compiler: $(emcc --version 2>&1 | head -1)"

# Source files
SOURCES=(
    src/main.cpp
    src/engine/Engine.cpp
    src/core/DrawUtils.cpp
    src/core/Localization.cpp
    src/core/MobileUI.cpp
    src/core/SaveManager.cpp
    src/core/SettingsManager.cpp
    src/core/StateMachine.cpp
    src/core/StateRegistry.cpp
    src/core/SoundManager.cpp
    src/systems/Office.cpp
    src/systems/CameraSystem.cpp
    src/systems/Doors.cpp
    src/systems/Animatronics.cpp
    src/systems/Power.cpp
    src/systems/Jumpscare.cpp
    src/game1/states/WarningState.cpp
    src/game1/states/MenuState.cpp
    src/game1/states/GameplayState.cpp
    src/game1/states/OptionsState.cpp
    src/game1/states/CustomNightState.cpp
    src/game1/states/StoryState.cpp
    src/game1/states/LoadingState.cpp
    src/game1/states/NightTransitionState.cpp
    src/game1/states/SixAMState.cpp
    src/game1/states/PaycheckState.cpp
    src/game1/states/NewspaperState.cpp
    src/game1/states/GameOverState.cpp
    src/game1/states/ExtrasState.cpp
    src/game1/states/ConquistasState.cpp
    src/game1/states/ArcadeState.cpp
)

em++ \
    "${SOURCES[@]}" \
    -std=c++23 \
    -Isrc \
    -O2 \
    -sUSE_SDL=2 \
    -sUSE_SDL_TTF=2 \
    -sUSE_SDL_IMAGE=2 \
    -sUSE_SDL_MIXER=2 \
    -sSDL2_IMAGE_FORMATS='["png"]' \
    -sSDL2_MIXER_FORMATS='["ogg"]' \
    -sALLOW_MEMORY_GROWTH=1 \
    -sINITIAL_MEMORY=134217728 \
    -sMAXIMUM_MEMORY=536870912 \
    -sFORCE_FILESYSTEM=1 \
    --preload-file assets \
    -lc++ -lc++abi \
    --shell-file web/shell.html \
    -o "$OUT_DIR/index.html" \
    2>&1

echo ""
echo "=== Build complete ==="
echo "Output: $OUT_DIR/index.html"
echo "To test: cd $OUT_DIR && python3 -m http.server 8080"
echo "Then open http://localhost:8080 in your browser"
