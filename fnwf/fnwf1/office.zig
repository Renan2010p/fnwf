// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Renan Lucas Vieira Hilário

//! FNWF 1 — the security office.
//!
//! The room is a 1920-wide panorama composited with the engine's
//! `neko.projection.Cylinder`, so the view curves around the viewer. The
//! door/light buttons live *inside* the panorama next to each doorway and are
//! hit-tested through the same projection.
//!
//! Panning works like FNAF 1: the mouse only matters near the edges. In the
//! middle the view stands still; near a side it drifts slowly that way.

const std: type = @import("std");
const math: type = std.math;
const neko: type = @import("neko");

const config: type = @import("config.zig");
const world: type = @import("world.zig");
const CharId: type = world.CharId;
const Positions: type = world.Positions;

const PI: f32 = 3.14159265;

/// How the panorama is composited (for A/B testing the projection).
pub const Mode: type = enum {
    /// Per-pixel UV mesh (a single `geometry` call): the Godot-shader look,
    /// with no fixed slices and no banding.
    dense,
    /// GPU quad-strip mesh with interpolated UVs (`neko.render.cylinder`).
    mesh,
    /// CPU columns with exact slice boundaries (no seams).
    continuous,
    /// CPU fixed-width slices (the original; shows banding).
    slices,

    pub fn label(self: Mode) []const u8 {
        return switch (self) {
            .dense => "SHADER (por pixel)",
            .mesh => "MALHA (GPU)",
            .continuous => "CONTINUA (CPU)",
            .slices => "FATIAS (atual)",
        };
    }
};

const OFFICE_W: i32 = config.OFFICE_W;
const WIN_W: i32 = config.SCREEN_W;
const WIN_H: i32 = config.SCREEN_H;
const MAX_PAN_PX: f32 = @floatFromInt(OFFICE_W - WIN_W);

const PAN_SPEED: f32 = 0.62; // full sweep in ~1.6s
const DEAD_ZONE: i32 = 210; // pixels around the centre where the view holds

const LEFT_DOOR: neko.Rect = neko.Rect{ .x = 70, .y = 140, .w = 230, .h = 460 };
const RIGHT_DOOR: neko.Rect = neko.Rect{ .x = 1620, .y = 140, .w = 230, .h = 460 };

// Buttons in panorama coordinates, beside each doorway.
const BTN_L_DOOR: neko.Rect = neko.Rect{ .x = 322, .y = 250, .w = 92, .h = 54 };
const BTN_L_LIGHT: neko.Rect = neko.Rect{ .x = 322, .y = 316, .w = 92, .h = 54 };
const BTN_R_DOOR: neko.Rect = neko.Rect{ .x = 1506, .y = 250, .w = 92, .h = 54 };
const BTN_R_LIGHT: neko.Rect = neko.Rect{ .x = 1506, .y = 316, .w = 92, .h = 54 };

// A shader the game supplies in its own assets (loaded on first use).
var game_shader: ?neko.Shader = null;
var game_shader_tried: bool = false;

/// A clickable office control.
pub const Action: type = enum { door_left, door_right, light_left, light_right };

