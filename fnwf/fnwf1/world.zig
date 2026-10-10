// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Renan Lucas Vieira Hilário

//! FNWF 1 — world data: cameras, characters, night AI levels and movement.

const std: type = @import("std");
const mem: type = std.mem;

/// A room the cameras can show.
pub const CameraId: type = enum {
    show_stage,
    dining,
    pirate_cove,
    west_hall,
    west_corner,
    supply,
    east_hall,
    east_corner,
    backstage,
    kitchen,
    restrooms,

    /// The on-monitor code (1A, 1B, …).
    pub fn code(self: CameraId) []const u8 {
        return switch (self) {
            .show_stage => "1A",
            .dining => "1B",
            .pirate_cove => "1C",
            .west_hall => "2A",
            .west_corner => "2B",
            .supply => "3",
            .east_hall => "4A",
            .east_corner => "4B",
            .backstage => "5",
            .kitchen => "6",
            .restrooms => "7",
        };
    }

    pub fn name(self: CameraId) []const u8 {
        return switch (self) {
            .show_stage => "Show Stage",
            .dining => "Dining Area",
            .pirate_cove => "Pirate Cove",
            .west_hall => "West Hall",
            .west_corner => "West Hall Corner",
            .supply => "Supply Closet",
            .east_hall => "East Hall",
            .east_corner => "East Hall Corner",
            .backstage => "Backstage",
            .kitchen => "Kitchen",
            .restrooms => "Restrooms",
        };
    }
};

/// Anywhere a character can be: a camera, a door, or the office.
pub const Location: type = enum {
    show_stage,
    dining,
    pirate_cove,
    west_hall,
    west_corner,
    supply,
    east_hall,
    east_corner,
    backstage,
    kitchen,
    restrooms,
    left_door,
    right_door,
    office,

    pub fn camera(self: Location) ?CameraId {
        return switch (self) {
            .show_stage => .show_stage,
            .dining => .dining,
            .pirate_cove => .pirate_cove,
            .west_hall => .west_hall,
            .west_corner => .west_corner,
            .supply => .supply,
            .east_hall => .east_hall,
            .east_corner => .east_corner,
            .backstage => .backstage,
            .kitchen => .kitchen,
            .restrooms => .restrooms,
            .left_door, .right_door, .office => null,
        };
    }

    pub fn fromCamera(cam: CameraId) Location {
        return switch (cam) {
            .show_stage => .show_stage,
            .dining => .dining,
            .pirate_cove => .pirate_cove,
            .west_hall => .west_hall,
            .west_corner => .west_corner,
            .supply => .supply,
            .east_hall => .east_hall,
            .east_corner => .east_corner,
            .backstage => .backstage,
            .kitchen => .kitchen,
            .restrooms => .restrooms,
        };
    }
};

/// The four characters.
pub const CharId: type = enum {
    eser,
    alice,
    sonk,
    cedro,

    pub fn name(self: CharId) []const u8 {
        return switch (self) {
            .eser => "Eser",
            .alice => "Alice",
            .sonk => "Sonk",
            .cedro => "Cedro",
        };
    }

    pub fn sprite(self: CharId) []const u8 {
        return switch (self) {
            .eser => "eser",
            .alice => "alice",
            .sonk => "Sonk",
            .cedro => "cedro",
        };
    }
};

/// Where every character currently is.
pub const Positions: type = struct {
    eser: Location,
    alice: Location,
    sonk: Location,
    cedro: Location,
};

/// Base AI levels for a night, in `[eser, alice, sonk, cedro]` order.
pub fn night_ai(night: i32) [4]i32 {
    const table: [6][4]i32 = .{
        .{ 0, 0, 0, 0 },
        .{ 3, 1, 1, 0 },
        .{ 0, 5, 2, 1 },
        .{ 2, 4, 6, 1 },
        .{ 5, 7, 5, 3 },
        .{ 10, 12, 6, 4 },
    };
    if (night < 1 or night > 6) return table[0];
    return table[@intCast(night - 1)];
}

/// Seconds between movement opportunities (FNAF 1 timers).
pub const MO_TIMER: [4]f32 = .{ 4.97, 4.98, 5.01, 3.02 };

/// `eser`'s route (left side).
pub fn eser_path(from: Location) []const Location {
    return switch (from) {
        .show_stage => &.{.dining},
        .dining => &.{ .backstage, .supply },
        .backstage => &.{.west_hall},
        .supply => &.{.west_hall},
        .west_hall => &.{.west_corner},
        .west_corner => &.{.left_door},
        .left_door => &.{.dining},
        else => &.{},
    };
}

/// `alice`'s route (right side).
pub fn alice_path(from: Location) []const Location {
    return switch (from) {
        .show_stage => &.{.dining},
        .dining => &.{ .restrooms, .kitchen },
        .restrooms => &.{.kitchen},
        .kitchen => &.{.east_hall},
        .east_hall => &.{.east_corner},
        .east_corner => &.{.right_door},
        .right_door => &.{.dining},
        else => &.{},
    };
}

/// `cedro`'s route: the same right side, but he can reach the office.
pub fn cedro_path(from: Location) []const Location {
    return switch (from) {
        .show_stage => &.{.dining},
        .dining => &.{ .restrooms, .kitchen },
        .restrooms => &.{.kitchen},
        .kitchen => &.{.east_hall},
        .east_hall => &.{.east_corner},
        .east_corner => &.{.right_door},
        .right_door => &.{.office},
        else => &.{},
    };
}

/// True when `name` (a character) appears in `cam`.
pub fn in_camera(cam: CameraId, loc: Location) bool {
    return if (loc.camera()) |c| c == cam else false;
}

/// Case-insensitive-ish equality helper used across the game.
pub fn eql(a: []const u8, b: []const u8) bool {
    return mem.eql(u8, a, b);
}
