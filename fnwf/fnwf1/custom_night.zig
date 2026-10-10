// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Renan Lucas Vieira Hilário

//! FNWF 1 — the custom night (set each animatronic's AI 0-20).

const std: type = @import("std");
const fmt: type = std.fmt;
const neko: type = @import("neko");
const common: type = @import("common");

const screen: type = @import("screen.zig");
const config: type = @import("config.zig");
const world: type = @import("world.zig");

const Allocator: type = std.mem.Allocator;

/// The custom night configuration screen.
pub const CustomNight: type = struct {
    node: neko.scene.Node,
    levels: [4]i32 = .{ 0, 0, 0, 0 },
    selected: i32 = 0,
    done: bool = false,
    result: []const u8 = "",
    timer: f32 = 0,

    pub fn create(allocator: Allocator) !*neko.scene.Node {
        const self: *CustomNight = try allocator.create(CustomNight);
        self.* = CustomNight{
            .node = neko.scene.Node{ .ptr = @ptrCast(self), .vtable = &vtable, .allocator = allocator, .name = "custom_night" },
        };
        screen.attach(self, &screen_vtable);
        neko.sprite.load("eser");
        neko.sprite.load("alice");
        neko.sprite.load("Sonk");
        neko.sprite.load("cedro");
        return &self.node;
    }

    pub fn from_node(n: *neko.scene.Node) *CustomNight {
        return @ptrCast(@alignCast(n));
    }

    pub fn ai(self: *const CustomNight) [4]i32 {
        return self.levels;
    }

    fn adjust(self: *CustomNight, dir: i32) void {
        const i: usize = @intCast(self.selected);
        self.levels[i] = @max(0, @min(20, self.levels[i] + dir));
        common.sound.play("blip", 0, -1);
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
    const self: *CustomNight = @ptrCast(@alignCast(ptr));
    self.timer += dt;
}

fn input(ptr: *anyopaque, ev: neko.Event) void {
    const self: *CustomNight = @ptrCast(@alignCast(ptr));
    switch (ev) {
        .key_down => |k| {
            const code = k.code;
            if (code == 1073741906 or code == 'w') {
                self.selected = @mod(self.selected - 1 + 4, 4);
                common.sound.play("blip", 0, -1);
            } else if (code == 1073741905 or code == 's') {
                self.selected = @mod(self.selected + 1, 4);
                common.sound.play("blip", 0, -1);
            } else if (code == 1073741903 or code == 'd') {
                self.adjust(1);
            } else if (code == 1073741904 or code == 'a') {
                self.adjust(-1);
            } else if (code == 13 or code == 32) {
                self.done = true;
                self.result = "start";
                common.sound.play("select", 0, -1);
            } else if (code == 27) {
                self.done = true;
                self.result = "back";
            }
        },
        .mouse_button_down => |m| {
            var i: i32 = 0;
            while (i < 4) : (i += 1) {
                const y: i32 = 200 + i * 90;
                if (m.y >= y - 10 and m.y <= y + 70) {
                    self.selected = i;
                    if (m.x > config.SCREEN_W / 2 + 40) {
                        self.adjust(1);
                    } else if (m.x < config.SCREEN_W / 2 - 40) {
                        self.adjust(-1);
                    }
                }
            }
        },
        else => {},
    }
}

fn draw(ptr: *anyopaque, at: neko.Point) void {
    _ = at;
    const self: *CustomNight = @ptrCast(@alignCast(ptr));
    neko.draw.clear(neko.Color{ .r = 10, .g = 9, .b = 14 });

    neko.sprite.text("NOITE CUSTOM", config.SCREEN_W / 2, 70, .{ .size = 46, .center = true, .color = config.ACCENT });
    neko.sprite.text("Ajuste a IA de cada um (0 a 20)", config.SCREEN_W / 2, 120, .{ .size = 16, .center = true, .color = config.MUTED });

    const ids = [4]world.CharId{ .eser, .alice, .sonk, .cedro };
    for (ids, 0..) |id, i| {
        const y: i32 = 200 + @as(i32, @intCast(i)) * 90;
        const sel: bool = @as(i32, @intCast(i)) == self.selected;
        if (sel) {
            neko.draw.rect(neko.Rect{ .x = 160, .y = y - 14, .w = config.SCREEN_W - 320, .h = 82 }, neko.Color{ .r = 26, .g = 24, .b = 34 }, true);
        }
        neko.sprite.face(id.sprite(), 190, y - 12, 80, 80);
        neko.sprite.text(id.name(), 300, y + 18, .{ .size = 30, .color = if (sel) config.WHITE else config.MUTED });

        var buf: [8]u8 = undefined;
        neko.sprite.text(fmt.bufPrint(&buf, "{d}", .{self.levels[i]}) catch "", config.SCREEN_W / 2 + 40, y + 8, .{ .size = 40, .center = true, .color = config.ACCENT });
        neko.sprite.text("<", config.SCREEN_W / 2 - 30, y + 16, .{ .size = 34, .center = true, .color = config.MUTED });
        neko.sprite.text(">", config.SCREEN_W / 2 + 110, y + 16, .{ .size = 34, .center = true, .color = config.MUTED });
    }

    if (@mod(@as(i32, @intFromFloat(self.timer * 2)), 2) == 1) {
        neko.sprite.text("W/S escolhe   A/D ajusta   ENTER começa   ESC volta", config.SCREEN_W / 2, config.SCREEN_H - 54, .{ .size = 16, .center = true, .color = config.MUTED });
    }
}

fn is_done(ptr: *anyopaque) bool {
    const self: *CustomNight = @ptrCast(@alignCast(ptr));
    return self.done;
}

fn result(ptr: *anyopaque) []const u8 {
    const self: *CustomNight = @ptrCast(@alignCast(ptr));
    return self.result;
}

fn deinit(ptr: *anyopaque, allocator: Allocator) void {
    const self: *CustomNight = @ptrCast(@alignCast(ptr));
    allocator.destroy(self);
}
