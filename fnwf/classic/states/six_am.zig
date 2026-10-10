// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Renan Lucas Vieira Hilário

//! The 6 AM screen — a scene tree: labels only, the root drives the timing.

const std: type = @import("std");
const neko: type = @import("neko");
const common: type = @import("common");

const screen: type = @import("../screen.zig");
const constants: type = @import("../config/constants.zig");

const Allocator: type = std.mem.Allocator;

/// Shows "5 AM" then "6 AM", with a chime, then finishes.
pub const SixAm: type = struct {
    node: neko.scene.Node,
    night: i32,
    result: []const u8,

    timer: f32 = 0,
    done: bool = false,
    hour: i32 = 5,
    show_six: bool = false,
    played_chime: bool = false,

    hour_label: *neko.scene.Label = undefined,
    press_label: *neko.scene.Label = undefined,

    pub fn create(allocator: Allocator, night: i32) !*neko.scene.Node {
        const self: *SixAm = try allocator.create(SixAm);
        self.* = SixAm{
            .node = neko.scene.Node{
                .ptr = @ptrCast(self),
                .vtable = &vtable,
                .allocator = allocator,
                .name = "six_am",
            },
            .night = night,
            .result = if (night == 5) "paycheck" else "menu",
        };
        screen.attach(self, &screen_vtable);

        const cx: i32 = @divTrunc(constants.SCREEN_WIDTH, 2);
        const cy: i32 = @divTrunc(constants.SCREEN_HEIGHT, 2);
        self.hour_label = try neko.scene.addLabel(&self.node, neko.scene.Label.Options{
            .text = "5",
            .pos = neko.Point{ .x = cx - 40, .y = cy - 20 },
            .size = 120,
            .center = true,
        });
        _ = try neko.scene.addLabel(&self.node, neko.scene.Label.Options{
            .text = "AM",
            .pos = neko.Point{ .x = cx + 80, .y = cy - 10 },
            .size = 50,
            .center = true,
        });
        self.press_label = try neko.scene.addLabel(&self.node, neko.scene.Label.Options{
            .text = neko.localization.text("press_any_key"),
            .pos = neko.Point{ .x = cx, .y = constants.SCREEN_HEIGHT - 50 },
            .size = 16,
            .center = true,
            .color = neko.Color{ .r = 150, .g = 150, .b = 150 },
        });
        self.press_label.node.visible = false;
        return &self.node;
    }
};

const vtable: neko.scene.Node.VTable = neko.scene.Node.VTable{
    .ready = neko.scene.no_ready,
    .process = process,
    .draw = neko.scene.no_draw,
    .input = input,
    .deinit = deinit,
};

const screen_vtable: screen.VTable = .{ .is_done = is_done, .result = result };

fn process(ptr: *anyopaque, dt: f32) void {
    const self: *SixAm = @ptrCast(@alignCast(ptr));
    self.timer += dt;

    if (!self.show_six and self.timer > 2.0) {
        self.hour = 6;
        self.hour_label.text = "6";
        self.show_six = true;
    }
    if (self.show_six and !self.played_chime) {
        common.sound.play("noite_concluida", 0, -1);
        self.played_chime = true;
    }
    if (self.timer > 10.0) self.done = true;

    self.press_label.node.visible = self.timer > 8.0 and @mod(@as(i32, @intFromFloat(self.timer * 2)), 2) == 1;
}

fn input(ptr: *anyopaque, ev: neko.Event) void {
    const self: *SixAm = @ptrCast(@alignCast(ptr));
    if (self.timer <= 2.0) return;
    switch (ev) {
        .key_down, .mouse_button_down => self.done = true,
        else => {},
    }
}

fn is_done(ptr: *anyopaque) bool {
    const self: *SixAm = @ptrCast(@alignCast(ptr));
    return self.done;
}

fn result(ptr: *anyopaque) []const u8 {
    const self: *SixAm = @ptrCast(@alignCast(ptr));
    return self.result;
}

fn deinit(ptr: *anyopaque, allocator: Allocator) void {
    const self: *SixAm = @ptrCast(@alignCast(ptr));
    allocator.destroy(self);
}
