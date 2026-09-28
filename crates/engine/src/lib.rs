#![cfg_attr(not(feature = "std"), no_std)]
#![warn(missing_docs)]
//! `fnwf-engine` — the pure, platform-agnostic engine contract.
//!
//! This crate knows nothing about SDL, the GPU or the operating system. It only
//! defines the [`Engine`] trait, the [`Event`] type and opaque resource
//! handles. Every other crate talks to the engine through these types, which
//! keeps the game and the platform backends fully decoupled.
//!
//! The crate builds with or without the standard library: disable the default
//! `std` feature to target bare-metal platforms such as the PlayStation 2
//! (`alloc` is still required for `String`/`Vec`).

extern crate alloc;

mod engine;
pub mod event;
pub mod handle;
pub mod keys;

pub use engine::Engine;
pub use event::{Event, EventType};
pub use handle::{SoundHandle, TextureHandle};
