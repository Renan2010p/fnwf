#![cfg_attr(not(feature = "std"), no_std)]
#![warn(missing_docs)]
//! `fnwf-game` — gameplay systems and states.

extern crate alloc;

pub mod colors;
pub mod data;
pub mod states;
pub mod systems;
pub mod types;
