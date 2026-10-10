//! The options screen — port of `game1/states/OptionsState`.

const std: type = @import("std");
const mem: type = std.mem;
const fmt: type = std.fmt;
const neko: type = @import("neko");
const common: type = @import("common");

const screen: type = @import("../screen.zig");
const constants: type = @import("../config/constants.zig");
const settings: type = @import("../config/settings.zig");

const Allocator: type = std.mem.Allocator;

const MAX_OPTIONS: usize = 16;
const MAX_RESOLUTIONS: usize = 32;
const ITEM_H: i32 = 50;

/// What one row does.
const Kind: type = enum {
    resolution,
    fullscreen,
    language,
    master_volume,
    sfx_volume,
    music_volume,
    show_fps,
    vsync,
    quality,
    discord_rpc,
    backend,
    render,
    back,
};

const OptionItem: type = struct {
    kind: Kind,
    label: []const u8,
};

const Resolution: type = struct {
    w: i32,
    h: i32,
};

/// The options screen.
pub const Options: type = struct {
    node: neko.scene.Node,
    allocator: Allocator,

    options: [MAX_OPTIONS]OptionItem = undefined,
    max_options: usize = 0,

    resolutions: [MAX_RESOLUTIONS]Resolution = undefined,
    res_count: usize = 0,
    current_res_idx: i32 = 0,

    is_fullscreen: bool = false,
    show_fps: bool = false,
    vsync: bool = true,
    lang: settings.Language = .en,
    quality: settings.Quality = .high,
    discord_rpc: bool = true,
    master_volume: i32 = 80,
    sfx_volume: i32 = 100,
    music_volume: i32 = 70,

    renders: [16][]const u8 = undefined,
    render_count: usize = 0,
    render_idx: i32 = 0,

    selected: i32 = 1,
    done: bool = false,
    result: []const u8 = "",

    timer: f32 = 0,
    bg_scroll: f32 = 0,
    highlight_y: f32 = 150,
    scroll_offset: f32 = 0,
    scroll_target: f32 = 0,
    item_glows: [MAX_OPTIONS]f32 = @splat(0),

    pub fn create(allocator: Allocator) !*neko.scene.Node {
        const self: *Options = try allocator.create(Options);
        self.* = Options{
            .node = neko.scene.Node{ .ptr = @ptrCast(self), .vtable = &vtable, .allocator = allocator, .name = "options" },
            .allocator = allocator,
        };
        screen.attach(self, &screen_vtable);

        self.build_resolutions();

        const s: *settings.Settings = settings.get();
        self.current_res_idx = 0;
        var i: i32 = 0;
        while (i < @as(i32, @intCast(self.res_count))) : (i += 1) {
            const r = self.resolutions[@intCast(i)];
            if (r.w == s.resolution_w and r.h == s.resolution_h) {
                self.current_res_idx = i;
                break;
            }
        }
        self.is_fullscreen = s.fullscreen;
        self.show_fps = s.show_fps;
        self.vsync = s.vsync;
        self.lang = s.language;
        self.quality = s.quality;
        self.discord_rpc = s.discord_rpc;
        self.master_volume = s.master_volume;
        self.sfx_volume = s.sfx_volume;
        self.music_volume = s.music_volume;

        // Neko render list (to let the player pick a renderer).
        const list = neko.screen.renderers(allocator);
        defer allocator.free(list);
        self.render_count = @min(list.len, self.renders.len);
        var ri: usize = 0;
        while (ri < self.render_count) : (ri += 1) self.renders[ri] = list[ri].name;
        const cur = neko.screen.render_name();
        self.render_idx = 0;
        ri = 0;
        while (ri < self.render_count) : (ri += 1) {
            if (mem.eql(u8, self.renders[ri], cur)) self.render_idx = @intCast(ri);
        }

        self.rebuild_options();
        if (self.max_options > 0) self.item_glows[0] = 1.0;
        return &self.node;
    }

    pub fn from_node(n: *neko.scene.Node) *Options {
        return @ptrCast(@alignCast(n));
    }

    fn build_resolutions(self: *Options) void {
        const allocator: Allocator = self.allocator;
        const modes: []neko.DisplayMode = neko.screen.display_modes(allocator);
        defer allocator.free(modes);

        for (modes) |m| {
            var dup = false;
            var i: usize = 0;
            while (i < self.res_count) : (i += 1) {
                if (self.resolutions[i].w == m.width and self.resolutions[i].h == m.height) {
                    dup = true;
                    break;
                }
            }
            if (!dup and self.res_count < MAX_RESOLUTIONS) {
                self.resolutions[self.res_count] = Resolution{ .w = m.width, .h = m.height };
                self.res_count += 1;
            }
        }
        if (self.res_count == 0) {
            self.resolutions[0] = Resolution{ .w = constants.SCREEN_WIDTH, .h = constants.SCREEN_HEIGHT };
            self.res_count = 1;
        }

        // Sort by width (simple insertion sort; the list is tiny).
        var a: usize = 1;
        while (a < self.res_count) : (a += 1) {
            const key = self.resolutions[a];
            var b: usize = a;
            while (b > 0 and self.resolutions[b - 1].w > key.w) : (b -= 1) {
                self.resolutions[b] = self.resolutions[b - 1];
            }
            self.resolutions[b] = key;
        }
    }

    fn add(self: *Options, kind: Kind, label: []const u8) void {
        if (self.max_options >= MAX_OPTIONS) return;
        self.options[self.max_options] = OptionItem{ .kind = kind, .label = label };
        self.max_options += 1;
    }

    fn rebuild_options(self: *Options) void {
        self.max_options = 0;
        const text = neko.localization.text;

        self.add(.resolution, text("resolution"));
        self.add(.fullscreen, text("fullscreen"));
        self.add(.language, text("language"));
        self.add(.master_volume, text("master_volume"));
        self.add(.sfx_volume, text("sfx_volume"));
        self.add(.music_volume, text("music_volume"));
        self.add(.show_fps, text("show_fps"));
        self.add(.vsync, text("vsync"));
        self.add(.quality, text("quality"));
        self.add(.discord_rpc, text("discord_rpc"));
        self.add(.backend, "Backend (Neko)");
        self.add(.render, "Render (Neko)");
        self.add(.back, text("back"));

        if (self.selected > @as(i32, @intCast(self.max_options))) {
            self.selected = @intCast(self.max_options);
        }
    }

    fn cycle_language(self: *Options) void {
        self.lang = if (self.lang == .pt) .en else .pt;
        neko.localization.set_language(self.lang.code());
        self.rebuild_options();
    }

    /// Adjusts the selected option in `dir` (-1 left, +1 right).
    fn adjust(self: *Options, dir: i32) void {
        const kind = self.options[@intCast(self.selected - 1)].kind;
        const res_count: i32 = @intCast(self.res_count);
        switch (kind) {
            .resolution => self.current_res_idx = @mod(self.current_res_idx + dir, res_count),
            .language => self.cycle_language(),
            .quality => self.quality = if (self.quality == .low) .high else .low,
            .fullscreen => self.is_fullscreen = !self.is_fullscreen,
            .show_fps => self.show_fps = !self.show_fps,
            .vsync => self.vsync = !self.vsync,
            .discord_rpc => self.discord_rpc = !self.discord_rpc,
            .master_volume => self.master_volume = @max(0, @min(100, self.master_volume + dir * 5)),
            .sfx_volume => self.sfx_volume = @max(0, @min(100, self.sfx_volume + dir * 5)),
            .music_volume => self.music_volume = @max(0, @min(100, self.music_volume + dir * 5)),
            .backend => {},
            .render => {
                if (self.render_count > 0) {
                    const n: i32 = @intCast(self.render_count);
                    self.render_idx = @mod(self.render_idx + dir + n, n);
                    _ = neko.screen.set_renderer(self.renders[@intCast(self.render_idx)]);
                }
            },
            .back => {},
        }
        common.sound.play("blip", 0, -1);
    }

    fn apply_settings(self: *Options) void {
        const s: *settings.Settings = settings.get();
        s.resolution_w = self.resolutions[@intCast(self.current_res_idx)].w;
        s.resolution_h = self.resolutions[@intCast(self.current_res_idx)].h;
        s.fullscreen = self.is_fullscreen;
        s.language = self.lang;
        s.show_fps = self.show_fps;
        s.vsync = self.vsync;
        s.quality = self.quality;
        s.discord_rpc = self.discord_rpc;
        s.master_volume = self.master_volume;
        s.sfx_volume = self.sfx_volume;
        s.music_volume = self.music_volume;
        if (self.render_count > 0) s.render = self.renders[@intCast(self.render_idx)];

        neko.screen.set_resolution(@intCast(s.resolution_w), @intCast(s.resolution_h));
        neko.screen.set_logical_size(@intCast(constants.SCREEN_WIDTH), @intCast(constants.SCREEN_HEIGHT));
        neko.screen.set_fullscreen(s.fullscreen);
        neko.screen.set_vsync(s.vsync);
        neko.sprite.set_quality(s.quality.code());
        common.sound.master_volume(s.master_volume);
        common.sound.sfx_volume(s.sfx_volume);
        common.sound.music_volume(s.music_volume);

        settings.save();
    }
};

