//! The core gameplay loop — port of `game1/states/GameplayState`.

const std: type = @import("std");
const fmt: type = std.fmt;
const neko: type = @import("neko");
const common: type = @import("common");

const screen: type = @import("../screen.zig");
const constants: type = @import("../config/constants.zig");
const colors: type = @import("../config/colors.zig");
const cheats_mod: type = @import("../config/cheats.zig");
const Cheats: type = cheats_mod.Cheats;
const save: type = @import("../save.zig");
const locations: type = @import("../world/locations.zig");
const CameraId: type = locations.CameraId;

const animatronics: type = @import("../systems/animatronics.zig");
const AnimatronicManager: type = animatronics.AnimatronicManager;
const AnimatronicId: type = animatronics.AnimatronicId;
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

/// One night in the office.
pub const Gameplay: type = struct {
    node: neko.scene.Node,
    allocator: Allocator,
    night: i32,

    office: Office = .{},
    cameras: CameraSystem = .{},
    doors: Doors = .{},
    power: Power = .{},
    animatronics: AnimatronicManager = undefined,
    jumpscare: Jumpscare = .{},

    time_elapsed: f32 = 0,
    night_duration: f32 = 0,
    current_hour: i32 = 0,
    prev_hour: i32 = 0,

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

    win_triggered: bool = false,
    power_out_snd: bool = false,
    secret_mode: bool = false,

    infinite_power: bool = false,
    fast_nights: bool = false,

    save_notify: bool = false,
    save_notify_timer: f32 = 0,

    pub fn create(allocator: Allocator, night: i32, custom_ai: ?[]const i32, cheats: Cheats) !*neko.scene.Node {
        const self: *Gameplay = try allocator.create(Gameplay);
        self.* = Gameplay{
            .node = neko.scene.Node{ .ptr = @ptrCast(self), .vtable = &vtable, .allocator = allocator, .name = "game" },
            .allocator = allocator,
            .night = night,
            .infinite_power = cheats.infinite_power,
            .fast_nights = cheats.fast_nights,
        };
        screen.attach(self, &screen_vtable);
        self.office.init();
        self.cameras.init();
        self.animatronics = AnimatronicManager.init(night, custom_ai);
        self.secret_mode = self.animatronics.is_secret_mode();
        const speed: f32 = if (cheats.fast_nights) 0.5 else 1.0;
        self.night_duration = constants.HOUR_DURATION * 6.0 * speed;
        return &self.node;
    }

    pub fn from_node(n: *neko.scene.Node) *Gameplay {
        return @ptrCast(@alignCast(n));
    }

    fn cam_looking(self: *Gameplay) ?CameraId {
        if (self.cameras.is_fully_open()) return self.cameras.current_cam;
        return null;
    }
};

const vtable: neko.scene.Node.VTable = neko.scene.Node.VTable{
    .ready = neko.scene.no_ready,
    .process = vt_update,
    .draw = vt_draw,
    .input = vt_handle_event,
    .deinit = vt_deinit,
};

const screen_vtable: screen.VTable = .{ .is_done = vt_is_done, .result = vt_result };

fn as_self(ptr: *anyopaque) *Gameplay {
    return @ptrCast(@alignCast(ptr));
}

