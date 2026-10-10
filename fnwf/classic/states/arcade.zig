// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Renan Lucas Vieira Hilário

//! The endless arcade mode — port of `game1/states/ArcadeState`.
//!
//! A survival variant of the office: no clock, no win — difficulty ramps every
//! 30 seconds until the animatronics get you. `result` is "arcade_die" or
//! "menu".

const std: type = @import("std");
const fmt: type = std.fmt;
const mem: type = std.mem;
const neko: type = @import("neko");
const common: type = @import("common");

const screen: type = @import("../screen.zig");
const constants: type = @import("../config/constants.zig");

const locations: type = @import("../world/locations.zig");
const CameraId: type = locations.CameraId;

const animatronics: type = @import("../systems/animatronics.zig");
const AnimatronicManager: type = animatronics.AnimatronicManager;
const office_mod: type = @import("../systems/office.zig");
const Office: type = office_mod.Office;
const camera_system: type = @import("../systems/camera_system.zig");
const CameraSystem: type = camera_system.CameraSystem;
const doors_mod: type = @import("../systems/doors.zig");
const Doors: type = doors_mod.Doors;
const power_mod: type = @import("../systems/power.zig");
const Power: type = power_mod.Power;
const jumpscare_mod: type = @import("../systems/jumpscare.zig");
const Jumpscare: type = jumpscare_mod.Jumpscare;

const Allocator: type = std.mem.Allocator;