/// The office, doors and lights.
pub const Office: type = struct {
    view: f32 = 0.5,
    left_door: bool = false,
    right_door: bool = false,
    left_light: bool = false,
    right_light: bool = false,
    left_anim: f32 = 0,
    right_anim: f32 = 0,

    cylindrical: bool = false,
    office_tex: neko.TextureHandle = neko.TextureHandle{ .id = 0 },
    proj: neko.projection.Cylinder = undefined,
    mode: Mode = .dense,

    pub fn init(self: *Office) void {
        self.proj = neko.projection.Cylinder.init(.{ .source_width = OFFICE_W });

        if (!neko.screen.supports_offscreen_targets()) return;
        self.office_tex = neko.texture.create_target(@intCast(OFFICE_W), @intCast(WIN_H)) orelse return;
        self.cylindrical = true;
    }

    /// Panning like FNAF 1: only the screen edges move the view.
    pub fn update(self: *Office, mouse_x: i32, dt: f32) void {
        const center: i32 = @divTrunc(WIN_W, 2);
        var dir: f32 = 0;
        if (mouse_x < center - DEAD_ZONE) {
            dir = -1;
        } else if (mouse_x > center + DEAD_ZONE) {
            dir = 1;
        }
        self.view = @max(0.0, @min(1.0, self.view + dir * PAN_SPEED * dt));

        const tl: f32 = if (self.left_door) 1.0 else 0.0;
        if (self.left_anim < tl) {
            self.left_anim = @min(tl, self.left_anim + 3.4 * dt);
        } else if (self.left_anim > tl) {
            self.left_anim = @max(tl, self.left_anim - 3.4 * dt);
        }
        const tr: f32 = if (self.right_door) 1.0 else 0.0;
        if (self.right_anim < tr) {
            self.right_anim = @min(tr, self.right_anim + 3.4 * dt);
        } else if (self.right_anim > tr) {
            self.right_anim = @max(tr, self.right_anim - 3.4 * dt);
        }
    }

    pub fn extra_usage(self: *const Office) i32 {
        var n: i32 = 0;
        if (self.left_door) n += 1;
        if (self.right_door) n += 1;
        if (self.left_light) n += 1;
        if (self.right_light) n += 1;
        return n;
    }

    /// The current pan in the engine's -1..1 convention.
    fn pan(self: *const Office) f32 {
        return (self.view - 0.5) * 2.0;
    }

    /// Composites the panorama. Priority: a shader the *game* ships in its own
    /// assets, then the engine's built-in cylinder shader, then the per-column
    /// mesh. The game shader is added/changed without touching the engine.
    fn composite(self: *Office, pan_ang: f32) void {
        if (!game_shader_tried) {
            game_shader_tried = true;
            game_shader = neko.shader.load_files(neko.allocator(), "fnwf/fnwf1/assets/shaders", "office.vert", "office.frag");
        }
        const params = [4]f32{
            pan_ang,
            @floatFromInt(OFFICE_W),
            @floatFromInt(WIN_W),
            @floatFromInt(WIN_H),
        };
        if (game_shader) |prog| {
            prog.draw(self.office_tex, params);
            return;
        }
        if (self.proj.composite_shader(self.office_tex, pan_ang)) return;
        self.proj.composite_mesh(self.office_tex, pan_ang);
    }

    /// Cycles the projection mode (for A/B testing).
    pub fn cycle_mode(self: *Office) void {
        self.mode = switch (self.mode) {
            .dense => .mesh,
            .mesh => .continuous,
            .continuous => .slices,
            .slices => .dense,
        };
    }

    pub fn mode_label(self: *const Office) []const u8 {
        return self.mode.label();
    }

    /// Tests a screen click against the buttons, through the projection.
    pub fn handle_click(self: *Office, x: i32, y: i32) ?Action {
        const p: f32 = self.pan();
        if (self.proj.hit(p, BTN_L_DOOR, x, y)) {
            self.left_door = !self.left_door;
            return .door_left;
        }
        if (self.proj.hit(p, BTN_L_LIGHT, x, y)) {
            self.left_light = !self.left_light;
            return .light_left;
        }
        if (self.proj.hit(p, BTN_R_DOOR, x, y)) {
            self.right_door = !self.right_door;
            return .door_right;
        }
        if (self.proj.hit(p, BTN_R_LIGHT, x, y)) {
            self.right_light = !self.right_light;
            return .light_right;
        }
        return null;
    }

    // ── Drawing ──────────────────────────────────────────────────────

    pub fn draw(self: *Office, p: Positions, power_dead: bool) void {
        const t: f32 = @as(f32, @floatFromInt(neko.time.ticks_ms())) / 1000.0;

        if (self.cylindrical) {
            neko.texture.set_target(self.office_tex);
            self.draw_room(p, 0, t, power_dead);
            neko.texture.reset_target();
            const p_ang: f32 = self.pan();
            switch (self.mode) {
                .dense => self.composite(p_ang),
                .mesh => neko.render.cylinder(self.office_tex, neko.render.CylinderOptions{ .source_width = OFFICE_W, .pan = p_ang }),
                .continuous => self.composite_continuous(p_ang),
                .slices => self.proj.composite(self.office_tex, p_ang),
            }
        } else {
            const ox: i32 = -@as(i32, @intFromFloat(self.view * MAX_PAN_PX));
            self.draw_room(p, ox, t, power_dead);
        }

        neko.draw.rect(neko.Rect{ .x = 0, .y = 0, .w = WIN_W, .h = 130 }, neko.Color{ .r = 0, .g = 0, .b = 0, .a = 40 }, true);
        neko.draw.rect(neko.Rect{ .x = 0, .y = WIN_H - 120, .w = WIN_W, .h = 120 }, neko.Color{ .r = 0, .g = 0, .b = 0, .a = 35 }, true);
    }

    /// CPU compositor with exact slice boundaries: one slice's source range
    /// ends exactly where the next begins, so no pixels are skipped or doubled
    /// — the banding of the fixed-slice method disappears.
    fn composite_continuous(self: *Office, pan_ang: f32) void {
        const cyl = &self.proj;
        const w: i32 = cyl.screen_w;
        const h: i32 = cyl.screen_h;
        const center: f32 = PI / 2.0 + pan_ang * cyl.pan_max;
        const step: i32 = cyl.slice_width;
        const half: f32 = @as(f32, @floatFromInt(w)) / 2.0;

        var x: i32 = 0;
        while (x < w) : (x += step) {
            const x1: i32 = @min(x + step, w);
            const th0: f32 = math.atan((@as(f32, @floatFromInt(x)) - half) / cyl.focal);
            const th1: f32 = math.atan((@as(f32, @floatFromInt(x1)) - half) / cyl.focal);
            const ix0: i32 = @intFromFloat(@floor((center + th0) * cyl.pixels_per_radian));
            const ix1: i32 = @intFromFloat(@floor((center + th1) * cyl.pixels_per_radian));

            var src_x: i32 = ix0;
            var src_w: i32 = @max(1, ix1 - ix0);
            if (src_x < 0) {
                src_w += src_x;
                src_x = 0;
            }
            if (src_x + src_w > cyl.source_width) src_w = cyl.source_width - src_x;
            if (src_w <= 0) continue;

            const thm: f32 = (th0 + th1) / 2.0;
            const target_h: i32 = @intFromFloat(@as(f32, @floatFromInt(h)) / @cos(thm));

            neko.texture.draw(
                self.office_tex,
                neko.Rect{ .x = x, .y = @divTrunc(h - target_h, 2), .w = x1 - x, .h = target_h },
                neko.Rect{ .x = src_x, .y = 0, .w = src_w, .h = h },
                null,
            );
        }
    }

    fn draw_room(self: *Office, p: Positions, ox: i32, t: f32, power_dead: bool) void {
        neko.draw.rect(neko.Rect{ .x = ox, .y = 0, .w = OFFICE_W, .h = 120 }, neko.Color{ .r = 18, .g = 16, .b = 22 }, true);
        neko.draw.rect(neko.Rect{ .x = ox, .y = 120, .w = OFFICE_W, .h = 480 }, config.WALL, true);
        neko.draw.rect(neko.Rect{ .x = ox, .y = 112, .w = OFFICE_W, .h = 10 }, neko.Color{ .r = 22, .g = 20, .b = 26 }, true);
        neko.draw.rect(neko.Rect{ .x = ox, .y = 596, .w = OFFICE_W, .h = 124 }, config.FLOOR, true);
        neko.draw.rect(neko.Rect{ .x = ox, .y = 596, .w = OFFICE_W, .h = 6 }, neko.Color{ .r = 54, .g = 46, .b = 42 }, true);

        var s: i32 = 0;
        while (s < OFFICE_W) : (s += 160) {
            neko.draw.line(ox + s, 120, ox + s, 596, neko.Color{ .r = 32, .g = 29, .b = 37 });
        }
        var fy: i32 = 620;
        while (fy < WIN_H) : (fy += 26) {
            neko.draw.line(ox, fy, ox + OFFICE_W, fy, neko.Color{ .r = 28, .g = 24, .b = 22 });
        }

        draw_poster(ox);
        draw_doorway(ox, LEFT_DOOR, self.left_anim, self.left_light, self.left_occupant(p));
        draw_doorway(ox, RIGHT_DOOR, self.right_anim, self.right_light, self.right_occupant(p));
        draw_desk(ox, t);

        if (!power_dead) {
            draw_button(ox, BTN_L_DOOR, "DOOR", self.left_door, config.RED);
            draw_button(ox, BTN_L_LIGHT, "LIGHT", self.left_light, config.GREEN);
            draw_button(ox, BTN_R_DOOR, "DOOR", self.right_door, config.RED);
            draw_button(ox, BTN_R_LIGHT, "LIGHT", self.right_light, config.GREEN);
        }
    }

    fn left_occupant(self: *Office, p: Positions) ?CharId {
        _ = self;
        if (p.eser == .left_door) return .eser;
        if (p.alice == .left_door) return .alice;
        return null;
    }

    fn right_occupant(self: *Office, p: Positions) ?CharId {
        _ = self;
        if (p.eser == .right_door) return .eser;
        if (p.alice == .right_door) return .alice;
        return null;
    }
};

