# Five Nights With Friends — Classic Edition 2.1.0

**The game is now written in Rust.**

This release is a complete, faithful rewrite of the original C++ codebase into
safe, modern Rust. The gameplay, assets, save data and behaviour are preserved;
the engine and platform layers were rebuilt from scratch.

## Highlights

- **100% Rust game code**, organised as small, focused crates with enforced
  layer boundaries.
- **Desktop** (Linux / Windows / macOS) through the pure-Rust `sdl2` crate.
- **Web** (browser) through WebAssembly + Canvas2D — no Emscripten needed.
- **Packaging**: self-contained archives and a Linux **AppImage**.
- **Documentation**: every public item documented, plus architecture and
  porting guides.

## Fixed in this rewrite

- Custom Night AI levels are now actually applied (the original ignored them).
- Save/Load (F5/F8) works (the original used the wrong key codes).
- The `survive_n7` achievement is awarded on completing Night 7.
- Extras modifiers (infinite power / fast nights) persist when saved.

## Downloads

| Platform | Artifact |
| --- | --- |
| Linux | `fnwf-2.1.0-linux-x86_64.tar.gz` or `fnwf-2.1.0-x86_64.AppImage` |
| macOS | `fnwf-2.1.0-macos-*.tar.gz` |
| Windows | `fnwf-2.1.0-windows-x86_64.zip` (SDL2 bundled) |
| Web | `fnwf-web.tar.gz` (serve over HTTP and open `index.html`) |

## Running

Extract the archive and run `fnwf` (or `run.sh` / `run.bat`). The game finds
`assets/` next to the executable, so the folder is self-contained. On Linux and
macOS you need SDL2 installed (SDL2, SDL2_ttf, SDL2_image, SDL2_mixer); the
Windows package bundles the SDL2 runtime.

The AppImage is standalone:

```sh
chmod +x fnwf-2.1.0-x86_64.AppImage
./fnwf-2.1.0-x86_64.AppImage
```

## Controls

Mouse to look around; `Q`/`E` doors, `A`/`D` lights, `L` vent light, `Space`
mask, `1-9` cameras, `Tab` monitor, `Esc` menu. F5/F8 save and load.

## Notes

- Consoles (PlayStation 2) remain built from the original C/C++ project; see
  `docs/PS2.md`.

Full changelog: [`CHANGELOG.md`](CHANGELOG.md).
