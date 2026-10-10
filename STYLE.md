# fnwf — Zig Style Guide

Captured from Renan's existing code (the C++ game and `build.zig`). Everything
below is a rule the assistant follows when writing the Zig rewrite. If
something here is wrong, we fix it here first, then in the code.

## Language

- Identifiers and comments are written in **English**.
- File names are **snake_case**, short and easy to read: `engine.zig`,
  `sdl2.zig`, `state_machine.zig`, `power_system.zig`.
- One concept per file once a file grows; small related types may share a file.

## Explicit types

Types are written explicitly everywhere a type exists. This applies to
**everything without exception**, including struct and union fields and every
`const` / `var`.

- Every `const` / `var` gets a type annotation:
  `const std: type = @import("std");`
  `const target: Builder.ResolvedTarget = b.resolveTargetQuery(query);`
- Every struct and union field declares its type:
  `pub const Color = struct { r: u8, g: u8, b: u8, a: u8 = 255 };`
- Every function declares every parameter type and the return type.
- Struct / union literals carry the explicit type prefix:
  `Target.Query{ .abi = .gnu }`, not `.{ .abi = .gnu }`.
- Enum values are fully qualified: `builtin.OptimizeMode.ReleaseFast`.

## No `std.` in the body

Every `std` symbol is brought to a named constant at the top of the file and
used through it, mirroring the symbol's own name:

```zig
const std: type = @import("std");
const Allocator: type = std.mem.Allocator;
const mem: type = std.mem;
const fmt: type = std.fmt;
const TextureMap: type = std.AutoHashMapUnmanaged(u32, *Tex);

fn example(allocator: Allocator) void {
    _ = mem.span(...);
    _ = fmt.allocPrint(allocator, ...);
}
```

Generic instantiations get a concrete alias (`TextureMap`), so the alias can
still carry the explicit `: type` annotation. The body must never say `std.`.

## Naming

- Types, unions and enums: `PascalCase` (`Engine`, `Sdl2Engine`, `Event`).
- Functions, methods, fields, locals and file-scope consts: `snake_case`.
- Configuration constants: `SCREAMING_SNAKE_CASE`.
- No `m_` prefix on fields; access is always through `self`.

## Layout of a file

Top-to-bottom order:

1. `//!` module doc comment.
2. Imports.
3. Public types and constants.
4. Private helpers.
5. `test` blocks (when present).

Conceptual blocks inside a file are separated with a box comment:

```
// ── Lifecycle ────────────────────────────────────────────────────────
```

## Documentation

- Every public declaration gets a `///` doc comment explaining *why* it exists,
  not only what it does.
- The module header uses `//!`.

## Formatting

- `zig fmt`, never hand-formatted: 4 spaces, 100 columns, no tabs.
- No manual alignment of columns.

## Errors and memory

- Fallible functions return an error union and are called with `try`;
  optional lookups use `?T` + `orelse`.
- Allocators are passed explicitly as an `std.mem.Allocator` parameter; no
  hidden global allocator.
- Shared services and caches may live as module-level `var` state, mirroring
  the C++ statics/singletons. Prefer module state over passing everything
  through every call.

## Platform boundary

- Game code imports only the `engine` module.
- SDL / OS headers appear only under `engine/platform/`.

## Modules

Each top-level directory is a Zig module, wired in `build.zig`:

- `core/` — engine-agnostic data types and services (`core/event.zig` today).
- `engine/` — the abstract `Engine` interface; imports `core`.
- `engine/platform/<backend>/` — one module per backend (SDL2 today).
- `fnwf/` — the game itself; imports `engine` and the chosen backend.

Zig does not allow importing a file outside a module's root directory, so
cross-directory types are exposed as modules instead of relative paths.
