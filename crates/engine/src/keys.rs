//! Raw key codes used by the game.
//!
//! These mirror `SDL_Keycode` values so that the ported gameplay code can keep
//! comparing against stable numbers, but with names that make the intent clear.

// Control / text keys
/// Backspace key.
pub const BACKSPACE: i32 = 8;
/// Tab key.
pub const TAB: i32 = 9;
/// Return / Enter key (SDL `SDLK_RETURN`, `'\r'`).
pub const RETURN: i32 = 13;
/// Escape key.
pub const ESCAPE: i32 = 27;
/// Space bar.
pub const SPACE: i32 = 32;

// Printable letters (lowercase ASCII key codes)
/// Letter `A` key.
pub const A: i32 = b'a' as i32;
/// Letter `D` key.
pub const D: i32 = b'd' as i32;
/// Letter `E` key.
pub const E: i32 = b'e' as i32;
/// Letter `L` key.
pub const L: i32 = b'l' as i32;
/// Letter `P` key.
pub const P: i32 = b'p' as i32;
/// Letter `Q` key.
pub const Q: i32 = b'q' as i32;
/// Letter `S` key.
pub const S: i32 = b's' as i32;
/// Letter `W` key.
pub const W: i32 = b'w' as i32;

// SDL key code base used for navigation and function keys.
const SCANCODE_MASK: i32 = 1 << 30;

/// The right arrow key (SDL scancode 79); one of the navigation keys (SDL
/// scancodes 79..82).
pub const RIGHT: i32 = SCANCODE_MASK | 79;
/// Left arrow key.
pub const LEFT: i32 = SCANCODE_MASK | 80;
/// Down arrow key.
pub const DOWN: i32 = SCANCODE_MASK | 81;
/// Up arrow key.
pub const UP: i32 = SCANCODE_MASK | 82;

/// The `F1` function key (SDL scancode 58); one of the function keys (SDL
/// scancodes 58..69).
pub const F1: i32 = SCANCODE_MASK | 58;
/// Function key `F2`.
pub const F2: i32 = SCANCODE_MASK | 59;
/// Function key `F3`.
pub const F3: i32 = SCANCODE_MASK | 60;
/// Function key `F4`.
pub const F4: i32 = SCANCODE_MASK | 61;
/// Function key `F5`.
pub const F5: i32 = SCANCODE_MASK | 62;
/// Function key `F6`.
pub const F6: i32 = SCANCODE_MASK | 63;
/// Function key `F7`.
pub const F7: i32 = SCANCODE_MASK | 64;
/// Function key `F8`.
pub const F8: i32 = SCANCODE_MASK | 65;
/// Function key `F9`.
pub const F9: i32 = SCANCODE_MASK | 66;
/// Function key `F10`.
pub const F10: i32 = SCANCODE_MASK | 67;
/// Function key `F11`.
pub const F11: i32 = SCANCODE_MASK | 68;
/// Function key `F12`.
pub const F12: i32 = SCANCODE_MASK | 69;

/// The `0` key on the numeric keypad (SDL scancode 88); one of the keypad
/// digits 0-9 (SDL scancodes 88..97).
pub const KP_0: i32 = SCANCODE_MASK | 88;
/// Numeric keypad digit `1`.
pub const KP_1: i32 = SCANCODE_MASK | 89;
/// Numeric keypad digit `2`.
pub const KP_2: i32 = SCANCODE_MASK | 90;
/// Numeric keypad digit `3`.
pub const KP_3: i32 = SCANCODE_MASK | 91;
/// Numeric keypad digit `4`.
pub const KP_4: i32 = SCANCODE_MASK | 92;
/// Numeric keypad digit `5`.
pub const KP_5: i32 = SCANCODE_MASK | 93;
/// Numeric keypad digit `6`.
pub const KP_6: i32 = SCANCODE_MASK | 94;
/// Numeric keypad digit `7`.
pub const KP_7: i32 = SCANCODE_MASK | 95;
/// Numeric keypad digit `8`.
pub const KP_8: i32 = SCANCODE_MASK | 96;
/// Numeric keypad digit `9`.
pub const KP_9: i32 = SCANCODE_MASK | 97;

/// Returns the key code for an ASCII digit `b'0'..=b'9'`, or `None`.
///
/// Non-digit bytes (including other ASCII characters) yield `None`.
pub const fn digit(d: u8) -> Option<i32> {
    if d.is_ascii_digit() {
        Some(d as i32)
    } else {
        None
    }
}

/// Maps a keypad key code to its digit, or `None` if not a keypad digit.
///
/// Accepts only the [`KP_0`]..[`KP_9`] codes; all other codes yield `None`.
pub const fn keypad_digit(code: i32) -> Option<u8> {
    match code {
        KP_0 => Some(0),
        KP_1 => Some(1),
        KP_2 => Some(2),
        KP_3 => Some(3),
        KP_4 => Some(4),
        KP_5 => Some(5),
        KP_6 => Some(6),
        KP_7 => Some(7),
        KP_8 => Some(8),
        KP_9 => Some(9),
        _ => None,
    }
}
