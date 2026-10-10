// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Renan Lucas Vieira Hilário

//! Cheat toggles from the Extras screen.
//!
//! In the C++ these were stored but never read: the toggles did nothing and
//! were not saved. Here they are threaded into `Gameplay` so they actually
//! change the night, and persisted through `save.save_progress`.

/// The two configurable modifiers.
pub const Cheats: type = struct {
    /// The power meter never drains.
    infinite_power: bool = false,
    /// The night runs at double speed (half the usual duration).
    fast_nights: bool = false,
};
