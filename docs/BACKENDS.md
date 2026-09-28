# Backends

A backend is any type that implements `fnwf_engine::Engine`. The game only ever
sees `&mut dyn Engine`, so a new platform is a matter of writing one crate.

## The contract

Implement these and the whole game runs:

* **Lifecycle** — `init`, `shutdown`, `poll_events`, `ticks`, `keeps_running`,
  `request_stop`, `present`.
* **Window** — `set_logical_size`, `set_fullscreen`, `set_vsync`,
  `set_resolution`, `get_display_modes`.
* **Drawing** — `clear`, `draw_rect`, `line`, `circle`, textures and text.
  `fill_quad` has a scanline default; override it if the platform has a real
  polygon primitive (the PS2/gsKit backend did).
* **Resources** — `load_texture`, `create_target`, `load_sound`, `load_font`,
  `font_text_size`, `texture_size`.
* **Render targets** — `set_render_target` / `reset_render_target`.
* **Sound / input / volume** — playback, `mouse_pos`, channel and master
  volumes, `update_discord`.

Then advertise optional capabilities:

```rust
fn supports_cylindrical_office(&self) -> bool { true }  // false = draw flat
fn supports_offscreen_targets(&self) -> bool { true }   // false = draw direct
fn set_draw_offset(&mut self, _dx: i32, _dy: i32) {}    // direct-to-screen fx
```

## `fnwf-backend-sdl2` (desktop)

The reference implementation, mirroring the original `EngineSDL2`.

* **Rendering** — `sdl2::render::WindowCanvas`. Render targets are bound with a
  raw `SDL_SetRenderTarget` call because the safe `sdl2` API does not expose it;
  `Texture::raw()` / `Canvas::raw()` provide the pointers.
* **Textures** — built with the `unsafe_textures` feature so handles have no
  lifetime and can be stored in a map. Renderer teardown frees them.
* **Text** — TTF rendering cached by an FNV-1a hash of (text, font, color), with
  a size cap that clears the cache when it grows too large.
* **Audio** — `SDL2_mixer`; sounds are decoded once into `Chunk`s. SFX volume is
  applied per channel, master volume scales music and SFX.
* **VSync** — toggling recreates the window and renderer (SDL cannot change it
  live) and clears the shared draw cache.
* **Fallback** — if an accelerated renderer cannot be created, the backend falls
  back to a software renderer (useful for headless/CI runs).

## `fnwf-backend-web` (browser)

Renders through **Canvas2D** with `web-sys`, targeting
`wasm32-unknown-unknown` — no Emscripten and no SDL required.

* **Drawing** — rects, lines, arcs and polygons map onto
  `CanvasRenderingContext2d`. Textures are `HtmlImageElement`s; render targets
  are detached `<canvas>` elements used as image sources.
* **Input** — DOM listeners push into a queue that `poll_events` drains. Key
  repeats are ignored so held keys do not toggle doors repeatedly.
* **Audio** — `HtmlAudioElement`, with the same channel conventions as SDL.
* **Loop** — the browser owns the event loop, so the app drives the game from
  `requestAnimationFrame` (`fnwf_app::web::start`).
* **Limitations** — images load asynchronously (a sprite may be blank for the
  first frames); file-based saves are a no-op until wired to `localStorage`.

Build with `scripts/build-web.sh` (needs `wasm-bindgen-cli`), serve the
repository root, and open `index.html`.

## Writing a new backend

1. Create `crates/backend-<name>` and depend on `fnwf-engine` (and `fnwf-core`
   only if you need `draw::clear_cache`).
2. Implement `Engine`. Do not import anything from `fnwf-game`.
3. Return the backend from a `create_engine()` function.
4. Select it in `crates/app` (see how `make_engine` switches on the target).

Keep the game untouched. If you find yourself needing a game change, add a
capability method with a sensible default instead.

## The Mock engine

Because `Engine` is a trait, tests can provide a **mock** that records draw
calls and returns canned input instead of touching SDL. This enables headless
tests of AI, power drain, save/load and the transition table. A `fnwf-testkit`
crate is the natural home for it.

## Platform status

| Platform | Backend | Status |
| --- | --- | --- |
| Linux / Windows / macOS | `fnwf-backend-sdl2` | implemented, default |
| Web (wasm) | `fnwf-backend-web` | implemented, compiles for `wasm32-unknown-unknown` |
| Consoles | — | built from the C/C++ project; see `docs/PS2.md` |

See `docs/PORTING.md` for the C++ → Rust mapping and the deliberate fixes.
