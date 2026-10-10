// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Renan Lucas Vieira Hilário

//! FNWF 1 — the animatronic AI.
//!
//! Each walker gets a "movement opportunity" every few seconds and rolls 1-20:
//! it moves when the roll is at or below its AI level (the FNAF 1 rule). Cedro
//! only moves while he is *not* on camera; Sonk from Pirate Cove charges down
//! the west hall if nobody checks on him.

const std: type = @import("std");
const neko: type = @import("neko");
const common: type = @import("common");

const world: type = @import("world.zig");
const CharId: type = world.CharId;
const CameraId: type = world.CameraId;
const Location: type = world.Location;

/// A wandering character (Eser, Alice and Cedro).
pub const Walker: type = struct {
    id: CharId,
    ai_level: i32,
    position: Location,
    path: *const fn (Location) []const Location,
    mo_timer: f32 = 0,
    at_door: ?Location = null,
    attacking: bool = false,
    active: bool = false,
    watched: bool = false,

    pub fn init(id: CharId, ai: i32, start: Location, path: *const fn (Location) []const Location) Walker {
        return Walker{ .id = id, .ai_level = ai, .position = start, .path = path, .active = ai > 0 };
    }

    fn move(self: *Walker, left_closed: bool, right_closed: bool) void {
        if (self.position == .left_door) {
            if (!left_closed) {
                self.attacking = true;
            } else {
                self.position = .dining;
                self.at_door = null;
            }
            return;
        }
        if (self.position == .right_door) {
            if (!right_closed) {
                self.attacking = true;
            } else {
                self.position = .dining;
                self.at_door = null;
            }
            return;
        }

        const options = self.path(self.position);
        if (options.len == 0) return;
        const next = options[@intCast(neko.random.int_range(0, @as(i32, @intCast(options.len)) - 1))];
        const old = self.position;
        self.position = next;

        if (next == .left_door or next == .right_door) {
            self.at_door = next;
        } else {
            self.at_door = null;
        }

        if (old != next) {
            if (next == .left_door or next == .right_door) {
                common.sound.play("animatronic_door", 0, -1);
            } else {
                common.sound.play_footstep_random();
            }
        }
    }

    fn tick(self: *Walker, dt: f32, left_closed: bool, right_closed: bool) void {
        if (!self.active or self.attacking) return;
        self.mo_timer += dt;
        if (self.mo_timer < world.MO_TIMER[@backingInt(self.id)]) return;
        self.mo_timer = 0;
        const roll: i32 = neko.random.int_range(1, 20);
        if (roll <= self.ai_level) self.move(left_closed, right_closed);
    }
};

/// Sonk, who hides in Pirate Cove and charges the west hall.
pub const Foxy: type = struct {
    ai_level: i32,
    stage: i32 = 0,
    mo_timer: f32 = 0,
    run_timer: f32 = 0,
    is_running: bool = false,
    attacking: bool = false,
    active: bool = false,
    position: Location = .pirate_cove,

    pub fn init(ai: i32) Foxy {
        return Foxy{ .ai_level = ai, .active = ai > 0 };
    }

    fn tick(self: *Foxy, dt: f32, camera: ?CameraId, left_closed: bool) void {
        if (!self.active or self.attacking) return;

        if (self.is_running) {
            self.run_timer += dt;
            if (self.run_timer >= 1.6) {
                if (left_closed) {
                    self.is_running = false;
                    self.stage = 0;
                    self.position = .pirate_cove;
                    common.sound.play("portas", 0, -1);
                } else {
                    self.attacking = true;
                }
            }
            return;
        }

        self.mo_timer += dt;
        if (self.mo_timer < world.MO_TIMER[2]) return;
        self.mo_timer = 0;

        // Watching Pirate Cove freezes him.
        if (camera) |c| {
            if (c == .pirate_cove) return;
        }

        const roll: i32 = neko.random.int_range(1, 20);
        if (roll > self.ai_level) return;

        if (self.stage < 3) {
            self.stage += 1;
            self.position = .pirate_cove;
            common.sound.play("footstep", 0, -1);
        } else {
            self.is_running = true;
            self.run_timer = 0;
            common.sound.play("sonk_indo_pra_porta", 0, -1);
        }
    }
};