fn vt_handle_event(ptr: *anyopaque, ev: neko.Event) void {
    const self: *Gameplay = as_self(ptr);
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
                    if (std.mem.eql(u8, action, "light") and
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
            const key = kev.code;
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
            if (key == 29) {
                var snap = capture_snapshot(self);
                defer snap.deinit(self.allocator);
                if (save.save_game(snap)) {
                    self.save_notify = true;
                    self.save_notify_timer = 2.0;
                }
            }
            if (key == 31) {
                if (save.load_game(self.allocator)) |snap| {
                    var s = snap;
                    defer s.deinit(self.allocator);
                    restore_snapshot(self, s);
                    self.result = "load_done";
                    self.fading_out = true;
                    self.fade_alpha = 0;
                }
            }
            if (key == 'p') self.time_elapsed = self.night_duration;
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

fn vt_update(ptr: *anyopaque, dt: f32) void {
    const self: *Gameplay = as_self(ptr);
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
            self.result = "jumpscare";
            self.fading_out = true;
            self.fade_alpha = 0;
            common.sound.stop_all();
        }
        return;
    }
    if (self.power.is_dead) {
        update_power_out(self, dt);
        return;
    }

    self.time_elapsed += dt;
    var new_hour: i32 = 12 + @as(i32, @intFromFloat((self.time_elapsed / self.night_duration) * 6.0));
    if (new_hour > 12) new_hour = @mod(new_hour, 12);
    if (new_hour == 0) new_hour = 12;
    if (new_hour != self.prev_hour) {
        self.prev_hour = new_hour;
        common.sound.play("clock", 0, -1);
    }
    self.current_hour = new_hour;

    if (self.time_elapsed >= self.night_duration) {
        if (!self.win_triggered) {
            self.win_triggered = true;
            common.sound.stop_all();
            common.sound.play("win", 0, -1);
            self.result = "win";
            self.fading_out = true;
            self.fade_alpha = 0;
        }
        return;
    }

    const mouse = neko.input.mouse_pos();
    if (!self.cameras.is_animating) _ = self.cameras.check_mouse_trigger(mouse.x, mouse.y);

    if (self.save_notify) {
        self.save_notify_timer -= dt;
        if (self.save_notify_timer <= 0) self.save_notify = false;
    }

    if (!self.cameras.is_visible()) self.office.update(mouse.x, dt);
    self.cameras.update(dt);
    self.doors.update(dt);
    self.mask_on = self.cameras.is_mask_open or self.cameras.is_mask_animating;
    self.power.update(dt, self.doors.power_usage(), self.cameras.is_open, self.infinite_power);

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

fn update_power_out(self: *Gameplay, dt: f32) void {
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
            if (self.time_elapsed >= self.night_duration) {
                self.result = "win";
                self.fading_out = true;
            } else {
                self.power_out_phase = 2;
            }
        }
    } else if (self.power_out_phase == 2) {
        self.jumpscare.trigger(.cedro);
    }
}

fn vt_is_done(ptr: *anyopaque) bool {
    const self: *Gameplay = as_self(ptr);
    return self.result.len > 0 and self.fade_alpha >= 255;
}

fn vt_result(ptr: *anyopaque) []const u8 {
    return as_self(ptr).result;
}

fn vt_deinit(ptr: *anyopaque, allocator: Allocator) void {
    const self: *Gameplay = as_self(ptr);
    allocator.destroy(self);
}

