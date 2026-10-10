# FNWF — Parity Checklist (C++ → Zig)

Goal: the Zig rewrite must be **the same game** as the C++ one — same screens,
same behavior, visuals, audio and controls — but with a **new structure** and
**modern code**, reviewed by Renan, still written in his style.

The C++ under `games/fnwf/src/` is the behavioral reference. It is **not** a
structural template: the Zig module boundaries are free to differ. This list
tracks behavior parity and the porting order (dependencies first).

Legend: `[x]` done · `[~]` partial · `[ ]` todo · `n/a` out of scope (desktop
only; the PS2/web branches are skipped until later).

## Zig structure

Two packages. `neko` is the reusable engine; `fnwf` is this game and depends on
it.

```
../neko/                    the engine package (build.zig + build.zig.zon)
  src/neko.zig              public namespace root (neko.draw, neko.sprite, neko.scene, …)
  src/core/
    types.zig  backend.zig  context.zig
    graphics/  draw.zig  text.zig  texture.zig  sprite.zig  effect.zig
    system/    event.zig input.zig screen.zig time.zig lifecycle.zig random.zig
               localization.zig save.zig debug.zig
    scene/     state.zig  scene.zig
    audio/     sound.zig
  src/platform/sdl2/
    SDL2.h  sdl2.zig

fnwf/                       the game package (build.zig + build.zig.zon)
  fnwf/
    common/common.zig       mechanics shared by every FNFW game
    classic/
      main.zig              entry point + loop
      config/               constants.zig  colors.zig
      world/                locations.zig  game_data.zig
      i18n/                 localization.zig
      states/  systems/     per-game
      assets/               per-game sprites, audio, font
```

`neko` is consumed through `b.dependency("neko", .{ .backend = ... })`, where
the backend comes from the game's `neko/config.zig`. The engine instantiates
the selected backend, so game code only imports `neko`. The game is picked
with `-Dgame=<name>` (default `classic`).

## Engine / platform

- [x] Engine interface — ported to `engine/core/backend.zig` (full vtable)
- [x] Event types — `engine/core/event.zig` (raw code + key name + scan name)
- [x] SDL2 backend, full — `engine/platform/sdl2/sdl2.zig`
- [x] SDL2_image + SDL2_mixer + SDL2_ttf wired
- [ ] `plat_input.cpp` / `plat_sdl2.cpp` behavior folded into the backend
- n/a PS2 backend (`src/platform/ps2/`)
- n/a Mobile input

## game1 (settings and data)

- [x] `Colors.hpp` — `fnwf/classic/colors.zig` (using `neko.Color`)
- [x] `Constants.hpp` — `fnwf/classic/constants.zig`
- [x] `Types.hpp` — folded into `neko.Color` (no separate game colour)
- [x] `GameData.hpp` — `fnwf/classic/game_data.zig` + `locations.zig`
- [x] `GameSnapshot.hpp` — in `fnwf/classic/save.zig` (ids as enums, written as the original strings)
- [~] `GameSettings.hpp` — split across `colors/constants/game_data/locations`

## core (engine-agnostic services)

- [x] `DrawUtils` — ported as `neko.sprite` + `neko.effect`
- [x] `Localization` — `neko.localization` + `fnwf/classic/i18n/localization.zig`
- [x] `SaveManager` — `fnwf/classic/save.zig` + `neko.save` (C++-compatible bytes)
- [x] `SettingsManager` — `fnwf/classic/config/settings.zig` (C++-compatible `config.dat`)
- [x] `SoundManager` — `fnwf/common/sound.zig`
- [x] `StateMachine` — `neko.state.StateMachine` (general-purpose)
- [x] `StateRegistry` — not needed in Zig (states are plain structs)
- [x] `GameState` — `neko.state.State` (vtable)
- [ ] `InputManager`
- [x] `Rng` — ported as `neko.random`
- [ ] `Platform`
- n/a `MobileUI`

## systems

- [x] `Office` — `fnwf/classic/systems/office.zig` (full classic projection)
- [x] `CameraSystem` — `fnwf/classic/systems/camera_system.zig`
- [x] `Doors` — `fnwf/classic/systems/doors.zig`
- [x] `Power` — `fnwf/classic/systems/power.zig`
- [x] `Animatronics` — `fnwf/classic/systems/animatronics.zig`
- [x] `Jumpscare` — `fnwf/classic/systems/jumpscare.zig`

## states (`game1/states/`)

- [x] `Splash` — new intro (RL PROJECTS / Powered by Neko engine), not in the C++
- [x] `WarningState` — `fnwf/classic/states/warning.zig`
- [x] `MenuState` — `fnwf/classic/states/menu.zig`
- [x] `StoryState` — `fnwf/classic/states/story.zig`
- [x] `LoadingState` — `fnwf/classic/states/loading.zig`
- [x] `GameplayState` — `fnwf/classic/states/gameplay.zig`
- [x] `NightTransitionState` — `fnwf/classic/states/night_transition.zig`
- [x] `SixAMState` — `fnwf/classic/states/six_am.zig`
- [x] `PaycheckState` — `fnwf/classic/states/paycheck.zig`
- [x] `NewspaperState` — `fnwf/classic/states/newspaper.zig`
- [x] `GameOverState` — `fnwf/classic/states/game_over.zig`
- [x] `CustomNightState` — `fnwf/classic/states/custom_night.zig`
- [x] `ExtrasState` — `fnwf/classic/states/extras.zig`
- [x] `ConquistasState` — `fnwf/classic/states/conquistas.zig`
- [x] `OptionsState` — `fnwf/classic/states/options.zig`
- [x] `ArcadeState` — `fnwf/classic/states/arcade.zig`

## main

- [x] Entry point + state graph (`src/main.cpp`) — `fnwf/classic/main.zig`

## Build

- `zig build` / `zig build run` — on Linux this uses Zig's **self-hosted
  codegen backend** (`-fno-llvm`); other targets keep LLVM.
- `zig build -Dbackend=c cc` (and `... run`) — emit C and compile it with
  `zig cc` (portable release path).
- `zig build -Dgame=classic` — choose the game under `fnwf/` (default classic).
