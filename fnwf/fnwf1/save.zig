// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Renan Lucas Vieira Hilário

//! FNWF 1 — progress and settings persistence (`~/.fnwf1`).

const std: type = @import("std");
const fmt: type = std.fmt;
const neko: type = @import("neko");

const Allocator: type = std.mem.Allocator;

const PROGRESS_FILE: []const u8 = "progress.dat";
const SETTINGS_FILE: []const u8 = "settings.dat";
const MAGIC: u32 = 0x464E5731; // "FNW1"

/// Campaign progress.
pub const Progress: type = struct {
    completed_nights: i32 = 0,
};

/// Player settings.
pub const Settings: type = struct {
    master_volume: i32 = 80,
    sfx_volume: i32 = 100,
    music_volume: i32 = 70,
    quality_high: bool = true,
    /// Preferred render driver (e.g. "opengl"); empty = backend default.
    render: []const u8 = "",
};

pub var progress: Progress = .{};
pub var settings: Settings = .{};

var render_buf: [32]u8 = undefined;

var dir: []u8 = &.{};

/// Sets the save directory to `<home>/.fnwf1`.
pub fn init(io_: std.Io, home: ?[]const u8, allocator: Allocator) void {
    _ = io_;
    dir = fmt.allocPrint(allocator, "{s}/.fnwf1", .{home orelse "."}) catch &.{};
}

pub fn deinit(allocator: Allocator) void {
    if (dir.len > 0) allocator.free(dir);
    dir = &.{};
}

pub fn load(allocator: Allocator) void {
    if (neko.save.read_file(allocator, dir, PROGRESS_FILE, 1 << 16)) |bytes| {
        defer allocator.free(bytes);
        var r = neko.save.Reader.init(bytes);
        const magic = r.uint() catch return;
        if (magic != MAGIC) return;
        progress.completed_nights = r.int() catch return;
    }
    if (neko.save.read_file(allocator, dir, SETTINGS_FILE, 1 << 16)) |bytes| {
        defer allocator.free(bytes);
        var r = neko.save.Reader.init(bytes);
        const magic = r.uint() catch return;
        if (magic != MAGIC) return;
        settings.master_volume = r.int() catch return;
        settings.sfx_volume = r.int() catch return;
        settings.music_volume = r.int() catch return;
        settings.quality_high = r.flag() catch return;
        if (r.remaining() >= 4) {
            const rr = r.str_u64() catch "";
            const n: usize = @min(rr.len, render_buf.len);
            @memcpy(render_buf[0..n], rr[0..n]);
            settings.render = render_buf[0..n];
        }
    }
}

pub fn save_progress() void {
    var w = neko.save.Writer.init(neko.allocator());
    defer w.deinit();
    w.uint(MAGIC) catch return;
    w.int(progress.completed_nights) catch return;
    _ = neko.save.write_file(dir, PROGRESS_FILE, w.slice());
}

pub fn save_settings() void {
    var w = neko.save.Writer.init(neko.allocator());
    defer w.deinit();
    w.uint(MAGIC) catch return;
    w.int(settings.master_volume) catch return;
    w.int(settings.sfx_volume) catch return;
    w.int(settings.music_volume) catch return;
    w.flag(settings.quality_high) catch return;
    w.str_u64(settings.render) catch return;
    _ = neko.save.write_file(dir, SETTINGS_FILE, w.slice());
}
