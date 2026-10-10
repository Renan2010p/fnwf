// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Renan Lucas Vieira Hilário

//! FNWF 1 — the security monitor (cameras + map).

const std: type = @import("std");
const fmt: type = std.fmt;
const neko: type = @import("neko");

const config: type = @import("config.zig");
const world: type = @import("world.zig");
const CameraId: type = world.CameraId;
const Positions: type = world.Positions;

/// One room box on the floor-plan map (`id == null` is the office).
const Room: type = struct {
    id: ?CameraId,
    x: i32,
    y: i32,
    label: []const u8,
};

const MAP_X: i32 = 820;
const MAP_Y: i32 = 420;
const MAP_W: i32 = 440;
const MAP_H: i32 = 288;
const BOX_W: i32 = 76;
const BOX_H: i32 = 30;

/// A FNAF 1-style floor plan: rooms connected by halls, the office at the
/// bottom. Coordinates are map-local, relative to `MAP_X`/`MAP_Y`.
const ROOMS: [12]Room = .{
    .{ .id = .backstage, .x = 70, .y = 42, .label = "5" },
    .{ .id = .show_stage, .x = 200, .y = 34, .label = "1A" },
    .{ .id = .restrooms, .x = 336, .y = 42, .label = "7" },
    .{ .id = .pirate_cove, .x = 70, .y = 104, .label = "1C" },
    .{ .id = .dining, .x = 200, .y = 98, .label = "1B" },
    .{ .id = .kitchen, .x = 336, .y = 104, .label = "6" },
    .{ .id = .supply, .x = 70, .y = 168, .label = "3" },
    .{ .id = .west_hall, .x = 140, .y = 172, .label = "2A" },
    .{ .id = .east_hall, .x = 266, .y = 172, .label = "4A" },
    .{ .id = .west_corner, .x = 140, .y = 228, .label = "2B" },
    .{ .id = .east_corner, .x = 266, .y = 228, .label = "4B" },
    .{ .id = null, .x = 200, .y = 266, .label = "YOU" },
};

/// Connections between rooms, as indexes into `ROOMS`.
const LINKS: [14][2]usize = .{
    .{ 1, 4 }, // 1A - 1B
    .{ 4, 0 }, // 1B - 5
    .{ 4, 3 }, // 1B - 1C
    .{ 4, 2 }, // 1B - 7
    .{ 4, 5 }, // 1B - 6
    .{ 4, 7 }, // 1B - 2A
    .{ 4, 8 }, // 1B - 4A
    .{ 7, 6 }, // 2A - 3
    .{ 7, 9 }, // 2A - 2B
    .{ 8, 10 }, // 4A - 4B
    .{ 9, 11 }, // 2B - office
    .{ 10, 11 }, // 4B - office
    .{ 5, 8 }, // 6 - 4A
    .{ 2, 5 }, // 7 - 6
};

