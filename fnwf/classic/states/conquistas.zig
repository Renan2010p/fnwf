// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Renan Lucas Vieira Hilário

//! The achievements screen — port of `game1/states/ConquistasState`.
//!
//! Lists the four achievements and whether each has been unlocked. Any of
//! ESC, ENTER, SPACE or a click goes back to the menu.

const std: type = @import("std");
const mem: type = std.mem;
const neko: type = @import("neko");
const common: type = @import("common");

const screen: type = @import("../screen.zig");
const constants: type = @import("../config/constants.zig");
const colors: type = @import("../config/colors.zig");

const Allocator: type = std.mem.Allocator;

const MAX_ACHIEVEMENTS: usize = 4;

const AchData: type = struct {
    id: []const u8,
    name: []const u8,
    desc: []const u8,
};

/// The achievements list screen.
pub const Conquistas: type = struct {
    node: neko.scene.Node,
    unlocked: []const []u8,

    list: [MAX_ACHIEVEMENTS]AchData = undefined,
    timer: f32 = 0,
    done: bool = false,

    pub fn create(allocator: Allocator, unlocked: []const []u8) !*neko.scene.Node {
        const self: *Conquistas = try allocator.create(Conquistas);
        self.* = Conquistas{
            .node = neko.scene.Node{
                .ptr = @ptrCast(self),
                .vtable = &vtable,
                .allocator = allocator,
                .name = "conquistas",
            },
            .unlocked = unlocked,
        };
        self.list[0] = .{ .id = "survive_n1", .name = neko.localization.text("night_1_ach_title"), .desc = neko.localization.text("night_1_ach_desc") };
        self.list[1] = .{ .id = "survive_n5", .name = neko.localization.text("night_5_ach_title"), .desc = neko.localization.text("night_5_ach_desc") };
        self.list[2] = .{ .id = "survive_n6", .name = neko.localization.text("night_6_ach_title"), .desc = neko.localization.text("night_6_ach_desc") };
        self.list[3] = .{ .id = "survive_n7", .name = neko.localization.text("night_7_ach_title"), .desc = neko.localization.text("night_7_ach_desc") };
        screen.attach(self, &screen_vtable);
        return &self.node;
    }

    fn is_unlocked(self: *const Conquistas, id: []const u8) bool {
        for (self.unlocked) |u| {
            if (mem.eql(u8, u, id)) return true;
        }
        return false;
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
    const self: *Conquistas = @ptrCast(@alignCast(ptr));
    const w: i32 = constants.SCREEN_WIDTH;
    const h: i32 = constants.SCREEN_HEIGHT;

    neko.draw.clear(neko.Color{ .r = 10, .g = 10, .b = 15 });
    neko.effect.noise(0, 0, w, h, 0.01);
    neko.sprite.text(neko.localization.text("ach_title_screen"), 80, 60, .{ .size = 40, .color = colors.TITLE_COLOR });
    neko.draw.rect(neko.Rect{ .x = 80, .y = 110, .w = 600, .h = 2 }, colors.STAR_COLOR, true);

    for (self.list, 0..) |ach, i| {
        const y: i32 = 180 + @as(i32, @intCast(i)) * 100;
        const unlocked: bool = self.is_unlocked(ach.id);

        const cr: u8 = if (unlocked) 255 else 60;
        const cg: u8 = if (unlocked) 255 else 60;
        const cb: u8 = if (unlocked) 255 else 70;
        const bg_r: u8 = if (unlocked) 20 else 15;
        const bg_g: u8 = if (unlocked) 20 else 15;
        const bg_b: u8 = if (unlocked) 30 else 20;

        neko.draw.rect(neko.Rect{ .x = 80, .y = y - 10, .w = w - 160, .h = 80 }, neko.Color{ .r = bg_r, .g = bg_g, .b = bg_b }, true);
        if (unlocked) {
            neko.draw.rect(neko.Rect{ .x = 80, .y = y - 10, .w = w - 160, .h = 80 }, neko.Color{ .r = 40, .g = 40, .b = 60 }, false);
        }

        neko.sprite.text(if (unlocked) "\u{2605}" else "\u{2606}", 100, y + 10, .{
            .size = 40,
            .color = neko.Color{
                .r = if (unlocked) colors.STAR_COLOR.r else 40,
                .g = if (unlocked) colors.STAR_COLOR.g else 40,
                .b = if (unlocked) colors.STAR_COLOR.b else 50,
            },
        });
        neko.sprite.text(ach.name, 160, y, .{ .size = 28, .color = neko.Color{ .r = cr, .g = cg, .b = cb } });
        neko.sprite.text(ach.desc, 160, y + 35, .{
            .size = 18,
            .color = neko.Color{
                .r = if (unlocked) 120 else 40,
                .g = if (unlocked) 120 else 40,
                .b = if (unlocked) 130 else 45,
            },
        });
    }

    neko.sprite.text(neko.localization.text("ach_help"), @divTrunc(w, 2), h - 60, .{
        .size = 16,
        .center = true,
        .color = neko.Color{ .r = 180, .g = 180, .b = 180 },
    });
    neko.effect.scanlines(0, 0, w, h, 10);
}

fn process(ptr: *anyopaque, dt: f32) void {
    const self: *Conquistas = @ptrCast(@alignCast(ptr));
    self.timer += dt;
}

fn input(ptr: *anyopaque, ev: neko.Event) void {
    const self: *Conquistas = @ptrCast(@alignCast(ptr));
    switch (ev) {
        .key_down => |k| {
            if (k.code == 27 or k.code == 13 or k.code == 32) {
                self.done = true;
                common.sound.play("select", 0, -1);
            }
        },
        .mouse_button_down => {
            self.done = true;
            common.sound.play("select", 0, -1);
        },
        else => {},
    }
}

fn is_done(ptr: *anyopaque) bool {
    const self: *Conquistas = @ptrCast(@alignCast(ptr));
    return self.done;
}

fn deinit(ptr: *anyopaque, allocator: Allocator) void {
    const self: *Conquistas = @ptrCast(@alignCast(ptr));
    allocator.destroy(self);
}
