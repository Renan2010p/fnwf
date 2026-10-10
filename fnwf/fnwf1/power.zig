// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Renan Lucas Vieira Hilário

//! FNWF 1 — the office power meter.

const std: type = @import("std");
const fmt: type = std.fmt;
const neko: type = @import("neko");

const config: type = @import("config.zig");

/// Power drain from the doors, lights and monitor.
pub const Power: type = struct {
    value: f32 = config.POWER_MAX,
    usage: i32 = 1,
    dead: bool = false,
    dead_timer: f32 = 0,

    /// `extra` counts the door/light toggles active; `camera` adds one bar.
    pub fn update(self: *Power, dt: f32, extra: i32, camera: bool) void {
        if (self.dead) {
            self.dead_timer += dt;
            return;
        }
        self.usage = @min(5, 1 + extra + @as(i32, if (camera) 1 else 0));
        self.value -= config.BASE_POWER_DRAIN * @as(f32, @floatFromInt(self.usage)) * dt;
        if (self.value <= 0) {
            self.value = 0;
            self.dead = true;
            self.dead_timer = 0;
        }
    }

    pub fn fraction(self: *const Power) f32 {
        return self.value / config.POWER_MAX;
    }

    pub fn draw(self: *const Power) void {
        const x: i32 = 40;
        const y: i32 = config.SCREEN_H - 70;
        const pct: i32 = @max(0, @as(i32, @intFromFloat(self.value)));

        const col: neko.Color = if (pct <= 20) config.RED else if (pct <= 50) config.ACCENT else config.GREEN;
        var buf: [48]u8 = undefined;
        const label = fmt.bufPrint(&buf, "POWER LEFT: {d}%", .{pct}) catch "";
        neko.sprite.text(label, x, y, .{ .size = 22, .color = col });

        neko.sprite.text("USAGE:", x, y + 30, .{ .size = 18, .color = config.WHITE });
        var i: i32 = 0;
        while (i < 5) : (i += 1) {
            const bx: i32 = x + 90 + i * 20;
            const on: bool = i < self.usage;
            const c: neko.Color = if (on) config.GREEN else neko.Color{ .r = 45, .g = 45, .b = 50 };
            neko.draw.rect(neko.Rect{ .x = bx, .y = y + 34, .w = 14, .h = 18 }, c, true);
            neko.draw.rect(neko.Rect{ .x = bx, .y = y + 34, .w = 14, .h = 18 }, neko.Color{ .r = 90, .g = 90, .b = 96 }, false);
        }
    }
};
