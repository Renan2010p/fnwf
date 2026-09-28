//! Convenience re-exports for `no_std` builds.
//!
//! With `std`, `String`, `Vec`, `Box` and `format!` are already in the prelude;
//! on bare-metal they come from `alloc`. Importing this module everywhere keeps
//! both builds compiling without `cfg` at every call site. The imports are
//! allowed to be unused under `std`.

pub use alloc::boxed::Box;
pub use alloc::format;
pub use alloc::string::{String, ToString};
pub use alloc::vec;
pub use alloc::vec::Vec;

pub use crate::math::FloatExt;
