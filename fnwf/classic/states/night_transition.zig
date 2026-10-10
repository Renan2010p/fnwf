// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Renan Lucas Vieira Hilário

//! The between-nights Discord recap — port of `game1/states/NightTransitionState`.
//!
//! Shown after Nights 1 and 2, building one message per key press. Nights other
//! than 2 and 3 have no lines and pass straight through.

const std: type = @import("std");
const fmt: type = std.fmt;
const mem: type = std.mem;
const neko: type = @import("neko");
const common: type = @import("common");

const screen: type = @import("../screen.zig");
const constants: type = @import("../config/constants.zig");

const Allocator: type = std.mem.Allocator;

const MAX_MESSAGES: usize = 8;
const SIDEBAR_W: i32 = 240;

const CEDRO_COLOR: neko.Color = neko.Color{ .r = 140, .g = 110, .b = 80 };
const RENAN_COLOR: neko.Color = neko.Color{ .r = 100, .g = 180, .b = 255 };

const Message: type = struct {
    user: []const u8,
    avatar: []const u8,
    color: neko.Color,
    text: []const u8,
};

/// The Discord recap between nights.
pub const NightTransition: type = struct {
    node: neko.scene.Node,
    night: i32,

    phase: i32 = 0,
    fade_alpha: i32 = 255,
    done: bool = false,
    timer: f32 = 0,

    messages: [MAX_MESSAGES]Message = undefined,
    message_count: usize = 0,
    visible_messages: usize = 0,
    scroll_y: f32 = 0,
    target_scroll: f32 = 0,

    pub fn create(allocator: Allocator, night: i32) !*neko.scene.Node {
        const self: *NightTransition = try allocator.create(NightTransition);
        self.* = NightTransition{
            .node = neko.scene.Node{
                .ptr = @ptrCast(self),
                .vtable = &vtable,
                .allocator = allocator,
                .name = "night_transition",
            },
            .night = night,
        };
        screen.attach(self, &screen_vtable);

        neko.sprite.load("cedro");
        neko.sprite.load("renan");
        self.build_messages();
        return &self.node;
    }

    fn push(self: *NightTransition, user: []const u8, key: []const u8) void {
        if (self.message_count >= MAX_MESSAGES) return;
        const is_renan: bool = mem.eql(u8, user, "Renan");
        self.messages[self.message_count] = Message{
            .user = user,
            .avatar = if (is_renan) "renan" else "cedro",
            .color = if (is_renan) RENAN_COLOR else CEDRO_COLOR,
            .text = neko.localization.text(key),
        };
        self.message_count += 1;
    }

    fn build_messages(self: *NightTransition) void {
        self.message_count = 0;
        const server: []const u8 = neko.localization.text("discord_server");

        if (self.night == 2) {
            const keys = [6][]const u8{ "transition_n2_m0", "transition_n2_m1", "transition_n2_m2", "transition_n2_m3", "transition_n2_m4", "transition_n2_m5" };
            for (keys, 0..) |key, i| {
                self.push(if (i == 3) "Renan" else server, key);
            }
        } else if (self.night == 3) {
            const keys = [5][]const u8{ "transition_n3_m0", "transition_n3_m1", "transition_n3_m2", "transition_n3_m3", "transition_n3_m4" };
            for (keys, 0..) |key, i| {
                self.push(if (i == 3) "Renan" else server, key);
            }
        }
    }

    fn update_scroll(self: *NightTransition) void {
        var th: i32 = 15;
        var prev: []const u8 = "";
        var i: usize = 0;
        while (i < self.visible_messages and i < self.message_count) : (i += 1) {
            const m = self.messages[i];
            if (mem.eql(u8, prev, m.user)) {
                th += 24;
            } else {
                const gap: i32 = if (prev.len == 0) 0 else 8;
                th += gap + 48;
            }
            prev = m.user;
        }
        const va: i32 = constants.SCREEN_HEIGHT - 128;
        if (th > va) self.target_scroll = @floatFromInt(th - va);
    }
};

const vtable: neko.scene.Node.VTable = neko.scene.Node.VTable{
    .ready = neko.scene.no_ready,
    .process = process,
    .draw = draw,
    .input = input,
    .deinit = deinit,
};

const screen_vtable: screen.VTable = .{ .is_done = is_done, .result = screen.no_result };

fn advance(self: *NightTransition) void {
    if (self.phase == 0) {
        self.phase = 1;
        self.fade_alpha = 0;
    } else if (self.phase == 1) {
        if (self.visible_messages < self.message_count) {
            self.visible_messages += 1;
            self.update_scroll();
            common.sound.play("notification", 0, -1);
        } else {
            self.phase = 2;
            self.fade_alpha = 0;
        }
    }
}

fn process(ptr: *anyopaque, dt: f32) void {
    const self: *NightTransition = @ptrCast(@alignCast(ptr));
    self.timer += dt;

    if (self.phase == 0) {
        self.fade_alpha = @max(0, self.fade_alpha - @as(i32, @intFromFloat(250.0 * dt)));
        if (self.fade_alpha <= 0) {
            self.phase = 1;
            common.sound.play("notification", 0, -1);
        }
    } else if (self.phase == 1 and self.visible_messages == 0) {
        self.visible_messages = 1;
        self.update_scroll();
    } else if (self.phase == 2) {
        self.fade_alpha = @min(255, self.fade_alpha + @as(i32, @intFromFloat(250.0 * dt)));
        if (self.fade_alpha >= 255) self.done = true;
    }

    self.scroll_y = self.scroll_y + (self.target_scroll - self.scroll_y) * 6.0 * dt;
}

