# Contributing

Thanks for taking a look at Five Nights With Friends (Classic Edition)!

## Building

Desktop (Linux):

```bash
meson setup build
meson compile -C build
./build/fnwf
```

Windows (MSYS2), Web (Emscripten) and PlayStation 2 instructions are in
`README.txt` (see the "Building from Source" and "PlayStation 2" sections).

## Project layout

See `docs/ARCHITECTURE.md` for how the `Engine` abstraction and the platform
backends fit together. In short: game code depends only on the `Engine`
interface; platform code lives under `src/platform/<backend>/`.

## Code style

- C++17, `.clang-format` is provided — run `clang-format -i` on changed files.
- Trailing return types (`auto f() -> T`) are used throughout.
- Keep game code platform-agnostic: no SDL/gsKit/OS headers outside
  `src/platform/`. Need something new? Add it to the `Engine` interface.
- Prefer the existing helpers in `DrawUtils` over new ad-hoc drawing.

## Commits

- Write commit messages in **English**.
- Use a short prefix when it helps: `ps2:`, `web:`, `docs:`, `fix:`, `chore:`.
- Keep machine-generated files out of the repo (ISOs, tarballs, build
  directories) — they are covered by `.gitignore`.

## Assets

All character sprites and sounds are original/placeholder. Do not add
copyrighted material from other franchises.
