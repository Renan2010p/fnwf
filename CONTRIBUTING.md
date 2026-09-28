# Contributing

Thanks for helping with Five Nights With Friends — Classic Edition (Rust).

## Prerequisites

* Rust (stable) with `rustfmt` and `clippy`.
* SDL2 development libraries: `SDL2`, `SDL2_ttf`, `SDL2_image`, `SDL2_mixer`.

Debian/Ubuntu:

```bash
sudo apt install libsdl2-dev libsdl2-ttf-dev libsdl2-image-dev libsdl2-mixer-dev
```

## Build, run, test

```bash
cargo build --workspace
cargo run --release
cargo test --workspace
```

The game loads assets relative to the working directory, so run from the
repository root (or use `./scripts/run.sh`).

## Before opening a PR

```bash
cargo fmt --all
cargo clippy --workspace --all-targets -- -D warnings
cargo test --workspace
```

## Guidelines

* Read `docs/ARCHITECTURE.md` and honor the crate dependency rules. If a change
  needs a new capability, add a defaulted method to `Engine` rather than leaking
  a platform type into the game.
* Document every public item (`docs/CODE_STYLE.md`).
* Keep changes small and focused; one logical change per commit.
* Ports of upstream behaviour should reference the C++ original in a comment.

## Regenerating translations

```bash
python3 scripts/gen_localization.py
```

## License

By contributing you agree that your work is licensed under GPL-3.0.
