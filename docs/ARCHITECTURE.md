# Architecture

Five Nights With Friends is split into a small number of crates whose
dependencies form a strict, acyclic graph. The compiler enforces the layering
that the original C++ project expressed only through header discipline.

```
                         ┌──────────────────────────────┐
                         │ fnwf (crates/app)            │
                         │ boot, asset preload,         │
                         │ top-level transition table   │
                         └───────────────┬──────────────┘
                                         │
              ┌──────────────────────────┼──────────────────────────┐
              ▼                          ▼                          ▼
      ┌───────────────┐         ┌───────────────┐         ┌────────────────────┐
      │ fnwf-game     │         │ fnwf-core     │         │ fnwf-backend-sdl2  │
      │ systems+states│────────▶│ services      │◀────────│ SDL2 Engine impl   │
      └───────┬───────┘         └───────┬───────┘         └─────────┬──────────┘
              │                         │                          │
              └────────────┬────────────┴──────────────┬───────────┘
                           ▼                           ▼
                    ┌──────────────────────────────────────────┐
                    │ fnwf-engine                              │
                    │ Engine trait · Event · handles · keys    │
                    └──────────────────────────────────────────┘
```

## Dependency rules

| Crate | May depend on | Must never depend on |
| --- | --- | --- |
| `fnwf-engine` | nothing | SDL, OS, any other `fnwf-*` crate |
| `fnwf-core` | `fnwf-engine` | `fnwf-game`, backends |
| `fnwf-game` | `fnwf-engine`, `fnwf-core` | any backend |
| `fnwf-backend-sdl2` | `fnwf-engine`, `fnwf-core` | `fnwf-game` |
| `fnwf` (app) | everything | — |

The rule is simple: **only the app may know about both the game and a backend.**
Nothing in `fnwf-game` mentions SDL; nothing in `fnwf-engine` mentions an OS.

## The Engine seam

`fnwf_engine::Engine` is the single abstraction every layer above the OS talks
to. It exposes windowing, timing, 2D primitives, textures, text, render targets,
sound and input. Crucially:

* methods take `&mut self` and use plain value types (`i32`, `u8`, `&str`),
  so the trait is object-safe and can be used as `&mut dyn Engine`;
* there is no platform header anywhere in the trait;
* optional capabilities are advertised with defaulted methods
  (`supports_cylindrical_office`, `supports_offscreen_targets`,
  `set_draw_offset`), so backends can opt out without `#ifdef`.

## Engine injection, not stored references

Unlike the C++ original — where states held an `Engine&` and there was a global
`SoundManager::set_engine(ptr)` — every state receives the engine on each call:

```rust
fn update(&mut self, eng: &mut dyn Engine, dt: f32);
fn draw(&mut self, eng: &mut dyn Engine);
fn handle_event(&mut self, eng: &mut dyn Engine, ev: &Event);
```

`fnwf_core::audio` and `fnwf_core::draw` follow the same rule. This removes
shared-mutable-state hazards, makes the data flow explicit, and allows a fake
engine (see `docs/BACKENDS.md`) to drive the game in headless tests.

## Runtime data flow

```
main loop (crates/app/src/main.rs)
  │
  ├─ engine.poll_events() ──▶ state_machine.handle_event(eng, ev)
  ├─ state_machine.update(eng, dt)
  ├─ if current.is_done() ──▶ transition table ──▶ create next state
  ├─ state_machine.draw(eng)
  └─ engine.present()
```

The transition table lives in the app because it is the only place that needs
to know how every state relates to the others. States themselves are
independent: a state only reports `is_done()` and `result()`.

## The state contract

`fnwf_core::state::GameState` is implemented by every screen. Besides the
lifecycle methods it exposes typed accessors (`six_am_night`, `game_over_win`,
`custom_ai_levels`, `extras_cheats`) so the app can branch without `Any`
downcasts or `dynamic_cast`.

## Services (`fnwf-core`)

| Module | Responsibility |
| --- | --- |
| `config` | Screen constants and `assets/` path helpers. |
| `draw` | Sprites, text, scanlines, vignette, rounded textures. Caches sprites/fonts/scanlines behind a mutex. |
| `audio` | Decodes sounds once, maps logical names to OGG files, plays/stops channels. |
| `localization` | Embedded pt/en strings; returns `Cow<'static, str>`. |
| `settings` | User settings persisted to `config.dat`. |
| `save` | Progress (`save.dat`) and mid-night snapshot (`game_snapshot.dat`). |
| `rng` | Thread-local PCG32. |
| `time` | Monotonic clock for animated effects. |
| `state` | `GameState` trait and `StateMachine`. |

## Gameplay (`fnwf-game`)

* `systems/office` — the room, cylindrical panorama projection, doors, halls.
* `systems/camera` — monitor, per-camera views, ventilation, mask overlay.
* `systems/doors` — door/light state and the on-screen panels.
* `systems/power` — power drain and the usage gauge.
* `systems/animatronics` — movement graphs for Cedro/Eser/Alice and Sonk's
  staged charge.
* `systems/jumpscare` — the scare cutscene.
* `states/*` — the 15 screens (menu, gameplay, options, custom night, story,
  arcade, …).

## Why this shape

* **Testability** — gameplay logic depends on a trait, not SDL, so it can be
  exercised headless.
* **Portability** — a new platform only implements `Engine`; nothing else moves.
  This is what makes the planned web and PS2 backends feasible.
* **Replaceability** — localization, saves and settings are isolated modules
  with tiny public surfaces.
