//! Float math that works with or without the standard library.
//!
//! The standard library's inherent `f32` methods (`sin`, `cos`, `sqrt`, …) do
//! not exist on bare-metal targets. [`FloatExt`] mirrors the ones the game uses
//! and is implemented with `libm` when the `std` feature is off. With `std` it
//! simply forwards to the inherent methods, so behaviour on desktop is
//! unchanged.
//!
//! Bring the trait into scope in any module that does float math:
//!
//! ```ignore
//! use fnwf_core::math::FloatExt;
//! let y = angle.sin();
//! ```

macro_rules! float_ext {
    ($($method:ident => $libm:ident),* $(,)?) => {
        /// Extension trait providing the `f32` math methods the game needs on
        /// targets that have no standard library.
        pub trait FloatExt {
            $(
                #[doc = concat!("Returns the `", stringify!($method), "` of `self`.")]
                fn $method(self) -> f32;
            )*
            /// Raises `self` to an integer power.
            fn powi(self, n: i32) -> f32;
            /// Raises `self` to the power `y`.
            fn powf(self, y: f32) -> f32;
        }

        impl FloatExt for f32 {
            $(
                #[cfg(feature = "std")]
                #[inline]
                fn $method(self) -> f32 {
                    f32::$method(self)
                }
                #[cfg(not(feature = "std"))]
                #[inline]
                fn $method(self) -> f32 {
                    libm::$libm(self)
                }
            )*

            #[cfg(feature = "std")]
            #[inline]
            fn powi(self, n: i32) -> f32 {
                f32::powi(self, n)
            }
            #[cfg(not(feature = "std"))]
            fn powi(self, n: i32) -> f32 {
                // Integer power by repeated squaring (libm has no `powi`).
                let mut result = 1.0f32;
                let mut base = self;
                let mut exp = n.unsigned_abs();
                while exp > 0 {
                    if exp & 1 == 1 {
                        result *= base;
                    }
                    base *= base;
                    exp >>= 1;
                }
                if n < 0 {
                    1.0 / result
                } else {
                    result
                }
            }

            #[cfg(feature = "std")]
            #[inline]
            fn powf(self, y: f32) -> f32 {
                f32::powf(self, y)
            }
            #[cfg(not(feature = "std"))]
            #[inline]
            fn powf(self, y: f32) -> f32 {
                libm::powf(self, y)
            }
        }
    };
}

float_ext! {
    sin => sinf,
    cos => cosf,
    tan => tanf,
    atan => atanf,
    asin => asinf,
    acos => acosf,
    sqrt => sqrtf,
    exp => expf,
    ln => logf,
    abs => fabsf,
    floor => floorf,
    ceil => ceilf,
    round => roundf,
    trunc => truncf,
}

/// Two-argument arctangent.
#[cfg(feature = "std")]
#[inline]
pub fn atan2(y: f32, x: f32) -> f32 {
    y.atan2(x)
}

/// Two-argument arctangent.
#[cfg(not(feature = "std"))]
#[inline]
pub fn atan2(y: f32, x: f32) -> f32 {
    libm::atan2f(y, x)
}
