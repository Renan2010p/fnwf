// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Renan Lucas Vieira Hilário

//! The paycheck — port of `game1/states/PaycheckState`.
//!
//! Shown after surviving Night 5. A paper cheque fades in; any key continues
//! and it fades out.

const std: type = @import("std");
const fmt: type = std.fmt;
const neko: type = @import("neko");
const common: type = @import("common");

const screen: type = @import("../screen.zig");
const constants: type = @import("../config/constants.zig");

const Allocator: type = std.mem.Allocator;

/// The end-of-contract cheque.
pub const Paycheck: type = struct {
    node: neko.scene.Node,

    timer: f32 = 0,
    done: bool = false,
    fade_alpha: i32 = 255,
    fading_in: bool = true,
    fading_out: bool = false,

    name: []const u8 = "Renan Lucas",
    amount: []const u8 = "1.621,00",
    date: []const u8 = "15/02/2026",

    pub fn create(allocator: Allocator) !*neko.scene.Node {
        const self: *Paycheck = try allocator.create(Paycheck);
        self.* = Paycheck{
            .node = neko.scene.Node{
                .ptr = @ptrCast(self),
                .vtable = &vtable,
                .allocator = allocator,
                .name = "paycheck",
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
    const self: *Paycheck = @ptrCast(@alignCast(ptr));
    const w: i32 = constants.SCREEN_WIDTH;
    const h: i32 = constants.SCREEN_HEIGHT;

    neko.draw.clear(neko.Color{ .r = 20, .g = 20, .b = 25 });
    neko.effect.noise(0, 0, w, h, 0.01);

    const cw: i32 = 700;
    const ch: i32 = 350;
    const cx: i32 = @divTrunc(w - cw, 2);
    const cy: i32 = @divTrunc(h - ch, 2);

    neko.draw.rect(neko.Rect{ .x = cx, .y = cy, .w = cw, .h = ch }, neko.Color{ .r = 245, .g = 245, .b = 230 }, true);
    neko.draw.rect(neko.Rect{ .x = cx, .y = cy, .w = cw, .h = ch }, neko.Color{ .r = 50, .g = 50, .b = 50 }, false);

    neko.sprite.text(neko.localization.text("company_name"), cx + 30, cy + 30, .{ .size = 24, .color = .{ .r = 40, .g = 40, .b = 50 } });
    neko.sprite.text(neko.localization.text("pay_services"), cx + 30, cy + 65, .{ .size = 14, .color = .{ .r = 60, .g = 60, .b = 70 } });

    neko.draw.rect(neko.Rect{ .x = cx + cw - 220, .y = cy + 30, .w = 190, .h = 40 }, neko.Color{ .r = 255, .g = 255, .b = 255 }, true);
    neko.draw.rect(neko.Rect{ .x = cx + cw - 220, .y = cy + 30, .w = 190, .h = 40 }, neko.Color{ .r = 0, .g = 0, .b = 0 }, false);

    var amount_buf: [64]u8 = undefined;
    const amount = fmt.bufPrint(&amount_buf, "{s} {s}", .{ neko.localization.text("currency_br"), self.amount }) catch "";
    neko.sprite.text(amount, cx + cw - 210, cy + 38, .{ .size = 22, .color = .{ .r = 0, .g = 0, .b = 0 } });

    neko.sprite.text(neko.localization.text("pay_to"), cx + 30, cy + 130, .{ .size = 16, .color = .{ .r = 60, .g = 60, .b = 70 } });
    neko.sprite.text(self.name, cx + 50, cy + 160, .{ .size = 38, .color = .{ .r = 20, .g = 20, .b = 30 } });
    neko.draw.line(cx + 50, cy + 205, cx + cw - 50, cy + 205, neko.Color{ .r = 100, .g = 100, .b = 110 });

    var date_buf: [64]u8 = undefined;
    const date = fmt.bufPrint(&date_buf, "{s} {s}", .{ neko.localization.text("pay_date"), self.date }) catch "";
    neko.sprite.text(date, cx + 30, cy + 250, .{ .size = 16, .color = .{ .r = 60, .g = 60, .b = 70 } });
    neko.sprite.text(neko.localization.text("pay_signed"), cx + cw - 250, cy + 250, .{ .size = 14, .color = .{ .r = 60, .g = 60, .b = 70 } });
    neko.sprite.text("Cedro (Big Boss)", cx + cw - 250, cy + 280, .{ .size = 22, .color = .{ .r = 30, .g = 30, .b = 40 } });
    neko.draw.line(cx + cw - 260, cy + 275, cx + cw - 30, cy + 275, neko.Color{ .r = 0, .g = 0, .b = 0 });

    neko.sprite.text(neko.localization.text("pay_congrats_5"), @divTrunc(w, 2), cy + ch + 50, .{
        .size = 20,
        .center = true,
        .color = neko.Color{ .r = 255, .g = 255, .b = 255 },
    });
    neko.sprite.text(neko.localization.text("click_continue"), @divTrunc(w, 2), h - 40, .{
        .size = 14,
        .center = true,
        .color = neko.Color{ .r = 180, .g = 180, .b = 180 },
    });

    if (self.fade_alpha > 0) {
        neko.draw.rect(neko.Rect{ .x = 0, .y = 0, .w = w, .h = h }, neko.Color{ .r = 0, .g = 0, .b = 0, .a = @intCast(self.fade_alpha) }, true);
    }
}

fn process(ptr: *anyopaque, dt: f32) void {
    const self: *Paycheck = @ptrCast(@alignCast(ptr));
    self.timer += dt;

    if (self.fading_in) {
        self.fade_alpha = @max(0, self.fade_alpha - @as(i32, @intFromFloat(150.0 * dt)));
        if (self.fade_alpha <= 0) self.fading_in = false;
    }
    if (self.fading_out) {
        self.fade_alpha = @min(255, self.fade_alpha + @as(i32, @intFromFloat(150.0 * dt)));
        if (self.fade_alpha >= 255) self.done = true;
    }
}

fn input(ptr: *anyopaque, ev: neko.Event) void {
    const self: *Paycheck = @ptrCast(@alignCast(ptr));
    if (self.fading_in or self.fading_out) return;
    switch (ev) {
        .key_down, .mouse_button_down => {
            self.fading_out = true;
            common.sound.play("select", 0, -1);
        },
        else => {},
    }
}

fn is_done(ptr: *anyopaque) bool {
    const self: *Paycheck = @ptrCast(@alignCast(ptr));
    return self.done;
}

fn deinit(ptr: *anyopaque, allocator: Allocator) void {
    const self: *Paycheck = @ptrCast(@alignCast(ptr));
    allocator.destroy(self);
}
