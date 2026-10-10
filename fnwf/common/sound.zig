//! Named sound playback — port of `core/SoundManager`.
//!
//! Sounds are looked up by logical name ("door", "blip", …), loaded on first
//! use from `<assets_dir>/audio/<file>` and cached.

const std: type = @import("std");
const mem: type = std.mem;
const fmt: type = std.fmt;
const neko: type = @import("neko");

const SoundMap: type = std.StringHashMapUnmanaged(neko.SoundHandle);

var cache: SoundMap = .empty;
var menu_channel: i32 = -1;
var breathing_channel: i32 = -1;

const SoundFile: type = struct {
    name: []const u8,
    file: []const u8,
};

const FILES: []const SoundFile = &.{
    .{ .name = "door_open", .file = "portas.ogg" },
    .{ .name = "door_close", .file = "portas.ogg" },
    .{ .name = "door", .file = "portas.ogg" },
    .{ .name = "light", .file = "trocar_camera.ogg" },
    .{ .name = "footstep", .file = "passos.ogg" },
    .{ .name = "footsteps_1", .file = "passos.ogg" },
    .{ .name = "footsteps_2", .file = "passos.ogg" },
    .{ .name = "footsteps_3", .file = "passos.ogg" },
    .{ .name = "footsteps_4", .file = "passos.ogg" },
    .{ .name = "breathing", .file = "usando_a_mascara.ogg" },
    .{ .name = "mask_on", .file = "colocar_mascara.ogg" },
    .{ .name = "mask_off", .file = "retirar_mascara.ogg" },
    .{ .name = "blip", .file = "trocar_camera.ogg" },
    .{ .name = "select", .file = "trocar_camera.ogg" },
    .{ .name = "notification", .file = "trocar_camera.ogg" },
    .{ .name = "camera", .file = "trocar_camera.ogg" },
    .{ .name = "clock", .file = "trocar_camera.ogg" },
    .{ .name = "win", .file = "noite_concluida.ogg" },
    .{ .name = "noite_concluida", .file = "noite_concluida.ogg" },
    .{ .name = "vent", .file = "ventilacao.ogg" },
    .{ .name = "window_scare", .file = "animatronic_na_porta.ogg" },
    .{ .name = "animatronic_door", .file = "animatronic_na_porta.ogg" },
    .{ .name = "jumpscare", .file = "animatronic_na_porta.ogg" },
    .{ .name = "stinger", .file = "animatronic_na_porta.ogg" },
    .{ .name = "power_out", .file = "animatronic_na_porta.ogg" },
};

fn mapped_file(name: []const u8) ?[]const u8 {
    for (FILES) |f| {
        if (mem.eql(u8, f.name, name)) return f.file;
    }
    return null;
}

/// Returns the cached handle, loading and caching it if needed.
fn get_or_load(name: []const u8) ?neko.SoundHandle {
    if (cache.get(name)) |handle| return handle;

    var file_buf: [256]u8 = undefined;
    const file: []const u8 = mapped_file(name) orelse
        (fmt.bufPrint(&file_buf, "{s}.ogg", .{name}) catch return null);

    var path_buf: [512]u8 = undefined;
    const path = fmt.bufPrint(&path_buf, "{s}/audio/{s}", .{ neko.assets_dir(), file }) catch return null;

    const handle = neko.sound.load(path) orelse return null;

    const key = neko.allocator().dupe(u8, name) catch return handle;
    cache.put(neko.allocator(), key, handle) catch neko.allocator().free(key);
    return handle;
}

/// Loads every known sound up front (cheap playback later).
pub fn preload_all() void {
    for (FILES) |f| {
        _ = get_or_load(f.name);
    }
    _ = get_or_load("ambient");
    _ = get_or_load("menu_ambient");
}

/// Plays a sound by name on `channel` (-1 = first free), looping `loops` times
/// (-1 = forever).
pub fn play(name: []const u8, loops: i32, channel: i32) void {
    const handle = get_or_load(name) orelse return;
    _ = neko.sound.play(handle, loops, channel);
}

pub fn stop_channel(channel: i32) void {
    neko.sound.stop_channel(channel);
}

pub fn stop_all() void {
    neko.sound.stop_all();
}

pub fn play_menu_ambient() void {
    menu_channel = 0;
    play("menu_ambient", -1, 0);
}

pub fn stop_menu_ambient() void {
    if (menu_channel != -1) stop_channel(menu_channel);
}

pub fn play_ambient_loop() void {
    play("ambient", -1, 1);
}

pub fn stop_ambient() void {
    stop_channel(1);
}

pub fn play_scary_stinger() void {
    play("stinger", 0, -1);
}

pub fn play_camera_switch() void {
    play("blip", 0, -1);
}

pub fn play_door_sound() void {
    play("door", 0, -1);
}

pub fn play_light_sound() void {
    play("light", 0, -1);
}

pub fn play_jumpscare_sound() void {
    play("jumpscare", 0, -1);
}

pub fn play_window_scare() void {
    play("window_scare", 0, -1);
}

pub fn play_footstep_random() void {
    const idx: i32 = neko.random.int_range(1, 4);
    var buf: [32]u8 = undefined;
    const name = fmt.bufPrint(&buf, "footsteps_{d}", .{idx}) catch return;
    // The name is dynamic, so cache it under a stable key via the file map.
    _ = name;
    const handle = get_or_load_dynamic(idx) orelse return;
    _ = neko.sound.play(handle, 0, -1);
}

fn get_or_load_dynamic(idx: i32) ?neko.SoundHandle {
    const names = [_][]const u8{ "footsteps_1", "footsteps_2", "footsteps_3", "footsteps_4" };
    const i: usize = @intCast(@max(0, @min(3, idx - 1)));
    return get_or_load(names[i]);
}

pub fn play_mask_breathing() void {
    if (breathing_channel == -1) {
        breathing_channel = 5;
        play("breathing", -1, 5);
    }
}

pub fn stop_mask_breathing() void {
    if (breathing_channel != -1) {
        stop_channel(breathing_channel);
        breathing_channel = -1;
    }
}

pub fn master_volume(vol: i32) void {
    neko.sound.master_volume(vol);
}

pub fn sfx_volume(vol: i32) void {
    neko.sound.sfx_volume(vol);
}

pub fn music_volume(vol: i32) void {
    neko.sound.music_volume(vol);
}

/// Frees the name cache. Call once at shutdown.
pub fn deinit() void {
    var it = cache.iterator();
    while (it.next()) |entry| {
        neko.allocator().free(entry.key_ptr.*);
    }
    cache.deinit(neko.allocator());
}