/// The security monitor.
pub const Cameras: type = struct {
    is_open: bool = false,
    current: CameraId = .show_stage,
    static_timer: f32 = 0,
    anim: f32 = 0,

    pub fn toggle(self: *Cameras) void {
        self.is_open = !self.is_open;
        if (self.is_open) self.static_timer = 0.4;
    }

    pub fn lower(self: *Cameras) void {
        self.is_open = false;
    }

    pub fn select(self: *Cameras, cam: CameraId) void {
        if (cam != self.current) {
            self.current = cam;
            self.static_timer = 0.35;
        }
    }

    pub fn fully_open(self: *const Cameras) bool {
        return self.is_open and self.anim >= 0.99;
    }

    pub fn visible(self: *const Cameras) bool {
        return self.anim > 0.02;
    }

    pub fn update(self: *Cameras, dt: f32) void {
        if (self.static_timer > 0) self.static_timer -= dt;
        const target: f32 = if (self.is_open) 1.0 else 0.0;
        if (self.anim < target) {
            self.anim = @min(target, self.anim + 6.0 * dt);
        } else if (self.anim > target) {
            self.anim = @max(target, self.anim - 6.0 * dt);
        }
    }

    pub fn handle_click(self: *Cameras, x: i32, y: i32) bool {
        if (!self.fully_open()) return false;
        for (ROOMS) |r| {
            const id = r.id orelse continue;
            if (in_box(r, x, y)) {
                self.select(id);
                return true;
            }
        }
        // Close strip.
        if (x >= config.SCREEN_W / 2 - 200 and x <= config.SCREEN_W / 2 + 200 and y >= config.SCREEN_H - 34 and y <= config.SCREEN_H - 4) {
            self.lower();
            return true;
        }
        return false;
    }

    pub fn draw(self: *Cameras, p: Positions, power_dead: bool) void {
        if (self.anim <= 0.02) return;
        const oy: i32 = @intFromFloat((1.0 - self.anim) * @as(f32, @floatFromInt(config.SCREEN_H)));

        neko.draw.rect(neko.Rect{ .x = 0, .y = oy, .w = config.SCREEN_W, .h = config.SCREEN_H }, neko.Color{ .r = 4, .g = 6, .b = 4 }, true);
        draw_room(self.current, oy, p);

        // Static / noise.
        if (self.static_timer > 0) {
            neko.effect.noise(0, oy, config.SCREEN_W, config.SCREEN_H, 0.5);
        } else {
            neko.effect.noise(0, oy, config.SCREEN_W, config.SCREEN_H, 0.02);
            neko.effect.scanlines(0, oy, config.SCREEN_W, config.SCREEN_H, 18);
        }

        var buf: [32]u8 = undefined;
        const label = fmt.bufPrint(&buf, "CAM {s}", .{self.current.code()}) catch "CAM";
        neko.sprite.text(label, 40, oy + 34, .{ .size = 22, .color = config.MONITOR_GREEN });
        neko.sprite.text(self.current.name(), 40, oy + 62, .{ .size = 14, .color = neko.Color{ .r = 120, .g = 200, .b = 140 } });

        const rec_blink: bool = @mod(@as(i32, @intFromFloat(@as(f32, @floatFromInt(neko.time.ticks_ms())) / 1000.0)), 2) == 0;
        if (rec_blink) {
            neko.draw.circle(config.SCREEN_W - 70, oy + 34, 7, config.RED, true);
            neko.sprite.text("REC", config.SCREEN_W - 50, oy + 26, .{ .size = 13, .color = config.RED });
        }

        draw_map(oy, self.current);

        const close_rect = neko.Rect{ .x = config.SCREEN_W / 2 - 200, .y = oy + config.SCREEN_H - 34, .w = 400, .h = 30 };
        neko.draw.rect(close_rect, neko.Color{ .r = 20, .g = 24, .b = 20 }, true);
        neko.draw.rect(close_rect, neko.Color{ .r = 120, .g = 180, .b = 120 }, false);
        neko.sprite.text("FECHAR MONITOR", close_rect.x + @divTrunc(close_rect.w, 2), close_rect.y + 9, .{ .size = 13, .center = true, .color = neko.Color{ .r = 150, .g = 200, .b = 150 } });

        if (power_dead) {
            neko.draw.rect(neko.Rect{ .x = 0, .y = oy, .w = config.SCREEN_W, .h = config.SCREEN_H }, neko.Color{ .r = 0, .g = 0, .b = 0, .a = 220 }, true);
        }
    }
};

fn draw_room(cam: CameraId, oy: i32, p: Positions) void {
    const wall: neko.Color = switch (cam) {
        .show_stage => neko.Color{ .r = 40, .g = 30, .b = 36 },
        .dining => neko.Color{ .r = 30, .g = 28, .b = 32 },
        .pirate_cove => neko.Color{ .r = 20, .g = 16, .b = 26 },
        .kitchen => neko.Color{ .r = 12, .g = 12, .b = 12 },
        .restrooms => neko.Color{ .r = 26, .g = 32, .b = 34 },
        .backstage => neko.Color{ .r = 26, .g = 22, .b = 30 },
        else => neko.Color{ .r = 34, .g = 32, .b = 40 },
    };
    neko.draw.rect(neko.Rect{ .x = 180, .y = oy + 110, .w = 920, .h = 470 }, wall, true);
    neko.draw.rect(neko.Rect{ .x = 180, .y = oy + 110, .w = 920, .h = 470 }, neko.Color{ .r = 60, .g = 70, .b = 60 }, false);

    if (cam == .kitchen) {
        neko.sprite.text("CÂMERA COM DEFEITO", config.SCREEN_W / 2, oy + 320, .{ .size = 26, .center = true, .color = neko.Color{ .r = 120, .g = 200, .b = 140 } });
        neko.sprite.text("ÁUDIO APENAS", config.SCREEN_W / 2, oy + 356, .{ .size = 16, .center = true, .color = neko.Color{ .r = 90, .g = 140, .b = 100 } });
        return;
    }

    // Room label and simple props.
    neko.sprite.text(cam.name(), config.SCREEN_W / 2, oy + 140, .{ .size = 20, .center = true, .color = neko.Color{ .r = 150, .g = 200, .b = 150 } });

    if (cam == .show_stage) {
        neko.draw.rect(neko.Rect{ .x = 320, .y = oy + 480, .w = 640, .h = 40 }, neko.Color{ .r = 20, .g = 18, .b = 22 }, true);
    }
    if (cam == .pirate_cove) {
        neko.draw.rect(neko.Rect{ .x = 420, .y = oy + 180, .w = 440, .h = 340 }, neko.Color{ .r = 90, .g = 30, .b = 40 }, true);
        neko.draw.rect(neko.Rect{ .x = 420, .y = oy + 180, .w = 440, .h = 340 }, neko.Color{ .r = 40, .g = 14, .b = 20 }, false);
    }
    if (cam == .backstage) {
        var i: i32 = 0;
        while (i < 4) : (i += 1) {
            neko.draw.circle(360 + i * 180, oy + 420, 46, neko.Color{ .r = 70, .g = 66, .b = 60 }, true);
        }
    }

    // Occupants.
    draw_occupant(p.eser, .eser, cam, oy, 420, 280);
    draw_occupant(p.alice, .alice, cam, oy, 740, 280);
    draw_occupant(p.cedro, .cedro, cam, oy, 580, 300);
    draw_sonk(p.sonk, cam, oy);
}

