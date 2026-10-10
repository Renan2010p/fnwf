// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Renan Lucas Vieira Hilário

//! FNWF 1 — the main menu.

const std: type = @import("std");
const fmt: type = std.fmt;
const neko: type = @import("neko");
const common: type = @import("common");

const screen: type = @import("screen.zig");
const config: type = @import("config.zig");

const Allocator: type = std.mem.Allocator;
const MAX_OPTIONS: usize = 8;

const Option: type = struct { label: []const u8, action: []const u8 };

/// The title menu.
pub const Menu: type = struct {
    node: neko.scene.Node,
    allocator: Allocator,
    completed: i32,

    options: [MAX_OPTIONS]Option = undefined,
    count: usize = 0,
    selected: i32 = 0,
    done: bool = false,
    result: []const u8 = "",
    timer: f32 = 0,
    sprite: []const u8 = "cedro",
    cont_buf: [48]u8 = undefined,

    pub fn create(allocator: Allocator, completed: i32) !*neko.scene.Node {
        const self: *Menu = try allocator.create(Menu);
        self.* = Menu{
            .node = neko.scene.Node{ .ptr = @ptrCast(self), .vtable = &vtable, .allocator = allocator, .name = "menu" },
            .allocator = allocator,
            .completed = completed,
        };
        screen.attach(self, &screen_vtable);
        neko.sprite.load("eser");
        neko.sprite.load("alice");
        neko.sprite.load("Sonk");
        neko.sprite.load("cedro");
        const sprites = [4][]const u8{ "cedro", "eser", "alice", "Sonk" };
        self.sprite = sprites[@intCast(@mod(neko.random.int_range(0, 3), 4))];
        self.build();
        common.sound.play_menu_ambient();
        return &self.node;
    }

    fn add(self: *Menu, label: []const u8, action: []const u8) void {
        if (self.count >= MAX_OPTIONS) return;
        self.options[self.count] = .{ .label = label, .action = action };
        self.count += 1;
    }

    fn build(self: *Menu) void {
        self.count = 0;
        self.add("Nova Noite 1", "start1");
        if (self.completed >= 1 and self.completed < 6) {
            const next: i32 = @min(self.completed + 1, 6);
            const s = fmt.bufPrint(&self.cont_buf, "Continuar (Noite {d})", .{next}) catch "Continuar";
            self.add(s, "continue");
        }
        if (self.completed >= 5) {
            self.add("Noite 6 (Extra)", "night6");
            self.add("Noite Custom", "custom");
        }
        self.add("Extras", "extras");
        self.add("Opções", "options");
        self.add("Sair", "quit");
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
    const self: *Menu = @ptrCast(@alignCast(ptr));
    self.timer += dt;
}

fn input(ptr: *anyopaque, ev: neko.Event) void {
    const self: *Menu = @ptrCast(@alignCast(ptr));
    switch (ev) {
        .key_down => |k| {
            const code = k.code;
            if (code == 1073741906 or code == 'w') {
                self.selected = @mod(self.selected - 1 + @as(i32, @intCast(self.count)), @as(i32, @intCast(self.count)));
                common.sound.play("blip", 0, -1);
            } else if (code == 1073741905 or code == 's') {
                self.selected = @mod(self.selected + 1, @as(i32, @intCast(self.count)));
                common.sound.play("blip", 0, -1);
            } else if (code == 13 or code == 32) {
                self.result = self.options[@intCast(self.selected)].action;
                self.done = true;
                common.sound.play("select", 0, -1);
            } else if (code == 27) {
                self.result = "quit";
                self.done = true;
            }
        },
        .mouse_button_down => |m| {
            var i: usize = 0;
            while (i < self.count) : (i += 1) {
                const y: i32 = 300 + @as(i32, @intCast(i)) * 56;
                if (m.y >= y - 10 and m.y <= y + 40 and m.x >= 60 and m.x <= 560) {
                    self.selected = @intCast(i);
                    self.result = self.options[i].action;
                    self.done = true;
                    common.sound.play("select", 0, -1);
                }
            }
        },
        else => {},
    }
}

fn draw(ptr: *anyopaque, at: neko.Point) void {
    _ = at;
    const self: *Menu = @ptrCast(@alignCast(ptr));
    neko.draw.clear(neko.Color{ .r = 5, .g = 5, .b = 8 });
    neko.effect.noise(0, 0, config.SCREEN_W, config.SCREEN_H, 0.01);

    const bounce: i32 = @intFromFloat(6.0 * @sin(self.timer * 1.2));
    neko.sprite.face(self.sprite, config.SCREEN_W - 620, 60 + bounce, 560, 560);

    neko.sprite.text("FIVE NIGHTS", 70, 90, .{ .size = 54, .color = config.WHITE });
    neko.sprite.text("WITH FRIENDS", 70, 150, .{ .size = 54, .color = config.WHITE });
    neko.sprite.text("1", 470, 150, .{ .size = 54, .color = config.ACCENT });
    neko.sprite.text("EDIÇÃO DEFINITIVA", 72, 212, .{ .size = 16, .color = config.MUTED });
    neko.sprite.text("v" ++ common.VERSION ++ "   Neko: v" ++ common.NEKO_VERSION, 72, 238, .{ .size = 14, .color = neko.Color{ .r = 120, .g = 140, .b = 170 } });

    var i: usize = 0;
    while (i < self.count) : (i += 1) {
        const y: i32 = 300 + @as(i32, @intCast(i)) * 56;
        const sel: bool = @as(i32, @intCast(i)) == self.selected;
        if (sel) {
            neko.draw.rect(neko.Rect{ .x = 60, .y = y - 10, .w = 6, .h = 44 }, config.ACCENT, true);
        }
        neko.sprite.text(self.options[i].label, 84, y, .{ .size = 26, .color = if (sel) config.WHITE else config.MUTED });
    }

    neko.sprite.text("W/S seleciona   ENTER confirma", 70, config.SCREEN_H - 44, .{ .size = 14, .color = neko.Color{ .r = 110, .g = 110, .b = 118 } });
}

fn is_done(ptr: *anyopaque) bool {
    const self: *Menu = @ptrCast(@alignCast(ptr));
    return self.done;
}

fn result(ptr: *anyopaque) []const u8 {
    const self: *Menu = @ptrCast(@alignCast(ptr));
    return self.result;
}

fn deinit(ptr: *anyopaque, allocator: Allocator) void {
    const self: *Menu = @ptrCast(@alignCast(ptr));
    allocator.destroy(self);
}