fn draw_poster(ox: i32) void {
    neko.draw.rect(neko.Rect{ .x = ox + 800, .y = 168, .w = 320, .h = 226 }, neko.Color{ .r = 20, .g = 18, .b = 24 }, true);
    neko.draw.rect(neko.Rect{ .x = ox + 812, .y = 180, .w = 296, .h = 202 }, neko.Color{ .r = 40, .g = 30, .b = 34 }, true);
    neko.sprite.text("MAFIA", ox + 960, 210, .{ .size = 44, .center = true, .color = config.ACCENT });
    neko.sprite.text("PIZZARIA", ox + 960, 262, .{ .size = 24, .center = true, .color = neko.Color{ .r = 190, .g = 180, .b = 150 } });
    neko.sprite.text("FIVE NIGHTS", ox + 960, 320, .{ .size = 20, .center = true, .color = neko.Color{ .r = 150, .g = 145, .b = 130 } });
    neko.sprite.text("com os amigos", ox + 960, 346, .{ .size = 16, .center = true, .color = neko.Color{ .r = 120, .g = 115, .b = 104 } });
}

fn draw_doorway(ox: i32, r: neko.Rect, anim: f32, light: bool, occupant: ?CharId) void {
    const hall: neko.Color = if (light) config.HALL_LIGHT else neko.Color{ .r = 10, .g = 10, .b = 13 };
    neko.draw.rect(neko.Rect{ .x = ox + r.x, .y = r.y, .w = r.w, .h = r.h }, hall, true);

    if (light) {
        neko.draw.rect(neko.Rect{ .x = ox + r.x + 8, .y = r.y + 8, .w = r.w - 16, .h = r.h - 16 }, neko.Color{ .r = 226, .g = 214, .b = 170, .a = 26 }, true);
        if (occupant) |c| {
            neko.sprite.face(c.sprite(), ox + r.x + 20, r.y + 30, r.w - 40, 300);
        }
    } else if (occupant) |_| {
        neko.draw.circle(ox + r.x + 78, r.y + 120, 6, neko.Color{ .r = 220, .g = 220, .b = 210, .a = 120 }, true);
        neko.draw.circle(ox + r.x + 150, r.y + 120, 6, neko.Color{ .r = 220, .g = 220, .b = 210, .a = 120 }, true);
    }

    const closed_h: i32 = @intFromFloat(@as(f32, @floatFromInt(r.h)) * anim);
    if (closed_h > 0) {
        neko.draw.rect(neko.Rect{ .x = ox + r.x, .y = r.y, .w = r.w, .h = closed_h }, config.DOOR, true);
        var i: i32 = 0;
        while (i < closed_h) : (i += 22) {
            neko.draw.line(ox + r.x, r.y + i, ox + r.x + r.w, r.y + i, config.DOOR_EDGE);
        }
        neko.draw.rect(neko.Rect{ .x = ox + r.x, .y = r.y + closed_h - 8, .w = r.w, .h = 8 }, config.DOOR_EDGE, true);
    }

    neko.draw.rect(neko.Rect{ .x = ox + r.x - 6, .y = r.y - 6, .w = r.w + 12, .h = r.h + 12 }, neko.Color{ .r = 58, .g = 52, .b = 46 }, false);
}