fn vt_draw(ptr: *anyopaque, at: neko.Point) void {
    _ = at;
    const self: *Gameplay = as_self(ptr);
    const high_fx = neko.sprite.is_high_quality();

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

    const w: i32 = constants.SCREEN_WIDTH;
    const h: i32 = constants.SCREEN_HEIGHT;

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

    if (self.secret_mode) {
        const pulse: f32 = 0.5 + 0.5 * @sin(self.time_elapsed * 2.4);
        const alpha: u8 = @intFromFloat(36.0 + 24.0 * pulse);
        neko.draw.rect(neko.Rect{ .x = 0, .y = 0, .w = w, .h = h }, neko.Color{ .r = 120, .g = 8, .b = 8, .a = alpha }, true);
    }

    neko.effect.tone(neko.Color{ .r = 8, .g = 18, .b = 32, .a = if (high_fx) 12 else 8 });
    if (high_fx) neko.effect.vignette(0.20 + self.danger_level * 0.35, neko.Color{ .r = 0, .g = 0, .b = 0 });

    if (high_fx) {
        const lp: f32 = 0.6 + 0.4 * @sin(self.time_elapsed * 1.2);
        const cx: i32 = @divTrunc(w, 2);
        const cy: i32 = @intFromFloat(@as(f32, @floatFromInt(h)) * 0.64);
        neko.draw.rect(neko.Rect{ .x = cx - 320, .y = cy - 150, .w = 640, .h = 300 }, neko.Color{ .r = 220, .g = 200, .b = 150, .a = @intFromFloat(7.0 + 6.0 * lp) }, true);
        neko.draw.rect(neko.Rect{ .x = cx - 140, .y = cy - 78, .w = 280, .h = 156 }, neko.Color{ .r = 245, .g = 235, .b = 200, .a = @intFromFloat(4.0 + 3.0 * lp) }, true);
    }
    neko.draw.rect(neko.Rect{ .x = 0, .y = 0, .w = 64, .h = h }, neko.Color{ .r = 30, .g = 45, .b = 90, .a = 22 }, true);
    neko.draw.rect(neko.Rect{ .x = w - 64, .y = 0, .w = 64, .h = h }, neko.Color{ .r = 30, .g = 45, .b = 90, .a = 22 }, true);

    draw_hud(self);
    draw_save_notify(self);

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

fn draw_hud(self: *Gameplay) void {
    const w: i32 = constants.SCREEN_WIDTH;

    var hbuf: [32]u8 = undefined;
    const hour_str = fmt.bufPrint(&hbuf, "{d} {s}", .{ self.current_hour, neko.localization.text("am") }) catch "";
    neko.sprite.text(hour_str, w - 80, 20, neko.sprite.Options{ .size = 28, .center = true, .color = neko.Color{ .r = 255, .g = 255, .b = 255 } });

    var nbuf: [64]u8 = undefined;
    const night_label: []const u8 = if (self.night == 7)
        neko.localization.text("custom_night")
    else
        fmt.bufPrint(&nbuf, "{s} {d}", .{ neko.localization.text("night"), self.night }) catch "";
    neko.sprite.text(night_label, w - 80, 52, neko.sprite.Options{ .size = 18, .center = true, .color = neko.Color{ .r = 180, .g = 180, .b = 180 } });
    neko.sprite.text("\u{2501}\u{2501}\u{2501}\u{2501}\u{2501}\u{2501}\u{2501}\u{2501}", w - 80, 74, neko.sprite.Options{ .size = 10, .center = true, .color = neko.Color{ .r = 50, .g = 50, .b = 55 } });

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
        neko.sprite.text(label, x, y - 18, neko.sprite.Options{ .size = 14, .color = neko.Color{ .r = 255, .g = 255, .b = 255 } });
    }
}

fn draw_power_out(self: *Gameplay) void {
    const w: i32 = constants.SCREEN_WIDTH;
    const h: i32 = constants.SCREEN_HEIGHT;
    neko.draw.clear(neko.Color{ .r = 0, .g = 0, .b = 0 });

    if (self.power_out_phase >= 1) {
        if ((neko.time.ticks_ms() / 1000 * 2) % 3 != 0) {
            neko.sprite.face("cedro", 50, @divTrunc(h, 2) - 120, 200, 250);
            neko.draw.circle(120, @divTrunc(h, 2) - 20, 8, neko.Color{ .r = 255, .g = 255, .b = 255 }, true);
            neko.draw.circle(180, @divTrunc(h, 2) - 20, 8, neko.Color{ .r = 255, .g = 255, .b = 255 }, true);
            neko.draw.circle(120, @divTrunc(h, 2) - 20, 4, neko.Color{ .r = 30, .g = 30, .b = 200 }, true);
            neko.draw.circle(180, @divTrunc(h, 2) - 20, 4, neko.Color{ .r = 30, .g = 30, .b = 200 }, true);
            neko.sprite.text("\u{266a} \u{266b} \u{266a}", 150, @divTrunc(h, 2) + 140, neko.sprite.Options{ .size = 20, .center = true, .color = neko.Color{ .r = 60, .g = 60, .b = 100 } });
        }
    }
    _ = w;
}

fn draw_save_notify(self: *Gameplay) void {
    if (!self.save_notify) return;
    const alpha: u8 = @intFromFloat(200.0 * @min(1.0, self.save_notify_timer));
    neko.sprite.text("\u{24e1}  GAME SAVED!", @divTrunc(constants.SCREEN_WIDTH, 2), 10, neko.sprite.Options{
        .size = 18,
        .center = true,
        .color = neko.Color{ .r = 255, .g = 255, .b = 255, .a = alpha },
    });
}

