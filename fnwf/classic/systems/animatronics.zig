//! Animatronic AI — port of `systems/Animatronics`.
//!
//! Positions are `Location` enums and each animatronic carries a path function
//! (one of the graphs in `world/game_data.zig`) instead of a string map.

const std: type = @import("std");
const neko: type = @import("neko");
const common: type = @import("common");

const constants: type = @import("../config/constants.zig");
const locations: type = @import("../world/locations.zig");
const game_data: type = @import("../world/game_data.zig");
const Location: type = locations.Location;
const CameraId: type = locations.CameraId;

/// The four animatronics.
pub const AnimatronicId: type = enum {
    cedro,
    eser,
    alice,
    sonk,

    /// The asset/name used for sprites and saves.
    pub fn name(self: AnimatronicId) []const u8 {
        return switch (self) {
            .cedro => "cedro",
            .eser => "eser",
            .alice => "alice",
            .sonk => "Sonk",
        };
    }
};

const PathFn: type = *const fn (Location) []const Location;

/// Where every animatronic currently is.
pub const Positions: type = struct {
    cedro: Location,
    eser: Location,
    alice: Location,
    sonk: Location,
};

/// A wandering animatronic.
pub const Animatronic: type = struct {
    anim: AnimatronicId,
    ai_level: i32,
    position: Location,
    path: PathFn,

    move_timer: f32 = 0,
    active: bool = false,
    at_door: ?Location = null,
    at_vent: bool = false,
    attacking: bool = false,
    in_office: bool = false,
    just_left_office: bool = false,
    stare_timer: f32 = 0,
    max_stare: f32 = 4.0,
    move_interval: f32 = 5.0,

    pub fn init(anim: AnimatronicId, ai_level: i32, start: Location, path: PathFn) Animatronic {
        return Animatronic{
            .anim = anim,
            .ai_level = ai_level,
            .position = start,
            .path = path,
            .active = ai_level > 0,
        };
    }

    pub fn update(self: *Animatronic, dt: f32, camera_looking_at: ?CameraId, left_door_closed: bool, right_door_closed: bool, mask_on: bool) void {
        if (!self.active or self.attacking) return;
        self.just_left_office = false;
        self.move_timer += dt;

        if (self.at_door != null or self.at_vent or self.in_office) {
            self.stare_timer += dt;
            const target_max: f32 = if (self.in_office) 3.0 else self.max_stare;
            if (self.stare_timer >= target_max) {
                if (self.position == .office_vent or self.in_office) {
                    if (!mask_on) {
                        self.attacking = true;
                    } else {
                        self.position = first_of(self.path(.office_vent)) orelse .stage;
                        self.at_vent = false;
                        self.in_office = false;
                        self.just_left_office = true;
                        self.stare_timer = 0;
                    }
                }
            }
        }

        if (self.move_timer >= self.move_interval) {
            self.move_timer = 0;
            self.try_move(camera_looking_at, left_door_closed, right_door_closed);
        }
    }

    fn try_move(self: *Animatronic, camera_looking_at: ?CameraId, left_door_closed: bool, right_door_closed: bool) void {
        _ = camera_looking_at;

        const roll: i32 = neko.random.int_range(1, 20);
        if (roll > self.ai_level) return;

        if (self.position == .left_door) {
            if (!left_door_closed) {
                self.attacking = true;
            } else {
                self.position = first_of(self.path(.left_door)) orelse .stage;
                self.at_door = null;
            }
            return;
        }
        if (self.position == .right_door) {
            if (!right_door_closed) {
                self.attacking = true;
            } else {
                self.position = first_of(self.path(.right_door)) orelse .stage;
                self.at_door = null;
            }
            return;
        }
        if (self.position == .office_vent) return;

        const possible = self.path(self.position);
        if (possible.len == 0) return;

        const next = possible[@intCast(neko.random.int_range(0, @as(i32, @intCast(possible.len)) - 1))];
        const old_pos = self.position;
        self.position = next;

        if (old_pos != next) {
            if (self.anim == .alice and (next == .vent or next == .office_vent)) {
                common.sound.play("vent", 0, -1);
            } else {
                common.sound.play_footstep_random();
            }
        }

        if (next == .left_door or next == .right_door) {
            self.at_door = next;
            self.at_vent = false;
        } else if (next == .vent) {
            self.at_vent = false;
        } else if (next == .office_vent) {
            self.at_vent = true;
            self.in_office = true;
            self.at_door = null;
            self.stare_timer = 0;
        } else {
            self.at_door = null;
            self.at_vent = false;
            self.in_office = false;
            self.stare_timer = 0;
        }
    }

    pub fn is_at_left_door(self: *const Animatronic) bool {
        return self.position == .left_door;
    }

    pub fn is_at_right_door(self: *const Animatronic) bool {
        return self.position == .right_door;
    }
};

