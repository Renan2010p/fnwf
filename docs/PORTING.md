# Porting notes (C++ → Rust)

This document records how the original C++ codebase maps onto the Rust
workspace, and the places where behaviour was deliberately changed.

## File mapping

| C++ | Rust |
| --- | --- |
| `src/engine/Engine.hpp`, `Event.hpp` | `crates/engine/src/{engine,event}.rs` |
| `src/core/DrawUtils.*` | `crates/core/src/draw.rs` |
| `src/core/SoundManager.*` | `crates/core/src/audio.rs` |
| `src/core/Localization.*` | `crates/core/src/localization.rs` + generated `localization/localization_data.rs` |
| `src/core/SaveManager.*`, `GameSnapshot.hpp` | `crates/core/src/save.rs` |
| `src/core/SettingsManager.*` | `crates/core/src/settings.rs` |
| `src/core/StateMachine.*`, `GameState.hpp` | `crates/core/src/state.rs` |
| `src/core/Rng.hpp` | `crates/core/src/rng.rs` |
| `src/game1/{Colors,Constants,GameData,Types}.hpp` | `crates/game/src/{colors,data,types}.rs` + `core::config` |
| `src/systems/*` | `crates/game/src/systems/*` |
| `src/game1/states/*` | `crates/game/src/states/*` |
| `src/platform/sdl2/EngineSDL2.*` | `crates/backend-sdl2/src/engine_sdl2.rs` |
| `src/main.cpp` | `crates/app/src/main.rs` |
| `src/platform/ps2/*` | *planned* `crates/backend-ps2` |

## Type mapping

| C++ | Rust |
| --- | --- |
| `std::optional<T>` | `Option<T>` |
| `std::string` / `std::string_view` | `String` / `&str` |
| `std::uint32_t` ids | `u32` behind `TextureHandle` / `SoundHandle` |
| `int`/`std::int32_t` coordinates | `i32` throughout |
| `std::vector<Event>` | `Vec<Event>` |
| `unique_ptr<GameState>` | `Box<dyn GameState>` |
| `Engine&` stored in a state | `&mut dyn Engine` parameter |

## Documentation generation

`crates/core/src/localization/localization_data.rs` is generated from the C++
`Localization.cpp` by `scripts/gen_localization.py`. To regenerate:

```bash
python3 scripts/gen_localization.py
```

The script edits only the generated file; the C++ source is the reference.

## Deliberate fixes

The port preserves the game faithfully but corrects a few clear bugs:

1. **Custom Night AI levels are applied.** The original constructed the
   `AnimatronicManager` with `nullptr`, so the levels selected in the UI had no
   effect. `GameplayState::new` now passes them through.
2. **F5/F8 use the real key codes.** The original compared against `29`/`31`
   (ASCII control codes), so save/load never triggered. The port uses
   `SDLK_F5`/`SDLK_F8`.
3. **`survive_n7` is awarded** on completing Night 7.
4. **Extras modifiers persist.** Toggling infinite power / fast nights now
   updates the saved flags when leaving the Extras screen.

## Save format

Both formats are little-endian and length-prefixed. `config.dat`, `save.dat` and
`game_snapshot.dat` live in the working directory (`save.dat` also supports
`$HOME/.fnwf/`). The Rust layout matches the C++ layout on 64-bit
little-endian hosts; it is **not** guaranteed byte-compatible on other
endiannesses.

## Text and colour

Colour constants moved from `GameSettings::*` to `crates/game/src/colors.rs`;
`Color` (from `game1/Types.hpp`) is `crates/game/src/types.rs`.

Unicode characters that the C++ source escaped (e.g. the scanline bar `\xe2\x94\x81`
or the music note `\xe2\x99\xaa`) are written as Rust unicode escapes like
`\u{2501}` and `\u{266a}`.

The menu version label originally read `"v2.0f.3"` (a typo in the upstream
source); it now shows the actual version, `"v2.1.0"`.
