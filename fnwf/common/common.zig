//! Mechanics shared by every Five Nights With Friends game.
//!
//! Systems that turn out to be game-agnostic (office, cameras, doors, power,
//! animatronics, jumpscare) move here as they are ported.

const std: type = @import("std");
const neko: type = @import("neko");

/// The package release version. Keep in sync with `build.zig.zon`.
pub const VERSION: []const u8 = "2.3.0";

/// The engine version, shortened to `major.minor` for the menus (e.g. "0.1").
/// Sourced from `neko.version`.
pub const NEKO_VERSION: []const u8 = blk: {
    const full: []const u8 = neko.version;
    const patch: ?usize = std.mem.lastIndexOfScalar(u8, full, '.');
    break :blk if (patch) |i| full[0..i] else full;
};

pub const sound = @import("sound.zig");
