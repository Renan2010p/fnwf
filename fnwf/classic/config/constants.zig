//! Screen and gameplay constants for FNWF Classic Edition.
//! Port of `game1/Constants.hpp`.

const std: type = @import("std");
const fmt: type = std.fmt;

pub const SCREEN_WIDTH: i32 = 1280;
pub const SCREEN_HEIGHT: i32 = 720;
pub const FPS: i32 = 60;

/// Assets live inside the game package; the engine is told the same path.
pub const ASSETS_DIR: []const u8 = "fnwf/classic/assets";

pub const HOUR_DURATION: f32 = 60.0;
pub const MAX_POWER: f32 = 100.0;
pub const BASE_POWER_DRAIN: f32 = 0.12;
pub const OFFICE_WIDTH: i32 = 1280;

pub const PAN_SPEED: f32 = 8.0;
pub const PAN_MARGIN: i32 = 200;
pub const MOVE_INTERVAL: f32 = 5.0;

/// Formats `<ASSETS_DIR>/<name><ext>` into `buf`.
pub fn asset_file_into(buf: []u8, name: []const u8, ext: []const u8) []const u8 {
    return fmt.bufPrint(buf, "{s}/{s}{s}", .{ ASSETS_DIR, name, ext }) catch "";
}
