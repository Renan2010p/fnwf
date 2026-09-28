<div align="center">

# Five Nights With Friends — Classic Edition

**A survival-horror game written in Rust.**

Rewrite of the original C++ *Classic Edition* — same gameplay, same assets, a
modern and safe codebase.

[![CI](https://github.com/Renan2010p/fnwf/actions/workflows/ci.yml/badge.svg?branch=rust-rewrite)](https://github.com/Renan2010p/fnwf/actions/workflows/ci.yml)
[![License: GPL-3.0](https://img.shields.io/badge/license-GPL--3.0-blue.svg)](LICENSE)
[![Rust](https://img.shields.io/badge/rust-1.75%2B-orange.svg?logo=rust)](https://www.rust-lang.org)

</div>

---

Survive from 12 AM to 6 AM across seven nights while four animatronics — **Cedro**,
**Eser**, **Alice** and **Sonk** — hunt you through the halls and vents of the
Mafia pizzeria. Watch the cameras, lock the doors, check the lights, and ration
your power until sunrise.

## Features

- **Seven nights + Custom Night** with per-animatronic AI levels and secret
  presets.
- **Cameras, doors, hall lights, ventilation and the mask** — the full classic
  toolkit.
- **Extras & achievements**, story dialogues and an arcade endless mode.
- **Localised** in Portuguese and English.
- **Save/load** mid-night snapshots.
- Runs on **Linux, Windows, macOS and the web**.

## Written in Rust

The entire game is Rust. It is split into small, focused crates whose
dependencies form a strict acyclic graph — the compiler enforces the layering
that the C++ original expressed only through header discipline.

```
        fnwf-game  (gameplay: systems + states)
             │
             ├──────────────► fnwf-core   (draw, audio, i18n, save, settings, state machine)
             │                    │
             └──────────────► fnwf-engine (the Engine trait — no platform code)
                                  ▲                     ▲
                                  │                     │
                     fnwf-backend-sdl2          fnwf-backend-web
                     (Linux/Windows/macOS)      (wasm + Canvas2D)
                                  ▲                     ▲
                                  └──────────┬──────────┘
                                             │
                                    fnwf (app: binary + wasm)
```

| Crate | Responsibility |
| --- | --- |
| `crates/engine` | Platform-agnostic `Engine` trait, events, key codes, handles. |
| `crates/core` | Engine-agnostic services: `draw`, `audio`, `localization`, `save`, `settings`, `rng`, `time`, state machine. |
| `crates/game` | Gameplay `systems/` (office, cameras, doors, power, animatronics, jumpscare) and `states/`. |
| `crates/backend-sdl2` | Desktop backend (pure-Rust `sdl2` bindings). |
| `crates/backend-web` | Browser backend (`web-sys` + Canvas2D, no Emscripten). |
| `crates/app` | Startup, asset preloading and the top-level transition table. |

## Platforms

| Platform | Backend | Artifact |
| --- | --- | --- |
| Linux | `fnwf-backend-sdl2` | `.tar.gz` / **AppImage** |
| Windows | `fnwf-backend-sdl2` | `.zip` (SDL2 bundled) |
| macOS | `fnwf-backend-sdl2` | `.tar.gz` |
| Web | `fnwf-backend-web` | static bundle |

> Consoles (PlayStation 2) are built from the original C/C++ project. See
> [`docs/PS2.md`](docs/PS2.md).

## Build & run

Requires the Rust toolchain and the SDL2 development libraries
(SDL2, SDL2_ttf, SDL2_image, SDL2_mixer).

```bash
cargo run --release          # from the repository root (so ./assets resolves)
```

| OS | Install SDL2 |
| --- | --- |
| Debian/Ubuntu | `sudo apt install libsdl2-dev libsdl2-ttf-dev libsdl2-image-dev libsdl2-mixer-dev` |
| Fedora | `sudo dnf install SDL2-devel SDL2_ttf-devel SDL2_image-devel SDL2_mixer-devel` |
| macOS | `brew install sdl2 sdl2_ttf sdl2_image sdl2_mixer` |
| Windows (MSYS2) | `pacman -S mingw-w64-x86_64-SDL2 mingw-w64-x86_64-SDL2_ttf mingw-w64-x86_64-SDL2_image mingw-w64-x86_64-SDL2_mixer` |

Debug shortcut: `cargo run --release -- -o` boots straight into the office.

## Web build

```bash
rustup target add wasm32-unknown-unknown
cargo install wasm-bindgen-cli          # must match the version in Cargo.lock
./scripts/build-web.sh                  # writes web/pkg/
python3 -m http.server 8000             # serve the repository root
# open http://localhost:8000/
```

## Packaging & releases

```bash
./scripts/package.sh            # dist/fnwf-<version>-<platform>.tar.gz (.zip on Windows)
./scripts/build-appimage.sh     # dist/fnwf-<version>-x86_64.AppImage  (Linux)
```

Both stage the binary with `assets/`, a launcher and the license. The binary
finds `assets/` next to itself, so the extracted folder (or AppImage) is
self-contained.

Pushing a tag (`git tag v2.1.0 && git push origin v2.1.0`) runs the release
workflow, which builds and attaches Linux, macOS, Windows, AppImage and web
artifacts to a GitHub Release.

## Documentation

- [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) — crates, layers and data flow.
- [`docs/BACKENDS.md`](docs/BACKENDS.md) — the `Engine` contract and backends.
- [`docs/PORTING.md`](docs/PORTING.md) — the C++ → Rust mapping and fixes.
- [`docs/CODE_STYLE.md`](docs/CODE_STYLE.md) — conventions.
- [`CONTRIBUTING.md`](CONTRIBUTING.md) · [`CHANGELOG.md`](CHANGELOG.md) · [`RELEASE_NOTES.md`](RELEASE_NOTES.md)

## Credits

Created by **Renan Lucas Vieira Hilário**.
Animatronics: **Cedro, Eser, Alice, Sonk** — friends who became the monsters.
Font: FiraCode Nerd Font Mono (SIL OFL).
Special thanks to everyone who played and to the FNAF community.

## License

[GPL-3.0](LICENSE). Assets are original to the project. This project contains no
copyrighted material from *Five Nights at Freddy's* or any other franchise.
