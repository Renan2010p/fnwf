//! Player settings — port of `core/SettingsManager`.
//!
//! Binary-compatible with the C++ `config.dat` (same field order and sizes).

const std: type = @import("std");
const neko: type = @import("neko");

const FILE: []const u8 = "config.dat";

/// UI language.
pub const Language: type = enum {
    pt,
    en,

    pub fn code(self: Language) []const u8 {
        return switch (self) {
            .pt => "pt",
            .en => "en",
        };
    }

    pub fn from_code(text: []const u8) ?Language {
        if (std.mem.eql(u8, text, "pt")) return .pt;
        if (std.mem.eql(u8, text, "en")) return .en;
        return null;
    }
};

/// Render quality.
pub const Quality: type = enum {
    high,
    low,

    pub fn code(self: Quality) []const u8 {
        return switch (self) {
            .high => "high",
            .low => "low",
        };
    }

    pub fn from_code(text: []const u8) ?Quality {
        if (std.mem.eql(u8, text, "high")) return .high;
        if (std.mem.eql(u8, text, "low")) return .low;
        return null;
    }
};

/// The player's settings.
pub const Settings: type = struct {
    language: Language = .en,
    show_fps: bool = false,
    vsync: bool = true,
    resolution_w: i32 = 1280,
    resolution_h: i32 = 720,
    fullscreen: bool = false,
    quality: Quality = .high,
    discord_rpc: bool = true,
    master_volume: i32 = 80,
    sfx_volume: i32 = 100,
    music_volume: i32 = 70,
    /// Preferred render driver (e.g. "opengl"); empty = backend default.
    render: []const u8 = "",
};

var current_settings: Settings = Settings{};
var render_buf: [32]u8 = undefined;

/// The live settings. Mutate the returned struct, then call `save`.
pub fn get() *Settings {
    return &current_settings;
}

/// Loads `config.dat`; missing or corrupt files leave the defaults.
pub fn load() void {
    const allocator: std.mem.Allocator = neko.allocator();
    const bytes = neko.save.read_file(allocator, ".", FILE, 1 << 20) orelse return;
    defer allocator.free(bytes);

    var r = neko.save.Reader.init(bytes);
    var s = Settings{};

    const lang = r.str_u64() catch return;
    s.language = Language.from_code(lang) orelse .en;
    s.show_fps = r.flag() catch return;
    s.vsync = r.flag() catch return;
    s.resolution_w = r.int() catch return;
    s.resolution_h = r.int() catch return;
    s.fullscreen = r.flag() catch return;
    const qual = r.str_u64() catch return;
    s.quality = Quality.from_code(qual) orelse .high;
    s.discord_rpc = r.flag() catch return;

    if (r.remaining() >= 4) s.master_volume = r.int() catch s.master_volume;
    if (r.remaining() >= 4) s.sfx_volume = r.int() catch s.sfx_volume;
    if (r.remaining() >= 4) s.music_volume = r.int() catch s.music_volume;

    if (r.remaining() >= 4) {
        const rr = r.str_u64() catch "";
        const n: usize = @min(rr.len, render_buf.len);
        @memcpy(render_buf[0..n], rr[0..n]);
        s.render = render_buf[0..n];
    }

    current_settings = s;
}

/// Writes `config.dat`.
pub fn save() void {
    var w = neko.save.Writer.init(neko.allocator());
    defer w.deinit();

    w.str_u64(current_settings.language.code()) catch return;
    w.flag(current_settings.show_fps) catch return;
    w.flag(current_settings.vsync) catch return;
    w.int(current_settings.resolution_w) catch return;
    w.int(current_settings.resolution_h) catch return;
    w.flag(current_settings.fullscreen) catch return;
    w.str_u64(current_settings.quality.code()) catch return;
    w.flag(current_settings.discord_rpc) catch return;
    w.int(current_settings.master_volume) catch return;
    w.int(current_settings.sfx_volume) catch return;
    w.int(current_settings.music_volume) catch return;
    w.str_u64(current_settings.render) catch return;

    _ = neko.save.write_file(".", FILE, w.slice());
}