fn draw_desk(ox: i32, t: f32) void {
    neko.draw.rect(neko.Rect{ .x = ox + 600, .y = 470, .w = 720, .h = 26 }, config.DESK_TOP, true);
    neko.draw.rect(neko.Rect{ .x = ox + 600, .y = 496, .w = 720, .h = 150 }, config.DESK, true);
    neko.draw.rect(neko.Rect{ .x = ox + 600, .y = 470, .w = 720, .h = 4 }, neko.Color{ .r = 96, .g = 82, .b = 74 }, true);

    neko.draw.rect(neko.Rect{ .x = ox + 1090, .y = 372, .w = 226, .h = 100 }, neko.Color{ .r = 14, .g = 16, .b = 20 }, true);
    neko.draw.rect(neko.Rect{ .x = ox + 1090, .y = 372, .w = 226, .h = 100 }, neko.Color{ .r = 70, .g = 74, .b = 82 }, false);
    neko.draw.rect(neko.Rect{ .x = ox + 1180, .y = 472, .w = 46, .h = 18 }, neko.Color{ .r = 40, .g = 40, .b = 46 }, true);

    const fx: i32 = ox + 820;
    const fy: i32 = 430;
    neko.draw.rect(neko.Rect{ .x = fx - 8, .y = fy + 34, .w = 16, .h = 20 }, neko.Color{ .r = 50, .g = 50, .b = 56 }, true);
    neko.draw.rect(neko.Rect{ .x = fx - 16, .y = fy + 54, .w = 32, .h = 6 }, neko.Color{ .r = 60, .g = 60, .b = 66 }, true);
    neko.draw.circle(fx, fy, 30, neko.Color{ .r = 66, .g = 66, .b = 72 }, true);
    neko.draw.circle(fx, fy, 26, neko.Color{ .r = 44, .g = 44, .b = 48 }, true);
    const ft: f32 = t * 10.0;
    var i: i32 = 0;
    while (i < 4) : (i += 1) {
        const a: f32 = ft + @as(f32, @floatFromInt(i)) * 1.5708;
        neko.draw.line(fx, fy, fx + @as(i32, @intFromFloat(@cos(a) * 24.0)), fy + @as(i32, @intFromFloat(@sin(a) * 24.0)), neko.Color{ .r = 104, .g = 104, .b = 110 });
    }
    neko.draw.circle(fx, fy, 6, neko.Color{ .r = 80, .g = 80, .b = 86 }, true);

    neko.draw.rect(neko.Rect{ .x = ox + 660, .y = 442, .w = 30, .h = 28 }, neko.Color{ .r = 190, .g = 120, .b = 150 }, true);
    neko.draw.rect(neko.Rect{ .x = ox + 660, .y = 452, .w = 30, .h = 18 }, neko.Color{ .r = 200, .g = 60, .b = 70 }, true);
}

fn draw_button(ox: i32, r: neko.Rect, label: []const u8, on: bool, accent: neko.Color) void {
    const fill: neko.Color = if (on) accent else neko.Color{ .r = 26, .g = 26, .b = 30 };
    neko.draw.rect(neko.Rect{ .x = ox + r.x, .y = r.y, .w = r.w, .h = r.h }, fill, true);
    neko.draw.rect(neko.Rect{ .x = ox + r.x, .y = r.y, .w = r.w, .h = r.h }, neko.Color{ .r = 90, .g = 88, .b = 84 }, false);
    neko.sprite.text(label, ox + r.x + @divTrunc(r.w, 2), r.y + @divTrunc(r.h, 2), .{ .size = 14, .center = true, .color = if (on) config.DARK else config.MUTED });
}
