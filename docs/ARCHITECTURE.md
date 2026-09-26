# Architecture

Five Nights With Friends (Classic Edition) is a portable C++17 game. The game
code never talks to SDL, the GPU or the OS directly — it only talks to the
`Engine` interface. Each platform provides its own backend.

```
        src/game1/  src/systems/  src/core/
                     |
                     v
             Engine (src/engine/Engine.hpp)
              /                    \
   src/platform/sdl2/        src/platform/ps2/
 (Linux/Windows/macOS/Web)   (PlayStation 2, gsKit)
```

## Layers

- **`src/engine/`** — the pure-abstract `Engine` interface: window, timing,
  input events, 2D primitives, textures, fonts, sound, render targets. No
  platform headers are included here.
- **`src/core/`** — engine-agnostic services: `DrawUtils` (sprites, text,
  effects), `StateMachine`, `SaveManager`, `SettingsManager`, `Localization`,
  `SoundManager`, `Platform`.
- **`src/systems/`** — the gameplay subsystems: `Office`, `CameraSystem`,
  `Doors`, `Power`, `Animatronics`, `Jumpscare`.
- **`src/game1/`** — the state machine states (menu, story, gameplay, loading,
  options, …) plus `GameSettings` (colors, constants, asset paths).
- **`src/platform/`** — the concrete backends:
  - `sdl2/` — desktop, web and mobile. SDL2 + SDL2_ttf/image/mixer. Supports
    the cylindrical office projection and offscreen render targets.
  - `ps2/` — PlayStation 2. SDL is used only for timers, image decoding and
    text rasterisation; **all drawing goes through gsKit to the GS**. The
    office is drawn flat and effects go straight to the screen because the GS
    has only 4MB of VRAM and no cheap cylindrical warp.

## Capabilities

Backends advertise what they can do so the shared game code can adapt without
`#ifdef`s:

- `supports_cylindrical_office()` — PS2 returns `false` (flat office).
- `supports_offscreen_targets()` — PS2 returns `false`; the office and camera
  draw directly to the screen.
- `set_draw_offset()` — temporary translation, used by the direct-to-screen
  camera monitor.

## Assets

`assets/` holds PNG sprites, an OGG audio set and a TTF font. `DrawUtils`
caches sprites in RAM; `SoundManager` caches sounds. On PS2 everything is
preloaded at boot so the slow DVD never stutters gameplay.

## Build

Meson. The platform backend is selected from `host_machine.system()` in
`meson.build`. See the root `README.txt` for per-platform instructions and
`docs/PS2-BUILD.md` for the PlayStation 2 toolchain.
