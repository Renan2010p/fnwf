// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Renan Lucas Vieira Hilário

//! The story prologue — port of `game1/states/StoryState`.
//!
//! A Discord-style chat builds one message per key press (ENTER/SPACE or a
//! click), then fades out. Built from the `story_nX_mY` translation keys.

const std: type = @import("std");
const fmt: type = std.fmt;
const mem: type = std.mem;
const neko: type = @import("neko");
const common: type = @import("common");

const screen: type = @import("../screen.zig");
const constants: type = @import("../config/constants.zig");

const Allocator: type = std.mem.Allocator;

const MAX_MESSAGES: usize = 48;
const SIDEBAR_W: i32 = 240;
const WRAP_SIZE: u32 = 14;

const CEDRO_COLOR: neko.Color = neko.Color{ .r = 140, .g = 110, .b = 80 };
const RENAN_COLOR: neko.Color = neko.Color{ .r = 100, .g = 180, .b = 255 };

const Kind: type = enum { chat, title };

const Message: type = struct {
    kind: Kind,
    user: []const u8 = "",
    avatar: []const u8 = "",
    color: neko.Color = neko.Color{ .r = 220, .g = 220, .b = 220 },
    text: []const u8,
};

/// The Discord chat prologue.
pub const Story: type = struct {
    node: neko.scene.Node,
    night: i32,

    phase: i32 = 0,
    fade_alpha: i32 = 255,
    done: bool = false,
    timer: f32 = 0,

    messages: [MAX_MESSAGES]Message = undefined,
    message_count: usize = 0,
    visible_messages: usize = 0,
    scroll_y: f32 = 0,
    target_scroll: f32 = 0,

    wrap_font: i64 = -1,
    title_buf: [64]u8 = undefined,

    pub fn create(allocator: Allocator, night: i32) !*neko.scene.Node {
        const self: *Story = try allocator.create(Story);
        self.* = Story{
            .node = neko.scene.Node{
                .ptr = @ptrCast(self),
                .vtable = &vtable,
                .allocator = allocator,
                .name = "story",
            },
            .night = night,
        };
        screen.attach(self, &screen_vtable);

        neko.sprite.load("cedro");
        neko.sprite.load("renan");
        neko.sprite.load("mafia");

        var path_buf: [512]u8 = undefined;
        const path = fmt.bufPrint(&path_buf, "{s}/font/font.ttf", .{neko.assets_dir()}) catch "";
        self.wrap_font = neko.text.load_font(path, @intCast(WRAP_SIZE));

        self.build_messages();
        return &self.node;
    }

    // ── Message building ─────────────────────────────────────────────

    fn lookup(key: []const u8) []const u8 {
        return neko.localization.text(key);
    }

    fn key_for(self: *const Story, suffix: []const u8, buf: []u8) []const u8 {
        return fmt.bufPrint(buf, "story_n{d}_{s}", .{ self.night, suffix }) catch suffix;
    }

    fn row(self: *Story, user: []const u8, avatar: []const u8, color: neko.Color, key: []const u8) Message {
        var buf: [48]u8 = undefined;
        return Message{ .kind = .chat, .user = user, .avatar = avatar, .color = color, .text = lookup(self.key_for(key, &buf)) };
    }

    fn push(self: *Story, m: Message) void {
        if (self.message_count >= MAX_MESSAGES) return;
        self.messages[self.message_count] = m;
        self.message_count += 1;
    }

    fn push_title(self: *Story, text: []const u8) void {
        self.push(Message{ .kind = .title, .text = text });
    }

    fn night_title(self: *Story) []const u8 {
        return fmt.bufPrint(&self.title_buf, "{s} {d}", .{ neko.localization.text("night"), self.night }) catch "";
    }

    fn build_messages(self: *Story) void {
        self.message_count = 0;
        const cedro: []const u8 = "Cedro";
        const cientista: []const u8 = "Cientista";

        if (self.night == 1) {
            self.push(self.row(cedro, "cedro", CEDRO_COLOR, "m0"));
            self.push(self.row(cedro, "cedro", CEDRO_COLOR, "m1"));
            self.push(self.row(cedro, "cedro", CEDRO_COLOR, "m2"));
            self.push(self.row(cientista, "renan", RENAN_COLOR, "m3"));
            self.push(self.row(cedro, "cedro", CEDRO_COLOR, "m4"));
            self.push_title(self.night_title());
            self.push(self.row(cedro, "cedro", CEDRO_COLOR, "m5"));
            self.push(self.row(cedro, "cedro", CEDRO_COLOR, "m6"));
            self.push(self.row(cientista, "renan", RENAN_COLOR, "m7"));
            self.push(self.row(cedro, "cedro", CEDRO_COLOR, "m8"));
            self.push(self.row(cedro, "cedro", CEDRO_COLOR, "m9"));
            self.push(self.row(cedro, "cedro", CEDRO_COLOR, "m10"));
            self.push(self.row(cientista, "renan", RENAN_COLOR, "m11"));
            self.push(self.row(cedro, "cedro", CEDRO_COLOR, "m12"));
            self.push(self.row(cientista, "renan", RENAN_COLOR, "m13"));
            return;
        }

        if (self.night >= 2 and self.night <= 5) {
            self.push(self.row(cedro, "cedro", CEDRO_COLOR, "m0"));
            self.push(self.row(cientista, "renan", RENAN_COLOR, "m1"));
            self.push(self.row(cedro, "cedro", CEDRO_COLOR, "m2"));
            self.push_title(self.night_title());

            var i: i32 = 3;
            while (true) : (i += 1) {
                var buf: [48]u8 = undefined;
                const suffix = fmt.bufPrint(&buf, "m{d}", .{i}) catch break;
                var kbuf: [48]u8 = undefined;
                const key = self.key_for(suffix, &kbuf);
                if (mem.eql(u8, lookup(key), key)) break;

                const is_cedro: bool = @mod(i, 2) != 0;
                const speaker: []const u8 = if (is_cedro) cedro else cientista;
                const avatar: []const u8 = if (is_cedro) "cedro" else "renan";
                const color: neko.Color = if (is_cedro) CEDRO_COLOR else RENAN_COLOR;
                self.push(Message{ .kind = .chat, .user = speaker, .avatar = avatar, .color = color, .text = lookup(key) });
            }
            return;
        }

        if (self.night == 6) {
            self.push(self.row(cedro, "cedro", CEDRO_COLOR, "m0"));
            self.push(self.row(cientista, "renan", RENAN_COLOR, "m1"));
            self.push(self.row(cedro, "cedro", CEDRO_COLOR, "m2"));
            self.push(self.row(cedro, "cedro", CEDRO_COLOR, "m3"));
            self.push(self.row(cientista, "renan", RENAN_COLOR, "m4"));
            self.push_title(self.night_title());
            self.push(self.row(cedro, "cedro", CEDRO_COLOR, "m5"));
            return;
        }

        if (self.night == 7) {
            self.push(self.row(cedro, "cedro", CEDRO_COLOR, "m0"));
            self.push(self.row(cientista, "renan", RENAN_COLOR, "m1"));
            self.push(self.row(cedro, "cedro", CEDRO_COLOR, "m2"));
            self.push_title(neko.localization.text("custom_night"));
            self.push(self.row(cedro, "cedro", CEDRO_COLOR, "m3"));
            self.push(self.row(cientista, "renan", RENAN_COLOR, "m4"));
            self.push(self.row(cedro, "cedro", CEDRO_COLOR, "m5"));
            return;
        }

        self.push_title(self.night_title());
    }

    // ── Text wrapping ────────────────────────────────────────────────

    fn text_width(self: *const Story, s: []const u8) i32 {
        if (self.wrap_font >= 0) {
            if (neko.text.size(s, @intCast(self.wrap_font))) |sz| return sz.x;
        }
        return @divTrunc(@as(i32, @intCast(s.len)) * @as(i32, @intCast(WRAP_SIZE)), 2);
    }

    /// Counts the wrapped lines `text` needs at `max_width`.
    fn count_lines(self: *const Story, text: []const u8, max_width: i32) usize {
        var iter = WrapIter{ .self = self, .text = text, .max_width = max_width };
        var n: usize = 0;
        while (iter.next()) |_| n += 1;
        return n;
    }

    /// Draws `text` wrapped into `max_width`, one line every `line_h` pixels.
    fn draw_wrapped(
        self: *const Story,
        text: []const u8,
        x: i32,
        y_in: i32,
        max_width: i32,
        line_h: i32,
        color: neko.Color,
    ) void {
        var y: i32 = y_in;
        var iter = WrapIter{ .self = self, .text = text, .max_width = max_width };
        while (iter.next()) |line| {
            neko.sprite.text(line, x, y, .{ .size = WRAP_SIZE, .color = color });
            y += line_h;
        }
    }

    // ── Layout ───────────────────────────────────────────────────────

    fn update_scroll_target(self: *Story) void {
        const cwl: i32 = constants.SCREEN_WIDTH - SIDEBAR_W - 100;
        var th: i32 = 15;
        var prev: []const u8 = "";

        var i: usize = 0;
        while (i < self.visible_messages and i < self.message_count) : (i += 1) {
            const msg = self.messages[i];
            if (msg.kind == .title) {
                th += 50;
                prev = "";
            } else {
                const lines: i32 = @intCast(self.count_lines(msg.text, cwl));
                if (mem.eql(u8, prev, msg.user)) {
                    th += 24 * lines;
                } else {
                    const gap: i32 = if (prev.len == 0) 0 else 8;
                    th += gap + 22 + 24 * lines;
                }
                prev = msg.user;
            }
        }

        const va: i32 = constants.SCREEN_HEIGHT - 48 - 80;
        if (th > va) self.target_scroll = @floatFromInt(th - va);
    }
};

