// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Renan Lucas Vieira Hilário

//! FNWF 1 — one night in the office.

const std: type = @import("std");
const fmt: type = std.fmt;
const neko: type = @import("neko");
const common: type = @import("common");

const screen: type = @import("screen.zig");
const config: type = @import("config.zig");
const world: type = @import("world.zig");
const office_mod: type = @import("office.zig");
const Office: type = office_mod.Office;
const cameras_mod: type = @import("cameras.zig");
const Cameras: type = cameras_mod.Cameras;
const power_mod: type = @import("power.zig");
const Power: type = power_mod.Power;
const animatronics_mod: type = @import("animatronics.zig");
const Manager: type = animatronics_mod.Manager;
const CharId: type = world.CharId;
const CameraId: type = world.CameraId;

const Allocator: type = std.mem.Allocator;

/// A short scare before the game-over screen.
const Jumpscare: type = struct {
    active: bool = false,
    anim: CharId = .eser,
    timer: f32 = 0,
    duration: f32 = 1.3,
    done: bool = false,

    fn trigger(self: *Jumpscare, anim: CharId) void {
        if (self.active) return;
        self.active = true;
        self.anim = anim;
        self.timer = 0;
        self.done = false;
    }

    fn update(self: *Jumpscare, dt: f32) void {
        if (!self.active) return;
        self.timer += dt;
        if (self.timer >= self.duration) self.done = true;
    }

    fn draw(self: *const Jumpscare) void {
        const prog: f32 = @min(1.0, self.timer / self.duration);
        neko.draw.clear(config.BLACK);
        if (prog < 0.12) {
            const a: u8 = @intFromFloat(255.0 * (1.0 - prog / 0.12));
            neko.draw.rect(neko.Rect{ .x = 0, .y = 0, .w = config.SCREEN_W, .h = config.SCREEN_H }, neko.Color{ .r = 255, .g = 255, .b = 255, .a = a }, true);
        }
        const sx: i32 = neko.random.int_range(-18, 18);
        const sy: i32 = neko.random.int_range(-18, 18);
        const fw: i32 = @intFromFloat(@as(f32, @floatFromInt(config.SCREEN_W)) * 0.62 * (1.0 + prog * 0.3));
        const fh: i32 = @intFromFloat(@as(f32, @floatFromInt(config.SCREEN_H)) * 0.72 * (1.0 + prog * 0.3));
        neko.sprite.face(self.anim.sprite(), config.SCREEN_W / 2 - @divTrunc(fw, 2) + sx, config.SCREEN_H / 2 - @divTrunc(fh, 2) + sy - 24, fw, fh);
        neko.effect.noise(0, 0, config.SCREEN_W, config.SCREEN_H, 0.1 + prog * 0.2);
    }
};

/// One night.
pub const Gameplay: type = struct {
    node: neko.scene.Node,
    allocator: Allocator,
    night: i32,

    office: Office = .{},
    cameras: Cameras = .{},
    power: Power = .{},
    animatronics: Manager = undefined,
    jumpscare: Jumpscare = .{},

    time: f32 = 0,
    hour: i32 = 0,
    fade_alpha: i32 = 255,
    fading_in: bool = true,
    fading_out: bool = false,
    result: []const u8 = "",
    ambient_started: bool = false,

    power_out_timer: f32 = 0,

    pub fn create(allocator: Allocator, night: i32, custom: ?[]const i32) !*neko.scene.Node {
        const self: *Gameplay = try allocator.create(Gameplay);
        self.* = Gameplay{
            .node = neko.scene.Node{ .ptr = @ptrCast(self), .vtable = &vtable, .allocator = allocator, .name = "game" },
            .allocator = allocator,
            .night = night,
            .animatronics = Manager.init(night, custom),
        };
        screen.attach(self, &screen_vtable);
        self.office.init();
        neko.sprite.load("eser");
        neko.sprite.load("alice");
        neko.sprite.load("Sonk");
        neko.sprite.load("cedro");
        return &self.node;
    }
};

const vtable: neko.scene.Node.VTable = neko.scene.Node.VTable{
    .ready = neko.scene.no_ready,
    .process = process,
    .draw = draw,
    .input = input,
    .deinit = deinit,
};

const screen_vtable: screen.VTable = .{ .is_done = is_done, .result = result };

