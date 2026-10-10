// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Renan Lucas Vieira Hilário

//! FNWF 1 — constants and palette.

const neko: type = @import("neko");

pub const SCREEN_W = 1280;
pub const SCREEN_H = 720;

/// One in-game hour, in seconds. Six of them make a night.
pub const HOUR_SECONDS: f32 = 80.0;
pub const HOURS = 6;
pub const NIGHT_SECONDS: f32 = HOUR_SECONDS * @as(f32, @floatFromInt(HOURS));

pub const POWER_MAX: f32 = 100.0;
/// Percent of power drained per second, per usage bar.
pub const BASE_POWER_DRAIN: f32 = 0.135;

pub const OFFICE_W = 1920;

pub const ASSETS_DIR: []const u8 = "fnwf/fnwf1/assets";

// ── Palette ──────────────────────────────────────────────────────────────

pub const BLACK: neko.Color = neko.Color{ .r = 0, .g = 0, .b = 0 };
pub const WHITE: neko.Color = neko.Color{ .r = 255, .g = 255, .b = 255 };
pub const DARK: neko.Color = neko.Color{ .r = 8, .g = 8, .b = 10 };
pub const PANEL: neko.Color = neko.Color{ .r = 16, .g = 16, .b = 20 };
pub const LINE: neko.Color = neko.Color{ .r = 55, .g = 55, .b = 62 };
pub const MUTED: neko.Color = neko.Color{ .r = 140, .g = 140, .b = 148 };
pub const ACCENT: neko.Color = neko.Color{ .r = 220, .g = 200, .b = 90 };
pub const GREEN: neko.Color = neko.Color{ .r = 70, .g = 210, .b = 110 };
pub const RED: neko.Color = neko.Color{ .r = 210, .g = 50, .b = 50 };

pub const WALL: neko.Color = neko.Color{ .r = 46, .g = 42, .b = 52 };
pub const WALL_DARK: neko.Color = neko.Color{ .r = 30, .g = 27, .b = 35 };
pub const FLOOR: neko.Color = neko.Color{ .r = 34, .g = 29, .b = 27 };
pub const FLOOR_2: neko.Color = neko.Color{ .r = 40, .g = 35, .b = 32 };
pub const DESK: neko.Color = neko.Color{ .r = 62, .g = 52, .b = 46 };
pub const DESK_TOP: neko.Color = neko.Color{ .r = 76, .g = 64, .b = 58 };
pub const DOOR: neko.Color = neko.Color{ .r = 96, .g = 54, .b = 40 };
pub const DOOR_EDGE: neko.Color = neko.Color{ .r = 60, .g = 34, .b = 26 };
pub const HALL_LIGHT: neko.Color = neko.Color{ .r = 214, .g = 200, .b = 150 };
pub const MONITOR_GREEN: neko.Color = neko.Color{ .r = 60, .g = 200, .b = 90 };
