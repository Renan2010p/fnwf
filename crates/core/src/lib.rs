#![cfg_attr(not(feature = "std"), no_std)]
#![warn(missing_docs)]
//! `fnwf-core` — engine-agnostic game services.
//!
//! Everything in this crate only depends on the [`fnwf_engine::Engine`] trait.
//! It is split into focused modules:
//!
//! * [`config`]       — screen constants and asset path helpers
//! * [`draw`]         — sprites, text, scanlines, vignette, … (`DrawUtils`)
//! * [`audio`]        — cached sound effects (`SoundManager`)
//! * [`localization`] — embedded pt/en strings
//! * [`settings`]     — user settings persisted to `config.dat`
//! * [`save`]         — progress + in-game snapshot persistence
//! * [`rng`]          — small deterministic RNG
//! * [`state`]        — the [`state::GameState`] trait and [`state::StateMachine`]
//! * [`time`]         — monotonic clock used for animated effects
//!
//! The crate builds with or without the standard library: disable the default
//! `std` feature for bare-metal targets such as the PlayStation 2 (`alloc` is
//! still required).

extern crate alloc;

pub mod audio;
pub mod config;
pub mod draw;
pub mod localization;
pub mod math;
pub mod prelude;
pub mod rng;
pub mod save;
pub mod settings;
pub mod state;
pub mod time;
