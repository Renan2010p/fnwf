//! Palette used throughout the office and UI (C++ `GameSettings` colors).

#[allow(unused_imports)]
use fnwf_core::prelude::*;

use crate::types::Color;

/// Pure black.
pub const BLACK: Color = Color::new(0, 0, 0);
/// Pure white.
pub const WHITE: Color = Color::new(255, 255, 255);
/// Near-black used for deep shadow backgrounds.
pub const DARK_GRAY: Color = Color::new(30, 30, 35);
/// Medium gray used for mid-tone surfaces.
pub const MED_GRAY: Color = Color::new(50, 50, 58);
/// Light gray used for elevated surfaces.
pub const LIGHT_GRAY: Color = Color::new(80, 80, 90);
/// Base wall color of the office.
pub const WALL_COLOR: Color = Color::new(45, 42, 50);
/// Trim/accent color painted on the office walls.
pub const WALL_ACCENT: Color = Color::new(55, 52, 62);
/// Base floor color of the office.
pub const FLOOR_COLOR: Color = Color::new(35, 30, 28);
/// First color of the alternating floor checkerboard.
pub const FLOOR_TILE_1: Color = Color::new(40, 35, 32);
/// Second color of the alternating floor checkerboard.
pub const FLOOR_TILE_2: Color = Color::new(30, 26, 24);
/// Ceiling color of the office.
pub const CEILING_COLOR: Color = Color::new(25, 25, 30);
/// Body/side color of the office desk.
pub const DESK_COLOR: Color = Color::new(60, 50, 45);
/// Top surface color of the office desk.
pub const DESK_TOP: Color = Color::new(70, 60, 55);
/// Color of the closed security doors.
pub const DOOR_COLOR: Color = Color::new(80, 75, 70);
/// Color of the metal frames around the hallways.
pub const DOOR_FRAME_COLOR: Color = Color::new(55, 50, 48);
/// Green indicator used on active buttons and thumbnails.
pub const BUTTON_GREEN: Color = Color::new(30, 180, 60);
/// Red indicator used on active/alert buttons.
pub const BUTTON_RED: Color = Color::new(200, 40, 40);
/// Gray indicator used on inactive buttons.
pub const BUTTON_OFF: Color = Color::new(60, 60, 65);
/// Warm light cast into the hallways by the door lights.
pub const HALL_LIGHT: Color = Color::new(180, 170, 140);
/// Phosphor green of the camera monitor UI.
pub const MONITOR_GREEN: Color = Color::new(20, 200, 80);
/// Dark background of the camera monitor screen.
pub const MONITOR_BG: Color = Color::new(10, 15, 10);
/// Tint of the static noise overlay.
pub const STATIC_COLOR: Color = Color::new(120, 120, 120);
/// Default HUD text color.
pub const HUD_COLOR: Color = Color::new(200, 200, 200);
/// Power gauge color when the battery is healthy.
pub const POWER_COLOR: Color = Color::new(80, 200, 80);
/// Power gauge color when the battery is low.
pub const POWER_LOW: Color = Color::new(200, 60, 60);
/// Green outline of the camera map.
pub const CAM_OUTLINE: Color = Color::new(60, 180, 60);
/// Title text color for menus and screens.
pub const TITLE_COLOR: Color = Color::new(220, 220, 220);
/// Gold color of achievement stars.
pub const STAR_COLOR: Color = Color::new(255, 255, 100);
/// Signature color for the Cedro animatronic.
pub const CEDRO_COLOR: Color = Color::new(140, 110, 80);
/// Signature color for the Eser animatronic.
pub const ESER_COLOR: Color = Color::new(40, 60, 180);
/// Signature color for the Alice animatronic.
pub const ALICE_COLOR: Color = Color::new(255, 105, 180);
