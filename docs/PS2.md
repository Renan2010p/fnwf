# Consoles (PlayStation 2 and friends)

Consoles are **not** part of this Rust project. The console builds come from the
original **C/C++** codebase, which already ships a working gsKit backend for the
PlayStation 2 (`src/platform/ps2/`).

This project targets every platform where Rust runs (Linux, Windows, macOS,
web, …). The game logic is identical on both sides because everything is
written against the `Engine` trait:

```
        fnwf-engine::Engine
        /                  \
  Rust backends        C++ console backend
  (SDL2, Canvas2D)     (gsKit / PS2SDK)
```

## Why consoles stay in C/C++

A Rust PS2 backend was prototyped (custom `mips64r5900el-ps2-elf` target,
`-Z build-std`, a `no_std` port of `fnwf-core`/`fnwf-game`, and a gsKit `Engine`
implementation). It compiled and linked a bootable ELF, but running the full
game in an emulator exposed two practical problems that make C the better fit
for the console:

1. **Codegen vs. the emulator.** LLVM emits R5900 `MADD`/`MADDU` for many
   integer multiply-add patterns (including inside `compiler_builtins`'
   soft-float routines). PCSX2's EE recompiler logs these as *“Unknown R5900
   SPECIAL”*; the interpreter is far too slow for a 60 Hz game. These
   instructions are valid on real hardware, but the emulator path is fragile.
2. **`no_std` cost.** A console build needs a `no_std`+`alloc` variant of the
   whole game (no `HashMap`, no `std::sync`, no filesystem, software float
   math). That is real complexity for a target the C toolchain already serves
   well.

The Rust port therefore leaves consoles to the C/C++ project and keeps the
desktop/web backends as pure Rust. `fnwf-engine` remains `no_std`-capable
(`std` is a default feature), so a future console effort is still possible
without changing the game crates.