fn cam_looking(self: *Gameplay) ?CameraId {
    if (self.cameras.fully_open()) return self.cameras.current;
    return null;
}

fn process(ptr: *anyopaque, dt: f32) void {
    const self: *Gameplay = @ptrCast(@alignCast(ptr));

    if (self.fading_in) {
        self.fade_alpha = @max(0, self.fade_alpha - @as(i32, @intFromFloat(320.0 * dt)));
        if (self.fade_alpha <= 0) {
            self.fading_in = false;
            if (!self.ambient_started) {
                common.sound.play_ambient_loop();
                self.ambient_started = true;
            }
        }
        return;
    }
    if (self.fading_out) {
        self.fade_alpha = @min(255, self.fade_alpha + @as(i32, @intFromFloat(320.0 * dt)));
        return;
    }
    if (self.jumpscare.active) {
        self.jumpscare.update(dt);
        if (self.jumpscare.done) {
            self.result = "jumpscare";
            self.fading_out = true;
            self.fade_alpha = 0;
            common.sound.stop_all();
        }
        return;
    }
    if (self.power.dead) {
        update_power_out(self, dt);
        return;
    }

    self.time += dt;
    const idx: i32 = @intFromFloat(self.time / config.HOUR_SECONDS);
    if (idx != self.hour and idx <= config.HOURS) {
        self.hour = idx;
        self.animatronics.apply_hour(idx);
        if (idx > 0) common.sound.play("clock", 0, -1);
    }

    if (self.time >= config.NIGHT_SECONDS) {
        self.result = "win";
        self.fading_out = true;
        self.fade_alpha = 0;
        common.sound.stop_all();
        common.sound.play("win", 0, -1);
        return;
    }

    const mouse = neko.input.mouse_pos();
    if (!self.cameras.visible()) self.office.update(mouse.x, dt);
    self.cameras.update(dt);
    self.power.update(dt, self.office.extra_usage(), self.cameras.is_open);
    self.animatronics.update(dt, cam_looking(self), self.office.left_door, self.office.right_door);

    if (self.animatronics.attacker()) |attacker| {
        common.sound.stop_all();
        common.sound.play("jumpscare", 0, -1);
        self.jumpscare.trigger(attacker);
    }
}

fn update_power_out(self: *Gameplay, dt: f32) void {
    if (self.power_out_timer == 0) {
        common.sound.stop_all();
        common.sound.play("power_out", 0, -1);
        common.sound.play("ventilacao", -1, 0);
    }
    self.power_out_timer += dt;
    self.office.left_door = false;
    self.office.right_door = false;
    self.office.left_light = false;
    self.office.right_light = false;
    self.cameras.is_open = false;

    if (self.power_out_timer > 4.5) {
        self.jumpscare.trigger(.cedro);
    }
}

fn input(ptr: *anyopaque, ev: neko.Event) void {
    const self: *Gameplay = @ptrCast(@alignCast(ptr));
    if (self.jumpscare.active or self.power.dead or self.fading_in or self.fading_out) return;

    switch (ev) {
        .mouse_button_down => |m| {
            if (self.cameras.fully_open()) {
                if (self.cameras.handle_click(m.x, m.y)) common.sound.play("camera", 0, -1);
                return;
            }
            if (self.cameras.visible()) return;
            if (self.office.handle_click(m.x, m.y)) |action| {
                switch (action) {
                    .door_left, .door_right => common.sound.play("door", 0, -1),
                    .light_left, .light_right => {
                        common.sound.play("light", 0, -1);
                        if (at_lit_door(self)) common.sound.play("animatronic_door", 0, -1);
                    },
                }
            }
        },
        .key_down => |k| {
            const code = k.code;
            if (code == 'f') self.office.cycle_mode();
            if (code == 32) {
                self.cameras.toggle();
                common.sound.play("camera", 0, -1);
            } else if (self.cameras.fully_open()) {
                if (cam_for_key(code)) |cam| {
                    self.cameras.select(cam);
                    common.sound.play("camera", 0, -1);
                }
            } else {
                if (code == 'q' or code == 'a') {
                    self.office.left_door = !self.office.left_door;
                    common.sound.play("door", 0, -1);
                } else if (code == 'e' or code == 'd') {
                    self.office.right_door = !self.office.right_door;
                    common.sound.play("door", 0, -1);
                } else if (code == 'z') {
                    self.office.left_light = !self.office.left_light;
                    common.sound.play("light", 0, -1);
                } else if (code == 'c') {
                    self.office.right_light = !self.office.right_light;
                    common.sound.play("light", 0, -1);
                }
            }
            if (code == 27) {
                common.sound.stop_all();
                self.result = "menu";
                self.fading_out = true;
                self.fade_alpha = 0;
            }
        },
        else => {},
    }
}

