// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Renan Lucas Vieira Hilário

//! The loading screen — port of `game1/states/LoadingState`.
//!
//! Decodes a short list of sprites one per frame (so the progress bar moves),
//! shows a random tip and a spinning loader, then finishes. `result` names the
//! state the main loop should enter next.

const std: type = @import("std");
const fmt: type = std.fmt;
const neko: type = @import("neko");

const screen: type = @import("../screen.zig");
const constants: type = @import("../config/constants.zig");

const Allocator: type = std.mem.Allocator;

/// Shown while assets are decoded.
pub const Loading: type = struct {
    node: neko.scene.Node,
    preload: []const []const u8,
    next: []const u8,

    loaded: usize = 0,
    timer: f32 = 0,
    duration: f32 = 0.6,
    loader_angle: f32 = 0,
    font_alpha: i32 = 0,
    done: bool = false,

    tip_buf: [16]u8 = undefined,
    tip: []const u8 = "tip_1",

    /// `preload` must outlive the state (main passes a static list); `next` is
    /// the state name returned once loading finishes.
    pub fn create(allocator: Allocator, preload: []const []const u8, next: []const u8) !*neko.scene.Node {
        const self: *Loading = try allocator.create(Loading);
        self.* = Loading{
            .node = neko.scene.Node{
                .ptr = @ptrCast(self),
                .vtable = &vtable,
                .allocator = allocator,
                .name = "loading",
            },
            .preload = preload,
            .next = next,
        };
        self.tip = fmt.bufPrint(&self.tip_buf, "tip_{d}", .{neko.random.int_range(1, 12)}) catch "tip_1";
        screen.attach(self, &screen_vtable);
        return &self.node;
    }
};

const vtable: neko.scene.Node.VTable = neko.scene.Node.VTable{
    .ready = neko.scene.no_ready,
    .process = process,
    .draw = draw,
    .input = neko.scene.no_input,
    .deinit = deinit,
};

const screen_vtable: screen.VTable = .{ .is_done = is_done, .result = result };

fn draw(ptr: *anyopaque, at: neko.Point) void {
    _ = at;
    const self: *Loading = @ptrCast(@alignCast(ptr));
    const w: i32 = constants.SCREEN_WIDTH;
    const h: i32 = constants.SCREEN_HEIGHT;

    neko.draw.clear(neko.Color{ .r = 3, .g = 3, .b = 5 });
    neko.effect.noise(0, 0, w, h, 0.012);

    const ox: i32 = if (neko.random.probability(0.05)) neko.random.int_range(-4, 4) else 0;
    neko.sprite.text(neko.localization.text(self.tip), @divTrunc(w, 2) + ox, @divTrunc(h, 2), neko.sprite.Options{
        .size = 18,
        .center = true,
        .color = neko.Color{ .r = 160, .g = 160, .b = 170, .a = @intCast(self.font_alpha) },
    });

    // Spinning loader, bottom right.
    const lx: i32 = w - 80;
    const ly: i32 = h - 80;
    const radius: i32 = 20;
    var i: i32 = 0;
    while (i < 8) : (i += 1) {
        const angle: f32 = @mod(self.loader_angle, 360.0) * 3.14159 / 180.0 + @as(f32, @floatFromInt(i)) * 45.0 * 3.14159 / 180.0;
        const ex: i32 = lx + @as(i32, @intFromFloat(@cos(angle) * @as(f32, @floatFromInt(radius))));
        const ey: i32 = ly + @as(i32, @intFromFloat(@sin(angle) * @as(f32, @floatFromInt(radius))));
        neko.draw.line(lx, ly, ex, ey, neko.Color{ .r = 120, .g = 120, .b = 130 });
    }
    neko.draw.circle(lx, ly, radius - 6, neko.Color{ .r = 0, .g = 0, .b = 0 }, true);
    neko.draw.circle(lx, ly, radius - 10, neko.Color{ .r = 150, .g = 150, .b = 160 }, false);

    neko.sprite.text(neko.localization.text("loading"), lx, ly + 35, neko.sprite.Options{
        .size = 14,
        .center = true,
        .color = neko.Color{ .r = 100, .g = 100, .b = 110 },
    });

    // Progress bar.
    if (self.preload.len > 0) {
        const bw: i32 = 420;
        const bh: i32 = 10;
        const bx: i32 = @divTrunc(w, 2) - @divTrunc(bw, 2);
        const by: i32 = h - 60;
        const filled: i32 = @divTrunc((bw - 4) * @as(i32, @intCast(self.loaded)), @as(i32, @intCast(self.preload.len)));

        neko.draw.rect(neko.Rect{ .x = bx, .y = by, .w = bw, .h = bh }, neko.Color{ .r = 30, .g = 30, .b = 36, .a = 220 }, true);
        neko.draw.rect(neko.Rect{ .x = bx + 2, .y = by + 2, .w = filled, .h = bh - 4 }, neko.Color{ .r = 150, .g = 150, .b = 160 }, true);
        neko.draw.rect(neko.Rect{ .x = bx, .y = by, .w = bw, .h = bh }, neko.Color{ .r = 90, .g = 90, .b = 100 }, false);

        if (self.loaded < self.preload.len) {
            neko.sprite.text(self.preload[self.loaded], @divTrunc(w, 2), by - 16, neko.sprite.Options{
                .size = 12,
                .center = true,
                .color = neko.Color{ .r = 120, .g = 120, .b = 130, .a = @intCast(@min(255, self.font_alpha)) },
            });
        }
    }
}

fn process(ptr: *anyopaque, dt: f32) void {
    const self: *Loading = @ptrCast(@alignCast(ptr));
    self.timer += dt;
    self.loader_angle += 360.0 * dt;

    if (self.timer < 0.4) {
        self.font_alpha = @intFromFloat((self.timer / 0.4) * 255.0);
    } else {
        self.font_alpha = 255;
    }

    // Real work: decode one queued sprite per frame so the bar advances.
    if (self.loaded < self.preload.len) {
        neko.sprite.load(self.preload[self.loaded]);
        self.loaded += 1;
    }

    const all_loaded: bool = (self.loaded >= self.preload.len) or self.timer >= 8.0;
    if (all_loaded and self.timer >= self.duration) self.done = true;
}

fn is_done(ptr: *anyopaque) bool {
    const self: *Loading = @ptrCast(@alignCast(ptr));
    return self.done;
}

fn result(ptr: *anyopaque) []const u8 {
    const self: *Loading = @ptrCast(@alignCast(ptr));
    return self.next;
}

fn deinit(ptr: *anyopaque, allocator: Allocator) void {
    const self: *Loading = @ptrCast(@alignCast(ptr));
    allocator.destroy(self);
}
