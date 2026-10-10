//! Save files — port of `core/SaveManager` (+ `GameData` / `GameSnapshot`).
//!
//! Binary-compatible with the C++: `~/.fnwf/save.dat` and
//! `~/.fnwf/game_snapshot.dat`, little-endian, same field order and sizes.

const std: type = @import("std");
const fmt: type = std.fmt;
const neko: type = @import("neko");

const locations: type = @import("world/locations.zig");
const CameraId: type = locations.CameraId;
const Location: type = locations.Location;

const Allocator: type = std.mem.Allocator;

pub const SAVE_FILE: []const u8 = "save.dat";
pub const GAME_SNAPSHOT_FILE: []const u8 = "game_snapshot.dat";

const MAX_STRING_LEN: u64 = 1024;
const MAX_ACHIEVEMENTS: u64 = 256;
const MAGIC: u32 = 0x464E5746; // "FNWF"
const VERSION: u32 = 1;

var io: std.Io = undefined;
var dir: []u8 = &.{};

/// Sets the save directory to `<home>/.fnwf`.
pub fn init(io_: std.Io, home: ?[]const u8, allocator: Allocator) void {
    io = io_;
    dir = fmt.allocPrint(allocator, "{s}/.fnwf", .{home orelse "."}) catch &.{};
}

/// Frees the save directory path.
pub fn deinit(allocator: Allocator) void {
    if (dir.len > 0) allocator.free(dir);
    dir = &.{};
}

// ── Data ─────────────────────────────────────────────────────────────────

/// Progress data (mirrors the C++ `GameData`).
pub const GameData: type = struct {
    completed_nights: i32 = 0,
    has_seen_story: bool = false,
    infinite_power: bool = false,
    fast_nights: bool = false,
    achievements: std.ArrayListUnmanaged([]u8) = .empty,

    pub fn deinit(self: *GameData, allocator: Allocator) void {
        for (self.achievements.items) |a| allocator.free(a);
        self.achievements.deinit(allocator);
    }
};

/// Full in-game snapshot (mirrors the C++ `GameSnapshot`). Ids are enums here;
/// they are written as the original strings.
pub const GameSnapshot: type = struct {
    night: i32 = 1,
    custom_ai: std.ArrayListUnmanaged(i32) = .empty,

    time_elapsed: f32 = 0,
    night_duration: f32 = 0,
    current_hour: i32 = 12,

    power: f32 = 100,
    power_usage_level: i32 = 1,
    power_is_dead: bool = false,
    power_dead_timer: f32 = 0,

    door_left_closed: bool = false,
    door_right_closed: bool = false,
    door_left_light: bool = false,
    door_right_light: bool = false,
    door_left_anim: f32 = 0,
    door_right_anim: f32 = 0,

    cam_open: bool = false,
    cam_current: CameraId = .stage,
    cam_mask_open: bool = false,

    office_pan_x: f32 = 0,
    office_vent_light: bool = false,

    mask_on: bool = false,
    oxygen: f32 = 100,
    max_oxygen: f32 = 100,

    is_blackout: bool = false,
    blackout_alpha: f32 = 0,
    blackout_timer: f32 = 0,

    cedro_pos: Location = .stage,
    eser_pos: Location = .stage,
    alice_pos: Location = .stage,
    sonk_pos: Location = .pirate_cove,
    sonk_stage: i32 = 0,

    sonk_charging: bool = false,
    sonk_charge_timer: f32 = 0,

    pub fn deinit(self: *GameSnapshot, allocator: Allocator) void {
        self.custom_ai.deinit(allocator);
    }
};

// ── Legacy save/load ─────────────────────────────────────────────────────

pub fn load_data(allocator: Allocator) GameData {
    var data = GameData{};

    const bytes = neko.save.read_file(allocator, dir, SAVE_FILE, 1 << 20) orelse return data;
    defer allocator.free(bytes);

    var r = neko.save.Reader.init(bytes);
    data.completed_nights = r.int() catch return data;
    data.has_seen_story = r.flag() catch return data;
    data.infinite_power = r.flag() catch return data;
    data.fast_nights = r.flag() catch return data;

    const count = r.size() catch return data;
    if (count > MAX_ACHIEVEMENTS) return data;

    var i: u64 = 0;
    while (i < count) : (i += 1) {
        const len = r.size() catch break;
        if (len > MAX_STRING_LEN) break;
        const s = r.raw(@intCast(len)) catch break;
        const dup = allocator.dupe(u8, s) catch break;
        data.achievements.append(allocator, dup) catch {
            allocator.free(dup);
            break;
        };
    }
    return data;
}

pub fn save_progress(data: GameData) void {
    var w = neko.save.Writer.init(neko.allocator());
    defer w.deinit();

    w.int(data.completed_nights) catch return;
    w.flag(data.has_seen_story) catch return;
    w.flag(data.infinite_power) catch return;
    w.flag(data.fast_nights) catch return;
    w.size(@intCast(data.achievements.items.len)) catch return;
    for (data.achievements.items) |a| {
        w.str_u64(a) catch return;
    }

    _ = neko.save.write_file(dir, SAVE_FILE, w.slice());
}

// ── Snapshot save/load ───────────────────────────────────────────────────

