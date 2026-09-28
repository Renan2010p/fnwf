//! Backend-neutral input / window events.
//!
//! `key` carries the raw platform key code (for the SDL2 backend this is
//! `SDL_Keycode`). Use the constants in [`crate::keys`] instead of magic
//! numbers when comparing against it.

use alloc::string::String;

/// The kind of an [`Event`].
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum EventType {
    /// No event, or the placeholder used by [`Event::none`].
    None,
    /// The user asked to close the window (SDL quit event).
    Quit,
    /// A key was pressed; [`Event::key`] holds the raw key code.
    KeyDown,
    /// A key was released; [`Event::key`] holds the raw key code.
    KeyUp,
    /// A mouse button was pressed; `x`/`y` hold the cursor position.
    MouseButtonDown,
    /// A mouse button was released; `x`/`y` hold the cursor position.
    MouseButtonUp,
    /// The cursor moved; `x`/`y` hold the new position.
    MouseMotion,
    /// The wheel was scrolled; `y` holds the scroll amount (positive = up).
    MouseWheel,
}

/// A single input / lifecycle event produced by the engine.
#[derive(Debug, Clone)]
pub struct Event {
    /// What happened.
    pub kind: EventType,
    /// Raw platform key code. Only meaningful for keyboard events.
    pub key: i32,
    /// Human-readable key name supplied by the platform, when available.
    pub key_name: String,
    /// Human-readable scancode name supplied by the platform, when available.
    pub scan_name: String,
    /// Horizontal cursor position in logical screen pixels (mouse events).
    pub x: i32,
    /// Vertical cursor position in logical screen pixels (mouse events); also
    /// carries the scroll delta for [`EventType::MouseWheel`].
    pub y: i32,
}

impl Default for Event {
    fn default() -> Self {
        Self::none()
    }
}

impl Event {
    /// An empty event.
    ///
    /// Equivalent to a zeroed event whose kind is [`EventType::None`].
    pub const fn none() -> Self {
        Self {
            kind: EventType::None,
            key: 0,
            key_name: String::new(),
            scan_name: String::new(),
            x: 0,
            y: 0,
        }
    }

    /// An event of the given kind with everything else zeroed.
    pub const fn new(kind: EventType) -> Self {
        Self {
            kind,
            key: 0,
            key_name: String::new(),
            scan_name: String::new(),
            x: 0,
            y: 0,
        }
    }
}
