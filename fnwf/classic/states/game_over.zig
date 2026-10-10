// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Renan Lucas Vieira Hilário

//! Game over / win — a scene tree: the root draws the dressing and owns the
//! text as `Label` children. The destination is in `result` ("menu" or
//! "newspaper").

const std: type = @import("std");
const fmt: type = std.fmt;
const neko: type = @import("neko");

const screen: type = @import("../screen.zig");
const constants: type = @import("../config/constants.zig");
const colors: type = @import("../config/colors.zig");

const Allocator: type = std.mem.Allocator;

/// The end-of-night newspaper (loss) or victory screen (win).
pub const GameOver: type = struct {
    node: neko.scene.Node,
    is_win: bool,
    night: i32,
    result: []const u8,

    timer: f32 = 0,
    text_alpha: i32 = 0,
    show_text: bool = false,

    news_title: *neko.scene.Label = undefined,
    news_h1: *neko.scene.Label = undefined,
    news_h2: *neko.scene.Label = undefined,
    body: [6]*neko.scene.Label = undefined,
    press_loss: *neko.scene.Label = undefined,

    win_label: *neko.scene.Label = undefined,
    win_night: *neko.scene.Label = undefined,
    win_press: *neko.scene.Label = undefined,

    body4: [160]u8 = undefined,
    win_title_buf: [160]u8 = undefined,

    pub fn create(allocator: Allocator, is_win: bool, night: i32) !*neko.scene.Node {
        const self: *GameOver = try allocator.create(GameOver);
        self.* = GameOver{
            .node = neko.scene.Node{
                .ptr = @ptrCast(self),
                .vtable = &vtable,
                .allocator = allocator,
                .name = "gameover",
            },
            .is_win = is_win,
            .night = night,
            .result = if (is_win or night == 0) "menu" else "newspaper",
        };
        screen.attach(self, &screen_vtable);

        const w: i32 = constants.SCREEN_WIDTH;
        const h: i32 = constants.SCREEN_HEIGHT;
        const cx: i32 = @divTrunc(w, 2);
        const py: i32 = @divTrunc(h, 2) - @divTrunc(350, 2) - 30;

        // Loss (newspaper).
        self.news_title = try neko.scene.addLabel(&self.node, .{ .text = neko.localization.text("news_title"), .pos = .{ .x = cx, .y = py + 20 }, .size = 18, .center = true, .color = .{ .r = 40, .g = 40, .b = 40 } });
        self.news_h1 = try neko.scene.addLabel(&self.node, .{ .text = neko.localization.text("news_headline_1"), .pos = .{ .x = cx, .y = py + 70 }, .size = 32, .center = true, .color = .{ .r = 30, .g = 30, .b = 30 } });
        self.news_h2 = try neko.scene.addLabel(&self.node, .{ .text = neko.localization.text("news_headline_2"), .pos = .{ .x = cx, .y = py + 110 }, .size = 38, .center = true, .color = .{ .r = 150, .g = 20, .b = 20 } });

        var nbuf: [32]u8 = undefined;
        const nl = fmt.bufPrint(&nbuf, "{s} {d}", .{ neko.localization.text("night"), night }) catch "";
        const l4 = fmt.bufPrint(&self.body4, "{s} {s}", .{ neko.localization.text("news_body_4"), nl }) catch "";
        const body_keys = [_][]const u8{
            neko.localization.text("news_body_1"),
            neko.localization.text("news_body_2"),
            neko.localization.text("news_body_3"),
            "",
            l4,
            neko.localization.text("news_body_5"),
        };
        for (body_keys, 0..) |key, i| {
            self.body[i] = try neko.scene.addLabel(&self.node, .{ .text = key, .pos = .{ .x = cx, .y = py + 165 + @as(i32, @intCast(i)) * 22 }, .size = 13, .center = true, .color = .{ .r = 50, .g = 50, .b = 50 } });
        }
        self.press_loss = try neko.scene.addLabel(&self.node, .{ .text = neko.localization.text("press_any_key"), .pos = .{ .x = cx, .y = h - 50 }, .size = 16, .center = true, .color = .{ .r = 100, .g = 100, .b = 100 } });

        // Win.
        self.win_label = try neko.scene.addLabel(&self.node, .{ .text = neko.localization.text("gameover_win"), .pos = .{ .x = cx, .y = @divTrunc(h, 2) - 40 }, .size = 80, .center = true });
        const win_title = fmt.bufPrint(&self.win_title_buf, "{s} {s}", .{ neko.localization.text("night_complete"), nl }) catch "";
        self.win_night = try neko.scene.addLabel(&self.node, .{ .text = win_title, .pos = .{ .x = cx, .y = @divTrunc(h, 2) + 50 }, .size = 24, .center = true, .color = .{ .r = 200, .g = 200, .b = 200 } });
        self.win_press = try neko.scene.addLabel(&self.node, .{ .text = neko.localization.text("press_any_key_continue"), .pos = .{ .x = cx, .y = h - 50 }, .size = 16, .center = true, .color = .{ .r = 100, .g = 100, .b = 100 } });

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

fn set_loss_visible(self: *GameOver, on: bool) void {
    self.news_title.node.visible = on;
    self.news_h1.node.visible = on;
    self.news_h2.node.visible = on;
    for (self.body) |b| b.node.visible = on;
    self.press_loss.node.visible = on;
}

fn set_win_visible(self: *GameOver, on: bool) void {
    self.win_label.node.visible = on;
    self.win_night.node.visible = on;
    self.win_press.node.visible = on;
}

fn process(ptr: *anyopaque, dt: f32) void {
    const self: *GameOver = @ptrCast(@alignCast(ptr));
    self.timer += dt;

    if (self.timer > 0.5 and !self.show_text) {
        self.show_text = true;
        if (self.is_win) {
            set_win_visible(self, true);
        } else {
            set_loss_visible(self, true);
        }
    }

    if (self.is_win) {
        self.win_night.node.visible = self.show_text and self.timer > 2.0;
        self.win_press.node.visible = self.timer > 3.5 and @mod(@as(i32, @intFromFloat(self.timer * 2)), 2) == 1;
    } else {
        if (self.timer > 0.5) {
            self.text_alpha = @min(255, self.text_alpha + @as(i32, @intFromFloat(200.0 * dt)));
            const a: u8 = @intCast(self.text_alpha);
            self.news_title.color.a = a;
            self.news_h1.color.a = a;
            self.news_h2.color.a = a;
            for (self.body) |b| b.color.a = a;
        }
        self.press_loss.node.visible = self.timer > 3.0 and @mod(@as(i32, @intFromFloat(self.timer * 2)), 2) == 1;
    }
}

fn draw(ptr: *anyopaque, at: neko.Point) void {
    _ = at;
    const self: *GameOver = @ptrCast(@alignCast(ptr));
    const w: i32 = constants.SCREEN_WIDTH;
    const h: i32 = constants.SCREEN_HEIGHT;

    if (self.is_win) {
        if (self.timer > 1.5) {
            const a: u8 = @intCast(@min(100, @as(i32, @intFromFloat((self.timer - 1.5) * 80.0))));
            neko.draw.rect(neko.Rect{ .x = 0, .y = 0, .w = w, .h = h }, neko.Color{ .r = 255, .g = 255, .b = 200, .a = a }, true);
        }
        if (self.timer > 2.0) {
            const stars: i32 = @min(self.night, 7);
            var i: i32 = 0;
            while (i < stars) : (i += 1) {
                neko.draw.star(@divTrunc(w, 2) - 75 + i * 25, @divTrunc(h, 2) + 100, 10, colors.STAR_COLOR);
            }
        }
    } else {
        if (!self.show_text) return;
        neko.draw.rect(neko.Rect{ .x = @divTrunc(w, 2) - 250, .y = @divTrunc(h, 2) - 205, .w = 500, .h = 350 }, neko.Color{ .r = 180, .g = 170, .b = 150, .a = @intCast(self.text_alpha) }, true);
        neko.effect.scanlines(0, 0, w, h, 15);
    }
}

fn input(ptr: *anyopaque, ev: neko.Event) void {
    _ = ptr;
    // The result is fixed at creation from `is_win`/`night` (like the C++ main,
    // which reads those fields instead of `result`); a key press only skips the
    // remaining wait visually. Nothing to do here.
    _ = ev;
}

fn is_done(ptr: *anyopaque) bool {
    const self: *GameOver = @ptrCast(@alignCast(ptr));
    return self.timer > 3.0;
}

fn result(ptr: *anyopaque) []const u8 {
    const self: *GameOver = @ptrCast(@alignCast(ptr));
    return self.result;
}

fn deinit(ptr: *anyopaque, allocator: Allocator) void {
    const self: *GameOver = @ptrCast(@alignCast(ptr));
    allocator.destroy(self);
}