fn lerp_f(a: f32, b: f32, t: f32) f32 {
    return a + (b - a) * @min(1.0, @max(0.0, t));
}

const vtable: neko.scene.Node.VTable = neko.scene.Node.VTable{
    .ready = neko.scene.no_ready,
    .process = vt_update,
    .draw = vt_draw,
    .input = vt_handle_event,
    .deinit = vt_deinit,
};

const screen_vtable: screen.VTable = .{ .is_done = vt_is_done, .result = vt_result };

fn as_self(ptr: *anyopaque) *Options {
    return @ptrCast(@alignCast(ptr));
}

fn vt_handle_event(ptr: *anyopaque, ev: neko.Event) void {
    const self: *Options = as_self(ptr);
    const count: i32 = @intCast(self.max_options);
    if (count == 0) return;

    switch (ev) {
        .key_down => |kev| {
            const key = kev.code;
            if (key == 1073741906 or key == 'w') {
                self.selected = @mod(self.selected - 2 + count, count) + 1;
                common.sound.play("blip", 0, -1);
            } else if (key == 1073741905 or key == 's') {
                self.selected = @mod(self.selected, count) + 1;
                common.sound.play("blip", 0, -1);
            } else if (key == 1073741904 or key == 'a' or key == 1073741903 or key == 'd') {
                const dir: i32 = if (key == 1073741903 or key == 'd') 1 else -1;
                self.adjust(dir);
            } else if (key == 13 or key == 32) {
                const kind = self.options[@intCast(self.selected - 1)].kind;
                if (kind == .back) {
                    common.sound.play("select", 0, -1);
                    self.apply_settings();
                    self.result = "back";
                    self.done = true;
                } else {
                    self.adjust(1);
                }
            } else if (key == 27) {
                common.sound.play("select", 0, -1);
                self.apply_settings();
                self.result = "back";
                self.done = true;
            }
        },
        .mouse_button_down => |m| handle_click(self, m.x, m.y),
        else => {},
    }
}

