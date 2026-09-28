//! Monotonic clock used by animated effects (fans, blinking eye, …).
//!
//! With `std` this is backed by [`std::time::Instant`]. On bare-metal targets
//! it is a counter advanced by the platform loop via [`advance`].

#[cfg(feature = "std")]
mod imp {
    use std::sync::LazyLock;
    use std::time::Instant;

    static START: LazyLock<Instant> = LazyLock::new(Instant::now);

    /// Seconds elapsed since the first call to this module.
    pub fn now() -> f32 {
        START.elapsed().as_secs_f32()
    }

    /// No-op: the `std` clock advances on its own.
    pub fn advance(_dt: f32) {}
}

#[cfg(not(feature = "std"))]
mod imp {
    use core::sync::atomic::{AtomicU32, Ordering};

    /// Milliseconds accumulated so far (stored as `f32` bits for lock-free
    /// access).
    static NOW: AtomicU32 = AtomicU32::new(0);

    /// Seconds elapsed since start.
    pub fn now() -> f32 {
        f32::from_bits(NOW.load(Ordering::Relaxed))
    }

    /// Advances the clock by `dt` seconds. Call once per frame on bare metal.
    pub fn advance(dt: f32) {
        let value = now() + dt;
        NOW.store(value.to_bits(), Ordering::Relaxed);
    }
}

pub use imp::{advance, now};
