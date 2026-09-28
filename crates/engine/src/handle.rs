//! Opaque, backend-owned resource handles.
//!
//! The game only ever stores these small `Copy` values; the actual GPU/audio
//! resources live inside the backend and are addressed by `id`.

/// A handle to a texture (or render target) owned by the engine.
///
/// The `id` is only meaningful to the backend instance that created it; the
/// game treats it as opaque and simply hands the handle back on draw calls.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub struct TextureHandle {
    /// Backend-assigned identifier. Obtain a handle from
    /// [`crate::Engine::load_texture`] or [`crate::Engine::create_target`]
    /// rather than constructing an arbitrary id.
    pub id: u32,
}

impl TextureHandle {
    /// Wraps a backend identifier in a texture handle.
    ///
    /// Backends call this when handing out a texture; game code normally gets
    /// its handles from the load/create methods instead.
    pub const fn new(id: u32) -> Self {
        Self { id }
    }
}

/// A handle to a decoded sound owned by the engine.
///
/// As with [`TextureHandle`], `id` is opaque and only valid for the backend
/// instance that produced it.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub struct SoundHandle {
    /// Backend-assigned identifier. Obtain a handle from
    /// [`crate::Engine::load_sound`] rather than constructing it by hand.
    pub id: u32,
}

impl SoundHandle {
    /// Wraps a backend identifier in a sound handle.
    ///
    /// Backends call this when handing out a decoded sound; game code normally
    /// gets its handles from [`crate::Engine::load_sound`] instead.
    pub const fn new(id: u32) -> Self {
        Self { id }
    }
}
