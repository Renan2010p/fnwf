//! Small shared value types.

#[allow(unused_imports)]
use fnwf_core::prelude::*;

/// An 8-bit RGB color.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct Color {
    /// Red channel.
    pub r: u8,
    /// Green channel.
    pub g: u8,
    /// Blue channel.
    pub b: u8,
}

impl Color {
    /// Creates a color from its 8-bit red, green and blue channels.
    pub const fn new(r: u8, g: u8, b: u8) -> Self {
        Self { r, g, b }
    }

    /// Multiplies each channel by `factor`, clamping to `0..=255`.
    pub fn shade(self, factor: f32) -> Self {
        let scale = |c: u8| (c as f32 * factor).clamp(0.0, 255.0) as u8;
        Self {
            r: scale(self.r),
            g: scale(self.g),
            b: scale(self.b),
        }
    }
}
