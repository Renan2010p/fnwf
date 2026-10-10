//! The main menu — a scene tree: the root draws the dressing and owns a
//! `Sprite` (the animatronic) plus one `Label` per option.

const std: type = @import("std");
const fmt: type = std.fmt;
const mem: type = std.mem;
const neko: type = @import("neko");
const common: type = @import("common");

const screen: type = @import("../screen.zig");
const constants: type = @import("../config/constants.zig");
const colors: type = @import("../config/colors.zig");

const Allocator: type = std.mem.Allocator;

const MAX_OPTIONS: usize = 12;
const ANIMALS: [4][]const u8 = .{ "eser", "cedro", "alice", "Sonk" };

const Option: type = struct { label: []const u8, action: []const u8 };

/// The main menu screen.
pub const Menu: type = struct {
    node: neko.scene.Node,
    allocator: Allocator,
    completed_nights: i32,
    has_seen_story: bool,

    selected: i32 = 1,
    done: bool = false,
    result: []const u8 = "",
    menu_page: []const u8 = "main",
    timer: f32 = 0,

    options: [MAX_OPTIONS]Option = undefined,
    option_count: usize = 0,
    option_labels: [MAX_OPTIONS]*neko.scene.Label = undefined,
    owned_texts: std.ArrayListUnmanaged([]u8) = .empty,
    sprite: ?*neko.scene.Sprite = null,

    pub fn create(allocator: Allocator, completed_nights: i32, has_seen_story: bool) !*neko.scene.Node {
        const self: *Menu = try allocator.create(Menu);
        self.* = Menu{
            .node = neko.scene.Node{
                .ptr = @ptrCast(self),
                .vtable = &vtable,
                .allocator = allocator,
                .name = "menu",
            },
            .allocator = allocator,
            .completed_nights = completed_nights,
            .has_seen_story = has_seen_story,
        };
        screen.attach(self, &screen_vtable);
        try self.rebuild();
        common.sound.play_menu_ambient();
        return &self.node;
    }

    pub fn from_node(n: *neko.scene.Node) *Menu {
        return @ptrCast(@alignCast(n));
    }

    fn free_texts(self: *Menu) void {
        for (self.owned_texts.items) |t| self.allocator.free(t);
        self.owned_texts.clearRetainingCapacity();
    }

    fn add_option(self: *Menu, label: []const u8, action: []const u8) !void {
        if (self.option_count >= MAX_OPTIONS) return;
        const text = try self.allocator.dupe(u8, label);
        try self.owned_texts.append(self.allocator, text);
        self.options[self.option_count] = Option{ .label = text, .action = action };
        self.option_count += 1;
    }

    /// Rebuilds the whole tree: the animatronic sprite plus one Label per option.
    fn rebuild(self: *Menu) !void {
        self.free_texts();
        self.node.clearChildren();
        self.option_count = 0;

        neko.sprite.load("cedro");
        neko.sprite.load("eser");
        neko.sprite.load("alice");
        neko.sprite.load("Sonk");

        // Animatronic on the right.
        const idx: usize = @intCast(@mod(neko.random.int_range(0, 3), 4));
        const sprite_node = try neko.scene.Sprite.create(self.allocator, neko.scene.Sprite.Options{
            .image = ANIMALS[idx],
            .pos = neko.Point{ .x = constants.SCREEN_WIDTH - 640, .y = 70 },
            .size = neko.Point{ .x = 560, .y = 560 },
        });
        self.sprite = neko.scene.Sprite.from_node(sprite_node);
        self.node.add(sprite_node);

        // Options.
        if (mem.eql(u8, self.menu_page, "main")) {
            try self.add_option(neko.localization.text("new_game"), "start");
            if (self.has_seen_story or self.completed_nights > 0) {
                const next: i32 = @min(self.completed_nights + 1, 6);
                var buf: [96]u8 = undefined;
                const s = fmt.bufPrint(&buf, "{s} ({s} {d})", .{
                    neko.localization.text("continue"),
                    neko.localization.text("night"),
                    next,
                }) catch "";
                try self.add_option(s, "continue");
            }
            if (self.completed_nights >= 5) {
                var buf: [64]u8 = undefined;
                const s = fmt.bufPrint(&buf, "{s} 6", .{neko.localization.text("night")}) catch "";
                try self.add_option(s, "night6");
                try self.add_option(neko.localization.text("more"), "more");
            }
            try self.add_option(neko.localization.text("options"), "options");
            try self.add_option(neko.localization.text("quit"), "quit");
        } else {
            if (self.completed_nights >= 5) {
                try self.add_option(neko.localization.text("extras"), "extras");
                try self.add_option(neko.localization.text("custom_night"), "night7");
            }
            try self.add_option(neko.localization.text("arcade"), "arcade");
            try self.add_option(neko.localization.text("achievements"), "conquistas");
            try self.add_option(neko.localization.text("back"), "back_menu");
        }

        // One Label per option.
        var i: usize = 0;
        while (i < self.option_count) : (i += 1) {
            const y: i32 = 300 + @as(i32, @intCast(i)) * 62;
            const label = try neko.scene.Label.create(self.allocator, neko.scene.Label.Options{
                .text = self.options[i].label,
                .pos = neko.Point{ .x = 68, .y = y - 5 },
                .size = 22,
                .color = neko.Color{ .r = 255, .g = 255, .b = 255 },
            });
            self.option_labels[i] = neko.scene.Label.from_node(label);
            self.node.add(label);
        }

        if (self.selected > @as(i32, @intCast(self.option_count))) self.selected = 1;
    }

    fn activate(self: *Menu, index: usize) void {
        common.sound.play("select", 0, -1);
        const action = self.options[index].action;
        if (mem.eql(u8, action, "more")) {
            self.menu_page = "more";
            self.selected = 1;
            self.rebuild() catch {};
            return;
        }
        if (mem.eql(u8, action, "back_menu")) {
            self.menu_page = "main";
            self.selected = 1;
            self.rebuild() catch {};
            return;
        }
        self.result = action;
        self.done = true;
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

fn draw(ptr: *anyopaque, at: neko.Point) void {
    _ = at;
    const self: *Menu = @ptrCast(@alignCast(ptr));
    neko.draw.clear(neko.Color{ .r = 4, .g = 5, .b = 9 });

    neko.effect.vhs("FIVE NIGHTS", 60, 64, neko.Color{ .r = 220, .g = 240, .b = 220 }, 46);
    neko.effect.vhs("WITH FRIENDS", 60, 116, neko.Color{ .r = 220, .g = 240, .b = 220 }, 46);

    const classic_alpha: u8 = @intFromFloat(120.0 + 100.0 * @sin(self.timer * 3.0));
    neko.sprite.text_rotated("CLASSIC EDITION", 310, 155, -8.0, neko.sprite.Options{
        .size = 20,
        .color = neko.Color{ .r = 255, .g = 220, .b = 50, .a = classic_alpha },
    });
    neko.sprite.text("v" ++ common.VERSION, 62, 176, neko.sprite.Options{
        .size = 15,
        .color = neko.Color{ .r = 140, .g = 170, .b = 200, .a = 220 },
    });
    neko.sprite.text("Neko: v" ++ common.NEKO_VERSION, 132, 176, neko.sprite.Options{
        .size = 15,
        .color = neko.Color{ .r = 120, .g = 140, .b = 170, .a = 200 },
    });

    const line_alpha: u8 = @intFromFloat(120.0 + 40.0 * @sin(self.timer * 2.0));
    neko.draw.rect(neko.Rect{ .x = 60, .y = 204, .w = 360, .h = 2 }, neko.Color{ .r = 100, .g = 180, .b = 255, .a = line_alpha }, true);

    var i: i32 = 0;
    while (i < @as(i32, @intCast(self.option_count))) : (i += 1) {
        const y: i32 = 300 + i * 62;
        if (i + 1 == self.selected) {
            neko.draw.rect(neko.Rect{ .x = 48, .y = y - 17, .w = 6, .h = 48 }, neko.Color{ .r = 100, .g = 180, .b = 255 }, true);
        }
    }

    neko.sprite.text("[ UP / DOWN ] SELECT     [ ENTER ] PLAY     [ ESC ] BACK", 60, constants.SCREEN_HEIGHT - 58, neko.sprite.Options{
        .size = 13,
        .color = neko.Color{ .r = 110, .g = 130, .b = 160, .a = 200 },
    });
    neko.sprite.text("Five Nights With Friends", 60, constants.SCREEN_HEIGHT - 38, neko.sprite.Options{
        .size = 11,
        .color = neko.Color{ .r = 80, .g = 90, .b = 110, .a = 140 },
    });
}

fn process(ptr: *anyopaque, dt: f32) void {
    const self: *Menu = @ptrCast(@alignCast(ptr));
    self.timer += dt;

    if (self.sprite) |sprite| {
        const bounce: f32 = 5.0 * @sin(self.timer * 0.8);
        sprite.node.pos = neko.Point{ .x = constants.SCREEN_WIDTH - 640, .y = @intFromFloat(70.0 + bounce) };
    }

    var i: usize = 0;
    while (i < self.option_count) : (i += 1) {
        const is_sel: bool = (@as(i32, @intCast(i)) + 1 == self.selected);
        const bri: u8 = if (is_sel) 255 else 140;
        const extra: u8 = if (is_sel) 20 else 0;
        self.option_labels[i].color = neko.Color{ .r = bri, .g = bri, .b = bri + extra };
    }
}

fn input(ptr: *anyopaque, ev: neko.Event) void {
    const self: *Menu = @ptrCast(@alignCast(ptr));
    const count: i32 = @intCast(self.option_count);
    if (count == 0 or self.done) return;

    switch (ev) {
        .key_down => |kev| {
            if (kev.code == 1073741906 or kev.code == 'w') {
                self.selected = @mod(self.selected - 2 + count, count) + 1;
                common.sound.play("blip", 0, -1);
            } else if (kev.code == 1073741905 or kev.code == 's') {
                self.selected = @mod(self.selected, count) + 1;
                common.sound.play("blip", 0, -1);
            } else if (kev.code == 13 or kev.code == 32) {
                self.activate(@intCast(self.selected - 1));
            }
        },
        .mouse_button_down => |m| {
            var i: i32 = 0;
            while (i < count) : (i += 1) {
                const y: i32 = 300 + i * 62 - 17;
                if (m.y >= y and m.y <= y + 48 and m.x >= 54 and m.x <= 414) {
                    self.selected = i + 1;
                    self.activate(@intCast(i));
                }
            }
        },
        else => {},
    }
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
    self.free_texts();
    self.owned_texts.deinit(allocator);
    allocator.destroy(self);
}