fn draw_occupant(loc: world.Location, id: world.CharId, cam: CameraId, oy: i32, x: i32, h: i32) void {
    const c = loc.camera() orelse return;
    if (c != cam) return;
    neko.sprite.face(id.sprite(), x, oy + 200, @divTrunc(h * 2, 3), h);
}

fn draw_sonk(loc: world.Location, cam: CameraId, oy: i32) void {
    if (loc != .pirate_cove or cam != .pirate_cove) return;
    neko.sprite.face("Sonk", config.SCREEN_W / 2 - 90, oy + 200, 180, 300);
}

fn room_screen(r: Room, oy: i32) neko.Point {
    return neko.Point{ .x = MAP_X + r.x, .y = oy + MAP_Y + r.y };
}

fn in_box(r: Room, x: i32, y: i32) bool {
    const c = room_screen(r, 0);
    return x >= c.x - @divTrunc(BOX_W, 2) and x <= c.x + @divTrunc(BOX_W, 2) and
        y >= c.y - @divTrunc(BOX_H, 2) and y <= c.y + @divTrunc(BOX_H, 2);
}

fn draw_map(oy: i32, current: CameraId) void {
    // Panel.
    neko.draw.rect(neko.Rect{ .x = MAP_X, .y = oy + MAP_Y, .w = MAP_W, .h = MAP_H }, neko.Color{ .r = 6, .g = 14, .b = 6, .a = 225 }, true);
    neko.draw.rect(neko.Rect{ .x = MAP_X, .y = oy + MAP_Y, .w = MAP_W, .h = MAP_H }, config.MONITOR_GREEN, false);
    neko.sprite.text("MAPA", MAP_X + 12, oy + MAP_Y + 8, .{ .size = 12, .color = neko.Color{ .r = 120, .g = 200, .b = 140 } });

    // Halls / links.
    for (LINKS) |link| {
        const a = room_screen(ROOMS[link[0]], oy);
        const b = room_screen(ROOMS[link[1]], oy);
        neko.draw.line(a.x, a.y, b.x, b.y, neko.Color{ .r = 0, .g = 120, .b = 0 });
    }

    // Room boxes.
    for (ROOMS) |r| {
        const c = room_screen(r, oy);
        const is_office = r.id == null;
        const active = if (r.id) |id| id == current else false;

        const bg: neko.Color = if (active)
            neko.Color{ .r = 30, .g = 110, .b = 30 }
        else if (is_office)
            neko.Color{ .r = 60, .g = 60, .b = 20 }
        else
            neko.Color{ .r = 8, .g = 22, .b = 8 };
        const border: neko.Color = if (active) neko.Color{ .r = 140, .g = 255, .b = 140 } else if (is_office) neko.Color{ .r = 230, .g = 210, .b = 90 } else config.MONITOR_GREEN;
        const text: neko.Color = if (active) neko.Color{ .r = 220, .g = 255, .b = 220 } else if (is_office) neko.Color{ .r = 240, .g = 220, .b = 120 } else neko.Color{ .r = 120, .g = 240, .b = 120 };

        neko.draw.rect(neko.Rect{ .x = c.x - @divTrunc(BOX_W, 2), .y = c.y - @divTrunc(BOX_H, 2), .w = BOX_W, .h = BOX_H }, bg, true);
        neko.draw.rect(neko.Rect{ .x = c.x - @divTrunc(BOX_W, 2), .y = c.y - @divTrunc(BOX_H, 2), .w = BOX_W, .h = BOX_H }, border, false);
        neko.sprite.text(r.label, c.x, c.y - 8, .{ .size = 13, .center = true, .color = text });
    }
}