fn handle_click(self: *Options, mx: i32, my: i32) void {
    const panel_x: i32 = 40;
    const panel_w: i32 = constants.SCREEN_WIDTH - 80;

    var i: i32 = 0;
    while (i < @as(i32, @intCast(self.max_options))) : (i += 1) {
        const y: i32 = 150 + i * ITEM_H - @as(i32, @intFromFloat(self.scroll_offset));
        if (my >= y - 9 and my <= y + 40 and mx >= panel_x + 25 and mx <= panel_x + panel_w - 25) {
            self.selected = i + 1;
            const kind = self.options[@intCast(i)].kind;

            if (kind == .back) {
                common.sound.play("select", 0, -1);
                self.apply_settings();
                self.result = "back";
                self.done = true;
                return;
            }

            const value_x: i32 = 500;
            switch (kind) {
                .resolution, .language, .quality, .render => self.adjust(if (mx < value_x) -1 else 1),
                .fullscreen, .show_fps, .vsync, .discord_rpc => self.adjust(1),
                .backend => {},
                .master_volume, .sfx_volume, .music_volume => {
                    const bar_x: i32 = value_x - 10;
                    const bar_w: i32 = 200;
                    const ratio: f32 = @max(0.0, @min(1.0, @as(f32, @floatFromInt(mx - bar_x)) / @as(f32, @floatFromInt(bar_w))));
                    const v: i32 = @intFromFloat(ratio * 100.0);
                    switch (kind) {
                        .master_volume => self.master_volume = v,
                        .sfx_volume => self.sfx_volume = v,
                        else => self.music_volume = v,
                    }
                    common.sound.play("blip", 0, -1);
                },
                .back => {},
            }
            return;
        }
    }
}

