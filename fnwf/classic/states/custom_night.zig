// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Renan Lucas Vieira Hilário

//! The custom night setup — port of `game1/states/CustomNightState`.
//!
//! Four cards set each animatronic's AI level (0..20, or 40 once the "2025"
//! secret code is entered), plus a row of presets and a READY button.

const std: type = @import("std");
const fmt: type = std.fmt;
const mem: type = std.mem;
const neko: type = @import("neko");
const common: type = @import("common");

const screen: type = @import("../screen.zig");
const constants: type = @import("../config/constants.zig");
const colors: type = @import("../config/colors.zig");

const Allocator: type = std.mem.Allocator;

const MAX_PRESETS: usize = 5;

const AnimEntry: type = struct {
    name: []const u8,
    sprite: []const u8,
    size_w: i32,
    size_h: i32,
};

const ANIMATRONICS: [4]AnimEntry = .{
    .{ .name = "Cedro", .sprite = "cedro", .size_w = 220, .size_h = 220 },
    .{ .name = "Eser", .sprite = "eser", .size_w = 220, .size_h = 220 },
    .{ .name = "Alice", .sprite = "alice", .size_w = 220, .size_h = 220 },
    .{ .name = "Sonk", .sprite = "Sonk", .size_w = 220, .size_h = 220 },
};

const Preset: type = struct {
    name: []const u8,
    levels: [4]i32 = .{ 0, 0, 0, 0 },
    has_levels: bool = false,
};