/// Yields the wrapped lines of `text` as sub-slices of the original string.
const WrapIter: type = struct {
    self: *const Story,
    text: []const u8,
    max_width: i32,
    pos: usize = 0,

    fn next(self: *WrapIter) ?[]const u8 {
        while (self.pos < self.text.len and self.text[self.pos] == ' ') self.pos += 1;
        if (self.pos >= self.text.len) return null;

        const start: usize = self.pos;
        var line_end: usize = start;
        var scan: usize = start;

        while (scan < self.text.len) {
            var we: usize = scan;
            while (we < self.text.len and self.text[we] != ' ') we += 1;
            const fits: bool = self.self.text_width(self.text[start..we]) <= self.max_width;
            if (fits or line_end == start) {
                line_end = we;
                scan = we;
                while (scan < self.text.len and self.text[scan] == ' ') scan += 1;
            } else break;
        }

        self.pos = line_end;
        return self.text[start..line_end];
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

fn process(ptr: *anyopaque, dt: f32) void {
    const self: *Story = @ptrCast(@alignCast(ptr));
    self.timer += dt;

    if (self.phase == 0) {
        self.fade_alpha = @max(0, self.fade_alpha - @as(i32, @intFromFloat(250.0 * dt)));
        if (self.fade_alpha <= 0) self.phase = 1;
    } else if (self.phase == 1 and self.visible_messages == 0) {
        self.visible_messages = 1;
        self.update_scroll_target();
    } else if (self.phase == 2) {
        self.fade_alpha = @min(255, self.fade_alpha + @as(i32, @intFromFloat(200.0 * dt)));
        if (self.fade_alpha >= 255) self.done = true;
    }

    self.scroll_y = self.scroll_y + (self.target_scroll - self.scroll_y) * 6.0 * dt;
}

fn advance(self: *Story) void {
    if (self.phase == 0) {
        self.phase = 1;
        self.fade_alpha = 0;
    } else if (self.phase == 1) {
        if (self.visible_messages < self.message_count) {
            self.visible_messages += 1;
            self.update_scroll_target();
            common.sound.play("notification", 0, -1);
        } else {
            self.phase = 2;
            self.fade_alpha = 0;
        }
    }
}

fn input(ptr: *anyopaque, ev: neko.Event) void {
    const self: *Story = @ptrCast(@alignCast(ptr));
    switch (ev) {
        .key_down => |k| {
            if (k.code != 13 and k.code != 32) return;
            advance(self);
        },
        .mouse_button_down => advance(self),
        else => {},
    }
}

fn draw(ptr: *anyopaque, at: neko.Point) void {
    _ = at;
    const self: *Story = @ptrCast(@alignCast(ptr));
    const w: i32 = constants.SCREEN_WIDTH;
    const h: i32 = constants.SCREEN_HEIGHT;

    neko.draw.clear(neko.Color{ .r = 54, .g = 57, .b = 63 });
    if (self.phase >= 1) draw_discord(self);
    neko.effect.noise(0, 0, w, h, 0.005);

    if (self.phase == 1) {
        const blink: bool = @mod(@as(i32, @intFromFloat(self.timer * 2)), 2) == 0;
        if (blink) {
            const txt: []const u8 = if (self.visible_messages < self.message_count)
                neko.localization.text("story_skip")
            else
                neko.localization.text("story_start_night");
            neko.sprite.text(txt, @divTrunc(w, 2), h - 20, .{
                .size = 12,
                .center = true,
                .color = neko.Color{ .r = 130, .g = 130, .b = 140 },
            });
        }
    }

    if (self.fade_alpha > 0) {
        neko.draw.rect(neko.Rect{ .x = 0, .y = 0, .w = w, .h = h }, neko.Color{ .r = 54, .g = 57, .b = 63, .a = @intCast(self.fade_alpha) }, true);
    }
}

fn draw_discord(self: *Story) void {
    const w: i32 = constants.SCREEN_WIDTH;
    const h: i32 = constants.SCREEN_HEIGHT;

    neko.draw.rect(neko.Rect{ .x = 0, .y = 0, .w = SIDEBAR_W, .h = h }, neko.Color{ .r = 47, .g = 49, .b = 54 }, true);
    neko.draw.rect(neko.Rect{ .x = 0, .y = 0, .w = SIDEBAR_W, .h = 48 }, neko.Color{ .r = 40, .g = 43, .b = 48 }, true);
    neko.sprite.text(neko.localization.text("discord_server"), 15, 14, .{ .size = 14, .color = neko.Color{ .r = 220, .g = 220, .b = 220 } });
    neko.draw.line(0, 48, SIDEBAR_W, 48, neko.Color{ .r = 30, .g = 33, .b = 36 });

    const chans = [4][]const u8{
        neko.localization.text("chan_general"),
        neko.localization.text("chan_announcements"),
        neko.localization.text("chan_security"),
        neko.localization.text("chan_cameras"),
    };
    for (chans, 0..) |ch, idx0| {
        const idx: i32 = @as(i32, @intCast(idx0)) + 1;
        const y: i32 = 65 + (idx - 1) * 32;
        const selected: bool = idx == 3;
        if (selected) {
            neko.draw.rect(neko.Rect{ .x = 8, .y = y - 4, .w = SIDEBAR_W - 16, .h = 28 }, neko.Color{ .r = 60, .g = 63, .b = 69 }, true);
        }
        const c: u8 = if (selected) 220 else 130;
        neko.sprite.text(ch, 18, y, .{ .size = 13, .color = neko.Color{ .r = c, .g = c, .b = if (selected) 220 else 140 } });
    }

    const cx: i32 = SIDEBAR_W;
    const cw: i32 = w - SIDEBAR_W;
    neko.draw.rect(neko.Rect{ .x = cx, .y = 0, .w = cw, .h = 48 }, neko.Color{ .r = 54, .g = 57, .b = 63 }, true);
    neko.sprite.text(neko.localization.text("discord_channel"), cx + 18, 14, .{ .size = 15, .color = neko.Color{ .r = 220, .g = 220, .b = 220 } });
    neko.draw.line(cx, 48, w, 48, neko.Color{ .r = 40, .g = 43, .b = 48 });

    var my: i32 = 63 - @as(i32, @intFromFloat(self.scroll_y));
    var prev: []const u8 = "";

    var i: usize = 0;
    while (i < self.visible_messages and i < self.message_count) : (i += 1) {
        const msg = self.messages[i];
        if (msg.kind == .title) {
            neko.draw.line(cx + 20, my + 10, w - 20, my + 10, neko.Color{ .r = 72, .g = 75, .b = 81 });
            neko.sprite.text(msg.text, cx + @divTrunc(cw, 2), my + 10, .{ .size = 12, .center = true, .color = neko.Color{ .r = 130, .g = 130, .b = 140 } });
            my += 50;
            prev = "";
            continue;
        }

        const max_w: i32 = cw - 100;
        if (mem.eql(u8, prev, msg.user)) {
            self.draw_wrapped(msg.text, cx + 75, my, max_w, 24, neko.Color{ .r = 220, .g = 220, .b = 220 });
            my += 24 * @as(i32, @intCast(self.count_lines(msg.text, max_w)));
        } else {
            if (prev.len != 0) my += 8;
            const av_size: i32 = 40;
            neko.draw.circle(cx + 20 + @divTrunc(av_size, 2), my + @divTrunc(av_size, 2), @divTrunc(av_size, 2), neko.Color{ .r = 80, .g = 80, .b = 90 }, true);
            neko.sprite.face(msg.avatar, cx + 20, my, av_size, av_size);
            neko.sprite.text(msg.user, cx + 75, my, .{ .size = 14, .color = msg.color });
            my += 22;
            self.draw_wrapped(msg.text, cx + 75, my, max_w, 24, neko.Color{ .r = 220, .g = 220, .b = 220 });
            my += 24 * @as(i32, @intCast(self.count_lines(msg.text, max_w)));
        }
        prev = msg.user;
    }

    const iy: i32 = h - 65;
    neko.draw.rect(neko.Rect{ .x = cx + 16, .y = iy, .w = cw - 32, .h = 44 }, neko.Color{ .r = 64, .g = 68, .b = 75 }, true);
    neko.sprite.text(neko.localization.text("discord_input"), cx + 30, iy + 13, .{ .size = 13, .color = neko.Color{ .r = 100, .g = 100, .b = 110 } });
}

fn is_done(ptr: *anyopaque) bool {
    const self: *Story = @ptrCast(@alignCast(ptr));
    return self.done;
}

fn deinit(ptr: *anyopaque, allocator: Allocator) void {
    const self: *Story = @ptrCast(@alignCast(ptr));
    allocator.destroy(self);
}