fn vt_update(ptr: *anyopaque, dt: f32) void {
    const self: *Options = as_self(ptr);
    self.timer += dt;
    self.bg_scroll += dt * 35.0;

    const visible_h: i32 = constants.SCREEN_HEIGHT - 200;
    const content_h: i32 = @as(i32, @intCast(self.max_options)) * ITEM_H;
    const target_item_y: i32 = (self.selected - 1) * ITEM_H;

    if (content_h > visible_h) {
        const max_scroll: i32 = content_h - visible_h;
        if (target_item_y < @as(i32, @intFromFloat(self.scroll_offset))) {
            self.scroll_target = @floatFromInt(target_item_y);
        } else if (target_item_y + ITEM_H > @as(i32, @intFromFloat(self.scroll_offset)) + visible_h) {
            self.scroll_target = @floatFromInt(target_item_y - visible_h + ITEM_H);
        }
        self.scroll_target = @max(0.0, @min(@as(f32, @floatFromInt(max_scroll)), self.scroll_target));
    } else {
        self.scroll_target = 0;
    }

    self.scroll_offset = self.scroll_offset + (self.scroll_target - self.scroll_offset) * @min(1.0, 12.0 * dt);
    self.highlight_y = 150.0 + @as(f32, @floatFromInt(self.selected - 1)) * @as(f32, @floatFromInt(ITEM_H)) - 9.0 - self.scroll_offset;

    var i: usize = 0;
    while (i < self.max_options) : (i += 1) {
        const target: f32 = if (@as(i32, @intCast(i)) + 1 == self.selected) 1.0 else 0.0;
        self.item_glows[i] = self.item_glows[i] + (target - self.item_glows[i]) * @min(1.0, 8.0 * dt);
    }
}