fn input(ptr: *anyopaque, ev: neko.Event) void {
    const self: *NightTransition = @ptrCast(@alignCast(ptr));
    switch (ev) {
        .key_down => |k| {
            if (k.code == 13 or k.code == 32) advance(self);
        },
        .mouse_button_down => advance(self),
        else => {},
    }
}

fn draw(ptr: *anyopaque, at: neko.Point) void {
    _ = at;
    const self: *NightTransition = @ptrCast(@alignCast(ptr));
    const w: i32 = constants.SCREEN_WIDTH;
    const h: i32 = constants.SCREEN_HEIGHT;

    neko.draw.clear(neko.Color{ .r = 54, .g = 57, .b = 63 });
    if (self.phase >= 1) draw_discord(self);
    neko.effect.noise(0, 0, w, h, 0.005);

    if (self.phase == 1) {
        const blink: bool = @mod(@as(i32, @intFromFloat(self.timer * 2)), 2) == 0;
        if (blink) {
            var buf: [96]u8 = undefined;
            const txt: []const u8 = if (self.visible_messages < self.message_count)
                neko.localization.text("story_skip")
            else
                fmt.bufPrint(&buf, "{s} {d}", .{ neko.localization.text("story_start_night"), self.night }) catch "";
            neko.sprite.text(txt, @divTrunc(w, 2), h - 20, .{
                .size = 11,
                .center = true,
                .color = neko.Color{ .r = 130, .g = 130, .b = 140 },
            });
        }
    }

    if (self.fade_alpha > 0) {
        neko.draw.rect(neko.Rect{ .x = 0, .y = 0, .w = w, .h = h }, neko.Color{ .r = 54, .g = 57, .b = 63, .a = @intCast(self.fade_alpha) }, true);
    }
}

fn draw_discord(self: *NightTransition) void {
    const w: i32 = constants.SCREEN_WIDTH;
    const h: i32 = constants.SCREEN_HEIGHT;

    neko.draw.rect(neko.Rect{ .x = 0, .y = 0, .w = SIDEBAR_W, .h = h }, neko.Color{ .r = 47, .g = 49, .b = 54 }, true);
    neko.draw.rect(neko.Rect{ .x = 0, .y = 0, .w = SIDEBAR_W, .h = 48 }, neko.Color{ .r = 40, .g = 43, .b = 48 }, true);
    neko.sprite.text(neko.localization.text("discord_server"), 15, 14, .{ .size = 14, .color = neko.Color{ .r = 220, .g = 220, .b = 220 } });
    neko.draw.line(0, 48, SIDEBAR_W, 48, neko.Color{ .r = 30, .g = 33, .b = 36 });

    const cx: i32 = SIDEBAR_W;
    const cw: i32 = w - SIDEBAR_W;
    neko.draw.rect(neko.Rect{ .x = cx, .y = 0, .w = cw, .h = 48 }, neko.Color{ .r = 54, .g = 57, .b = 63 }, true);
    neko.sprite.text(neko.localization.text("chan_security"), cx + 18, 14, .{ .size = 15, .color = neko.Color{ .r = 220, .g = 220, .b = 220 } });

    var my: i32 = 63 - @as(i32, @intFromFloat(self.scroll_y));
    var buf: [96]u8 = undefined;
    const header = fmt.bufPrint(&buf, "--- {s} {d} ---", .{ neko.localization.text("night"), self.night }) catch "";
    neko.sprite.text(header, cx + @divTrunc(cw, 2), my, .{ .size = 12, .center = true, .color = neko.Color{ .r = 130, .g = 130, .b = 140 } });
    my += 30;

    var prev: []const u8 = "";
    var i: usize = 0;
    while (i < self.visible_messages and i < self.message_count) : (i += 1) {
        const m = self.messages[i];
        if (mem.eql(u8, prev, m.user)) {
            neko.sprite.text(m.text, cx + 75, my, .{ .size = 14, .color = neko.Color{ .r = 220, .g = 220, .b = 220 } });
            my += 24;
        } else {
            if (prev.len != 0) my += 8;
            neko.draw.circle(cx + 40, my + 20, 20, neko.Color{ .r = 80, .g = 80, .b = 90 }, true);
            neko.sprite.face(m.avatar, cx + 20, my, 40, 40);
            neko.sprite.text(m.user, cx + 75, my, .{ .size = 14, .color = m.color });
            my += 22;
            neko.sprite.text(m.text, cx + 75, my, .{ .size = 14, .color = neko.Color{ .r = 220, .g = 220, .b = 220 } });
            my += 24;
        }
        prev = m.user;
    }

    neko.draw.rect(neko.Rect{ .x = cx + 16, .y = h - 65, .w = cw - 32, .h = 44 }, neko.Color{ .r = 64, .g = 68, .b = 75 }, true);
    neko.sprite.text(neko.localization.text("discord_input"), cx + 30, h - 52, .{ .size = 13, .color = neko.Color{ .r = 100, .g = 100, .b = 110 } });
}

fn is_done(ptr: *anyopaque) bool {
    const self: *NightTransition = @ptrCast(@alignCast(ptr));
    return self.done;
}

fn deinit(ptr: *anyopaque, allocator: Allocator) void {
    const self: *NightTransition = @ptrCast(@alignCast(ptr));
    allocator.destroy(self);
}