/// Sonk, who charges the left door after staring.
pub const Sonk: type = struct {
    anim: AnimatronicId = .sonk,
    ai_level: i32,
    active: bool = false,
    position: Location = .pirate_cove,
    stage: i32 = 0,
    move_timer: f32 = 0,
    at_door: ?Location = null,
    at_vent: bool = false,
    in_office: bool = false,
    attacking: bool = false,
    stare_timer: f32 = 0,
    is_charging: bool = false,
    charge_timer: f32 = 0,
    charge_duration: f32 = 1.1,
    move_interval: f32 = 5.0,

    pub fn init(ai_level: i32) Sonk {
        return Sonk{ .ai_level = ai_level, .active = ai_level > 0 };
    }

    pub fn update(self: *Sonk, dt: f32, camera_looking_at: ?CameraId) void {
        if (!self.active or self.attacking) return;

        if (self.is_charging) {
            self.charge_timer += dt;
            if (self.charge_timer >= self.charge_duration) {
                self.is_charging = false;
                self.position = .left_door;
                self.at_door = .left_door;
                self.stare_timer = 0;
                common.sound.play("animatronic_door", 0, -1);
            }
            return;
        }

        self.move_timer += dt;

        if (self.position == .left_door) {
            self.stare_timer += dt;
            if (self.stare_timer >= 1.0) {
                self.position = .pirate_cove;
                self.stage = 0;
                self.at_door = null;
                self.stare_timer = 0;
            }
            return;
        }

        if (self.move_timer < self.move_interval) return;
        self.move_timer = 0;

        var effective_ai = self.ai_level;
        if (camera_looking_at) |cam| {
            if (cam == .pirate_cove) effective_ai = @max(0, effective_ai - 7);
        }

        const roll: i32 = neko.random.int_range(1, 20);
        if (roll > effective_ai) return;

        if (self.stage < 3) {
            self.stage += 1;
        } else {
            self.is_charging = true;
            self.charge_timer = 0;
            common.sound.play("footstep", 0, -1);
        }
    }

    pub fn is_at_left_door(self: *const Sonk) bool {
        return self.position == .left_door;
    }
};

