# Changelog

All notable changes to this project are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project
adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.1.0] — 2026-09-28

**Five Nights With Friends is now written in Rust.**

This release is the result of a complete rewrite of the original C++ codebase
into safe, modern Rust. The game logic, assets, save format and behaviour are
faithfully preserved; the engine and platform layers were rebuilt from scratch
and split into focused crates.

### Added

* **Full Rust rewrite** of the game, organised as a Cargo workspace:
  `fnwf-engine` (platform-agnostic `Engine` trait), `fnwf-core` (draw, audio,
  i18n, save, settings, state machine), `fnwf-game` (systems + states),
  `fnwf-backend-sdl2` (desktop), `fnwf-backend-web` (wasm/Canvas2D) and the
  `fnwf` app.
* **Web build**: the game runs in the browser via WebAssembly and Canvas2D, no
  Emscripten required.
* **Release packaging**: self-contained archives for Linux, macOS and Windows
  (`scripts/package.sh`) and a Linux **AppImage** (`scripts/build-appimage.sh`).
* **Tag-triggered release workflow** that publishes Linux, macOS, Windows,
  AppImage and web builds to a GitHub Release.
* Comprehensive API documentation (`#![warn(missing_docs)]` across all crates)
  and `docs/` (architecture, backends, porting, code style).
* Optional `no_std` support for the engine and game crates (`std` is the
  default), which keeps the game logic portable to bare-metal targets.

### Fixed

* **Custom Night AI levels are now applied.** The original built the
  animatronics with `nullptr` and silently ignored the levels chosen in the UI.
* **Save/Load (F5/F8) uses the real key codes.** The original compared against
  `29`/`31`, so saving never triggered.
* **`survive_n7` is awarded** when Night 7 is completed.
* **Extras modifiers** (infinite power / fast nights) persist to the save file.

### Notes

* Consoles (PlayStation 2) remain built from the original C/C++ codebase; see
  `docs/PS2.md` for the rationale.

## [2.0.12]

Original C++ release (the reference implementation this rewrite is based on).

[2.1.0]: https://github.com/Renan2010p/fnwf/releases/tag/v2.1.0
[2.0.12]: https://github.com/Renan2010p/fnwf/releases/tag/v2.0.12
