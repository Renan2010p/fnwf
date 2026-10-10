//! Gameplay data tables for FNWF Classic Edition.
//! Port of `game1/GameData.hpp`.

const locations: type = @import("locations.zig");
const Location: type = locations.Location;

/// AI level of each animatronic (Cedro, Eser, Alice, Sonk) for a given night.
pub fn night_ai_levels(night: i32) [4]i32 {
    const levels: [7][4]i32 = .{
        .{ 3, 2, 0, 0 },
        .{ 5, 4, 3, 0 },
        .{ 7, 6, 6, 5 },
        .{ 10, 9, 10, 8 },
        .{ 13, 12, 14, 12 },
        .{ 16, 15, 18, 15 },
        .{ 20, 20, 20, 20 },
    };
    if (night < 1 or night > 7) return levels[0];
    return levels[@intCast(night - 1)];
}

/// Cedro's movement graph (sneaks down the left hall).
pub fn cedro_path(from: Location) []const Location {
    return switch (from) {
        .stage => &.{.dining},
        .dining => &.{ .west_hall, .supply, .backstage },
        .backstage => &.{.dining},
        .west_hall => &.{ .west_corner, .dining, .supply },
        .supply => &.{.west_hall},
        .west_corner => &.{.left_door},
        .left_door => &.{.dining},
        else => &.{},
    };
}

/// Eser's movement graph (charges the right hall).
pub fn eser_path(from: Location) []const Location {
    return switch (from) {
        .stage => &.{.dining},
        .dining => &.{.east_hall},
        .east_hall => &.{ .east_corner, .dining },
        .east_corner => &.{.right_door},
        .right_door => &.{.dining},
        else => &.{},
    };
}

/// Alice's movement graph (crawls through the vents).
pub fn alice_path(from: Location) []const Location {
    return switch (from) {
        .stage => &.{.dining},
        .dining => &.{ .east_hall, .west_hall },
        .east_hall => &.{.vent},
        .west_hall => &.{.vent},
        .vent => &.{.office_vent},
        .office_vent => &.{.dining},
        else => &.{},
    };
}

/// The generic graph used by any animatronic that can take any door.
pub fn any_door_path(from: Location) []const Location {
    return switch (from) {
        .stage => &.{.dining},
        .dining => &.{ .west_hall, .east_hall, .supply, .backstage },
        .backstage => &.{.dining},
        .west_hall => &.{ .west_corner, .dining, .supply, .east_hall },
        .west_corner => &.{ .left_door, .right_door, .west_hall },
        .supply => &.{ .west_hall, .dining },
        .east_hall => &.{ .east_corner, .dining, .west_hall },
        .east_corner => &.{ .right_door, .left_door, .east_hall },
        .left_door => &.{.dining},
        .right_door => &.{.dining},
        else => &.{},
    };
}
