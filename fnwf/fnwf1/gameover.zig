// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Renan Lucas Vieira Hilário

//! FNWF 1 — the game-over newspaper.

const std: type = @import("std");
const fmt: type = std.fmt;
const neko: type = @import("neko");
const common: type = @import("common");

const screen: type = @import("screen.zig");
const config: type = @import("config.zig");

const Allocator: type = std.mem.Allocator;

/// Shown after a lost night.
pub const GameOver: type = struct {
    node: neko.scene.Node,
    night: i32,
    timer: f32 = 0,
    done: bool = false,
    result: []const u8 = "",

    pub fn create(allocator: Allocator, night: i32) !*neko.scene.Node {
        const self: *GameOver = try allocator.create(GameOver);
        self.* = GameOver{
            .node = neko.scene.Node{ .ptr = @ptrCast(self), .vtable = &vtable, .allocator = allocator, .name = "gameover" },
            .night = night,
        };
        screen.attach(self, &screen_vtable);
        common.sound.play("stinger", 0, -1);
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
    const self: *GameOver = @ptrCast(@alignCast(ptr));
    self.timer += dt;
    if (self.timer > 12.0) {
        self.done = true;
        self.result = "menu";
    }
}

fn input(ptr: *anyopaque, ev: neko.Event) void {
    const self: *GameOver = @ptrCast(@alignCast(ptr));
    if (self.timer < 1.6) return;
    switch (ev) {
        .key_down, .mouse_button_down => {
            self.done = true;
            self.result = "menu";
        },
        else => {},
    }
}

fn draw(ptr: *anyopaque, at: neko.Point) void {
    _ = at;
    const self: *GameOver = @ptrCast(@alignCast(ptr));
    neko.draw.clear(neko.Color{ .r = 10, .g = 10, .b = 14 });
    neko.effect.noise(0, 0, config.SCREEN_W, config.SCREEN_H, 0.05);

    const pw: i32 = 620;
    const ph: i32 = 460;
    const px: i32 = config.SCREEN_W / 2 - @divTrunc(pw, 2);
    const py: i32 = config.SCREEN_H / 2 - @divTrunc(ph, 2);
    neko.draw.rect(neko.Rect{ .x = px, .y = py, .w = pw, .h = ph }, neko.Color{ .r = 158, .g = 152, .b = 138 }, true);
    neko.draw.rect(neko.Rect{ .x = px, .y = py, .w = pw, .h = ph }, neko.Color{ .r = 30, .g = 30, .b = 30 }, false);

    neko.sprite.text("A GAZETA DOS TABACUDOS", px + 30, py + 24, .{ .size = 20, .color = neko.Color{ .r = 40, .g = 40, .b = 40 } });
    neko.draw.line(px + 20, py + 52, px + pw - 20, py + 52, neko.Color{ .r = 40, .g = 40, .b = 40 });
    neko.sprite.text("SEGURANÇA DESAPARECIDO", px + @divTrunc(pw, 2), py + 88, .{ .size = 34, .center = true, .color = neko.Color{ .r = 20, .g = 20, .b = 20 } });

    var nbuf: [32]u8 = undefined;
    const nl = fmt.bufPrint(&nbuf, "Turno da Noite {d}", .{self.night}) catch "";
    const body = [5][]const u8{
        "As autoridades investigam o desaparecimento",
        "de mais um vigia noturno da Pizzaria.",
        "O incidente ocorreu",
        nl,
        "A empresa não comentou o caso.",
    };
    for (body, 0..) |line, i| {
        neko.sprite.text(line, px + @divTrunc(pw, 2), py + 150 + @as(i32, @intCast(i)) * 26, .{ .size = 15, .center = true, .color = neko.Color{ .r = 45, .g = 45, .b = 45 } });
    }
    neko.sprite.text("Assinado: Cedro (Big Boss)", px + pw - 240, py + ph - 60, .{ .size = 18, .color = neko.Color{ .r = 35, .g = 35, .b = 35 } });
    neko.draw.line(px + pw - 250, py + ph - 66, px + pw - 40, py + ph - 66, neko.Color{ .r = 30, .g = 30, .b = 30 });

    if (self.timer > 2.0 and @mod(@as(i32, @intFromFloat(self.timer * 2)), 2) == 1) {
        neko.sprite.text("Pressione ENTER", config.SCREEN_W / 2, config.SCREEN_H - 50, .{ .size = 18, .center = true, .color = config.WHITE });
    }
}

fn is_done(ptr: *anyopaque) bool {
    const self: *GameOver = @ptrCast(@alignCast(ptr));
    return self.done;
}

fn result(ptr: *anyopaque) []const u8 {
    const self: *GameOver = @ptrCast(@alignCast(ptr));
    return self.result;
}

fn deinit(ptr: *anyopaque, allocator: Allocator) void {
    const self: *GameOver = @ptrCast(@alignCast(ptr));
    allocator.destroy(self);
}
