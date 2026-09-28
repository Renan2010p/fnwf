#![warn(missing_docs)]
//! `fnwf-backend-sdl2` — the desktop and web SDL2 backend.
//!
//! This crate provides the concrete SDL2 implementation of the
//! [`fnwf_engine::Engine`] trait: window and event handling, rendering, image,
//! font, and audio loading. It is the boundary between the engine-agnostic game
//! code and the platform, and is the only crate in the workspace that links
//! against SDL2 and its satellite libraries (`SDL2_image`, `SDL2_ttf`, and
//! `SDL2_mixer`).
//!
//! Construct a backend with [`create_engine`].

mod engine_sdl2;

pub use engine_sdl2::Sdl2Engine;

/// Creates the default SDL2 backend as a boxed [`fnwf_engine::Engine`].
///
/// The returned engine is uninitialized; call
/// [`Engine::init`](fnwf_engine::Engine::init) before using it.
pub fn create_engine() -> Box<dyn fnwf_engine::Engine> {
    Box::new(Sdl2Engine::default())
}
