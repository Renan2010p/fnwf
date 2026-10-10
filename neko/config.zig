//! Neko engine configuration for fnwf.
//!
//! Read by the game's `build.zig` and forwarded to the `neko` dependency,
//! so the backend is chosen here — in a normal source file — and not in
//! `build.zig`.

/// Backends Neko can provide. Must match the ones in the engine.
pub const Backend: type = enum {
    sdl2,
    sdl3,
    @"sdl2-opengl",
    @"sdl2-vulkan",
    ps2,
    psx,
    headless,
};

/// The backend this game is built with.
pub const backend: Backend = .sdl3;