/// Owns the four characters and their night configuration.
pub const Manager: type = struct {
    eser: Walker,
    alice: Walker,
    cedro: Walker,
    sonk: Foxy,
    night: i32,
    hour_applied: i32 = 12,

    pub fn init(night: i32, custom: ?[]const i32) Manager {
        var levels: [4]i32 = world.night_ai(night);
        if (custom) |c| {
            for (0..4) |i| {
                if (i < c.len) levels[i] = c[i];
            }
        }
        return Manager{
            .eser = Walker.init(.eser, levels[0], .show_stage, &world.eser_path),
            .alice = Walker.init(.alice, levels[1], .show_stage, &world.alice_path),
            .cedro = Walker.init(.cedro, levels[3], .show_stage, &world.cedro_path),
            .sonk = Foxy.init(levels[2]),
            .night = night,
        };
    }

    /// Applies the FNAF 1 in-night AI ramp at each hour.
    pub fn apply_hour(self: *Manager, hour: i32) void {
        if (hour == self.hour_applied) return;
        self.hour_applied = hour;
        switch (hour) {
            2 => self.eser.ai_level += 1,
            3 => {
                self.eser.ai_level += 1;
                self.alice.ai_level += 1;
                self.sonk.ai_level += 1;
            },
            4 => {
                self.eser.ai_level += 1;
                self.alice.ai_level += 2;
                self.sonk.ai_level += 2;
            },
            else => {},
        }
        self.eser.active = self.eser.ai_level > 0;
        self.alice.active = self.alice.ai_level > 0;
        self.sonk.active = self.sonk.ai_level > 0;
    }

    pub fn update(self: *Manager, dt: f32, camera: ?CameraId, left_closed: bool, right_closed: bool) void {
        self.eser.tick(dt, left_closed, right_closed);
        self.alice.tick(dt, left_closed, right_closed);

        // Cedro only moves while not on camera.
        const cedro_watched = if (camera) |c| is_camera_of(c, self.cedro.position) else false;
        if (!cedro_watched) self.cedro.tick(dt, left_closed, right_closed);

        self.sonk.tick(dt, camera, left_closed);
    }

    pub fn attacker(self: *const Manager) ?CharId {
        if (self.eser.attacking) return .eser;
        if (self.alice.attacking) return .alice;
        if (self.sonk.attacking) return .sonk;
        if (self.cedro.attacking) return .cedro;
        return null;
    }

    pub fn positions(self: *const Manager) world.Positions {
        return world.Positions{
            .eser = self.eser.position,
            .alice = self.alice.position,
            .sonk = self.sonk.position,
            .cedro = self.cedro.position,
        };
    }

    pub fn at_left_door(self: *const Manager) ?CharId {
        if (self.eser.position == .left_door and !self.eser.attacking) return .eser;
        if (self.alice.position == .left_door and !self.alice.attacking) return .alice;
        return null;
    }

    pub fn at_right_door(self: *const Manager) ?CharId {
        if (self.eser.position == .right_door and !self.eser.attacking) return .eser;
        if (self.alice.position == .right_door and !self.alice.attacking) return .alice;
        // Cedro is never shown by the door light in FNAF 1.
        return null;
    }

    pub fn is_cedro_at_door(self: *const Manager) bool {
        return self.cedro.position == .right_door or self.cedro.position == .office;
    }

    pub fn sonk_stage(self: *const Manager) i32 {
        if (self.sonk.attacking) return 3;
        return self.sonk.stage;
    }
};

fn is_camera_of(cam: CameraId, loc: Location) bool {
    return if (loc.camera()) |c| c == cam else false;
}
