// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Renan Lucas Vieira Hilário

//! FNWF 1 — options (volumes, quality and the Neko backend/render).

const std: type = @import("std");
const fmt: type = std.fmt;
const mem: type = std.mem;
const neko: type = @import("neko");
const common: type = @import("common");

const screen: type = @import("screen.zig");
const config: type = @import("config.zig");
const save: type = @import("save.zig");

const Allocator: type = std.mem.Allocator;

const KIND: [7][]const u8 = .{
    "Volume Geral",
    "Efeitos",
    "Música",
    "Qualidade",
    "Backend (Neko)",
    "Render (Neko)",
    "Voltar",
};
const COUNT: i32 = 7;

/// The options screen.
pub const Options: type = struct {
    node: neko.scene.Node,
    selected: i32 = 0,
    done: bool = false,
    result: []const u8 = "",

    renders: [16][]const u8 = undefined,
    render_count: usize = 0,
    render_idx: i32 = 0,

    pub fn create(allocator: Allocator) !*neko.scene.Node {
        const self: *Options = try allocator.create(Options);
        self.* = Options{
            .node = neko.scene.Node{ .ptr = @ptrCast(self), .vtable = &vtable, .allocator = allocator, .name = "options" },
        };
        screen.attach(self, &screen_vtable);

        const list = neko.screen.renderers(allocator);
        defer allocator.free(list);
        self.render_count = @min(list.len, self.renders.len);
        var i: usize = 0;
        while (i < self.render_count) : (i += 1) self.renders[i] = list[i].name;
        const cur = neko.screen.render_name();
        i = 0;
        while (i < self.render_count) : (i += 1) {
            if (mem.eql(u8, self.renders[i], cur)) self.render_idx = @intCast(i);
        }
        return &self.node;
    }
};

const vtable: neko.scene.Node.VTable = neko.scene.Node.VTable{
    .ready = neko.scene.no_ready,
    .process = neko.scene.no_process,
    .draw = draw,
    .input = input,
    .deinit = deinit,
};

const screen_vtable: screen.VTable = .{ .is_done = is_done, .result = result };

fn adjust(self: *Options, dir: i32) void {
    switch (self.selected) {
        0 => save.settings.master_volume = @max(0, @min(100, save.settings.master_volume + dir * 5)),
        1 => save.settings.sfx_volume = @max(0, @min(100, save.settings.sfx_volume + dir * 5)),
        2 => save.settings.music_volume = @max(0, @min(100, save.settings.music_volume + dir * 5)),
        3 => save.settings.quality_high = !save.settings.quality_high,
        4 => {}, // backend is fixed (SDL2) — read-only
        5 => {
            if (self.render_count > 0) {
                const n: i32 = @intCast(self.render_count);
                self.render_idx = @mod(self.render_idx + dir + n, n);
                _ = neko.screen.set_renderer(self.renders[@intCast(self.render_idx)]);
                save.settings.render = self.renders[@intCast(self.render_idx)];
            }
        },
        else => {},
    }
    apply_settings();
    common.sound.play("blip", 0, -1);
}

fn apply_settings() void {
    neko.sound.master_volume(save.settings.master_volume);
    neko.sound.sfx_volume(save.settings.sfx_volume);
    neko.sound.music_volume(save.settings.music_volume);
    neko.sprite.set_quality(if (save.settings.quality_high) "high" else "low");
}

fn input(ptr: *anyopaque, ev: neko.Event) void {
    const self: *Options = @ptrCast(@alignCast(ptr));
    switch (ev) {
        .key_down => |k| {
            const code = k.code;
            if (code == 1073741906 or code == 'w') {
                self.selected = @mod(self.selected - 1 + COUNT, COUNT);
                common.sound.play("blip", 0, -1);
            } else if (code == 1073741905 or code == 's') {
                self.selected = @mod(self.selected + 1, COUNT);
                common.sound.play("blip", 0, -1);
            } else if (code == 1073741903 or code == 'd') {
                adjust(self, 1);
            } else if (code == 1073741904 or code == 'a') {
                adjust(self, -1);
            } else if (code == 13 or code == 32 or code == 27) {
                if ((code == 13 or code == 32) and self.selected == COUNT - 1) {
                    save.save_settings();
                    self.done = true;
                    self.result = "back";
                    common.sound.play("select", 0, -1);
                } else if (code == 27) {
                    save.save_settings();
                    self.done = true;
                    self.result = "back";
                    common.sound.play("select", 0, -1);
                } else {
                    adjust(self, 1);
                }
            }
        },
        else => {},
    }
}