/// The custom night configuration screen.
pub const CustomNight: type = struct {
    node: neko.scene.Node,

    timer: f32 = 0,
    selected: i32 = 1,
    done: bool = false,
    result: []const u8 = "",

    ai_levels: [4]i32 = .{ 0, 0, 0, 0 },
    presets: [MAX_PRESETS]Preset = undefined,
    preset_count: usize = 0,
    current_preset: usize = 0,

    secret_buf: [8]u8 = undefined,
    secret_len: usize = 0,
    secret_code_pending: bool = false,
    secret_mode_unlocked: bool = false,

    card_rects: [4]neko.Rect = undefined,
    up_rects: [4]neko.Rect = undefined,
    down_rects: [4]neko.Rect = undefined,
    preset_prev: neko.Rect = undefined,
    preset_next: neko.Rect = undefined,
    preset_label: neko.Rect = undefined,
    ready_rect: neko.Rect = undefined,
    card_scales: [4]f32 = .{ 1.0, 1.0, 1.0, 1.0 },
    card_glows: [4]f32 = .{ 0, 0, 0, 0 },

    pub fn create(allocator: Allocator) !*neko.scene.Node {
        const self: *CustomNight = try allocator.create(CustomNight);
        self.* = CustomNight{
            .node = neko.scene.Node{
                .ptr = @ptrCast(self),
                .vtable = &vtable,
                .allocator = allocator,
                .name = "custom_night",
            },
        };
        screen.attach(self, &screen_vtable);

        for (ANIMATRONICS) |a| neko.sprite.load(a.sprite);
        self.presets[0] = Preset{ .name = "Custom" };
        self.presets[1] = Preset{ .name = neko.localization.text("preset_1"), .levels = .{ 5, 5, 20, 8 }, .has_levels = true };
        self.presets[2] = Preset{ .name = neko.localization.text("preset_2"), .levels = .{ 10, 20, 10, 10 }, .has_levels = true };
        self.presets[3] = Preset{ .name = neko.localization.text("preset_3"), .levels = .{ 20, 20, 20, 20 }, .has_levels = true };
        self.preset_count = 4;
        self.card_scales[0] = 1.02;
        self.card_glows[0] = 1.0;
        self.rebuild_layout();
        return &self.node;
    }

    /// Recovers the `CustomNight` from its scene-tree node.
    pub fn from_node(n: *neko.scene.Node) *CustomNight {
        return @ptrCast(@alignCast(n));
    }

    /// The AI levels chosen for Cedro, Eser, Alice and Sonk.
    pub fn levels(self: *const CustomNight) [4]i32 {
        return self.ai_levels;
    }

    fn ai_cap(self: *const CustomNight) i32 {
        return if (self.secret_mode_unlocked) 40 else 20;
    }

    fn unlock_secret_mode(self: *CustomNight) void {
        if (!self.secret_mode_unlocked) {
            self.secret_mode_unlocked = true;
            self.presets[self.preset_count] = Preset{ .name = neko.localization.text("preset_secret"), .levels = .{ 40, 40, 40, 40 }, .has_levels = true };
            self.preset_count += 1;
        }
        self.current_preset = self.preset_count - 1;
        self.apply_preset(self.preset_count - 1);
    }

    fn apply_preset(self: *CustomNight, index: usize) void {
        if (index >= self.preset_count) return;
        self.current_preset = index;
        if (self.presets[index].has_levels) {
            for (0..4) |i| self.ai_levels[i] = self.presets[index].levels[i];
        }
        common.sound.play("blip", 0, -1);
    }

    fn cycle_preset(self: *CustomNight, direction: i32) void {
        const count: i32 = @intCast(self.preset_count);
        const cur: i32 = @intCast(self.current_preset);
        self.apply_preset(@intCast(@mod(cur + direction, count)));
    }

    fn rebuild_layout(self: *CustomNight) void {
        const card_w: i32 = 280;
        const card_h: i32 = 430;
        const gap: i32 = 42;
        const total_w: i32 = 4 * card_w + 3 * gap;
        const start_x: i32 = @divTrunc(constants.SCREEN_WIDTH, 2) - @divTrunc(total_w, 2);
        const y: i32 = 120;

        for (0..4) |i| {
            const x: i32 = start_x + @as(i32, @intCast(i)) * (card_w + gap);
            self.card_rects[i] = neko.Rect{ .x = x, .y = y, .w = card_w, .h = card_h };
            self.up_rects[i] = neko.Rect{ .x = x + @divTrunc(card_w, 2) - 32, .y = y + 300, .w = 64, .h = 44 };
            self.down_rects[i] = neko.Rect{ .x = x + @divTrunc(card_w, 2) - 32, .y = y + 380, .w = 64, .h = 44 };
        }

        const cx: i32 = @divTrunc(constants.SCREEN_WIDTH, 2);
        self.preset_prev = neko.Rect{ .x = cx - 250, .y = 580, .w = 80, .h = 48 };
        self.preset_next = neko.Rect{ .x = cx + 170, .y = 580, .w = 80, .h = 48 };
        self.preset_label = neko.Rect{ .x = cx - 160, .y = 580, .w = 320, .h = 48 };
        self.ready_rect = neko.Rect{ .x = cx - 180, .y = 642, .w = 360, .h = 54 };
    }

    fn clamp_ai(self: *CustomNight, i: usize, delta: i32) void {
        self.ai_levels[i] = @max(0, @min(self.ai_cap(), self.ai_levels[i] + delta));
        self.current_preset = 0;
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

fn lerp_f(a: f32, b: f32, t: f32) f32 {
    return a + (b - a) * @min(1.0, @max(0.0, t));
}

fn digit_from_key(code: i32) i32 {
    if (code >= '0' and code <= '9') return code - '0';
    const table = [10]struct { code: i32, digit: i32 }{
        .{ .code = 1073741922, .digit = 0 },
        .{ .code = 1073741913, .digit = 1 },
        .{ .code = 1073741914, .digit = 2 },
        .{ .code = 1073741915, .digit = 3 },
        .{ .code = 1073741916, .digit = 4 },
        .{ .code = 1073741917, .digit = 5 },
        .{ .code = 1073741918, .digit = 6 },
        .{ .code = 1073741919, .digit = 7 },
        .{ .code = 1073741920, .digit = 8 },
        .{ .code = 1073741921, .digit = 9 },
    };
    for (table) |e| {
        if (e.code == code) return e.digit;
    }
    return -1;
}

fn push_secret_digit(self: *CustomNight, digit: i32) void {
    self.secret_buf[self.secret_len] = @intCast('0' + digit);
    self.secret_len += 1;
    if (self.secret_len > 4) {
        var i: usize = 0;
        while (i < self.secret_len - 1) : (i += 1) self.secret_buf[i] = self.secret_buf[i + 1];
        self.secret_len = 4;
    }
    if (self.secret_len == 4 and mem.eql(u8, self.secret_buf[0..4], "2025")) {
        self.secret_code_pending = true;
        self.selected = 5;
        common.sound.play("notification", 0, -1);
        self.secret_len = 0;
    }
}

fn input(ptr: *anyopaque, ev: neko.Event) void {
    const self: *CustomNight = @ptrCast(@alignCast(ptr));
    switch (ev) {
        .key_down => |k| {
            const code: i32 = k.code;
            const digit: i32 = digit_from_key(code);
            if (digit >= 0) push_secret_digit(self, digit);

            if (code == 27) {
                self.result = "menu";
                self.done = true;
                common.sound.play("select", 0, -1);
            } else if (code == 1073741904 or code == 'a') {
                self.selected = @mod(self.selected - 2 + 5, 5) + 1;
                common.sound.play("blip", 0, -1);
            } else if (code == 1073741903 or code == 'd') {
                self.selected = @mod(self.selected, 5) + 1;
                common.sound.play("blip", 0, -1);
            }

            if (self.selected <= 4) {
                var change: i32 = 0;
                if (code == 1073741906 or code == 'w') {
                    change = 1;
                } else if (code == 1073741905 or code == 's') {
                    change = -1;
                }
                if (change != 0) {
                    self.clamp_ai(@intCast(self.selected - 1), change);
                    common.sound.play("blip", 0, -1);
                }
            }

            if (code == 13 or code == 32) {
                if (self.selected == 5) {
                    if (self.secret_code_pending) {
                        self.secret_code_pending = false;
                        self.unlock_secret_mode();
                        common.sound.play("select", 0, -1);
                    } else {
                        self.result = "start";
                        self.done = true;
                        common.sound.play("select", 0, -1);
                    }
                } else {
                    self.selected = 5;
                    common.sound.play("blip", 0, -1);
                }
            }
        },
        .mouse_button_down => |m| {
            const mx: i32 = m.x;
            const my: i32 = m.y;
            for (0..4) |i| {
                if (in_rect(self.card_rects[i], mx, my)) self.selected = @as(i32, @intCast(i)) + 1;
            }
            for (0..4) |i| {
                if (in_rect(self.up_rects[i], mx, my)) {
                    self.clamp_ai(i, 1);
                    self.selected = @as(i32, @intCast(i)) + 1;
                    common.sound.play("blip", 0, -1);
                }
                if (in_rect(self.down_rects[i], mx, my)) {
                    self.clamp_ai(i, -1);
                    self.selected = @as(i32, @intCast(i)) + 1;
                    common.sound.play("blip", 0, -1);
                }
            }
            if (in_rect(self.preset_prev, mx, my)) self.cycle_preset(-1);
            if (in_rect(self.preset_next, mx, my)) self.cycle_preset(1);
            if (in_rect(self.ready_rect, mx, my)) {
                if (self.secret_code_pending) {
                    self.secret_code_pending = false;
                    self.unlock_secret_mode();
                    common.sound.play("select", 0, -1);
                } else {
                    self.result = "start";
                    self.done = true;
                    common.sound.play("select", 0, -1);
                }
            }
        },
        else => {},
    }
}

fn in_rect(r: neko.Rect, mx: i32, my: i32) bool {
    return mx >= r.x and mx <= r.x + r.w and my >= r.y and my <= r.y + r.h;
}

fn process(ptr: *anyopaque, dt: f32) void {
    const self: *CustomNight = @ptrCast(@alignCast(ptr));
    self.timer += dt;
    for (0..4) |i| {
        const is_sel: bool = @as(i32, @intCast(i)) + 1 == self.selected;
        const target_scale: f32 = if (is_sel) 1.02 else 1.0;
        const target_glow: f32 = if (is_sel) 1.0 else 0.0;
        self.card_scales[i] = self.card_scales[i] + (target_scale - self.card_scales[i]) * @min(1.0, 8.0 * dt);
        self.card_glows[i] = self.card_glows[i] + (target_glow - self.card_glows[i]) * @min(1.0, 6.0 * dt);
    }
}

fn draw(ptr: *anyopaque, at: neko.Point) void {
    _ = at;
    const self: *CustomNight = @ptrCast(@alignCast(ptr));
    const w: i32 = constants.SCREEN_WIDTH;
    const h: i32 = constants.SCREEN_HEIGHT;

    neko.draw.clear(neko.Color{ .r = 6, .g = 9, .b = 18 });
    var stripe: i32 = 0;
    while (stripe < h) : (stripe += 90) {
        const a: u8 = if (@mod(@divTrunc(stripe, 90), 2) == 0) 12 else 7;
        neko.draw.rect(neko.Rect{ .x = 0, .y = stripe, .w = w, .h = 90 }, neko.Color{ .r = 10, .g = 14, .b = 26, .a = a }, true);
    }
    neko.effect.noise(0, 0, w, h, 0.01);
    neko.draw.rect(neko.Rect{ .x = 24, .y = 24, .w = w - 48, .h = 76 }, neko.Color{ .r = 80, .g = 110, .b = 160, .a = 70 }, false);
    neko.sprite.text(neko.localization.text("custom_night"), @divTrunc(w, 2), 38, .{
        .size = 54,
        .center = true,
        .color = colors.TITLE_COLOR,
    });

    for (0..4) |i| {
        const a = ANIMATRONICS[i];
        const r = self.card_rects[i];
        const cx: i32 = r.x + @divTrunc(r.w, 2);
        const glow: f32 = self.card_glows[i];
        const scale: f32 = self.card_scales[i];
        const dw: i32 = @intFromFloat(@as(f32, @floatFromInt(r.w)) * scale);
        const dh: i32 = @intFromFloat(@as(f32, @floatFromInt(r.h)) * scale);
        const dx: i32 = r.x - @divTrunc(dw - r.w, 2);
        const dy: i32 = r.y - @divTrunc(dh - r.h, 2);

        if (glow > 0.05) {
            const pulse: f32 = 0.5 + 0.5 * @sin(self.timer * 6.0);
            const edge: u8 = @intFromFloat(lerp_f(120, 230, glow));
            const blue: u8 = @intFromFloat(130.0 + pulse * 110.0 * glow);
            neko.draw.rect(neko.Rect{ .x = dx - 3, .y = dy - 3, .w = dw + 6, .h = dh + 6 }, neko.Color{ .r = 90, .g = 120, .b = blue }, false);
            neko.draw.rect(neko.Rect{ .x = dx, .y = dy, .w = dw, .h = dh }, neko.Color{ .r = edge, .g = edge, .b = @min(255, edge + 45) }, false);
        } else {
            neko.draw.rect(neko.Rect{ .x = dx, .y = dy, .w = dw, .h = dh }, neko.Color{ .r = 70, .g = 85, .b = 115 }, false);
        }

        const img_x: i32 = dx + 18;
        const img_y: i32 = dy + 18;
        const img_w: i32 = dw - 36;
        const img_h: i32 = 220;
        const sw: i32 = @min(a.size_w, img_w - 8);
        const sh: i32 = @min(a.size_h, img_h - 8);
        const sx: i32 = img_x + @divTrunc(img_w - sw, 2);
        const sy: i32 = img_y + @divTrunc(img_h - sh, 2);
        neko.sprite.face(a.sprite, sx, sy, sw, sh);

        neko.sprite.text(a.name, cx, r.y + 260, .{ .size = 30, .center = true, .color = neko.Color{ .r = 255, .g = 255, .b = 255 } });

        const up = self.up_rects[i];
        const dn = self.down_rects[i];
        const btn_r: u8 = if (glow > 0.2) 150 else 90;
        const btn_g: u8 = if (glow > 0.2) 170 else 90;
        const btn_b: u8 = if (glow > 0.2) 210 else 105;

        neko.draw.rect(up, neko.Color{ .r = btn_r, .g = btn_g, .b = btn_b }, false);
        neko.sprite.text("\u{25b2}", up.x + @divTrunc(up.w, 2), up.y + @divTrunc(up.h, 2) + 1, .{ .size = 26, .center = true, .color = neko.Color{ .r = 255, .g = 255, .b = 255 } });

        const lvl: i32 = self.ai_levels[i];
        const val_r: u8 = if (lvl >= 20) 255 else if (lvl == 0) 80 else 255;
        const val_g: u8 = if (lvl >= 20) 60 else if (lvl == 0) 220 else 255;
        const val_b: u8 = if (lvl >= 20) 60 else if (lvl == 0) 110 else 255;
        var lbuf: [8]u8 = undefined;
        neko.sprite.text(fmt.bufPrint(&lbuf, "{d}", .{lvl}) catch "", cx, r.y + 360, .{
            .size = 52,
            .center = true,
            .color = neko.Color{ .r = val_r, .g = val_g, .b = val_b },
        });

        neko.draw.rect(dn, neko.Color{ .r = btn_r, .g = btn_g, .b = btn_b }, false);
        neko.sprite.text("\u{25bc}", dn.x + @divTrunc(dn.w, 2), dn.y + @divTrunc(dn.h, 2) + 1, .{ .size = 26, .center = true, .color = neko.Color{ .r = 255, .g = 255, .b = 255 } });
    }

    const pulse: f32 = 0.5 + 0.5 * @sin(self.timer * 4.0);
    const arrow_r: u8 = 200;
    const arrow_g: u8 = 200;
    const arrow_b: u8 = @intFromFloat(140.0 + 70.0 * pulse);

    neko.draw.rect(self.preset_prev, neko.Color{ .r = 120, .g = 120, .b = 140 }, false);
    neko.sprite.text("<<", self.preset_prev.x + @divTrunc(self.preset_prev.w, 2), self.preset_prev.y + @divTrunc(self.preset_prev.h, 2), .{ .size = 28, .center = true, .color = neko.Color{ .r = arrow_r, .g = arrow_g, .b = arrow_b } });

    neko.draw.rect(self.preset_label, neko.Color{ .r = 100, .g = 100, .b = 120 }, false);
    const p_name: []const u8 = self.presets[self.current_preset].name;
    const label_size: u32 = if (p_name.len >= 22) 20 else if (p_name.len >= 16) 24 else 30;
    neko.sprite.text(p_name, self.preset_label.x + @divTrunc(self.preset_label.w, 2), self.preset_label.y + @divTrunc(self.preset_label.h, 2), .{ .size = label_size, .center = true, .color = neko.Color{ .r = 255, .g = 255, .b = 120 } });

    neko.draw.rect(self.preset_next, neko.Color{ .r = 120, .g = 120, .b = 140 }, false);
    neko.sprite.text(">>", self.preset_next.x + @divTrunc(self.preset_next.w, 2), self.preset_next.y + @divTrunc(self.preset_next.h, 2), .{ .size = 28, .center = true, .color = neko.Color{ .r = arrow_r, .g = arrow_g, .b = arrow_b } });

    const rs: bool = self.selected == 5;
    if (rs) {
        const glow: u8 = @intFromFloat(100.0 + 100.0 * (0.5 + 0.5 * @sin(self.timer * 7.0)));
        neko.draw.rect(self.ready_rect, neko.Color{ .r = glow, .g = glow, .b = 80 }, false);
    } else {
        neko.draw.rect(self.ready_rect, neko.Color{ .r = 120, .g = 120, .b = 130 }, false);
    }

    const ready_label: []const u8 = if (self.secret_code_pending) neko.localization.text("apply_code") else neko.localization.text("ready");
    var rbuf: [64]u8 = undefined;
    const full = if (rs) fmt.bufPrint(&rbuf, ">> {s}", .{ready_label}) catch ready_label else ready_label;
    neko.sprite.text(full, self.ready_rect.x + @divTrunc(self.ready_rect.w, 2), self.ready_rect.y + @divTrunc(self.ready_rect.h, 2), .{
        .size = 40,
        .center = true,
        .color = neko.Color{ .r = if (rs) 255 else 150, .g = if (rs) 255 else 150, .b = if (rs) 255 else 160 },
    });

    neko.sprite.text(neko.localization.text("custom_controls_help"), @divTrunc(w, 2), h - 22, .{
        .size = 14,
        .center = true,
        .color = neko.Color{ .r = 100, .g = 100, .b = 110 },
    });
    neko.effect.scanlines(0, 0, w, h, 15);
}

fn is_done(ptr: *anyopaque) bool {
    const self: *CustomNight = @ptrCast(@alignCast(ptr));
    return self.done;
}

fn result(ptr: *anyopaque) []const u8 {
    const self: *CustomNight = @ptrCast(@alignCast(ptr));
    return self.result;
}

fn deinit(ptr: *anyopaque, allocator: Allocator) void {
    const self: *CustomNight = @ptrCast(@alignCast(ptr));
    allocator.destroy(self);
}