fn vt_draw(ptr: *anyopaque, at: neko.Point) void {
    _ = at;
    const self: *Options = as_self(ptr);

    neko.draw.clear(neko.Color{ .r = 5, .g = 5, .b = 12 });

    // Animated grid.
    const grid_size: i32 = 80;
    const off_x: i32 = @intFromFloat(@mod(self.bg_scroll, 80.0));
    const off_y: i32 = @intFromFloat(@mod(self.bg_scroll * 0.4, 80.0));

    var y: i32 = off_y;
    while (y < constants.SCREEN_HEIGHT) : (y += grid_size) {
        const a: u8 = @intFromFloat(12.0 + 8.0 * @sin(self.timer * 0.5 + @as(f32, @floatFromInt(y)) * 0.01));
        neko.draw.line(0, y, constants.SCREEN_WIDTH, y, neko.Color{ .r = 90, .g = 130, .b = 255, .a = a });
    }
    var x: i32 = off_x;
    while (x < constants.SCREEN_WIDTH) : (x += grid_size) {
        const a: u8 = @intFromFloat(12.0 + 8.0 * @cos(self.timer * 0.5 + @as(f32, @floatFromInt(x)) * 0.01));
        neko.draw.line(x, 0, x, constants.SCREEN_HEIGHT, neko.Color{ .r = 90, .g = 130, .b = 255, .a = a });
    }

    neko.effect.noise(0, 0, constants.SCREEN_WIDTH, constants.SCREEN_HEIGHT, 0.006);

    const panel_x: i32 = 40;
    const panel_y: i32 = 30;
    const panel_w: i32 = constants.SCREEN_WIDTH - 80;
    const panel_h: i32 = constants.SCREEN_HEIGHT - 70;
    neko.draw.rect(neko.Rect{ .x = panel_x, .y = panel_y, .w = panel_w, .h = panel_h }, neko.Color{ .r = 20, .g = 25, .b = 45, .a = 180 }, true);

    const border_pulse: f32 = 0.5 + 0.5 * @sin(self.timer * 1.2);
    const border_a: u8 = @intFromFloat(30.0 + 15.0 * border_pulse);
    neko.draw.rect(neko.Rect{ .x = panel_x - 2, .y = panel_y - 2, .w = panel_w + 4, .h = panel_h + 4 }, neko.Color{ .r = 100, .g = 180, .b = 255, .a = border_a }, false);

    neko.sprite.text(neko.localization.text("options"), 70, 56, neko.sprite.Options{
        .size = 42,
        .color = neko.Color{ .r = 255, .g = 255, .b = 255 },
    });
    neko.sprite.text("SYSTEM CONFIGURATION", 72, 98, neko.sprite.Options{
        .size = 12,
        .color = neko.Color{ .r = 100, .g = 180, .b = 255, .a = 180 },
    });

    const hl_y: i32 = @intFromFloat(self.highlight_y);
    const hl_pulse: f32 = 0.8 + 0.2 * @sin(self.timer * 5.0);
    neko.draw.rect(neko.Rect{ .x = 65, .y = hl_y, .w = panel_w - 50, .h = 46 }, neko.Color{ .r = 100, .g = 180, .b = 255, .a = @intFromFloat(35.0 * hl_pulse) }, false);
    neko.draw.rect(neko.Rect{ .x = 65, .y = hl_y, .w = 4, .h = 46 }, neko.Color{ .r = 100, .g = 180, .b = 255 }, true);

    var i: usize = 0;
    while (i < self.max_options) : (i += 1) {
        const item = self.options[i];
        const y0: i32 = 150 + @as(i32, @intCast(i)) * ITEM_H - @as(i32, @intFromFloat(self.scroll_offset));
        if (y0 < 130 or y0 > constants.SCREEN_HEIGHT - 80) continue;

        const glow: f32 = self.item_glows[i];
        const tc: u8 = @intFromFloat(lerp_f(140, 255, glow));
        const is_sel: bool = @as(i32, @intCast(i)) + 1 == self.selected;

        neko.sprite.text(item.label, 80, y0, neko.sprite.Options{
            .size = 24,
            .color = neko.Color{ .r = tc, .g = tc, .b = tc + @as(u8, @intFromFloat(20.0 * glow)) },
        });

        draw_value(self, item.kind, y0, is_sel, tc, glow);
    }

    neko.sprite.text(neko.localization.text("help_input"), 70, constants.SCREEN_HEIGHT - 55, neko.sprite.Options{
        .size = 14,
        .color = neko.Color{ .r = 90, .g = 110, .b = 140, .a = 180 },
    });

    neko.effect.scanlines(0, 0, constants.SCREEN_WIDTH, constants.SCREEN_HEIGHT, 14);
}

