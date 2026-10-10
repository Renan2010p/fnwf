// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Renan Lucas Vieira Hilário

//! FNWF 1 — extras: the cast and credits.

const std: type = @import("std");
const neko: type = @import("neko");
const common: type = @import("common");

const screen: type = @import("screen.zig");
const config: type = @import("config.zig");
const world: type = @import("world.zig");

const Allocator: type = std.mem.Allocator;

const INFO: [4]struct { id: world.CharId, role: []const u8, desc: []const u8 } = .{
    .{ .id = .eser, .role = "O braço direito", .desc = "Vigia a ala oeste. Ataque pela porta esquerda." },
    .{ .id = .alice, .role = "A especialista", .desc = "Vem pela ala leste e pela cozinha. Porta direita." },
    .{ .id = .sonk, .role = "O da Pirate Cove", .desc = "Não gosta de ser observado. Corre pelo corredor." },
    .{ .id = .cedro, .role = "O Big Boss", .desc = "Quase não sai do palco. Fica mais ativo no escuro." },
};

/// The extras screen.
pub const Extras: type = struct {
    node: neko.scene.Node,
    timer: f32 = 0,
    done: bool = false,
    result: []const u8 = "",

    pub fn create(allocator: Allocator) !*neko.scene.Node {
        const self: *Extras = try allocator.create(Extras);
        self.* = Extras{
            .node = neko.scene.Node{ .ptr = @ptrCast(self), .vtable = &vtable, .allocator = allocator, .name = "extras" },
        };
        screen.attach(self, &screen_vtable);
        for (INFO) |it| neko.sprite.load(it.id.sprite());
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
    const self: *Extras = @ptrCast(@alignCast(ptr));
    self.timer += dt;
}

fn input(ptr: *anyopaque, ev: neko.Event) void {
    const self: *Extras = @ptrCast(@alignCast(ptr));
    switch (ev) {
        .key_down => |k| {
            if (k.code == 27 or k.code == 13 or k.code == 32) {
                self.done = true;
                self.result = "back";
                common.sound.play("select", 0, -1);
            }
        },
        .mouse_button_down => {
            self.done = true;
            self.result = "back";
            common.sound.play("select", 0, -1);
        },
        else => {},
    }
}

fn draw(ptr: *anyopaque, at: neko.Point) void {
    _ = at;
    const self: *Extras = @ptrCast(@alignCast(ptr));
    _ = self;
    neko.draw.clear(neko.Color{ .r = 8, .g = 8, .b = 12 });
    neko.effect.noise(0, 0, config.SCREEN_W, config.SCREEN_H, 0.008);
    neko.sprite.text("EXTRAS", config.SCREEN_W / 2, 50, .{ .size = 40, .center = true, .color = config.ACCENT });

    for (INFO, 0..) |it, i| {
        const x: i32 = 120 + @as(i32, @intCast(i)) * 270;
        neko.draw.rect(neko.Rect{ .x = x, .y = 150, .w = 240, .h = 400 }, config.PANEL, true);
        neko.draw.rect(neko.Rect{ .x = x, .y = 150, .w = 240, .h = 400 }, config.LINE, false);
        neko.sprite.face(it.id.sprite(), x + 30, 170, 180, 220);
        neko.sprite.text(it.id.name(), x + 120, 400, .{ .size = 28, .center = true, .color = config.WHITE });
        neko.sprite.text(it.role, x + 120, 432, .{ .size = 14, .center = true, .color = config.ACCENT });
        neko.sprite.text(it.desc, x + 20, 462, .{ .size = 13, .color = config.MUTED });
    }

    neko.sprite.text("Criado por Renan Lucas Vieira Hilário", config.SCREEN_W / 2, config.SCREEN_H - 90, .{ .size = 18, .center = true, .color = config.MUTED });
    neko.sprite.text("FIVE NIGHTS WITH FRIENDS 1", config.SCREEN_W / 2, config.SCREEN_H - 56, .{ .size = 20, .center = true, .color = config.WHITE });
}

fn is_done(ptr: *anyopaque) bool {
    const self: *Extras = @ptrCast(@alignCast(ptr));
    return self.done;
}

fn result(ptr: *anyopaque) []const u8 {
    const self: *Extras = @ptrCast(@alignCast(ptr));
    return self.result;
}

fn deinit(ptr: *anyopaque, allocator: Allocator) void {
    const self: *Extras = @ptrCast(@alignCast(ptr));
    allocator.destroy(self);
}
