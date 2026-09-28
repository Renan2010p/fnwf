# Code style

## General

* Rust 2021, formatted with `cargo fmt` (see `rustfmt.toml`).
* `cargo clippy --workspace --all-targets` must be clean.
* Prefer small, focused modules over large files.
* No `unwrap()` in library code unless the invariant is impossible to violate
  and is documented with a comment.
* `unsafe` is allowed only for platform FFI, must be the smallest possible
  block, and must carry a comment explaining the safety argument.

## Layering

* `fnwf-game` and `fnwf-core` must not mention SDL or any platform type.
* Platform details belong in `crates/backend-*`.
* Add a capability method to `Engine` (with a default) instead of special-casing
  a platform in the game.

## Documentation

Every crate, module, trait, public type, public field and public function is
documented. The workspace enables `#![warn(missing_docs)]`; treat a missing-doc
warning as a build failure.

Doc comments should explain **why** and any non-obvious **invariants**, not just
restate the name. When behaviour mirrors the C++ original, say so.

```rust
/// Draws a sub-region of a texture.
///
/// Coordinates are in logical screen pixels; the SDL2 backend passes them
/// straight to `SDL_RenderCopy`.
fn draw_texture_region(...);
```

## Naming

* Types/`enum`s: `UpperCamelCase`; functions/methods/fields: `snake_case`.
* Constants: `SCREAMING_SNAKE_CASE` in modules, associated consts on types.
* Modules are nouns describing the responsibility (`draw`, `audio`, `save`).
* State structs end with `State`; engine backends with `Engine`.

## Commit messages

Conventional-commit style, imperative mood:

```
feat(web): add wasm backend
fix(audio): stop mask breathing on mask removal
docs(engine): document render target contract
```
