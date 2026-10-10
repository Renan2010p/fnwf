// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Renan Lucas Vieira Hilário

//! The newspaper epilogue — port of `game1/states/NewspaperState`.
//!
//! Shown on a loss: a paper reports the "disappearance". Waits a few seconds,
//! then any key continues.

const std: type = @import("std");
const neko: type = @import("neko");
const common: type = @import("common");

const screen: type = @import("../screen.zig");
const constants: type = @import("../config/constants.zig");

const Allocator: type = std.mem.Allocator;

/// The in-universe newspaper page.
pub const Newspaper: type = struct {
    node: neko.scene.Node,

    timer: f32 = 0,
    done: bool = false,
    fade_alpha: i32 = 255,
    fading_in: bool = true,
    fading_out: bool = false,

    pub fn create(allocator: Allocator) !*neko.scene.Node {
        const self: *Newspaper = try allocator.create(Newspaper);
        self.* = Newspaper{
            .node = neko.scene.Node{
                .ptr = @ptrCast(self),
                .vtable = &vtable,
                .allocator = allocator,
                .name = "newspaper",
            },
        };
        screen.attach(self, &screen_vtable);
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

const screen_vtable: screen.VTable = .{ .is_done = is_done, .result = screen.no_result };

fn draw(ptr: *anyopaque, at: neko.Point) void {
    _ = at;
    const self: *Newspaper = @ptrCast(@alignCast(ptr));
    const w: i32 = constants.SCREEN_WIDTH;
    const h: i32 = constants.SCREEN_HEIGHT;

    neko.draw.clear(neko.Color{ .r = 10, .g = 10, .b = 15 });
    neko.effect.noise(0, 0, w, h, 0.015);

    const pw: i32 = 600;
    const ph: i32 = 450;
    const px: i32 = @divTrunc(w - pw, 2);
    const py: i32 = @divTrunc(h - ph, 2);

    neko.draw.rect(neko.Rect{ .x = px, .y = py, .w = pw, .h = ph }, neko.Color{ .r = 160, .g = 155, .b = 140 }, true);
    neko.draw.rect(neko.Rect{ .x = px, .y = py, .w = pw, .h = ph }, neko.Color{ .r = 30, .g = 30, .b = 30 }, false);

    neko.sprite.text(neko.localization.text("newspaper_name"), px + 30, py + 20, .{ .size = 20, .color = .{ .r = 40, .g = 40, .b = 40 } });
    neko.draw.line(px + 20, py + 45, px + pw - 20, py + 45, neko.Color{ .r = 40, .g = 40, .b = 40 });
    neko.sprite.text(neko.localization.text("newspaper_h1"), px + @divTrunc(pw, 2), py + 80, .{
        .size = 34,
        .center = true,
        .color = neko.Color{ .r = 20, .g = 20, .b = 20 },
    });
    neko.sprite.text(neko.localization.text("newspaper_h2"), px + @divTrunc(pw, 2), py + 120, .{
        .size = 16,
        .center = true,
        .color = neko.Color{ .r = 50, .g = 50, .b = 50 },
    });

    const lines = [9][]const u8{
        neko.localization.text("newspaper_p1"),
        neko.localization.text("newspaper_p2"),
        neko.localization.text("newspaper_p3"),
        neko.localization.text("newspaper_p4"),
        "",
        neko.localization.text("newspaper_p5"),
        neko.localization.text("newspaper_p6"),
        "",
        neko.localization.text("newspaper_p7"),
    };
    for (lines, 0..) |line, i| {
        neko.sprite.text(line, px + @divTrunc(pw, 2), py + 170 + @as(i32, @intCast(i)) * 22, .{
            .size = 14,
            .center = true,
            .color = neko.Color{ .r = 30, .g = 30, .b = 30 },
        });
    }

    if (self.timer > 3.0 and @mod(@as(i32, @intFromFloat(self.timer * 2)), 2) == 1) {
        neko.sprite.text(neko.localization.text("click_continue"), @divTrunc(w, 2), h - 50, .{
            .size = 16,
            .center = true,
            .color = neko.Color{ .r = 255, .g = 255, .b = 255 },
        });
    }

    if (self.fade_alpha > 0) {
        neko.draw.rect(neko.Rect{ .x = 0, .y = 0, .w = w, .h = h }, neko.Color{ .r = 0, .g = 0, .b = 0, .a = @intCast(self.fade_alpha) }, true);
    }
}

fn process(ptr: *anyopaque, dt: f32) void {
    const self: *Newspaper = @ptrCast(@alignCast(ptr));
    self.timer += dt;

    if (self.fading_in) {
        self.fade_alpha = @max(0, self.fade_alpha - @as(i32, @intFromFloat(100.0 * dt)));
        if (self.fade_alpha <= 0) self.fading_in = false;
    }
    if (self.fading_out) {
        self.fade_alpha = @min(255, self.fade_alpha + @as(i32, @intFromFloat(150.0 * dt)));
        if (self.fade_alpha >= 255) self.done = true;
    }
}

fn input(ptr: *anyopaque, ev: neko.Event) void {
    const self: *Newspaper = @ptrCast(@alignCast(ptr));
    if (self.fading_in or self.fading_out or self.timer <= 3.0) return;
    switch (ev) {
        .key_down, .mouse_button_down => {
            self.fading_out = true;
            common.sound.play("select", 0, -1);
        },
        else => {},
    }
}

fn is_done(ptr: *anyopaque) bool {
    const self: *Newspaper = @ptrCast(@alignCast(ptr));
    return self.done;
}

fn deinit(ptr: *anyopaque, allocator: Allocator) void {
    const self: *Newspaper = @ptrCast(@alignCast(ptr));
    allocator.destroy(self);
}
