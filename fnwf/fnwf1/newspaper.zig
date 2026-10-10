// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Renan Lucas Vieira Hilário

//! FNWF 1 — the victory newspaper.

const std: type = @import("std");
const neko: type = @import("neko");
const common: type = @import("common");

const screen: type = @import("screen.zig");
const config: type = @import("config.zig");

const Allocator: type = std.mem.Allocator;

/// Shown after the contract ends.
pub const Newspaper: type = struct {
    node: neko.scene.Node,
    timer: f32 = 0,
    done: bool = false,
    result: []const u8 = "",

    pub fn create(allocator: Allocator) !*neko.scene.Node {
        const self: *Newspaper = try allocator.create(Newspaper);
        self.* = Newspaper{
            .node = neko.scene.Node{ .ptr = @ptrCast(self), .vtable = &vtable, .allocator = allocator, .name = "newspaper" },
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
    const self: *Newspaper = @ptrCast(@alignCast(ptr));
    self.timer += dt;
}

fn input(ptr: *anyopaque, ev: neko.Event) void {
    const self: *Newspaper = @ptrCast(@alignCast(ptr));
    if (self.timer < 1.0) return;
    switch (ev) {
        .key_down, .mouse_button_down => {
            self.done = true;
            self.result = "menu";
            common.sound.play("select", 0, -1);
        },
        else => {},
    }
}

fn draw(ptr: *anyopaque, at: neko.Point) void {
    _ = at;
    const self: *Newspaper = @ptrCast(@alignCast(ptr));
    neko.draw.clear(neko.Color{ .r = 12, .g = 12, .b = 16 });
    neko.effect.noise(0, 0, config.SCREEN_W, config.SCREEN_H, 0.012);

    const pw: i32 = 640;
    const ph: i32 = 470;
    const px: i32 = config.SCREEN_W / 2 - @divTrunc(pw, 2);
    const py: i32 = config.SCREEN_H / 2 - @divTrunc(ph, 2);
    neko.draw.rect(neko.Rect{ .x = px, .y = py, .w = pw, .h = ph }, neko.Color{ .r = 158, .g = 152, .b = 138 }, true);
    neko.draw.rect(neko.Rect{ .x = px, .y = py, .w = pw, .h = ph }, neko.Color{ .r = 30, .g = 30, .b = 30 }, false);

    neko.sprite.text("A GAZETA DOS TABACUDOS", px + 30, py + 22, .{ .size = 20, .color = neko.Color{ .r = 40, .g = 40, .b = 40 } });
    neko.draw.line(px + 20, py + 50, px + pw - 20, py + 50, neko.Color{ .r = 40, .g = 40, .b = 40 });
    neko.sprite.text("PIZZARIA FECHADA!", px + @divTrunc(pw, 2), py + 84, .{ .size = 34, .center = true, .color = neko.Color{ .r = 20, .g = 20, .b = 20 } });
    neko.sprite.text("ESQUEMA DA MÁFIA REVELADO", px + @divTrunc(pw, 2), py + 124, .{ .size = 18, .center = true, .color = neko.Color{ .r = 60, .g = 60, .b = 60 } });

    const body = [8][]const u8{
        "O vigia Renan Lucas entregou às autoridades",
        "os registros do Discord da Pizzaria dos Tabacudos,",
        "comprovando que o local servia de fachada",
        "para a Máfia Brasileira dos Tabacudos.",
        "",
        "O 'Big Boss' Cedro e seus comparsas fugiram",
        "antes da chegada da polícia.",
        "Renan Lucas recebeu o título de herói local.",
    };
    for (body, 0..) |line, i| {
        neko.sprite.text(line, px + @divTrunc(pw, 2), py + 168 + @as(i32, @intCast(i)) * 24, .{ .size = 15, .center = true, .color = neko.Color{ .r = 35, .g = 35, .b = 35 } });
    }

    if (@mod(@as(i32, @intFromFloat(self.timer * 2)), 2) == 1) {
        neko.sprite.text("Pressione ENTER", config.SCREEN_W / 2, config.SCREEN_H - 50, .{ .size = 16, .center = true, .color = config.WHITE });
    }
}

fn is_done(ptr: *anyopaque) bool {
    const self: *Newspaper = @ptrCast(@alignCast(ptr));
    return self.done;
}

fn result(ptr: *anyopaque) []const u8 {
    const self: *Newspaper = @ptrCast(@alignCast(ptr));
    return self.result;
}

fn deinit(ptr: *anyopaque, allocator: Allocator) void {
    const self: *Newspaper = @ptrCast(@alignCast(ptr));
    allocator.destroy(self);
}
