# Five Nights With Friends 1

A *Five Nights at Freddy's*-style horror game starring your friends as the night
animatronics. The native engine is **C++26 + SDL2**; the entire game logic —
states, AI, power, cameras, doors — is written in **Lua**.

## License notice

- **Engine & game code (C++, Lua)**: **Open source** — licensed under the
  [GPL-3.0](LICENSE). You are free to use, modify and redistribute it, provided
  derived works stay GPL-3.0.
- **Game assets (sounds, character/animatronic art, images, fonts)**: **Proprietary**.
  They belong to their respective owners and are **not** covered by the open
  license. Do **not** redistribute them. The engine loads everything from
  `assets/` at runtime, so you can drop in your own licensed assets.

> Engine code = open. Assets = proprietary. Keep that boundary in mind.

## Architecture

- **Engine (C++26 + SDL2)** — `src/`: exposes a single native `Engine` object to Lua
  (window, render, textures, fonts, audio, events).
  - Style: `auto foo() -> T` everywhere, Allman braces, `std::expected` / `std::span` /
    `std::string_view`, smart pointers and an explicit Zig-flavoured arena allocator.
- **Logic (Lua)** — `scripts/` + `main.lua`: state machine, animatronics, cameras,
  power, office and HUD.
- **Rendering** — the office uses a render texture plus a cylindrical slice projection.

### Dependencies
SDL2 (core, TTF, image, mixer) + Lua 5.4.

## Build

Requires: CMake, a C++26 compiler, pkg-config, SDL2 (dev) and Lua 5.4 (dev).

### Linux
```bash
./build.sh          # produces bin/fnwf-Linux
./fnwf              # normal game
./fnwf -o           # jump straight to the office (fast test)
```

### Windows (MinGW + pkg-config)
```bat
build-windows.bat   % produces bin\fnwf-Windows.exe
```

## Layout
```
fnwf/
├── CMakeLists.txt          multi-platform build (fnwf-<OS>)
├── build.sh / build-windows.bat
├── fnwf                    launcher
├── config.lua              settings (resolution, language, etc.)
├── main.lua                main loop + state machine
├── scripts/
│   ├── game1/
│   │   ├── settings.lua    constants, balance, per-night AI
│   │   └── states/         menu, game(office), custom_night, story, etc.
│   └── core/
│       ├── systems/        animatronics, cameras, doors, jumpscare, office, power
│       └── utils/          draw, localization, sounds, save_manager, settings_manager
├── src/
│   ├── main.cpp            entrypoint (Lua C API + main.lua)
│   └── engine/             native engine (Engine, LuaBindings, Allocator)
└── assets/                 NOT versioned — proprietary (see notice)
```

## License
Copyright (C) 2026 — contributors. Code under [GPL-3.0](LICENSE). Assets
(character art, sounds, images, fonts) are proprietary and excluded from the
open license.
