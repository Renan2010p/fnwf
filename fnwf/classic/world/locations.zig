//! Camera ids and movement nodes.
//!
//! The C++ used free-form strings ("1A", "LEFT_DOOR", ...). Here they are
//! enums, so a typo is a compile error. `code`/`from_code` convert to and from
//! the strings used in save files.

const std: type = @import("std");
const mem: type = std.mem;

/// A camera the monitor can show.
pub const CameraId: type = enum {
    stage,
    dining,
    backstage,
    pirate_cove,
    west_hall,
    west_corner,
    supply,
    east_hall,
    east_corner,
    vent,

    /// The on-monitor code, e.g. "1A".
    pub fn code(self: CameraId) []const u8 {
        return switch (self) {
            .stage => "1A",
            .dining => "1B",
            .backstage => "1C",
            .pirate_cove => "5",
            .west_hall => "2A",
            .west_corner => "2B",
            .supply => "3",
            .east_hall => "4A",
            .east_corner => "4B",
            .vent => "V",
        };
    }

    /// The human-readable name, e.g. "Show Stage".
    pub fn name(self: CameraId) []const u8 {
        return switch (self) {
            .stage => "Show Stage",
            .dining => "Dining Area",
            .backstage => "Backstage",
            .pirate_cove => "Pirate Cove",
            .west_hall => "West Hall",
            .west_corner => "West Hall Corner",
            .supply => "Supply Closet",
            .east_hall => "East Hall",
            .east_corner => "East Hall Corner",
            .vent => "Ventilation",
        };
    }

    /// The inverse of `code`.
    pub fn from_code(text: []const u8) ?CameraId {
        const pairs = [_]struct { code: []const u8, id: CameraId }{
            .{ .code = "1A", .id = .stage },
            .{ .code = "1B", .id = .dining },
            .{ .code = "1C", .id = .backstage },
            .{ .code = "5", .id = .pirate_cove },
            .{ .code = "2A", .id = .west_hall },
            .{ .code = "2B", .id = .west_corner },
            .{ .code = "3", .id = .supply },
            .{ .code = "4A", .id = .east_hall },
            .{ .code = "4B", .id = .east_corner },
            .{ .code = "V", .id = .vent },
        };
        for (pairs) |p| {
            if (mem.eql(u8, text, p.code)) return p.id;
        }
        return null;
    }
};

/// Anywhere an animatronic can be: a camera, a door, or the office vent.
pub const Location: type = enum {
    stage,
    dining,
    backstage,
    pirate_cove,
    west_hall,
    west_corner,
    supply,
    east_hall,
    east_corner,
    vent,
    left_door,
    right_door,
    office_vent,

    /// The camera at this location, if it is one.
    pub fn camera(self: Location) ?CameraId {
        return switch (self) {
            .stage => .stage,
            .dining => .dining,
            .backstage => .backstage,
            .pirate_cove => .pirate_cove,
            .west_hall => .west_hall,
            .west_corner => .west_corner,
            .supply => .supply,
            .east_hall => .east_hall,
            .east_corner => .east_corner,
            .vent => .vent,
            .left_door, .right_door, .office_vent => null,
        };
    }

    /// The string used in save files, e.g. "1A" or "LEFT_DOOR".
    pub fn code(self: Location) []const u8 {
        return switch (self) {
            .stage => "1A",
            .dining => "1B",
            .backstage => "1C",
            .pirate_cove => "5",
            .west_hall => "2A",
            .west_corner => "2B",
            .supply => "3",
            .east_hall => "4A",
            .east_corner => "4B",
            .vent => "V",
            .left_door => "LEFT_DOOR",
            .right_door => "RIGHT_DOOR",
            .office_vent => "OFFICE_VENT",
        };
    }

    /// The inverse of `code`.
    pub fn from_code(text: []const u8) ?Location {
        const pairs = [_]struct { code: []const u8, loc: Location }{
            .{ .code = "1A", .loc = .stage },
            .{ .code = "1B", .loc = .dining },
            .{ .code = "1C", .loc = .backstage },
            .{ .code = "5", .loc = .pirate_cove },
            .{ .code = "2A", .loc = .west_hall },
            .{ .code = "2B", .loc = .west_corner },
            .{ .code = "3", .loc = .supply },
            .{ .code = "4A", .loc = .east_hall },
            .{ .code = "4B", .loc = .east_corner },
            .{ .code = "V", .loc = .vent },
            .{ .code = "LEFT_DOOR", .loc = .left_door },
            .{ .code = "RIGHT_DOOR", .loc = .right_door },
            .{ .code = "OFFICE_VENT", .loc = .office_vent },
        };
        for (pairs) |p| {
            if (mem.eql(u8, text, p.code)) return p.loc;
        }
        return null;
    }

    /// The location of a camera, for comparisons.
    pub fn from_camera(cam: CameraId) Location {
        return switch (cam) {
            .stage => .stage,
            .dining => .dining,
            .backstage => .backstage,
            .pirate_cove => .pirate_cove,
            .west_hall => .west_hall,
            .west_corner => .west_corner,
            .supply => .supply,
            .east_hall => .east_hall,
            .east_corner => .east_corner,
            .vent => .vent,
        };
    }
};