/// The endless arcade mode.
pub const Arcade: type = struct {
    node: neko.scene.Node,

    office: Office = .{},
    cameras: CameraSystem = .{},
    doors: Doors = .{},
    power: Power = .{},
    animatronics: AnimatronicManager = undefined,
    jumpscare: Jumpscare = .{},

    time_survived: f32 = 0,
    ramp_timer: f32 = 0,
    difficulty_level: i32 = 0,

    fade_alpha: i32 = 255,
    fade_speed: i32 = 300,
    fading_in: bool = true,
    fading_out: bool = false,
    result: []const u8 = "",
    ambient_started: bool = false,

    mask_on: bool = false,
    oxygen: f32 = 100,
    max_oxygen: f32 = 100,
    oxygen_depletion_rate: f32 = 5.5,
    oxygen_recovery_rate: f32 = 8.0,

    is_blackout: bool = false,
    blackout_alpha: f32 = 0,
    blackout_timer: f32 = 0,

    power_out_phase: i32 = 0,
    power_out_timer: f32 = 0,
    power_out_delay: f32 = 0,
    fx_timer: f32 = 0,
    danger_level: f32 = 0,

    power_out_snd: bool = false,
    base_move_interval: f32 = 5.0,
    base_power_drain: f32 = 0.12,

    pub fn create(allocator: Allocator) !*neko.scene.Node {
        const self: *Arcade = try allocator.create(Arcade);
        self.* = Arcade{
            .node = neko.scene.Node{
                .ptr = @ptrCast(self),
                .vtable = &vtable,
                .allocator = allocator,
                .name = "arcade",
            },
            .animatronics = AnimatronicManager.init(1, null),
        };
        screen.attach(self, &screen_vtable);

        // Arcade starts easier than Night 1 and ramps up.
        self.animatronics.cedro.ai_level = 3;
        self.animatronics.eser.ai_level = 2;
        self.animatronics.alice.ai_level = 0;
        self.animatronics.sonk.ai_level = 0;
        self.animatronics.cedro.active = true;
        self.animatronics.eser.active = true;
        self.animatronics.alice.active = false;
        self.animatronics.sonk.active = false;

        self.office.init();
        self.cameras.init();
        return &self.node;
    }

    fn cam_looking(self: *Arcade) ?CameraId {
        if (self.cameras.is_fully_open()) return self.cameras.current_cam;
        return null;
    }

    fn update_difficulty(self: *Arcade) void {
        const new_level: i32 = @intFromFloat(self.time_survived / 30.0);
        if (new_level <= self.difficulty_level) return;
        self.difficulty_level = new_level;

        const cedro_ai: i32 = @min(20, 3 + self.difficulty_level);
        const eser_ai: i32 = @min(20, 2 + self.difficulty_level);
        const alice_ai: i32 = @min(20, @max(0, self.difficulty_level - 2));
        const sonk_ai: i32 = @min(20, @max(0, self.difficulty_level - 3));

        self.animatronics.cedro.ai_level = cedro_ai;
        self.animatronics.eser.ai_level = eser_ai;
        self.animatronics.alice.ai_level = alice_ai;
        self.animatronics.sonk.ai_level = sonk_ai;
        self.animatronics.alice.active = alice_ai > 0;
        self.animatronics.sonk.active = sonk_ai > 0;

        const new_interval: f32 = @max(1.5, self.base_move_interval - @as(f32, @floatFromInt(self.difficulty_level)) * 0.2);
        self.animatronics.cedro.move_interval = new_interval;
        self.animatronics.eser.move_interval = new_interval;
        self.animatronics.alice.move_interval = new_interval;
        self.animatronics.sonk.move_interval = new_interval;

        self.base_power_drain = 0.12 + @as(f32, @floatFromInt(self.difficulty_level)) * 0.008;
    }

    fn update_power_out(self: *Arcade, dt: f32) void {
        if (!self.power_out_snd) {
            common.sound.stop_ambient();
            common.sound.play("power_out", 0, -1);
            self.power_out_snd = true;
        }
        self.power_out_timer += dt;

        if (self.power_out_phase == 0) {
            self.doors.left_closed = false;
            self.doors.right_closed = false;
            self.doors.left_light = false;
            self.doors.right_light = false;
            self.office.vent_light = false;
            self.cameras.is_open = false;
            self.mask_on = false;
            if (self.power_out_timer > 3.0) {
                self.power_out_phase = 1;
                self.power_out_delay = 0;
            }
        } else if (self.power_out_phase == 1) {
            self.power_out_delay += dt;
            if (self.power_out_delay > 5.0 + neko.random.float_range(0.0, 10.0)) {
                self.power_out_phase = 2;
            }
        } else if (self.power_out_phase == 2) {
            self.jumpscare.trigger(.cedro);
        }
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

fn process(ptr: *anyopaque, dt: f32) void {
    const self: *Arcade = @ptrCast(@alignCast(ptr));
    self.fx_timer += dt;

    if (self.fading_in) {
        self.fade_alpha = @max(0, self.fade_alpha - @as(i32, @intFromFloat(@as(f32, @floatFromInt(self.fade_speed)) * dt)));
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
        self.fade_alpha = @min(255, self.fade_alpha + @as(i32, @intFromFloat(@as(f32, @floatFromInt(self.fade_speed)) * dt)));
        return;
    }
    if (self.jumpscare.active) {
        self.jumpscare.update(dt);
        if (self.jumpscare.done) {
            self.result = "arcade_die";
            self.fading_out = true;
            self.fade_alpha = 0;
            common.sound.stop_all();
        }
        return;
    }
    if (self.power.is_dead) {
        self.update_power_out(dt);
        return;
    }

    self.time_survived += dt;
    self.ramp_timer += dt;
    self.update_difficulty();

    const mouse = neko.input.mouse_pos();
    if (!self.cameras.is_animating) _ = self.cameras.check_mouse_trigger(mouse.x, mouse.y);

    if (!self.cameras.is_visible()) self.office.update(mouse.x, dt);
    self.cameras.update(dt);
    self.doors.update(dt);
    self.mask_on = self.cameras.is_mask_open or self.cameras.is_mask_animating;
    self.power.update(dt, self.doors.power_usage(), self.cameras.is_open, false);

    self.animatronics.update(dt, self.cam_looking(), self.doors.left_closed, self.doors.right_closed, self.mask_on);

    if (self.mask_on) {
        self.oxygen = @max(0.0, self.oxygen - self.oxygen_depletion_rate * dt);
        if (self.oxygen <= 0) {
            self.cameras.force_remove_mask();
            self.mask_on = self.cameras.is_mask_open or self.cameras.is_mask_animating;
        }
    } else {
        self.oxygen = @min(self.max_oxygen, self.oxygen + self.oxygen_recovery_rate * dt);
    }

    if (self.animatronics.alice_just_left()) {
        self.is_blackout = true;
        self.blackout_alpha = 255.0;
        self.blackout_timer = 0.5;
    }

    if (self.is_blackout) {
        if (self.blackout_timer > 0) {
            self.blackout_timer -= dt;
        } else {
            self.blackout_alpha = @max(0.0, self.blackout_alpha - 250.0 * dt);
            if (self.blackout_alpha <= 0) self.is_blackout = false;
        }
    }

    if (self.animatronics.attacker()) |attacker| {
        common.sound.stop_all();
        common.sound.play("jumpscare", 0, -1);
        self.jumpscare.trigger(attacker);
    }

    var danger: f32 = 0;
    if (self.animatronics.at_left_door() != null) danger += 0.22;
    if (self.animatronics.at_right_door() != null) danger += 0.22;
    if (self.animatronics.at_vent() != null) danger += 0.18;
    if (self.animatronics.in_office() != null) danger += 0.35;
    if (self.power.power <= 25) danger += 0.15;
    if (self.oxygen <= 35) danger += 0.1;
    self.danger_level = @max(0.0, @min(1.0, danger));
}

fn input(ptr: *anyopaque, ev: neko.Event) void {
    const self: *Arcade = @ptrCast(@alignCast(ptr));
    if (self.jumpscare.active or self.power.is_dead or self.fading_in or self.fading_out) return;

    switch (ev) {
        .mouse_button_down => |m| {
            if (self.cameras.check_toggle_click(m.x, m.y)) {
                common.sound.play("camera", 0, -1);
                return;
            }
            if (self.cameras.check_mask_toggle_click(m.x, m.y)) {
                common.sound.play("camera", 0, -1);
                return;
            }
            if (self.cameras.is_fully_open()) {
                if (self.cameras.handle_click(m.x, m.y)) common.sound.play("camera", 0, -1);
                return;
            }
            if (!self.cameras.is_visible()) {
                if (self.office.handle_button(m.x, m.y)) |btn| {
                    const action = self.doors.press(btn);
                    common.sound.play(action, 0, -1);
                    if (mem.eql(u8, action, "light") and
                        ((self.doors.left_light and self.animatronics.at_left_door() != null) or
                            (self.doors.right_light and self.animatronics.at_right_door() != null)))
                    {
                        common.sound.play("animatronic_door", 0, -1);
                    }
                    return;
                }
            }
        },
        .key_down => |kev| {
            const key: i32 = kev.code;
            if (!self.cameras.is_visible()) {
                if (key == 'q') {
                    self.doors.left_closed = !self.doors.left_closed;
                    common.sound.play("door", 0, -1);
                } else if (key == 'e') {
                    self.doors.right_closed = !self.doors.right_closed;
                    common.sound.play("door", 0, -1);
                } else if (key == 'a') {
                    self.doors.left_light = !self.doors.left_light;
                    common.sound.play("light", 0, -1);
                    if (self.doors.left_light and self.animatronics.at_left_door() != null) common.sound.play("animatronic_door", 0, -1);
                } else if (key == 'd') {
                    self.doors.right_light = !self.doors.right_light;
                    common.sound.play("light", 0, -1);
                    if (self.doors.right_light and self.animatronics.at_right_door() != null) common.sound.play("animatronic_door", 0, -1);
                } else if (key == 'l') {
                    self.office.vent_light = !self.office.vent_light;
                    common.sound.play("light", 0, -1);
                    if (self.office.vent_light and self.animatronics.at_vent() != null) common.sound.play("animatronic_door", 0, -1);
                }
            }

            if (self.cameras.is_fully_open()) {
                if (cam_for_key(key)) |cam| {
                    self.cameras.switch_camera(cam);
                    common.sound.play("camera", 0, -1);
                }
            }

            if (key == 32 or key == 9) {
                self.cameras.toggle();
                common.sound.play("camera", 0, -1);
            }
            if (key == 'x' and !self.cameras.is_open) self.cameras.toggle_mask();
            if (key == 27) {
                common.sound.stop_all();
                self.result = "menu";
                self.fading_out = true;
                self.fade_alpha = 0;
            }
        },
        else => {},
    }
}

fn cam_for_key(key: i32) ?CameraId {
    return switch (key) {
        '1' => .stage,
        '2' => .dining,
        '3' => .backstage,
        '4' => .west_hall,
        '5' => .west_corner,
        '6' => .supply,
        '7' => .east_hall,
        '8' => .east_corner,
        '9' => .pirate_cove,
        else => null,
    };
}

fn draw(ptr: *anyopaque, at: neko.Point) void {
    _ = at;
    const self: *Arcade = @ptrCast(@alignCast(ptr));
    const w: i32 = constants.SCREEN_WIDTH;
    const h: i32 = constants.SCREEN_HEIGHT;
    const high_fx: bool = neko.sprite.is_high_quality();

    if (self.jumpscare.active) {
        self.jumpscare.draw();
        draw_fade(self);
        return;
    }
    if (self.power.is_dead) {
        draw_power_out(self);
        draw_fade(self);
        return;
    }

    const positions = self.animatronics.positions();
    self.office.draw(
        self.doors.left_anim,
        self.doors.right_anim,
        self.doors.left_light,
        self.doors.right_light,
        self.animatronics.at_left_door(),
        self.animatronics.at_right_door(),
        self.animatronics.at_vent(),
        self.animatronics.in_office(),
    );

    self.cameras.draw(camera_system.CamPositions{ .cedro = positions.cedro, .eser = positions.eser }, self.animatronics.sonk_stage());

    if (high_fx and !self.cameras.is_visible()) {
        const light_pulse: f32 = 0.55 + 0.45 * @sin(self.fx_timer * 8.0);
        if (self.doors.left_light) {
            var i: i32 = 1;
            while (i <= 5) : (i += 1) {
                const ww: i32 = 100 + i * 58;
                const a: u8 = @intFromFloat((@as(f32, @floatFromInt(50 - i * 7))) * light_pulse);
                neko.draw.rect(neko.Rect{ .x = 0, .y = 0, .w = ww, .h = h }, neko.Color{ .r = 205, .g = 210, .b = 235, .a = a }, true);
            }
        }
        if (self.doors.right_light) {
            var i: i32 = 1;
            while (i <= 5) : (i += 1) {
                const ww: i32 = 100 + i * 58;
                const a: u8 = @intFromFloat((@as(f32, @floatFromInt(50 - i * 7))) * light_pulse);
                neko.draw.rect(neko.Rect{ .x = w - ww, .y = 0, .w = ww, .h = h }, neko.Color{ .r = 205, .g = 210, .b = 235, .a = a }, true);
            }
        }
        if (self.office.vent_light) {
            var i: i32 = 1;
            while (i <= 4) : (i += 1) {
                const hh: i32 = 70 + i * 30;
                const a: u8 = @intCast(38 - i * 6);
                neko.draw.rect(neko.Rect{ .x = 0, .y = 0, .w = w, .h = hh }, neko.Color{ .r = 185, .g = 210, .b = 230, .a = a }, true);
            }
        }
    }

    neko.effect.tone(neko.Color{ .r = 8, .g = 18, .b = 32, .a = if (high_fx) 12 else 8 });
    if (high_fx) neko.effect.vignette(0.20 + self.danger_level * 0.35, neko.Color{ .r = 0, .g = 0, .b = 0 });

    if (high_fx) {
        const lp: f32 = 0.6 + 0.4 * @sin(self.time_survived * 1.2);
        const cx: i32 = @divTrunc(w, 2);
        const cy: i32 = @intFromFloat(@as(f32, @floatFromInt(h)) * 0.64);
        neko.draw.rect(neko.Rect{ .x = cx - 320, .y = cy - 150, .w = 640, .h = 300 }, neko.Color{ .r = 220, .g = 200, .b = 150, .a = @intFromFloat(7.0 + 6.0 * lp) }, true);
        neko.draw.rect(neko.Rect{ .x = cx - 140, .y = cy - 78, .w = 280, .h = 156 }, neko.Color{ .r = 245, .g = 235, .b = 200, .a = @intFromFloat(4.0 + 3.0 * lp) }, true);
    }
    neko.draw.rect(neko.Rect{ .x = 0, .y = 0, .w = 64, .h = h }, neko.Color{ .r = 30, .g = 45, .b = 90, .a = 22 }, true);
    neko.draw.rect(neko.Rect{ .x = w - 64, .y = 0, .w = 64, .h = h }, neko.Color{ .r = 30, .g = 45, .b = 90, .a = 22 }, true);

    draw_hud(self);

    if (!self.is_blackout or self.blackout_alpha < 150) {
        const n_base: f32 = if (high_fx) 0.008 else 0.003;
        const n_k: f32 = if (high_fx) 0.02 else 0.008;
        const noise: f32 = n_base + self.danger_level * n_k;
        const s_base: f32 = if (high_fx) 10.0 else 6.0;
        const s_k: f32 = if (high_fx) 16.0 else 8.0;
        const scan: u8 = @intFromFloat(s_base + self.danger_level * s_k);
        neko.effect.camera(noise, scan, 0);
    }

    const any_door = self.animatronics.at_left_door() != null or self.animatronics.at_right_door() != null or
        self.animatronics.at_vent() != null or self.animatronics.in_office() != null;
    if (any_door and !self.is_blackout) {
        if (neko.random.probability(0.08)) {
            neko.draw.rect(neko.Rect{ .x = 0, .y = 0, .w = w, .h = h }, neko.Color{ .r = 0, .g = 0, .b = 0, .a = @intCast(50 + neko.random.int_range(0, 130)) }, true);
        }
    }

    if (self.blackout_alpha > 0) {
        neko.draw.rect(neko.Rect{ .x = 0, .y = 0, .w = w, .h = h }, neko.Color{ .r = 0, .g = 0, .b = 0, .a = @intFromFloat(self.blackout_alpha) }, true);
    }

    draw_fade(self);
}

fn draw_hud(self: *Arcade) void {
    const w: i32 = constants.SCREEN_WIDTH;

    const minutes: i32 = @intFromFloat(self.time_survived / 60.0);
    const seconds: i32 = @mod(@as(i32, @intFromFloat(self.time_survived)), 60);
    var tbuf: [32]u8 = undefined;
    neko.sprite.text(fmt.bufPrint(&tbuf, "{d}:{d:0>2}", .{ minutes, seconds }) catch "", w - 80, 20, .{
        .size = 28,
        .center = true,
        .color = neko.Color{ .r = 255, .g = 255, .b = 255 },
    });
    neko.sprite.text(neko.localization.text("arcade_time"), w - 80, 52, .{ .size = 14, .center = true, .color = neko.Color{ .r = 180, .g = 180, .b = 180 } });

    var dbuf: [64]u8 = undefined;
    const diff = fmt.bufPrint(&dbuf, "{s} {d}", .{ neko.localization.text("arcade_level"), self.difficulty_level }) catch "";
    neko.sprite.text(diff, w - 80, 76, .{ .size = 16, .center = true, .color = neko.Color{ .r = 255, .g = 200, .b = 80 } });

    neko.sprite.text("\u{2501}\u{2501}\u{2501}\u{2501}\u{2501}\u{2501}\u{2501}\u{2501}", w - 80, 98, .{ .size = 10, .center = true, .color = neko.Color{ .r = 50, .g = 50, .b = 55 } });

    self.power.draw();

    if (self.mask_on or self.oxygen < self.max_oxygen) {
        const bar_w: i32 = 200;
        const bar_h: i32 = 12;
        const x: i32 = 20;
        const y: i32 = 100;
        neko.draw.rect(neko.Rect{ .x = x, .y = y, .w = bar_w, .h = bar_h }, neko.Color{ .r = 40, .g = 40, .b = 45 }, true);
        const cr: u8 = if (self.oxygen >= 30) 100 else 255;
        const cg: u8 = if (self.oxygen >= 30) 200 else 100;
        const cb: u8 = if (self.oxygen >= 30) 255 else 100;
        neko.draw.rect(neko.Rect{ .x = x, .y = y, .w = @intFromFloat(@as(f32, @floatFromInt(bar_w)) * (self.oxygen / self.max_oxygen)), .h = bar_h }, neko.Color{ .r = cr, .g = cg, .b = cb }, true);
        neko.draw.rect(neko.Rect{ .x = x, .y = y, .w = bar_w, .h = bar_h }, neko.Color{ .r = 80, .g = 80, .b = 85 }, false);

        var obuf: [64]u8 = undefined;
        const label = fmt.bufPrint(&obuf, "{s}: {d}%", .{ neko.localization.text("oxygen"), @as(i32, @intFromFloat(self.oxygen)) }) catch "";
        neko.sprite.text(label, x, y - 18, .{ .size = 14, .color = neko.Color{ .r = 255, .g = 255, .b = 255 } });
    }
}

fn draw_power_out(self: *Arcade) void {
    const h: i32 = constants.SCREEN_HEIGHT;
    neko.draw.clear(neko.Color{ .r = 0, .g = 0, .b = 0 });

    if (self.power_out_phase >= 1) {
        if ((neko.time.ticks_ms() / 1000 * 2) % 3 != 0) {
            neko.sprite.face("cedro", 50, @divTrunc(h, 2) - 120, 200, 250);
            neko.draw.circle(120, @divTrunc(h, 2) - 20, 8, neko.Color{ .r = 255, .g = 255, .b = 255 }, true);
            neko.draw.circle(180, @divTrunc(h, 2) - 20, 8, neko.Color{ .r = 255, .g = 255, .b = 255 }, true);
            neko.draw.circle(120, @divTrunc(h, 2) - 20, 4, neko.Color{ .r = 30, .g = 30, .b = 200 }, true);
            neko.draw.circle(180, @divTrunc(h, 2) - 20, 4, neko.Color{ .r = 30, .g = 30, .b = 200 }, true);
            neko.sprite.text("\u{266a} \u{266b} \u{266a}", 150, @divTrunc(h, 2) + 140, .{ .size = 20, .center = true, .color = neko.Color{ .r = 60, .g = 60, .b = 100 } });
        }
    }
}

fn draw_fade(self: *Arcade) void {
    if (self.fade_alpha > 0) {
        neko.draw.rect(neko.Rect{ .x = 0, .y = 0, .w = constants.SCREEN_WIDTH, .h = constants.SCREEN_HEIGHT }, neko.Color{ .r = 0, .g = 0, .b = 0, .a = @intCast(self.fade_alpha) }, true);
    }
}

fn is_done(ptr: *anyopaque) bool {
    const self: *Arcade = @ptrCast(@alignCast(ptr));
    return self.result.len > 0 and self.fade_alpha >= 255;
}

fn result(ptr: *anyopaque) []const u8 {
    const self: *Arcade = @ptrCast(@alignCast(ptr));
    return self.result;
}

fn deinit(ptr: *anyopaque, allocator: Allocator) void {
    const self: *Arcade = @ptrCast(@alignCast(ptr));
    allocator.destroy(self);
}
