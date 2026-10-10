# Five Nights With Friends — Classic Edition (Zig rewrite)

A from-scratch Zig rewrite of the classic FNWF game, built on the
[Neko](https://github.com/Renan2010p/neko) engine.

## Layout

```
build.zig / build.zig.zon   the game package (depends on the neko package)
neko/config.zig             engine config for this game (backend choice)
fnwf/
  common/                   mechanics shared by every FNFW game
  classic/
    main.zig                entry point + main loop
    config/                 constants.zig  colors.zig  settings.zig  cheats.zig
    world/                  locations.zig  game_data.zig
    i18n/                   localization.zig
    states/                 splash, warning, menu, options, …
    systems/                office, cameras, doors, power, AI, jumpscare
    assets/                 sprites, audio, font
  fnwf1/
    main.zig                FNWF 1 — entry point + state graph
    office.zig  cameras.zig  power.zig  animatronics.zig
    menu.zig  call.zig  gameplay.zig  six_am.zig  gameover.zig
    custom_night.zig  paycheck.zig  newspaper.zig  options.zig  extras.zig
    save.zig  config.zig  world.zig  assets/   sprites, audio, font
```

## Build

```sh
zig build run                 # native (self-hosted codegen on Linux)
zig build -Dbackend=c cc      # emit C and compile it with `zig cc`
zig build -Dgame=classic      # Classic Edition (default)
zig build -Dgame=fnwf1        # FNWF 1 — the five nights
```

The Neko engine is a **remote dependency** declared in `build.zig.zon`
(`github.com/Renan2010p/neko`, pinned to a commit). The first build downloads it
into Zig's global cache, so no local `../neko` checkout is needed. To move to a
new engine commit, point `.url` at the new commit's tarball and update `.hash`
(`zig fetch <url>` prints it):

```zig
.neko = .{
    .url = "https://github.com/Renan2010p/neko/archive/<commit>.tar.gz",
    .hash = "neko-0.1.0-...",
},
```

## FNWF 1

`-Dgame=fnwf1` builds **Five Nights With Friends 1**, a complete take on the
classic Five Nights at Freddy's formula, written from scratch for this package:

- **Office** with two hallways, a door and a light on each side, panned with the
  mouse.
- **Security monitor** with 11 cameras (Show Stage, Dining, Pirate Cove, West
  and East Halls, Supply, Backstage, Kitchen, Restrooms) and a map.
- **Power** meter with usage bars — doors, lights and the monitor all drain it.
- **Animatronic AI** using the FNAF 1 model: movement opportunities every few
  seconds, a 1-20 roll against the AI level, AI that ramps at 2/3/4 AM, Cedro
  (Freddy) who only moves when unwatched, and Sonk (Foxy) who charges the west
  hall when Pirate Cove is ignored.
- **Five nights** (plus Night 6 and a Custom Night), a 12 AM→6 AM clock, 6 AM
  celebration, jumpscares, a death newspaper, the paycheck and a victory paper.
- **Story**: Cedro, the guard before you, calls every night — a Portuguese
  take on the Phone Guy, leading into the pizzeria's secret.

Cast: **Eser** (left hall), **Alice** (right hall), **Sonk** (Pirate Cove) and
**Cedro** (the boss).

## Shaders (add one without touching the engine)

The office panorama is composited by a shader when the backend supports it. A
game can supply its own shader **from its own package**, in priority order:

1. **Shader files in the game's assets** — edit
   `fnwf/classic/assets/shaders/office.{vert,frag}` (or the `fnwf1` copy). The
   game loads them with `neko.shader.load_files(...)`.
2. The engine's built-in `cylinder` shader (`neko.shader.load_builtin`).
3. The per-column CPU mesh (always works, including the default SDL2 backend).

So a new effect is added by dropping GLSL in your game — no `neko` changes:

```zig
const prog = neko.shader.load_files(neko.allocator(), "fnwf/fnwf1/assets/shaders", "post.vert", "post.frag");
if (prog) |p| p.draw(scene_tex, .{ 0, 0, 0, 0 });
```

The default backend is **SDL3** (`sdl3`). Its `SDL_Renderer` supports several
drivers — including **Vulkan** — selectable at runtime from the game's Options
(**Neko Options → Render**). The SDL_Renderer API itself does not run custom
shaders, so the games composite the office with the CPU mesh unless a backend
with a shader path is selected.


## Credits

Created and directed by **Renan Lucas Vieira Hilário**, implemented with AI
assistance.

Animatronics: Cedro, Eser, Alice, Sonk.

## License

GNU General Public License v3.0 or later (GPL-3.0-or-later). See `LICENSE`.

Copyright (C) 2026 Renan Lucas Vieira Hilário.