/// Owns the four animatronics and their night configuration.
pub const AnimatronicManager: type = struct {
    cedro: Animatronic,
    eser: Animatronic,
    alice: Animatronic,
    sonk: Sonk,
    secret_mode: bool,

    pub fn init(night: i32, custom_ai: ?[]const i32) AnimatronicManager {
        var levels: [4]i32 = game_data.night_ai_levels(night);
        if (custom_ai) |ai| {
            for (0..4) |i| {
                if (i < ai.len) levels[i] = ai[i];
            }
        }

        var secret_mode = (night == 7);
        if (secret_mode and custom_ai != null) {
            for (0..4) |i| {
                if (levels[i] < 40) {
                    secret_mode = false;
                    break;
                }
            }
        }

        const move_int: f32 = if (secret_mode) 1.6 else constants.MOVE_INTERVAL;
        const cedro_path: PathFn = if (secret_mode) &game_data.any_door_path else &game_data.cedro_path;
        const eser_path: PathFn = if (secret_mode) &game_data.any_door_path else &game_data.eser_path;

        var cedro = Animatronic.init(.cedro, levels[0], .stage, cedro_path);
        var eser = Animatronic.init(.eser, levels[1], .stage, eser_path);
        var alice = Animatronic.init(.alice, levels[2], .stage, &game_data.alice_path);

        cedro.move_interval = move_int;
        eser.move_interval = move_int;
        alice.move_interval = move_int;
        if (secret_mode) {
            cedro.max_stare = 2.3;
            eser.max_stare = 2.3;
            alice.max_stare = 2.3;
        }

        var sonk_ai: i32 = levels[3];
        if (custom_ai == null and night >= 3 and sonk_ai <= 0) sonk_ai = 5;

        var sonk = Sonk.init(sonk_ai);
        sonk.move_interval = if (secret_mode) 1.25 else constants.MOVE_INTERVAL;
        if (secret_mode) sonk.charge_duration = 0.65;

        return AnimatronicManager{
            .cedro = cedro,
            .eser = eser,
            .alice = alice,
            .sonk = sonk,
            .secret_mode = secret_mode,
        };
    }

    pub fn update(self: *AnimatronicManager, dt: f32, camera_looking_at: ?CameraId, left_door_closed: bool, right_door_closed: bool, mask_on: bool) void {
        self.cedro.update(dt, camera_looking_at, left_door_closed, right_door_closed, mask_on);
        self.eser.update(dt, camera_looking_at, left_door_closed, right_door_closed, mask_on);
        self.alice.update(dt, camera_looking_at, left_door_closed, right_door_closed, mask_on);
        self.sonk.update(dt, camera_looking_at);
    }

    pub fn positions(self: *const AnimatronicManager) Positions {
        return Positions{
            .cedro = self.cedro.position,
            .eser = self.eser.position,
            .alice = self.alice.position,
            .sonk = self.sonk.position,
        };
    }

    pub fn attacker(self: *const AnimatronicManager) ?AnimatronicId {
        if (self.cedro.attacking) return .cedro;
        if (self.eser.attacking) return .eser;
        if (self.alice.attacking) return .alice;
        if (self.sonk.attacking) return .sonk;
        return null;
    }

    pub fn at_left_door(self: *const AnimatronicManager) ?AnimatronicId {
        if (self.cedro.is_at_left_door() and !self.cedro.attacking) return .cedro;
        if (self.eser.is_at_left_door() and !self.eser.attacking) return .eser;
        if (self.alice.is_at_left_door() and !self.alice.attacking) return .alice;
        if (self.sonk.is_at_left_door() and !self.sonk.attacking) return .sonk;
        return null;
    }

    pub fn at_right_door(self: *const AnimatronicManager) ?AnimatronicId {
        if (self.cedro.is_at_right_door() and !self.cedro.attacking) return .cedro;
        if (self.eser.is_at_right_door() and !self.eser.attacking) return .eser;
        if (self.alice.is_at_right_door() and !self.alice.attacking) return .alice;
        return null;
    }

    pub fn at_vent(self: *const AnimatronicManager) ?AnimatronicId {
        if (self.cedro.at_vent and !self.cedro.attacking) return .cedro;
        if (self.eser.at_vent and !self.eser.attacking) return .eser;
        if (self.alice.at_vent and !self.alice.attacking) return .alice;
        return null;
    }

    pub fn in_office(self: *const AnimatronicManager) ?AnimatronicId {
        if (self.cedro.in_office and !self.cedro.attacking) return .cedro;
        if (self.eser.in_office and !self.eser.attacking) return .eser;
        if (self.alice.in_office and !self.alice.attacking) return .alice;
        return null;
    }

    pub fn alice_just_left(self: *const AnimatronicManager) bool {
        return self.alice.just_left_office;
    }

    pub fn sonk_stage(self: *const AnimatronicManager) i32 {
        return self.sonk.stage;
    }

    pub fn is_secret_mode(self: *const AnimatronicManager) bool {
        return self.secret_mode;
    }
};

fn first_of(possible: []const Location) ?Location {
    if (possible.len == 0) return null;
    return possible[0];
}