fn draw(ptr: *anyopaque, at: neko.Point) void {
    _ = at;
    const self: *Options = @ptrCast(@alignCast(ptr));
    neko.draw.clear(config.BLACK);
    neko.sprite.text("OPÇÕES", config.SCREEN_W / 2, 70, .{ .size = 44, .center = true, .color = config.ACCENT });

    var y: i32 = 175;
    for (KIND, 0..) |label, i| {
        const sel: bool = @as(i32, @intCast(i)) == self.selected;
        if (sel) {
            neko.draw.rect(neko.Rect{ .x = 300, .y = y - 12, .w = config.SCREEN_W - 600, .h = 52 }, neko.Color{ .r = 26, .g = 24, .b = 32 }, true);
            neko.draw.rect(neko.Rect{ .x = 300, .y = y - 12, .w = 6, .h = 52 }, config.ACCENT, true);
        }
        const dim: bool = i >= 4 and i <= 5;
        const label_col = if (sel) config.WHITE else if (dim) neko.Color{ .r = 150, .g = 150, .b = 160 } else config.MUTED;
        neko.sprite.text(label, 340, y, .{ .size = 24, .color = label_col });

        if (i < 3) {
            const value: i32 = switch (i) {
                0 => save.settings.master_volume,
                1 => save.settings.sfx_volume,
                else => save.settings.music_volume,
            };
            const bx: i32 = 780;
            neko.draw.rect(neko.Rect{ .x = bx, .y = y + 4, .w = 240, .h = 16 }, neko.Color{ .r = 40, .g = 40, .b = 46 }, true);
            neko.draw.rect(neko.Rect{ .x = bx, .y = y + 4, .w = @divTrunc(240 * value, 100), .h = 16 }, config.ACCENT, true);
            var buf: [8]u8 = undefined;
            neko.sprite.text(fmt.bufPrint(&buf, "{d}", .{value}) catch "", bx + 260, y, .{ .size = 24, .color = config.WHITE });
        } else if (i == 3) {
            neko.sprite.text(if (save.settings.quality_high) "Alta" else "Baixa", 800, y, .{ .size = 24, .color = config.WHITE });
        } else if (i == 4) {
            neko.sprite.text(neko.backend_kind.name, 800, y, .{ .size = 24, .color = neko.Color{ .r = 180, .g = 180, .b = 190 } });
        } else if (i == 5) {
            if (self.render_count > 0) {
                var rbuf: [64]u8 = undefined;
                const s = fmt.bufPrint(&rbuf, "< {s} >", .{self.renders[@intCast(self.render_idx)]}) catch "";
                neko.sprite.text(s, 800, y, .{ .size = 24, .color = config.WHITE });
            }
        }
        y += 64;
    }

    neko.sprite.text("W/S seleciona   A/D ajusta   ENTER/ESC volta", config.SCREEN_W / 2, config.SCREEN_H - 40, .{ .size = 15, .center = true, .color = config.MUTED });
}

fn is_done(ptr: *anyopaque) bool {
    const self: *Options = @ptrCast(@alignCast(ptr));
    return self.done;
}

fn result(ptr: *anyopaque) []const u8 {
    const self: *Options = @ptrCast(@alignCast(ptr));
    return self.result;
}

fn deinit(ptr: *anyopaque, allocator: Allocator) void {
    const self: *Options = @ptrCast(@alignCast(ptr));
    allocator.destroy(self);
}
