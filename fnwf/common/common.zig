//! Mechanics shared by every Five Nights With Friends game.
//!
//! Systems that turn out to be game-agnostic (office, cameras, doors, power,
//! animatronics, jumpscare) move here as they are ported.

/// The package release version. Keep in sync with `build.zig.zon`.
pub const VERSION: []const u8 = "2.3.0";

/// The Neko engine version this package targets (its pinned dependency).
pub const NEKO_VERSION: []const u8 = "0.1";

pub const sound = @import("sound.zig");