pub fn save_game(snap: GameSnapshot) bool {
    var w = neko.save.Writer.init(neko.allocator());
    defer w.deinit();

    w.uint(MAGIC) catch return false;
    w.uint(VERSION) catch return false;
    w.int(snap.night) catch return false;
    w.uint(@intCast(snap.custom_ai.items.len)) catch return false;
    for (snap.custom_ai.items) |v| w.int(v) catch return false;

    w.real(snap.time_elapsed) catch return false;
    w.real(snap.night_duration) catch return false;
    w.int(snap.current_hour) catch return false;

    w.real(snap.power) catch return false;
    w.int(snap.power_usage_level) catch return false;
    w.flag(snap.power_is_dead) catch return false;
    w.real(snap.power_dead_timer) catch return false;

    w.flag(snap.door_left_closed) catch return false;
    w.flag(snap.door_right_closed) catch return false;
    w.flag(snap.door_left_light) catch return false;
    w.flag(snap.door_right_light) catch return false;
    w.real(snap.door_left_anim) catch return false;
    w.real(snap.door_right_anim) catch return false;

    w.flag(snap.cam_open) catch return false;
    w.str_u32(snap.cam_current.code()) catch return false;
    w.flag(snap.cam_mask_open) catch return false;

    w.real(snap.office_pan_x) catch return false;
    w.flag(snap.office_vent_light) catch return false;

    w.flag(snap.mask_on) catch return false;
    w.real(snap.oxygen) catch return false;
    w.real(snap.max_oxygen) catch return false;

    w.flag(snap.is_blackout) catch return false;
    w.real(snap.blackout_alpha) catch return false;
    w.real(snap.blackout_timer) catch return false;

    w.str_u32(snap.cedro_pos.code()) catch return false;
    w.str_u32(snap.eser_pos.code()) catch return false;
    w.str_u32(snap.alice_pos.code()) catch return false;
    w.str_u32(snap.sonk_pos.code()) catch return false;
    w.int(snap.sonk_stage) catch return false;

    w.flag(snap.sonk_charging) catch return false;
    w.real(snap.sonk_charge_timer) catch return false;

    if (!neko.save.write_file(dir, GAME_SNAPSHOT_FILE, w.slice())) return false;
    return true;
}

pub fn load_game(allocator: Allocator) ?GameSnapshot {
    const bytes = neko.save.read_file(allocator, dir, GAME_SNAPSHOT_FILE, 1 << 20) orelse return null;
    defer allocator.free(bytes);

    var snap = GameSnapshot{};
    errdefer snap.deinit(allocator);

    var r = neko.save.Reader.init(bytes);

    const magic = r.uint() catch return null;
    const version = r.uint() catch return null;
    if (magic != MAGIC or version != VERSION) return null;

    snap.night = r.int() catch return null;

    const ai_count = r.uint() catch return null;
    var i: u32 = 0;
    while (i < ai_count) : (i += 1) {
        const v = r.int() catch return null;
        snap.custom_ai.append(allocator, v) catch return null;
    }

    snap.time_elapsed = r.real() catch return null;
    snap.night_duration = r.real() catch return null;
    snap.current_hour = r.int() catch return null;

    snap.power = r.real() catch return null;
    snap.power_usage_level = r.int() catch return null;
    snap.power_is_dead = r.flag() catch return null;
    snap.power_dead_timer = r.real() catch return null;

    snap.door_left_closed = r.flag() catch return null;
    snap.door_right_closed = r.flag() catch return null;
    snap.door_left_light = r.flag() catch return null;
    snap.door_right_light = r.flag() catch return null;
    snap.door_left_anim = r.real() catch return null;
    snap.door_right_anim = r.real() catch return null;

    snap.cam_open = r.flag() catch return null;
    const cam_code = r.str_u32() catch return null;
    snap.cam_current = CameraId.from_code(cam_code) orelse .stage;
    snap.cam_mask_open = r.flag() catch return null;

    snap.office_pan_x = r.real() catch return null;
    snap.office_vent_light = r.flag() catch return null;

    snap.mask_on = r.flag() catch return null;
    snap.oxygen = r.real() catch return null;
    snap.max_oxygen = r.real() catch return null;

    snap.is_blackout = r.flag() catch return null;
    snap.blackout_alpha = r.real() catch return null;
    snap.blackout_timer = r.real() catch return null;

    const cedro = r.str_u32() catch return null;
    const eser = r.str_u32() catch return null;
    const alice = r.str_u32() catch return null;
    const sonk = r.str_u32() catch return null;
    snap.cedro_pos = Location.from_code(cedro) orelse .stage;
    snap.eser_pos = Location.from_code(eser) orelse .stage;
    snap.alice_pos = Location.from_code(alice) orelse .stage;
    snap.sonk_pos = Location.from_code(sonk) orelse .pirate_cove;
    snap.sonk_stage = r.int() catch return null;

    snap.sonk_charging = r.flag() catch return null;
    snap.sonk_charge_timer = r.real() catch return null;

    return snap;
}

pub fn has_saved_game() bool {
    return neko.save.file_exists(dir, GAME_SNAPSHOT_FILE);
}

pub fn delete_saved_game() void {
    neko.save.delete_file(dir, GAME_SNAPSHOT_FILE);
}