fn draw_fade(self: *Gameplay) void {
    if (self.fade_alpha > 0) {
        neko.draw.rect(neko.Rect{ .x = 0, .y = 0, .w = constants.SCREEN_WIDTH, .h = constants.SCREEN_HEIGHT }, neko.Color{ .r = 0, .g = 0, .b = 0, .a = @intCast(self.fade_alpha) }, true);
    }
}

fn capture_snapshot(self: *Gameplay) save.GameSnapshot {
    var s = save.GameSnapshot{};
    s.night = self.night;
    s.time_elapsed = self.time_elapsed;
    s.night_duration = self.night_duration;
    s.current_hour = self.current_hour;

    s.power = self.power.power;
    s.power_usage_level = self.power.usage_level;
    s.power_is_dead = self.power.is_dead;
    s.power_dead_timer = self.power.dead_timer;

    s.door_left_closed = self.doors.left_closed;
    s.door_right_closed = self.doors.right_closed;
    s.door_left_light = self.doors.left_light;
    s.door_right_light = self.doors.right_light;
    s.door_left_anim = self.doors.left_anim;
    s.door_right_anim = self.doors.right_anim;

    s.cam_open = self.cameras.is_open;
    s.cam_current = self.cameras.current_cam;
    s.cam_mask_open = self.cameras.is_mask_open;

    s.office_vent_light = self.office.vent_light;

    s.mask_on = self.mask_on;
    s.oxygen = self.oxygen;
    s.max_oxygen = self.max_oxygen;

    s.is_blackout = self.is_blackout;
    s.blackout_alpha = self.blackout_alpha;
    s.blackout_timer = self.blackout_timer;

    s.cedro_pos = self.animatronics.cedro.position;
    s.eser_pos = self.animatronics.eser.position;
    s.alice_pos = self.animatronics.alice.position;
    s.sonk_pos = self.animatronics.sonk.position;
    s.sonk_stage = self.animatronics.sonk.stage;
    s.sonk_charging = self.animatronics.sonk.is_charging;
    s.sonk_charge_timer = self.animatronics.sonk.charge_timer;

    return s;
}

fn restore_snapshot(self: *Gameplay, s: save.GameSnapshot) void {
    self.night = s.night;
    self.time_elapsed = s.time_elapsed;
    self.night_duration = s.night_duration;
    self.current_hour = s.current_hour;

    self.power.power = s.power;
    self.power.usage_level = s.power_usage_level;
    self.power.is_dead = s.power_is_dead;
    self.power.dead_timer = s.power_dead_timer;

    self.doors.left_closed = s.door_left_closed;
    self.doors.right_closed = s.door_right_closed;
    self.doors.left_light = s.door_left_light;
    self.doors.right_light = s.door_right_light;
    self.doors.left_anim = s.door_left_anim;
    self.doors.right_anim = s.door_right_anim;

    self.cameras.is_open = s.cam_open;
    self.cameras.current_cam = s.cam_current;
    self.cameras.is_mask_open = s.cam_mask_open;

    self.office.vent_light = s.office_vent_light;

    self.mask_on = s.mask_on;
    self.oxygen = s.oxygen;
    self.max_oxygen = s.max_oxygen;

    self.is_blackout = s.is_blackout;
    self.blackout_alpha = s.blackout_alpha;
    self.blackout_timer = s.blackout_timer;

    self.animatronics.cedro.position = s.cedro_pos;
    self.animatronics.eser.position = s.eser_pos;
    self.animatronics.alice.position = s.alice_pos;
    self.animatronics.sonk.position = s.sonk_pos;
    self.animatronics.sonk.stage = s.sonk_stage;
    self.animatronics.sonk.is_charging = s.sonk_charging;
    self.animatronics.sonk.charge_timer = s.sonk_charge_timer;

    self.fading_in = true;
    self.fade_alpha = 255;
    self.win_triggered = false;
    self.power_out_snd = false;
    self.result = "";
}
