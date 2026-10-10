// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Renan Lucas Vieira Hilário

//! The extras gallery — port of `game1/states/ExtrasState`.
//!
//! Four tabs: animatronic bios, credits, cheat toggles and achievements.

const std: type = @import("std");
const fmt: type = std.fmt;
const mem: type = std.mem;
const neko: type = @import("neko");
const common: type = @import("common");

const screen: type = @import("../screen.zig");
const constants: type = @import("../config/constants.zig");
const colors: type = @import("../config/colors.zig");

const Allocator: type = std.mem.Allocator;

const MAX_ACHIEVEMENTS: usize = 4;

const AnimData: type = struct {
    name: []const u8,
    sprite: []const u8,
    desc: []const u8,
};

const AchData: type = struct {
    id: []const u8,
    name: []const u8,
    desc: []const u8,
};

/// The extras gallery.
pub const Extras: type = struct {
    node: neko.scene.Node,

    timer: f32 = 0,
    done: bool = false,
    result: []const u8 = "",

    category: i32 = 1,
    anim_idx: i32 = 1,
    selected: i32 = 1,

    categories: [4][]const u8 = undefined,
    animatronics: [4]AnimData = undefined,
    achievements_list: [MAX_ACHIEVEMENTS]AchData = undefined,

    infinite_power: bool = false,
    fast_nights: bool = false,
    unlocked: []const []u8,

    wrap_font: i64 = -1,

    pub fn create(
        allocator: Allocator,
        infinite_power: bool,
        fast_nights: bool,
        unlocked: []const []u8,
    ) !*neko.scene.Node {
        const self: *Extras = try allocator.create(Extras);
        self.* = Extras{
            .node = neko.scene.Node{
                .ptr = @ptrCast(self),
                .vtable = &vtable,
                .allocator = allocator,
                .name = "extras",
            },
            .infinite_power = infinite_power,
            .fast_nights = fast_nights,
            .unlocked = unlocked,
        };
        screen.attach(self, &screen_vtable);

        self.categories[0] = neko.localization.text("cat_animatronics");
        self.categories[1] = neko.localization.text("cat_credits");
        self.categories[2] = neko.localization.text("cat_cheats");
        self.categories[3] = neko.localization.text("cat_achievements");

        self.animatronics[0] = .{ .name = "Cedro", .sprite = "cedro", .desc = neko.localization.text("cedro_desc") };
        self.animatronics[1] = .{ .name = "Eser", .sprite = "eser", .desc = neko.localization.text("eser_desc") };
        self.animatronics[2] = .{ .name = "Alice", .sprite = "alice", .desc = neko.localization.text("alice_desc") };
        self.animatronics[3] = .{ .name = "Renan", .sprite = "renan", .desc = neko.localization.text("renan_desc") };
        for (self.animatronics) |a| neko.sprite.load(a.sprite);

        self.achievements_list[0] = .{ .id = "survive_n1", .name = neko.localization.text("night_1_ach_title"), .desc = neko.localization.text("night_1_ach_desc") };
        self.achievements_list[1] = .{ .id = "survive_n5", .name = neko.localization.text("night_5_ach_title"), .desc = neko.localization.text("night_5_ach_desc") };
        self.achievements_list[2] = .{ .id = "survive_n6", .name = neko.localization.text("night_6_ach_title"), .desc = neko.localization.text("night_6_ach_desc") };
        self.achievements_list[3] = .{ .id = "survive_n7", .name = neko.localization.text("night_7_ach_title"), .desc = neko.localization.text("night_7_ach_desc") };

        var path_buf: [512]u8 = undefined;
        const path = fmt.bufPrint(&path_buf, "{s}/font/font.ttf", .{neko.assets_dir()}) catch "";
        self.wrap_font = neko.text.load_font(path, 20);
        return &self.node;
    }

    /// Recovers the `Extras` from its scene-tree node (to read the toggle state
    /// back when the screen closes).
    pub fn from_node(n: *neko.scene.Node) *Extras {
        return @ptrCast(@alignCast(n));
    }

    fn is_unlocked(self: *const Extras, id: []const u8) bool {
        for (self.unlocked) |u| {
            if (mem.eql(u8, u, id)) return true;
        }
        return false;
    }

    fn text_width(self: *const Extras, s: []const u8) i32 {
        if (self.wrap_font >= 0) {
            if (neko.text.size(s, @intCast(self.wrap_font))) |sz| return sz.x;
        }
        return @as(i32, @intCast(s.len)) * 10;
    }

    fn next_category(self: *Extras, dir: i32) void {
        self.category = @mod(self.category - 1 + dir, 4) + 1;
        self.selected = 1;
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
    const self: *Extras = @ptrCast(@alignCast(ptr));
    self.timer += dt;
}

fn input(ptr: *anyopaque, ev: neko.Event) void {
    const self: *Extras = @ptrCast(@alignCast(ptr));
    switch (ev) {
        .key_down => |k| {
            const code: i32 = k.code;
            if (code == 27) {
                self.result = "menu";
                self.done = true;
                common.sound.play("select", 0, -1);
            } else if (code == 1073741904 or code == 'a') {
                self.next_category(-1);
            } else if (code == 1073741903 or code == 'd') {
                self.next_category(1);
            }

            if (self.category == 1) {
                if (code == 1073741906 or code == 'w') {
                    self.anim_idx = @mod(self.anim_idx - 2 + 4, 4) + 1;
                    common.sound.play("blip", 0, -1);
                } else if (code == 1073741905 or code == 's') {
                    self.anim_idx = @mod(self.anim_idx, 4) + 1;
                    common.sound.play("blip", 0, -1);
                }
            } else if (self.category == 3) {
                if (code == 1073741906 or code == 'w') {
                    self.selected = @mod(self.selected - 2 + 2, 2) + 1;
                    common.sound.play("blip", 0, -1);
                } else if (code == 1073741905 or code == 's') {
                    self.selected = @mod(self.selected, 2) + 1;
                    common.sound.play("blip", 0, -1);
                } else if (code == 13 or code == 32) {
                    if (self.selected == 1) {
                        self.infinite_power = !self.infinite_power;
                    } else {
                        self.fast_nights = !self.fast_nights;
                    }
                    common.sound.play("select", 0, -1);
                }
            }
        },
        .mouse_button_down => |m| {
            if (m.y >= constants.SCREEN_HEIGHT - 50) {
                self.result = "menu";
                self.done = true;
                common.sound.play("select", 0, -1);
                return;
            }
            self.next_category(if (m.x < @divTrunc(constants.SCREEN_WIDTH, 2)) -1 else 1);
        },
        else => {},
    }
}

fn draw(ptr: *anyopaque, at: neko.Point) void {
    _ = at;
    const self: *Extras = @ptrCast(@alignCast(ptr));
    const w: i32 = constants.SCREEN_WIDTH;
    const h: i32 = constants.SCREEN_HEIGHT;

    neko.draw.clear(neko.Color{ .r = 5, .g = 5, .b = 10 });
    neko.effect.noise(0, 0, w, h, 0.01);

    for (self.categories, 0..) |cat, idx| {
        const i: i32 = @intCast(idx);
        const is_sel: bool = i + 1 == self.category;
        const c: u8 = if (is_sel) 255 else 100;
        neko.sprite.text(cat, 80 + i * 230, 40, .{ .size = 20, .color = neko.Color{ .r = c, .g = c, .b = if (is_sel) 255 else 110 } });
        if (is_sel) {
            neko.draw.rect(neko.Rect{ .x = 80 + i * 230, .y = 65, .w = 80, .h = 2 }, neko.Color{ .r = 255, .g = 255, .b = 255 }, true);
        }
    }

    switch (self.category) {
        1 => draw_animatronics(self),
        2 => draw_credits(self),
        3 => draw_cheats(self),
        4 => draw_achievements(self),
        else => {},
    }

    neko.sprite.text(neko.localization.text("extras_help"), 80, h - 40, .{ .size = 14, .color = neko.Color{ .r = 150, .g = 150, .b = 160 } });
    neko.effect.scanlines(0, 0, w, h, 10);
}

fn draw_animatronics(self: *Extras) void {
    const a = self.animatronics[@intCast(self.anim_idx - 1)];
    const img_x: i32 = 90;
    const img_y: i32 = 140;
    const img_w: i32 = 520;
    const img_h: i32 = 520;
    const text_x: i32 = 660;
    const text_w: i32 = constants.SCREEN_WIDTH - text_x - 80;

    neko.draw.rect(neko.Rect{ .x = img_x - 8, .y = img_y - 8, .w = img_w + 16, .h = img_h + 16 }, neko.Color{ .r = 65, .g = 80, .b = 110 }, false);
    neko.sprite.face(a.sprite, img_x, img_y, img_w, img_h);

    neko.sprite.text(a.name, text_x, 160, .{ .size = 56, .color = colors.TITLE_COLOR });

    var ly: i32 = 250;
    var count: usize = 0;
    var i: usize = 0;
    while (i < a.desc.len and count < 7) {
        while (i < a.desc.len and a.desc[i] == ' ') i += 1;
        if (i >= a.desc.len) break;

        const start: usize = i;
        var end: usize = i;
        var scan: usize = i;
        while (scan < a.desc.len) {
            var we: usize = scan;
            while (we < a.desc.len and a.desc[we] != ' ') we += 1;
            const fits: bool = self.text_width(a.desc[start..we]) <= text_w;
            if (fits or end == start) {
                end = we;
                scan = we;
                while (scan < a.desc.len and a.desc[scan] == ' ') scan += 1;
            } else break;
        }

        neko.sprite.text(a.desc[start..end], text_x, ly, .{ .size = 20, .color = neko.Color{ .r = 255, .g = 255, .b = 255 } });
        ly += 34;
        count += 1;
        i = end;
    }

    var buf: [32]u8 = undefined;
    const counter = fmt.bufPrint(&buf, "{d} / 4", .{self.anim_idx}) catch "";
    neko.sprite.text(counter, img_x, img_y + img_h + 18, .{ .size = 16, .color = neko.Color{ .r = 180, .g = 180, .b = 180 } });
}

fn draw_credits(self: *Extras) void {
    _ = self;
    const w: i32 = constants.SCREEN_WIDTH;
    const y: i32 = 200;

    neko.sprite.text("FIVE NIGHTS WITH FRIENDS", @divTrunc(w, 2), y, .{ .size = 40, .center = true, .color = colors.TITLE_COLOR });
    neko.sprite.text(neko.localization.text("created_by"), @divTrunc(w, 2), y + 60, .{ .size = 24, .center = true, .color = neko.Color{ .r = 255, .g = 255, .b = 255 } });
    neko.sprite.text("Renan Lucas", @divTrunc(w, 2), y + 110, .{ .size = 50, .center = true, .color = neko.Color{ .r = 100, .g = 200, .b = 255 } });
    neko.sprite.text(neko.localization.text("special_thanks"), @divTrunc(w, 2), y + 300, .{ .size = 18, .center = true, .color = neko.Color{ .r = 180, .g = 180, .b = 180 } });
    neko.sprite.text("Scott Cawthon (FNAF Original)", @divTrunc(w, 2), y + 330, .{ .size = 18, .center = true, .color = neko.Color{ .r = 255, .g = 255, .b = 255 } });
}

fn draw_cheats(self: *Extras) void {
    const labels = [2][]const u8{ neko.localization.text("cheat_energy"), neko.localization.text("cheat_fast") };
    for (labels, 0..) |label, idx| {
        const i: i32 = @intCast(idx);
        const is_sel: bool = i + 1 == self.selected;
        const r: u8 = if (is_sel) 255 else 120;
        const g: u8 = if (is_sel) 255 else 120;
        const b: u8 = if (is_sel) 255 else 130;
        const prefix: []const u8 = if (is_sel) ">> " else "   ";
        var lbuf: [96]u8 = undefined;
        const full = fmt.bufPrint(&lbuf, "{s}{s}", .{ prefix, label }) catch label;
        neko.sprite.text(full, 100, 250 + i * 60, .{ .size = 28, .color = neko.Color{ .r = r, .g = g, .b = b } });

        const on: bool = if (i == 0) self.infinite_power else self.fast_nights;
        const sr: u8 = if (on) 100 else 255;
        const sg: u8 = if (on) 255 else 100;
        const sb: u8 = if (on) 100 else 100;
        const st: []const u8 = if (on) neko.localization.text("on") else neko.localization.text("off");
        neko.sprite.text(st, 450, 250 + i * 60, .{
            .size = 28,
            .color = neko.Color{
                .r = if (is_sel) sr else r,
                .g = if (is_sel) sg else g,
                .b = if (is_sel) sb else b,
            },
        });
    }
}

fn draw_achievements(self: *Extras) void {
    for (self.achievements_list, 0..) |ach, idx| {
        const y: i32 = 220 + @as(i32, @intCast(idx)) * 80;
        const un: bool = self.is_unlocked(ach.id);
        neko.sprite.text(if (un) "\u{2605}" else "\u{2606}", 80, y, .{
            .size = 30,
            .color = neko.Color{
                .r = if (un) colors.STAR_COLOR.r else 50,
                .g = if (un) colors.STAR_COLOR.g else 50,
                .b = if (un) colors.STAR_COLOR.b else 60,
            },
        });
        neko.sprite.text(ach.name, 130, y, .{
            .size = 24,
            .color = neko.Color{ .r = if (un) 255 else 60, .g = if (un) 255 else 60, .b = if (un) 255 else 70 },
        });
        neko.sprite.text(ach.desc, 130, y + 30, .{
            .size = 16,
            .color = neko.Color{ .r = if (un) 120 else 40, .g = if (un) 120 else 40, .b = if (un) 130 else 45 },
        });
    }
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
