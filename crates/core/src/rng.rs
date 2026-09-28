//! A tiny, fast, non-cryptographic RNG shared by the whole game.
//!
//! Uses a PCG32 whose state is held in a `spin::Mutex` (there is no
//! `thread_local!` on bare-metal targets). API mirrors the original
//! `fnwf::Rng` helpers.

use spin::Mutex;

static STATE: Mutex<u64> = Mutex::new(0);

/// Returns (and lazily initialises) the generator state.
fn state() -> spin::MutexGuard<'static, u64> {
    let mut guard = STATE.lock();
    if *guard == 0 {
        *guard = seed();
    }
    guard
}

fn seed() -> u64 {
    #[cfg(feature = "std")]
    {
        use std::time::{SystemTime, UNIX_EPOCH};
        let nanos = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .map(|d| d.as_nanos() as u64)
            .unwrap_or(0x9E37_79B9_7F4A_7C15);
        let addr = &nanos as *const u64 as u64;
        let mut x = nanos ^ addr.rotate_left(17) ^ 0x9E37_79B9_7F4A_7C15;
        x = (x ^ (x >> 30)).wrapping_mul(0xBF58_476D_1CE4_E5B9);
        x = (x ^ (x >> 27)).wrapping_mul(0x94D0_49BB_1331_11EB);
        x ^ (x >> 31)
    }
    #[cfg(not(feature = "std"))]
    {
        // No clock on bare metal; a fixed non-zero seed is enough for gameplay.
        0x9E37_79B9_7F4A_7C15
    }
}

/// Advances the generator and returns a raw 32-bit value.
fn next_u32() -> u32 {
    let mut s = state();
    let old = *s;
    let next = old
        .wrapping_mul(6364136223846793005)
        .wrapping_add(1442695040888963407);
    *s = next;
    let xorshifted = (((old >> 18) ^ old) >> 27) as u32;
    let rot = (old >> 59) as u32;
    xorshifted.rotate_right(rot)
}

/// Uniform integer in the inclusive range `[min, max]`.
pub fn int_range(min: i32, max: i32) -> i32 {
    if max <= min {
        return min;
    }
    let span = (max - min + 1) as u32;
    let value = next_u32() % span;
    min + value as i32
}

/// Uniform float in `[min, max)`.
pub fn float_range(min: f32, max: f32) -> f32 {
    let unit = next_u32() as f32 / (u32::MAX as f32 + 1.0);
    min + (max - min) * unit
}

/// Returns `true` with probability `chance` (clamped to `[0, 1]`).
pub fn probability(chance: f32) -> bool {
    float_range(0.0, 1.0) < chance
}

/// Returns a random element from a slice, or `None` if empty.
pub fn choice<T>(items: &[T]) -> Option<&T> {
    if items.is_empty() {
        None
    } else {
        Some(&items[int_range(0, items.len() as i32 - 1) as usize])
    }
}