fn at_lit_door(self: *Gameplay) bool {
    const p = self.animatronics.positions();
    if (self.office.left_light and (p.eser == .left_door or p.alice == .left_door)) return true;
    if (self.office.right_light and (p.eser == .right_door or p.alice == .right_door)) return true;
    return false;
}

fn cam_for_key(code: i32) ?CameraId {
    return switch (code) {
        '1' => .show_stage,
        '2' => .dining,
        '3' => .pirate_cove,
        '4' => .west_hall,
        '5' => .west_corner,
        '6' => .supply,
        '7' => .east_hall,
        '8' => .east_corner,
        '9' => .backstage,
        'k' => .kitchen,
        'l' => .restrooms,
        else => null,
    };
}

fn draw(ptr: *anyopaque, at: neko.Point) void {
    _ = at;
    const self: *Gameplay = @ptrCast(@alignCast(ptr));

    if (self.jumpscare.active) {
        self.jumpscare.draw();
        return;
    }

    neko.draw.clear(config.BLACK);
    const positions = self.animatronics.positions();

    if (self.power.dead) {
        self.office.draw(positions, true);
        // Cedro waits in the dark.
        const t: f32 = @as(f32, @floatFromInt(neko.time.ticks_ms())) / 1000.0;
        if (@mod(@as(i32, @intFromFloat(t * 2.0)), 3) != 0) {
            neko.sprite.face("cedro", config.SCREEN_W / 2 - 130, 220, 260, 340);
            neko.draw.rect(neko.Rect{ .x = 0, .y = 0, .w = config.SCREEN_W, .h = config.SCREEN_H }, neko.Color{ .r = 0, .g = 0, .b = 0, .a = 150 }, true);
        } else {
            neko.draw.circle(config.SCREEN_W / 2 - 40, 260, 7, config.WHITE, true);
            neko.draw.circle(config.SCREEN_W / 2 + 40, 260, 7, config.WHITE, true);
        }
    } else {
        self.office.draw(positions, false);
        self.cameras.draw(positions, false);
    }

    if (!self.cameras.visible()) {
        self.power.draw();
        draw_hud(self);
    }

    if (self.fade_alpha > 0) {
        neko.draw.rect(neko.Rect{ .x = 0, .y = 0, .w = config.SCREEN_W, .h = config.SCREEN_H }, neko.Color{ .r = 0, .g = 0, .b = 0, .a = @intCast(self.fade_alpha) }, true);
    }
}

fn draw_hud(self: *Gameplay) void {
    var h: i32 = 12 + @mod(self.hour, 12);
    if (h > 12) h -= 12;
    var buf: [24]u8 = undefined;
    const clock = fmt.bufPrint(&buf, "{d} AM", .{h}) catch "";
    neko.sprite.text(clock, config.SCREEN_W - 60, 24, .{ .size = 34, .center = true, .color = config.WHITE });

    var nbuf: [32]u8 = undefined;
    const night = fmt.bufPrint(&nbuf, "Noite {d}", .{self.night}) catch "";
    neko.sprite.text(night, config.SCREEN_W - 60, 62, .{ .size = 18, .center = true, .color = config.MUTED });

    var mbuf: [64]u8 = undefined;
    const mlabel = fmt.bufPrint(&mbuf, "PROJEÇÃO: {s}  [F]", .{self.office.mode_label()}) catch "";
    neko.sprite.text(mlabel, 24, 20, .{ .size = 14, .color = config.MUTED });
}

fn is_done(ptr: *anyopaque) bool {
    const self: *Gameplay = @ptrCast(@alignCast(ptr));
    return self.result.len > 0 and self.fade_alpha >= 255;
}

fn result(ptr: *anyopaque) []const u8 {
    const self: *Gameplay = @ptrCast(@alignCast(ptr));
    return self.result;
}

fn deinit(ptr: *anyopaque, allocator: Allocator) void {
    const self: *Gameplay = @ptrCast(@alignCast(ptr));
    allocator.destroy(self);
}