fn draw_value(self: *Options, kind: Kind, y: i32, is_sel: bool, tc: u8, glow: f32) void {
    switch (kind) {
        .resolution => {
            const r = self.resolutions[@intCast(self.current_res_idx)];
            var buf: [32]u8 = undefined;
            const s = fmt.bufPrint(&buf, "< {d}x{d} >", .{ r.w, r.h }) catch return;
            toggle_color(s, y, is_sel);
        },
        .language => {
            toggle_color(if (self.lang == .pt) "< Português >" else "< English >", y, is_sel);
        },
        .quality => {
            const low = neko.localization.text("low");
            const high = neko.localization.text("high");
            if (self.quality == .low) {
                var buf: [64]u8 = undefined;
                const s = fmt.bufPrint(&buf, "< {s} >", .{low}) catch return;
                toggle_color(s, y, is_sel);
            } else {
                var buf: [64]u8 = undefined;
                const s = fmt.bufPrint(&buf, "< {s} >", .{high}) catch return;
                toggle_color(s, y, is_sel);
            }
        },
        .fullscreen, .show_fps, .vsync, .discord_rpc => {
            const on: bool = switch (kind) {
                .fullscreen => self.is_fullscreen,
                .show_fps => self.show_fps,
                .vsync => self.vsync,
                .discord_rpc => self.discord_rpc,
                else => false,
            };
            var r: u8 = if (on) 100 else 255;
            var g: u8 = if (on) 255 else 100;
            var b: u8 = if (on) 150 else 120;
            if (!is_sel) {
                r = @intFromFloat(@as(f32, @floatFromInt(r)) * 0.6);
                g = @intFromFloat(@as(f32, @floatFromInt(g)) * 0.6);
                b = @intFromFloat(@as(f32, @floatFromInt(b)) * 0.6);
            }
            const val = if (on) neko.localization.text("on") else neko.localization.text("off");
            neko.sprite.text(val, 500, y + 2, neko.sprite.Options{
                .size = 22,
                .color = neko.Color{ .r = r, .g = g, .b = b },
            });
        },
        .master_volume, .sfx_volume, .music_volume => {
            const value: i32 = switch (kind) {
                .master_volume => self.master_volume,
                .sfx_volume => self.sfx_volume,
                else => self.music_volume,
            };
            draw_slider(value, y, is_sel, tc, glow);
        },
        .backend => toggle_color(neko.backend_kind.name, y, is_sel),
        .render => {
            if (self.render_count > 0) {
                var rbuf: [64]u8 = undefined;
                const s = fmt.bufPrint(&rbuf, "< {s} >", .{self.renders[@intCast(self.render_idx)]}) catch return;
                toggle_color(s, y, is_sel);
            }
        },
        .back => {},
    }
}

fn toggle_color(str: []const u8, y: i32, is_sel: bool) void {
    const r: u8 = if (is_sel) 100 else 70;
    const g: u8 = if (is_sel) 220 else 150;
    const b: u8 = if (is_sel) 255 else 180;
    neko.sprite.text(str, 500, y + 2, neko.sprite.Options{
        .size = 22,
        .color = neko.Color{ .r = r, .g = g, .b = b },
    });
}

fn draw_slider(value: i32, y: i32, is_sel: bool, tc: u8, glow: f32) void {
    const bar_x: i32 = 500;
    const bar_w: i32 = 200;
    const bar_h: i32 = 10;
    const bar_y: i32 = y + 12;

    neko.draw.rect(neko.Rect{ .x = bar_x, .y = bar_y, .w = bar_w, .h = bar_h }, neko.Color{ .r = 40, .g = 50, .b = 70 }, true);
    const fill_w: i32 = @divTrunc(bar_w * value, 100);
    const sel_r: u8 = if (is_sel) 140 else 100;
    const sel_g: u8 = if (is_sel) 230 else 180;
    const sel_b: u8 = if (is_sel) 255 else 220;
    neko.draw.rect(neko.Rect{ .x = bar_x, .y = bar_y, .w = fill_w, .h = bar_h }, neko.Color{ .r = sel_r, .g = sel_g, .b = sel_b }, true);

    neko.draw.rect(neko.Rect{ .x = bar_x + fill_w - 4, .y = bar_y - 3, .w = 8, .h = 16 }, neko.Color{ .r = 255, .g = 255, .b = 255 }, true);

    var buf: [8]u8 = undefined;
    const label = fmt.bufPrint(&buf, "{d}%%", .{value}) catch return;
    neko.sprite.text(label, bar_x + bar_w + 15, y + 2, neko.sprite.Options{
        .size = 20,
        .color = neko.Color{ .r = tc, .g = tc, .b = tc + @as(u8, @intFromFloat(20.0 * glow)) },
    });
}

fn vt_is_done(ptr: *anyopaque) bool {
    const self: *Options = as_self(ptr);
    return self.done;
}

fn vt_result(ptr: *anyopaque) []const u8 {
    const self: *Options = as_self(ptr);
    return self.result;
}

fn vt_deinit(ptr: *anyopaque, allocator: Allocator) void {
    const self: *Options = as_self(ptr);
    allocator.destroy(self);
}
