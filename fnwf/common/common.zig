//! Mechanics shared by every Five Nights With Friends game.
//!
//! Systems that turn out to be game-agnostic (office, cameras, doors, power,
//! animatronics, jumpscare) move here as they are ported.

pub const sound = @import("sound.zig");
