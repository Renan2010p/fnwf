===========================================
  Five Nights With Friends — Classic Edition
  v2.0.12
===========================================

A survival horror game inspired by Five Nights at Freddy's,
featuring 4 animatronics based on real friends:

  - Cedro  — The Mafia Boss. Attacks from the left.
  - Eser   — The Enforcer. Fast and aggressive on the right.
  - Alice  — The Hacker. Comes through the ventilation ducts.
  - Sonk   — The Wild Card. Rushes when you stare too long.

===========================================
  About
===========================================

FNWF Classic Edition is my very first game. It started as a
personal project — a FNAF-style horror game but with my own
friends as the animatronics. Cedro, Alice, Sonk, and Eser are
real people, and putting them in a horror game was a fun way
to combine something I love (FNAF) with my circle of friends.

I originally made this game using Lua and a custom engine.
Unfortunately, I lost the original source code at some point.
After that, I did a full reverse engineering of the compiled
game, recovered everything, and rewrote the entire codebase
in C++23 — removing Lua entirely and building a clean,
modern engine from scratch.

Now I'm releasing the Classic Edition as open source so it
can be studied, preserved, and enjoyed. I'm currently
developing a new version of FNWF in Godot, and this Classic
Edition serves as both a tribute to where it all started
and a reference for how the game worked.

===========================================
  License
===========================================

  Code:   GNU General Public License v3.0 (GPL-3.0)
  Assets: All character sprites and sounds are original
          or generated specifically for this project.

  Copyright (C) 2024-2026 Renan Lucas Vieira Hilário
  All rights reserved under GPL-3.0.

  This project contains NO copyrighted material from
  Five Nights at Freddy's or any other franchise.
  All audio is synthetically generated or original.

===========================================
  Controls
===========================================

  Mouse       — Look around the office
  Left Click  — Interact with doors, buttons, cameras
  Q / E       — Toggle left/right door
  A / D       — Toggle left/right light
  L           — Toggle vent light
  Space       — Put on / take off Freddy mask
  1-9         — Switch camera (when monitor is open)
  ESC         — Return to menu / skip dialogue
  P           — Skip to 6 AM (debug)

===========================================
  Gameplay
===========================================

  Survive from 12 AM to 6 AM across 7 nights.
  Manage your power carefully — once it's out, you're vulnerable.
  Use doors, lights, and the Freddy mask to keep animatronics away.

  Each animatronic has a unique movement pattern:
    Cedro  — Sneaks down the left hall
    Eser   — Charges the right hall
    Alice  — Crawls through the vents
    Sonk   — Runs when you watch him too long

===========================================
  Repository layout
===========================================

  src/engine/       Abstract Engine interface (no platform code)
  src/core/         Engines-agnostic services (draw, save, audio, i18n)
  src/systems/      Gameplay systems (office, cameras, doors, power, AI)
  src/game1/        Game states + settings (colors, constants, assets)
  src/platform/     Backends: sdl2/ (desktop/web/mobile), ps2/ (gsKit)
  assets/           Sprites, audio and font
  scripts/          Helper scripts (web server, packaging helpers)
  docs/             Architecture and platform guides
  cross/            Meson cross-compile files
  subprojects/      Vendored dependencies (SDL2)

  See docs/ARCHITECTURE.md and CONTRIBUTING.md.

===========================================
  Building from Source
===========================================

  Requirements:
    - C++17 compiler
    - CMake 3.24+ (recommended) or Meson
    - SDL2, SDL2_ttf, SDL2_image, SDL2_mixer

  CMake — downloads and builds SDL2 automatically (FetchContent):

    cmake -S . -B build
    cmake --build build -j
    ./build/fnwf

    Add -DFNWF_USE_SYSTEM_DEPS=ON to use SDL2 already installed on the system.

    PlayStation 2:
      cmake -S . -B build-ps2 \
        -DCMAKE_TOOLCHAIN_FILE=cmake/toolchains/ps2.cmake
      cmake --build build-ps2 -j

    Web (Emscripten): use the emsdk (SDL2 ports), see cmake/platform/web.cmake.

  Meson (legacy, still supported while the migration is gradual):

  Linux (Ubuntu/Debian):
    sudo apt install meson ninja-build g++ pkg-config \
      libsdl2-dev libsdl2-ttf-dev libsdl2-image-dev \
      libsdl2-mixer-dev ffmpeg

    meson setup build
    meson compile -C build
    ./build/fnwf

  Windows (MSYS2):
    pacman -S mingw-w64-x86_64-gcc mingw-w64-x86_64-meson \
      mingw-w64-x86_64-ninja mingw-w64-x86_64-SDL2 \
      mingw-w64-x86_64-SDL2_ttf mingw-w64-x86_64-SDL2_image \
      mingw-w64-x86_64-SDL2_mixer mingw-w64-x86_64-ffmpeg

    meson setup build
    meson compile -C build
    ./build/fnwf.exe

  Generate placeholder sounds:
    bash generate_sounds.sh


===========================================
  PlayStation 2
===========================================

  Requirements:
    - ps2dev toolchain (ps2sdk + gsKit)

  Build the ELF and the bootable ISO:
    export PS2DEV=/usr/local/ps2dev
    ./build-ps2.sh
    ./build-ps2-iso.sh

  Run:
    - PCSX2: File > Run CDVD > fnwf-ps2.iso
    - Real hardware: burn the ISO, or use the USB layout
      described in docs/PS2-BUILD.md

  On PS2 the game renders through gsKit (the GS/GPU) at 60 FPS,
  with a flat office and real loading screens. See docs/PS2-BUILD.md.

===========================================
  Releasing
===========================================

  Tag a version to trigger the release workflow:

    git tag v2.0.9
    git push origin v2.0.9

  This will automatically build Linux and Windows packages
  and create a GitHub Release with download links.

===========================================
  Credits
===========================================

  Created by:    Renan Lucas Vieira Hilário
  Animatronics:  Cedro, Eser, Alice, Sonk
  Font:          FiraCode Nerd Font Mono (SIL Open Font License)
  Engine:        Custom C++23 + SDL2
  License:       GPL-3.0

  Special thanks to my friends who became animatronics.
  This game wouldn't exist without you guys.

===========================================
  Five Nights With Friends — Classic Edition
  The game that started everything.
===========================================
