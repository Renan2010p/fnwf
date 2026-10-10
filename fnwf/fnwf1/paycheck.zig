// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Renan Lucas Vieira Hilário

//! FNWF 1 — the paycheck after Night 5.

const std: type = @import("std");
const neko: type = @import("neko");
const common: type = @import("common");

const screen: type = @import("screen.zig");
const config: type = @import("config.zig");

const Allocator: type = std.mem.Allocator;

/// End-of-contract cheque.
pub const Paycheck: type = struct {
    node: neko.scene.Node,
    timer: f32 = 0,
    done: bool = false,
    result: []const u8 = "",

    pub fn create(allocator: Allocator) !*neko.scene.Node {
        const self: *Paycheck = try allocator.create(Paycheck);
        self.* = Paycheck{
            .node = neko.scene.Node{ .ptr = @ptrCast(self), .vtable = &vtable, .allocator = allocator, .name = "paycheck" },
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
    const self: *Paycheck = @ptrCast(@alignCast(ptr));
    self.timer += dt;
}

fn input(ptr: *anyopaque, ev: neko.Event) void {
    const self: *Paycheck = @ptrCast(@alignCast(ptr));
    if (self.timer < 0.6) return;
    switch (ev) {
        .key_down, .mouse_button_down => {
            self.done = true;
            self.result = "next";
            common.sound.play("select", 0, -1);
        },
        else => {},
    }
}

fn draw(ptr: *anyopaque, at: neko.Point) void {
    _ = at;
    const self: *Paycheck = @ptrCast(@alignCast(ptr));
    neko.draw.clear(neko.Color{ .r = 20, .g = 20, .b = 24 });
    neko.effect.noise(0, 0, config.SCREEN_W, config.SCREEN_H, 0.01);

    const cw: i32 = 720;
    const ch: i32 = 340;
    const cx: i32 = config.SCREEN_W / 2 - @divTrunc(cw, 2);
    const cy: i32 = config.SCREEN_H / 2 - @divTrunc(ch, 2);
    neko.draw.rect(neko.Rect{ .x = cx, .y = cy, .w = cw, .h = ch }, neko.Color{ .r = 245, .g = 243, .b = 226 }, true);
    neko.draw.rect(neko.Rect{ .x = cx, .y = cy, .w = cw, .h = ch }, neko.Color{ .r = 40, .g = 40, .b = 40 }, false);

    neko.sprite.text("MÁFIA DOS TABACUDOS LTDA.", cx + 30, cy + 28, .{ .size = 22, .color = neko.Color{ .r = 35, .g = 35, .b = 45 } });
    neko.sprite.text("PAGAMENTO DE SERVIÇOS", cx + 30, cy + 62, .{ .size = 14, .color = neko.Color{ .r = 70, .g = 70, .b = 78 } });
    neko.sprite.text("R$ 1.621,00", cx + cw - 220, cy + 34, .{ .size = 30, .color = neko.Color{ .r = 20, .g = 20, .b = 20 } });

    neko.sprite.text("PAGUE-SE A:", cx + 30, cy + 128, .{ .size = 15, .color = neko.Color{ .r = 70, .g = 70, .b = 78 } });
    neko.sprite.text("Renan Lucas", cx + 50, cy + 154, .{ .size = 36, .color = neko.Color{ .r = 20, .g = 20, .b = 30 } });
    neko.draw.line(cx + 50, cy + 200, cx + cw - 50, cy + 200, neko.Color{ .r = 100, .g = 100, .b = 110 });

    neko.sprite.text("DATA: 15/02/2026", cx + 30, cy + 244, .{ .size = 15, .color = neko.Color{ .r = 70, .g = 70, .b = 78 } });
    neko.sprite.text("Assinado: Cedro (Big Boss)", cx + cw - 300, cy + 244, .{ .size = 16, .color = neko.Color{ .r = 30, .g = 30, .b = 40 } });
    neko.draw.line(cx + cw - 310, cy + 240, cx + cw - 40, cy + 240, neko.Color{ .r = 0, .g = 0, .b = 0 });

    neko.sprite.text("Você sobreviveu às 5 noites. Mas o Cedro ligou de novo...", config.SCREEN_W / 2, cy + ch + 40, .{ .size = 18, .center = true, .color = config.WHITE });
    if (@mod(@as(i32, @intFromFloat(self.timer * 2)), 2) == 1) {
        neko.sprite.text("Pressione ENTER", config.SCREEN_W / 2, config.SCREEN_H - 50, .{ .size = 16, .center = true, .color = config.MUTED });
    }
}

fn is_done(ptr: *anyopaque) bool {
    const self: *Paycheck = @ptrCast(@alignCast(ptr));
    return self.done;
}

fn result(ptr: *anyopaque) []const u8 {
    const self: *Paycheck = @ptrCast(@alignCast(ptr));
    return self.result;
}

fn deinit(ptr: *anyopaque, allocator: Allocator) void {
    const self: *Paycheck = @ptrCast(@alignCast(ptr));
    allocator.destroy(self);
}
