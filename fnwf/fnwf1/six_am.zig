// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Renan Lucas Vieira Hilário

//! FNWF 1 — the 6 AM screen.

const std: type = @import("std");
const fmt: type = std.fmt;
const neko: type = @import("neko");
const common: type = @import("common");

const screen: type = @import("screen.zig");
const config: type = @import("config.zig");

const Allocator: type = std.mem.Allocator;

/// End-of-night celebration.
pub const SixAm: type = struct {
    node: neko.scene.Node,
    night: i32,
    timer: f32 = 0,
    chime: bool = false,
    done: bool = false,
    result: []const u8 = "",

    pub fn create(allocator: Allocator, night: i32) !*neko.scene.Node {
        const self: *SixAm = try allocator.create(SixAm);
        self.* = SixAm{
            .node = neko.scene.Node{ .ptr = @ptrCast(self), .vtable = &vtable, .allocator = allocator, .name = "six_am" },
            .night = night,
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

const screen_vtable: screen.VTable = .{ .is_done = is_done, .result = result };

fn process(ptr: *anyopaque, dt: f32) void {
    const self: *SixAm = @ptrCast(@alignCast(ptr));
    self.timer += dt;
    if (!self.chime and self.timer > 1.0) {
        common.sound.play("noite_concluida", 0, -1);
        self.chime = true;
    }
    if (self.timer > 12.0) self.done = true;
}

fn input(ptr: *anyopaque, ev: neko.Event) void {
    const self: *SixAm = @ptrCast(@alignCast(ptr));
    if (self.timer < 2.0) return;
    switch (ev) {
        .key_down, .mouse_button_down => {
            self.done = true;
            self.result = "done";
        },
        else => {},
    }
}

fn draw(ptr: *anyopaque, at: neko.Point) void {
    _ = at;
    const self: *SixAm = @ptrCast(@alignCast(ptr));
    neko.draw.clear(config.BLACK);
    const cx: i32 = config.SCREEN_W / 2;
    const cy: i32 = config.SCREEN_H / 2;
    const alpha: u8 = @intFromFloat(@min(255.0, self.timer * 300.0));
    neko.sprite.text("6", cx - 60, cy - 60, .{ .size = 160, .color = neko.Color{ .r = 240, .g = 220, .b = 120, .a = alpha } });
    neko.sprite.text("AM", cx + 90, cy - 20, .{ .size = 60, .color = neko.Color{ .r = 240, .g = 220, .b = 120, .a = alpha } });

    var nbuf: [48]u8 = undefined;
    const label = fmt.bufPrint(&nbuf, "Noite {d} concluída", .{self.night}) catch "";
    neko.sprite.text(label, cx, cy + 120, .{ .size = 26, .center = true, .color = neko.Color{ .r = 210, .g = 210, .b = 210, .a = alpha } });

    if (self.timer > 3.0 and @mod(@as(i32, @intFromFloat(self.timer * 2)), 2) == 1) {
        neko.sprite.text("Pressione ENTER", cx, config.SCREEN_H - 60, .{ .size = 18, .center = true, .color = config.MUTED });
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
