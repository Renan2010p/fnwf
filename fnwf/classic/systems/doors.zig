// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Renan Lucas Vieira Hilário

//! Office doors and lights — port of `systems/Doors`.
//!
//! The buttons now live inside the office panorama (`office.zig`), so this
//! system only owns the state, the slide animation and the power usage.

/// A door/light control.
pub const Button: type = enum { left_door, left_light, right_door, right_light };

/// The two door panels and their open/close + light state.
pub const Doors: type = struct {
    left_closed: bool = false,
    right_closed: bool = false,
    left_light: bool = false,
    right_light: bool = false,
    left_anim: f32 = 0,
    right_anim: f32 = 0,
    anim_speed: f32 = 4.0,

    pub fn update(self: *Doors, dt: f32) void {
        const tl: f32 = if (self.left_closed) 1.0 else 0.0;
        if (self.left_anim < tl) {
            self.left_anim = @min(tl, self.left_anim + self.anim_speed * dt);
        } else if (self.left_anim > tl) {
            self.left_anim = @max(tl, self.left_anim - self.anim_speed * dt);
        }

        const tr: f32 = if (self.right_closed) 1.0 else 0.0;
        if (self.right_anim < tr) {
            self.right_anim = @min(tr, self.right_anim + self.anim_speed * dt);
        } else if (self.right_anim > tr) {
            self.right_anim = @max(tr, self.right_anim - self.anim_speed * dt);
        }
    }

    /// Toggles `button`. Returns the sound to play ("door" or "light").
    pub fn press(self: *Doors, button: Button) []const u8 {
        switch (button) {
            .left_door => {
                self.left_closed = !self.left_closed;
                return "door";
            },
            .right_door => {
                self.right_closed = !self.right_closed;
                return "door";
            },
            .left_light => {
                self.left_light = !self.left_light;
                if (self.left_light) self.right_light = false;
                return "light";
            },
            .right_light => {
                self.right_light = !self.right_light;
                if (self.right_light) self.left_light = false;
                return "light";
            },
        }
    }

    /// How many of the four door/light toggles are on.
    pub fn power_usage(self: *const Doors) i32 {
        var usage: i32 = 0;
        if (self.left_closed) usage += 1;
        if (self.right_closed) usage += 1;
        if (self.left_light) usage += 1;
        if (self.right_light) usage += 1;
        return usage;
    }
};
