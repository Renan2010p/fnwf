// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Renan Lucas Vieira Hilário

//! The security office — port of `systems/Office`.
//!
//! The room is rendered as a 1280-wide panorama and then re-projected onto the
//! screen slice by slice (the classic cylindrical composite), so the player can
//! pan by moving the mouse. Platforms without cylindrical compositing (PS2)
//! draw the room flat, straight to the screen.

const std: type = @import("std");
const math: type = std.math;
const neko: type = @import("neko");

const constants: type = @import("../config/constants.zig");
const colors: type = @import("../config/colors.zig");
const animatronics: type = @import("animatronics.zig");
const AnimatronicId: type = animatronics.AnimatronicId;
const doors_mod: type = @import("doors.zig");
const Button: type = doors_mod.Button;

// A shader the game supplies in its own assets (loaded on first use).
var game_shader: ?neko.Shader = null;
var game_shader_tried: bool = false;

const PI: f32 = 3.14159265;

/// Pan speed, in `pan_x` units per second (full sweep in ~1.6s).
const PAN_SPEED: f32 = 1.25;
/// Pixels around the screen centre where the view holds still.
const DEAD_ZONE: i32 = 210;

/// A projected room point: screen x, screen y and depth scale.
const DepthPoint: type = struct {
    x: i32,
    y: i32,
    s: f32,
};

// Door/light buttons, in panorama coordinates beside each doorway.
const BTN_L_DOOR: neko.Rect = neko.Rect{ .x = 180, .y = 296, .w = 92, .h = 52 };
const BTN_L_LIGHT: neko.Rect = neko.Rect{ .x = 180, .y = 356, .w = 92, .h = 52 };
const BTN_R_DOOR: neko.Rect = neko.Rect{ .x = 1008, .y = 296, .w = 92, .h = 52 };
const BTN_R_LIGHT: neko.Rect = neko.Rect{ .x = 1008, .y = 356, .w = 92, .h = 52 };

/// The security office: a 180° panorama with two side halls, a vent and a desk.
pub const Office: type = struct {
    vent_light: bool = false,
    pan_x: f32 = 0,
    target_pan: f32 = 0,

    cylindrical: bool = false,
    office_tex: neko.TextureHandle = neko.TextureHandle{ .id = 0 },
    office_static_tex: neko.TextureHandle = neko.TextureHandle{ .id = 0 },
    static_ready: bool = false,

    vp_x: i32 = 0,
    vp_y: i32 = 0,
    bw_left: i32 = 0,
    bw_right: i32 = 0,
    bw_top: i32 = 0,
    bw_bottom: i32 = 0,
    hall_w: i32 = 100,
    hall_depth: i32 = 250,

    proj: neko.projection.Cylinder = undefined,

    /// Creates the panorama/static targets and bakes the projection + static room.
    pub fn init(self: *Office) void {
        self.vp_x = @divTrunc(constants.OFFICE_WIDTH, 2);
        self.vp_y = @divTrunc(constants.SCREEN_HEIGHT, 2) - 30;
        self.bw_left = self.vp_x - 240;
        self.bw_right = self.vp_x + 240;
        self.bw_top = 80;
        self.bw_bottom = constants.SCREEN_HEIGHT - 120;

        self.proj = neko.projection.Cylinder.init(.{
            .source_width = constants.OFFICE_WIDTH,
            .screen_width = constants.SCREEN_WIDTH,
            .screen_height = constants.SCREEN_HEIGHT,
        });

        const offscreen: bool = neko.screen.supports_offscreen_targets();
        if (neko.screen.supports_curved_panorama()) {
            if (neko.texture.create_target(@intCast(constants.OFFICE_WIDTH), @intCast(constants.SCREEN_HEIGHT))) |tex| {
                self.office_tex = tex;
                self.cylindrical = true;
            }
        }
        if (offscreen) {
            if (neko.texture.create_target(@intCast(constants.OFFICE_WIDTH), @intCast(constants.SCREEN_HEIGHT))) |tex| {
                self.office_static_tex = tex;
                self.static_ready = true;
            }
        }
        if (self.static_ready) self.build_static_layer();
    }

    /// Panning like FNAF 1: only the screen edges move the view; in the middle
    /// it stands still. `pan_x` is -1 (left) .. 1 (right).
    pub fn update(self: *Office, mouse_x: i32, dt: f32) void {
        const center: i32 = @divTrunc(constants.SCREEN_WIDTH, 2);
        var dir: f32 = 0;
        if (mouse_x < center - DEAD_ZONE) {
            dir = -1;
        } else if (mouse_x > center + DEAD_ZONE) {
            dir = 1;
        }
        self.target_pan = dir;
        self.pan_x = @max(-1.0, @min(1.0, self.pan_x + dir * PAN_SPEED * dt));
    }

    pub fn draw(
        self: *Office,
        left_anim: f32,
        right_anim: f32,
        left_light: bool,
        right_light: bool,
        at_left: ?AnimatronicId,
        at_right: ?AnimatronicId,
        at_vent: ?AnimatronicId,
        in_office: ?AnimatronicId,
    ) void {
        if (!self.cylindrical) {
            self.draw_flat(left_anim, right_anim, left_light, right_light, at_left, at_right, at_vent, in_office);
            return;
        }

        const t: f32 = @as(f32, @floatFromInt(neko.time.ticks_ms())) / 1000.0;

        neko.texture.set_target(self.office_tex);
        neko.texture.draw(self.office_static_tex, neko.Rect{ .x = 0, .y = 0, .w = constants.OFFICE_WIDTH, .h = constants.SCREEN_HEIGHT }, null, null);

        self.draw_back_wall_dynamic(t);
        self.draw_hallways_dynamic(left_light, right_light, at_left, at_right);
        self.draw_vent_dynamic(at_vent);
        self.draw_doors(left_anim, right_anim);
        self.draw_fan(t);
        self.draw_in_office(in_office);
        self.draw_buttons(left_anim, right_anim, left_light, right_light);
        neko.texture.reset_target();

        // Per-column cylindrical composite. Priority: a shader the *game*
        // provides in its assets, then the engine's built-in cylinder shader,
        // then the per-column mesh. The game shader can be added/changed
        // without touching the engine.
        self.composite();
    }

    fn composite(self: *Office) void {
        if (!game_shader_tried) {
            game_shader_tried = true;
            game_shader = neko.shader.load_files(neko.allocator(), "fnwf/classic/assets/shaders", "office.vert", "office.frag");
        }
        const params = [4]f32{
            self.pan_x,
            @floatFromInt(constants.OFFICE_WIDTH),
            @floatFromInt(constants.SCREEN_WIDTH),
            @floatFromInt(constants.SCREEN_HEIGHT),
        };
        if (game_shader) |prog| {
            prog.draw(self.office_tex, params);
            return;
        }
        if (self.proj.composite_shader(self.office_tex, self.pan_x)) return;
        self.proj.composite_mesh(self.office_tex, self.pan_x);
    }

    // ── Projection ───────────────────────────────────────────────────

    fn shade(c: neko.Color, factor: f32) neko.Color {
        return neko.Color{
            .r = @intFromFloat(@max(0.0, @min(255.0, @as(f32, @floatFromInt(c.r)) * factor))),
            .g = @intFromFloat(@max(0.0, @min(255.0, @as(f32, @floatFromInt(c.g)) * factor))),
            .b = @intFromFloat(@max(0.0, @min(255.0, @as(f32, @floatFromInt(c.b)) * factor))),
        };
    }

    fn project_depth(self: *const Office, nx: f32, z: f32, height: f32) DepthPoint {
        const zc: f32 = @max(0.0, @min(1.0, z));
        const scale: f32 = 0.40 + zc * 1.45;
        const world_half: f32 = 320;
        const sx: i32 = @intFromFloat(@as(f32, @floatFromInt(self.vp_x)) + nx * world_half * scale);
        const floor_y: i32 = self.bw_bottom + @as(i32, @intFromFloat(@as(f32, @floatFromInt(constants.SCREEN_HEIGHT - self.bw_bottom)) * math.pow(f32, zc, 1.2)));
        const sy: i32 = @intFromFloat(@as(f32, @floatFromInt(floor_y)) - height * scale);
        return DepthPoint{ .x = sx, .y = sy, .s = scale };
    }

    // ── Static layer ─────────────────────────────────────────────────

    fn build_static_layer(self: *Office) void {
        neko.texture.set_target(self.office_static_tex);
        neko.draw.clear(neko.Color{ .r = 5, .g = 5, .b = 8 });
        self.draw_ceiling();
        self.draw_floor();
        self.draw_back_wall_base();
        self.draw_depth_structure();
        self.draw_hallways_base();
        self.draw_vent_base();
        self.draw_side_walls();
        self.draw_wall_dressing();
        self.draw_office_elements();
        self.draw_ambient();
        neko.texture.reset_target();
    }

    fn draw_flat(
        self: *Office,
        left_anim: f32,
        right_anim: f32,
        left_light: bool,
        right_light: bool,
        at_left: ?AnimatronicId,
        at_right: ?AnimatronicId,
        at_vent: ?AnimatronicId,
        in_office: ?AnimatronicId,
    ) void {
        const t: f32 = @as(f32, @floatFromInt(neko.time.ticks_ms())) / 1000.0;

        if (self.static_ready) {
            neko.texture.draw(self.office_static_tex, neko.Rect{ .x = 0, .y = 0, .w = constants.OFFICE_WIDTH, .h = constants.SCREEN_HEIGHT }, null, null);
        } else {
            neko.draw.clear(neko.Color{ .r = 5, .g = 5, .b = 8 });
            self.draw_ceiling();
            self.draw_floor();
            self.draw_back_wall_base();
            self.draw_depth_structure();
            self.draw_hallways_base();
            self.draw_vent_base();
            self.draw_side_walls();
            self.draw_wall_dressing();
            self.draw_office_elements();
            self.draw_ambient();
        }

        self.draw_back_wall_dynamic(t);
        self.draw_hallways_dynamic(left_light, right_light, at_left, at_right);
        self.draw_vent_dynamic(at_vent);
        self.draw_doors(left_anim, right_anim);
        self.draw_fan(t);
        self.draw_in_office(in_office);
        self.draw_buttons(left_anim, right_anim, left_light, right_light);
    }

    // ── Door / light buttons (inside the panorama) ───────────────────

    /// Which button (if any) the screen point `(x, y)` is over.
    pub fn handle_button(self: *const Office, x: i32, y: i32) ?Button {
        if (self.cylindrical) {
            const p: f32 = self.pan_x;
            if (self.proj.hit(p, BTN_L_DOOR, x, y)) return .left_door;
            if (self.proj.hit(p, BTN_L_LIGHT, x, y)) return .left_light;
            if (self.proj.hit(p, BTN_R_DOOR, x, y)) return .right_door;
            if (self.proj.hit(p, BTN_R_LIGHT, x, y)) return .right_light;
            return null;
        }
        if (in_rect(BTN_L_DOOR, x, y)) return .left_door;
        if (in_rect(BTN_L_LIGHT, x, y)) return .left_light;
        if (in_rect(BTN_R_DOOR, x, y)) return .right_door;
        if (in_rect(BTN_R_LIGHT, x, y)) return .right_light;
        return null;
    }

    fn draw_buttons(self: *Office, left_anim: f32, right_anim: f32, left_light: bool, right_light: bool) void {
        _ = self;
        draw_button(BTN_L_DOOR, "DOOR", left_anim > 0.5, colors.BUTTON_RED);
        draw_button(BTN_L_LIGHT, "LIGHT", left_light, colors.BUTTON_GREEN);
        draw_button(BTN_R_DOOR, "DOOR", right_anim > 0.5, colors.BUTTON_RED);
        draw_button(BTN_R_LIGHT, "LIGHT", right_light, colors.BUTTON_GREEN);
    }

    // ── Base room ────────────────────────────────────────────────────

    fn draw_ceiling(self: *Office) void {
        neko.draw.quad(
            neko.Point{ .x = 0, .y = 0 },
            neko.Point{ .x = self.bw_right + self.hall_depth, .y = self.bw_top },
            neko.Point{ .x = self.bw_left - self.hall_depth, .y = self.bw_top },
            neko.Point{ .x = constants.OFFICE_WIDTH, .y = 0 },
            neko.Color{ .r = 22, .g = 20, .b = 25 },
        );
        var i: i32 = 1;
        while (i < 10) : (i += 1) {
            const prog: f32 = @as(f32, @floatFromInt(i)) / 10.0;
            const y: i32 = @intFromFloat(prog * @as(f32, @floatFromInt(self.bw_top)));
            const lx: i32 = @intFromFloat(@as(f32, @floatFromInt(self.bw_left - self.hall_depth)) * prog);
            const rx: i32 = @intFromFloat(@as(f32, @floatFromInt(constants.OFFICE_WIDTH)) - @as(f32, @floatFromInt(constants.OFFICE_WIDTH - self.bw_right - self.hall_depth)) * prog);
            const shade_v: u8 = @intFromFloat(@max(0.0, 30.0 - prog * 20.0));
            neko.draw.line(lx, y, rx, y, neko.Color{ .r = shade_v, .g = shade_v, .b = shade_v + 3 });
        }
        var j: i32 = 0;
        while (j <= 5) : (j += 1) {
            const frac: f32 = @as(f32, @floatFromInt(j + 1)) / 7.0;
            const top_x: i32 = @intFromFloat(@as(f32, @floatFromInt(constants.OFFICE_WIDTH)) * frac);
            const bot_x: i32 = @intFromFloat(@as(f32, @floatFromInt(self.bw_left - self.hall_depth)) + frac * @as(f32, @floatFromInt(self.bw_right + self.hall_depth - self.bw_left + self.hall_depth)));
            neko.draw.line(top_x, 0, bot_x, self.bw_top, neko.Color{ .r = 18, .g = 18, .b = 22 });
        }
    }

    fn draw_floor(self: *Office) void {
        const floor_left_far: i32 = self.bw_left - self.hall_depth;
        const floor_right_far: i32 = self.bw_right + self.hall_depth;
        neko.draw.quad(
            neko.Point{ .x = floor_left_far, .y = self.bw_bottom },
            neko.Point{ .x = floor_right_far, .y = self.bw_bottom },
            neko.Point{ .x = constants.OFFICE_WIDTH + 100, .y = constants.SCREEN_HEIGHT },
            neko.Point{ .x = -100, .y = constants.SCREEN_HEIGHT },
            colors.FLOOR_COLOR,
        );

        const rows: i32 = 4;
        const cols: i32 = 8;
        var r: i32 = 0;
        while (r < rows) : (r += 1) {
            const py0: f32 = @as(f32, @floatFromInt(r)) / @as(f32, @floatFromInt(rows));
            const py1: f32 = @as(f32, @floatFromInt(r + 1)) / @as(f32, @floatFromInt(rows));
            const y0: i32 = @intFromFloat(@as(f32, @floatFromInt(self.bw_bottom)) + py0 * @as(f32, @floatFromInt(constants.SCREEN_HEIGHT - self.bw_bottom)));
            const y1: i32 = @intFromFloat(@as(f32, @floatFromInt(self.bw_bottom)) + py1 * @as(f32, @floatFromInt(constants.SCREEN_HEIGHT - self.bw_bottom)));
            const lx0: i32 = @intFromFloat(@as(f32, @floatFromInt(floor_left_far)) + (-100.0 - @as(f32, @floatFromInt(floor_left_far))) * py0);
            const rx0: i32 = @intFromFloat(@as(f32, @floatFromInt(floor_right_far)) + (@as(f32, @floatFromInt(constants.OFFICE_WIDTH + 100)) - @as(f32, @floatFromInt(floor_right_far))) * py0);
            const lx1: i32 = @intFromFloat(@as(f32, @floatFromInt(floor_left_far)) + (-100.0 - @as(f32, @floatFromInt(floor_left_far))) * py1);
            const rx1: i32 = @intFromFloat(@as(f32, @floatFromInt(floor_right_far)) + (@as(f32, @floatFromInt(constants.OFFICE_WIDTH + 100)) - @as(f32, @floatFromInt(floor_right_far))) * py1);

            var c: i32 = 0;
            while (c < cols) : (c += 1) {
                const px0: i32 = lx0 + @as(i32, @intFromFloat(@as(f32, @floatFromInt(c)) / @as(f32, @floatFromInt(cols)) * @as(f32, @floatFromInt(rx0 - lx0))));
                const px1: i32 = lx0 + @as(i32, @intFromFloat(@as(f32, @floatFromInt(c + 1)) / @as(f32, @floatFromInt(cols)) * @as(f32, @floatFromInt(rx0 - lx0))));
                const px0b: i32 = lx1 + @as(i32, @intFromFloat(@as(f32, @floatFromInt(c)) / @as(f32, @floatFromInt(cols)) * @as(f32, @floatFromInt(rx1 - lx1))));
                const px1b: i32 = lx1 + @as(i32, @intFromFloat(@as(f32, @floatFromInt(c + 1)) / @as(f32, @floatFromInt(cols)) * @as(f32, @floatFromInt(rx1 - lx1))));
                const base = if (@mod(r + c, 2) == 0) colors.FLOOR_TILE_1 else colors.FLOOR_TILE_2;
                const fade: f32 = @max(0.3, 1.0 - (1.0 - py0) * 0.6);
                const col = shade(base, fade);
                neko.draw.quad(
                    neko.Point{ .x = px0, .y = y0 },
                    neko.Point{ .x = px1, .y = y0 },
                    neko.Point{ .x = px1b, .y = y1 },
                    neko.Point{ .x = px0b, .y = y1 },
                    col,
                );
            }
        }
    }

    fn draw_back_wall_base(self: *Office) void {
        neko.draw.rect(neko.Rect{ .x = self.bw_left, .y = self.bw_top, .w = self.bw_right - self.bw_left, .h = self.bw_bottom - self.bw_top }, colors.WALL_COLOR, true);
        neko.draw.rect(neko.Rect{ .x = self.bw_left + 10, .y = self.bw_top + 16, .w = self.bw_right - self.bw_left - 20, .h = 22 }, neko.Color{ .r = 34, .g = 32, .b = 40, .a = 190 }, true);
        var i: i32 = 0;
        while (i <= 6) : (i += 1) {
            const yy: i32 = self.bw_top + 14 + i * 4;
            neko.draw.line(self.bw_left + 16, yy, self.bw_right - 16, yy, neko.Color{ .r = 52, .g = 48, .b = 58, .a = 70 });
        }
        neko.draw.rect(neko.Rect{ .x = self.bw_left, .y = self.bw_bottom - 20, .w = self.bw_right - self.bw_left, .h = 20 }, neko.Color{ .r = 35, .g = 30, .b = 38 }, true);
        neko.draw.line(self.bw_left, self.bw_bottom - 20, self.bw_right, self.bw_bottom - 20, neko.Color{ .r = 50, .g = 45, .b = 55 });

        const p1x: i32 = self.vp_x - 64;
        const p1y: i32 = self.bw_top + 36;
        neko.draw.rect(neko.Rect{ .x = p1x, .y = p1y, .w = 128, .h = 128 }, neko.Color{ .r = 40, .g = 36, .b = 46 }, true);
        neko.draw.rect(neko.Rect{ .x = p1x + 2, .y = p1y + 2, .w = 124, .h = 124 }, neko.Color{ .r = 22, .g = 22, .b = 24 }, true);
        neko.draw.rect(neko.Rect{ .x = p1x + 8, .y = p1y + 10, .w = 112, .h = 108 }, neko.Color{ .r = 14, .g = 14, .b = 18 }, true);
        neko.draw.rect(neko.Rect{ .x = p1x, .y = p1y, .w = 128, .h = 128 }, colors.WALL_ACCENT, false);
        neko.sprite.text("MAFIA", p1x + 64, p1y + 52, .{ .size = 24, .center = true, .color = neko.Color{ .r = 255, .g = 255, .b = 100 } });
        neko.sprite.text("NIGHT SHIFT", p1x + 64, p1y + 82, .{ .size = 11, .center = true, .color = neko.Color{ .r = 160, .g = 150, .b = 72, .a = 220 } });
        var k: i32 = 0;
        while (k <= 5) : (k += 1) {
            neko.draw.line(p1x + 10, p1y + 96 + k * 3, p1x + 118, p1y + 90 + k * 3, neko.Color{ .r = 45, .g = 42, .b = 50, .a = 120 });
        }

        const flyer_x: i32 = self.bw_left + 42;
        const flyer_y: i32 = self.bw_top + 70;
        neko.draw.rect(neko.Rect{ .x = flyer_x, .y = flyer_y, .w = 84, .h = 104 }, neko.Color{ .r = 64, .g = 58, .b = 62 }, true);
        neko.draw.rect(neko.Rect{ .x = flyer_x + 5, .y = flyer_y + 8, .w = 74, .h = 88 }, neko.Color{ .r = 38, .g = 34, .b = 40 }, true);
        neko.sprite.text("RULES", flyer_x + 42, flyer_y + 26, .{ .size = 12, .center = true, .color = neko.Color{ .r = 188, .g = 182, .b = 168, .a = 245 } });
        var f: i32 = 0;
        while (f <= 5) : (f += 1) {
            neko.draw.line(flyer_x + 12, flyer_y + 40 + f * 9, flyer_x + 70, flyer_y + 40 + f * 9, neko.Color{ .r = 74, .g = 70, .b = 64, .a = 180 });
        }

        const clock_x: i32 = self.vp_x + 120;
        const clock_y: i32 = self.bw_top + 30;
        neko.draw.circle(clock_x, clock_y, 18, neko.Color{ .r = 50, .g = 48, .b = 55 }, true);
        neko.draw.circle(clock_x, clock_y, 18, colors.WALL_ACCENT, false);

        var g: i32 = 0;
        while (g <= 7) : (g += 1) {
            const gx: i32 = self.bw_left + 40 + g * 58;
            neko.draw.line(gx, self.bw_top + 44, gx + 8, self.bw_bottom - 26, neko.Color{ .r = 30, .g = 26, .b = 33, .a = 90 });
        }
        neko.draw.line(self.vp_x, self.bw_top, self.vp_x, self.bw_bottom, neko.Color{ .r = 60, .g = 55, .b = 65, .a = 120 });
    }

    fn draw_back_wall_dynamic(self: *Office, t: f32) void {
        const clock_x: i32 = self.vp_x + 120;
        const clock_y: i32 = self.bw_top + 30;
        neko.draw.line(clock_x, clock_y, clock_x + @as(i32, @intFromFloat(@cos(t) * 10.0)), clock_y + @as(i32, @intFromFloat(@sin(t) * 10.0)), neko.Color{ .r = 140, .g = 130, .b = 120 });
        const pulse: f32 = 0.45 + 0.55 * @sin(t * 2.8);
        const lamp_a: u8 = @intFromFloat(26.0 + pulse * 38.0);
        neko.draw.rect(neko.Rect{ .x = self.vp_x - 120, .y = self.bw_top + 6, .w = 240, .h = 16 }, neko.Color{ .r = 220, .g = 210, .b = 165, .a = lamp_a }, true);
    }

    fn draw_depth_structure(self: *Office) void {
        const depths = [6]f32{ 0.12, 0.24, 0.36, 0.50, 0.66, 0.82 };
        for (depths) |z| {
            const l = self.project_depth(-1.0, z, 0);
            const r = self.project_depth(1.0, z, 0);
            const shade_val: u8 = @intFromFloat(70.0 - z * 28.0);
            neko.draw.line(l.x, l.y, r.x, r.y, neko.Color{ .r = shade_val, .g = shade_val, .b = shade_val + 4, .a = 120 });
        }

        const side_depths = [3]f32{ 0.18, 0.42, 0.70 };
        const sides = [2]i32{ -1, 1 };
        for (sides) |side| {
            for (side_depths) |z| {
                const s0: f32 = @floatFromInt(side);
                const p0 = self.project_depth(0.82 * s0, z, 0);
                const p1 = self.project_depth(0.82 * s0, z, 150);
                const ww: i32 = @max(8, @as(i32, @intFromFloat(16.0 * p0.s)));
                const col = shade(neko.Color{ .r = 48, .g = 45, .b = 52 }, 1.05 - z * 0.35);
                neko.draw.rect(neko.Rect{ .x = p0.x - @divTrunc(ww, 2), .y = p1.y, .w = ww, .h = @max(8, p0.y - p1.y) }, neko.Color{ .r = col.r, .g = col.g, .b = col.b, .a = 150 }, true);
            }
        }
    }

    fn draw_side_walls(self: *Office) void {
        neko.draw.quad(
            neko.Point{ .x = self.bw_left - self.hall_depth, .y = 0 },
            neko.Point{ .x = self.bw_left, .y = self.bw_top },
            neko.Point{ .x = self.bw_left, .y = self.bw_bottom },
            neko.Point{ .x = self.bw_left - self.hall_depth, .y = constants.SCREEN_HEIGHT },
            neko.Color{ .r = 38, .g = 35, .b = 42 },
        );
        neko.draw.quad(
            neko.Point{ .x = self.bw_right, .y = self.bw_top },
            neko.Point{ .x = self.bw_right + self.hall_depth, .y = 0 },
            neko.Point{ .x = self.bw_right + self.hall_depth, .y = constants.SCREEN_HEIGHT },
            neko.Point{ .x = self.bw_right, .y = self.bw_bottom },
            neko.Color{ .r = 38, .g = 35, .b = 42 },
        );
    }

    fn draw_hallways_base(self: *Office) void {
        const ht: i32 = self.bw_top + 15;
        const hb: i32 = self.bw_bottom - 15;
        const lx: i32 = self.bw_left - self.hall_depth - self.hall_w;
        const lw: i32 = self.hall_w + 10;
        const lh: i32 = hb - ht;

        neko.draw.rect(neko.Rect{ .x = lx, .y = ht, .w = lw, .h = lh }, neko.Color{ .r = 8, .g = 8, .b = 10 }, true);
        neko.draw.rect(neko.Rect{ .x = lx, .y = ht, .w = lw, .h = lh }, colors.DOOR_FRAME_COLOR, false);
        var i: i32 = 0;
        while (i <= 8) : (i += 1) {
            const y: i32 = ht + @divTrunc(i * lh, 9);
            const c = if (@mod(i, 2) == 0) neko.Color{ .r = 168, .g = 138, .b = 42 } else neko.Color{ .r = 35, .g = 30, .b = 28 };
            neko.draw.line(lx + lw - 10, y, lx + lw, y, neko.Color{ .r = c.r, .g = c.g, .b = c.b, .a = 210 });
        }

        const rx: i32 = self.bw_right + self.hall_depth - 10;
        const rw: i32 = self.hall_w + 10;
        neko.draw.rect(neko.Rect{ .x = rx, .y = ht, .w = rw, .h = lh }, neko.Color{ .r = 8, .g = 8, .b = 10 }, true);
        neko.draw.rect(neko.Rect{ .x = rx, .y = ht, .w = rw, .h = lh }, colors.DOOR_FRAME_COLOR, false);
        var j: i32 = 0;
        while (j <= 8) : (j += 1) {
            const y: i32 = ht + @divTrunc(j * lh, 9);
            const c = if (@mod(j, 2) == 0) neko.Color{ .r = 168, .g = 138, .b = 42 } else neko.Color{ .r = 35, .g = 30, .b = 28 };
            neko.draw.line(rx, y, rx + 10, y, neko.Color{ .r = c.r, .g = c.g, .b = c.b, .a = 210 });
        }
    }

    fn draw_hallways_dynamic(self: *Office, left_light: bool, right_light: bool, anim_left: ?AnimatronicId, anim_right: ?AnimatronicId) void {
        const ht: i32 = self.bw_top + 15;
        const hb: i32 = self.bw_bottom - 15;
        const lx: i32 = self.bw_left - self.hall_depth - self.hall_w;
        const lw: i32 = self.hall_w + 10;
        const lh: i32 = hb - ht;
        const rx: i32 = self.bw_right + self.hall_depth - 10;
        const rw: i32 = self.hall_w + 10;

        if (left_light) {
            neko.draw.rect(neko.Rect{ .x = lx, .y = ht, .w = lw, .h = lh }, neko.Color{ .r = colors.HALL_LIGHT.r, .g = colors.HALL_LIGHT.g, .b = colors.HALL_LIGHT.b, .a = 70 }, true);
            neko.draw.rect(neko.Rect{ .x = lx + 6, .y = ht + 8, .w = lw - 12, .h = lh - 16 }, neko.Color{ .r = 226, .g = 214, .b = 170, .a = 24 }, true);
            if (anim_left) |a| neko.sprite.face(a.name(), lx + 10, ht + 20, lw - 20, 160);
        }
        if (right_light) {
            neko.draw.rect(neko.Rect{ .x = rx, .y = ht, .w = rw, .h = lh }, neko.Color{ .r = colors.HALL_LIGHT.r, .g = colors.HALL_LIGHT.g, .b = colors.HALL_LIGHT.b, .a = 70 }, true);
            neko.draw.rect(neko.Rect{ .x = rx + 6, .y = ht + 8, .w = rw - 12, .h = lh - 16 }, neko.Color{ .r = 226, .g = 214, .b = 170, .a = 24 }, true);
            if (anim_right) |a| neko.sprite.face(a.name(), rx + 10, ht + 20, rw - 20, 160);
        }
    }

    fn draw_vent_base(self: *Office) void {
        const vx: i32 = self.vp_x - 60;
        const vy: i32 = self.bw_bottom - 110;
        const vw: i32 = 120;
        const vh: i32 = 80;
        neko.draw.rect(neko.Rect{ .x = vx, .y = vy, .w = vw, .h = vh }, neko.Color{ .r = 5, .g = 5, .b = 7 }, true);
        neko.draw.rect(neko.Rect{ .x = vx, .y = vy, .w = vw, .h = vh }, neko.Color{ .r = 40, .g = 40, .b = 45 }, false);
        var i: i32 = 1;
        while (i <= 3) : (i += 1) {
            const by: i32 = vy + @divTrunc(i * vh, 4);
            neko.draw.line(vx, by, vx + vw, by, neko.Color{ .r = 35, .g = 35, .b = 40 });
        }
    }

    fn draw_vent_dynamic(self: *Office, anim_vent: ?AnimatronicId) void {
        const vx: i32 = self.vp_x - 60;
        const vy: i32 = self.bw_bottom - 110;
        const vw: i32 = 120;
        const vh: i32 = 80;
        if (self.vent_light) {
            neko.draw.rect(neko.Rect{ .x = vx, .y = vy, .w = vw, .h = vh }, neko.Color{ .r = 200, .g = 200, .b = 220, .a = 90 }, true);
            if (anim_vent) |a| neko.sprite.face(a.name(), vx + 20, vy + 10, vw - 40, vh - 20);
        } else if (anim_vent) |_| {
            neko.draw.circle(vx + 45, vy + 30, 4, neko.Color{ .r = 255, .g = 200, .b = 220 }, true);
            neko.draw.circle(vx + 75, vy + 30, 4, neko.Color{ .r = 255, .g = 200, .b = 220 }, true);
        }
    }

    fn draw_doors(self: *Office, left_anim: f32, right_anim: f32) void {
        const ht: i32 = self.bw_top + 15;
        const hb: i32 = self.bw_bottom - 15;
        const door_h: i32 = hb - ht;
        if (left_anim > 0.01) {
            self.draw_single_door(self.bw_left - self.hall_depth - self.hall_w, ht, self.hall_w + 10, @intFromFloat(@as(f32, @floatFromInt(door_h)) * left_anim));
        }
        if (right_anim > 0.01) {
            self.draw_single_door(self.bw_right + self.hall_depth - 10, ht, self.hall_w + 10, @intFromFloat(@as(f32, @floatFromInt(door_h)) * right_anim));
        }
    }

    fn draw_single_door(self: *Office, x: i32, y: i32, w: i32, v_h: i32) void {
        _ = self;
        neko.draw.rect(neko.Rect{ .x = x, .y = y, .w = w, .h = v_h }, colors.DOOR_COLOR, true);
        var i: i32 = 0;
        while (i < v_h) : (i += 14) {
            neko.draw.line(x, y + i, x + w, y + i, neko.Color{ .r = 85, .g = 80, .b = 78 });
        }
        const sh: i32 = 12;
        var j: i32 = 0;
        while (j <= w + sh) : (j += sh) {
            neko.draw.line(x + j, y, x + j - sh, y + @min(sh, v_h), neko.Color{ .r = 200, .g = 180, .b = 40 });
        }
        if (v_h > 80) {
            neko.draw.rect(neko.Rect{ .x = x + @divTrunc(w, 2) - 18, .y = y + 35, .w = 36, .h = 28 }, neko.Color{ .r = 15, .g = 25, .b = 15 }, true);
            neko.draw.rect(neko.Rect{ .x = x + @divTrunc(w, 2) - 18, .y = y + 35, .w = 36, .h = 28 }, neko.Color{ .r = 95, .g = 90, .b = 85 }, false);
        }
        neko.draw.rect(neko.Rect{ .x = x, .y = y, .w = w, .h = v_h }, neko.Color{ .r = 95, .g = 90, .b = 85 }, false);
    }

    fn draw_office_elements(self: *Office) void {
        const vx: i32 = self.vp_x;
        const back_y: i32 = 630;
        const front_y: i32 = 686;
        const back_hw: i32 = 230;
        const front_hw: i32 = 402;

        // Desk top (a clear, solid surface that stays on screen).
        neko.draw.quad(
            neko.Point{ .x = vx - back_hw, .y = back_y },
            neko.Point{ .x = vx + back_hw, .y = back_y },
            neko.Point{ .x = vx + front_hw, .y = front_y },
            neko.Point{ .x = vx - front_hw, .y = front_y },
            colors.DESK_TOP,
        );
        neko.draw.line(vx - back_hw, back_y, vx + back_hw, back_y, neko.Color{ .r = 128, .g = 110, .b = 92 });

        // Front face + a drawer.
        const face = shade(colors.DESK_COLOR, 0.82);
        neko.draw.quad(
            neko.Point{ .x = vx - front_hw, .y = front_y },
            neko.Point{ .x = vx + front_hw, .y = front_y },
            neko.Point{ .x = vx + front_hw, .y = 714 },
            neko.Point{ .x = vx - front_hw, .y = 714 },
            face,
        );
        neko.draw.line(vx - front_hw, front_y, vx + front_hw, front_y, neko.Color{ .r = 150, .g = 132, .b = 112 });
        neko.draw.rect(neko.Rect{ .x = vx + 250, .y = 690, .w = 96, .h = 20 }, neko.Color{ .r = 70, .g = 60, .b = 54 }, true);
        neko.draw.rect(neko.Rect{ .x = vx + 250, .y = 690, .w = 96, .h = 20 }, neko.Color{ .r = 40, .g = 34, .b = 30 }, false);

        // Keyboard on the desk.
        neko.draw.rect(neko.Rect{ .x = vx - 118, .y = 656, .w = 236, .h = 26 }, neko.Color{ .r = 38, .g = 40, .b = 46 }, true);
        neko.draw.rect(neko.Rect{ .x = vx - 118, .y = 656, .w = 236, .h = 26 }, neko.Color{ .r = 90, .g = 92, .b = 100 }, false);
        var kr: i32 = 0;
        while (kr < 3) : (kr += 1) {
            neko.draw.line(vx - 108, 662 + kr * 6, vx + 108, 662 + kr * 6, neko.Color{ .r = 70, .g = 72, .b = 80 });
        }

        // Monitor (rises from the back of the desk; kept compact).
        neko.draw.rect(neko.Rect{ .x = vx + 180, .y = 470, .w = 160, .h = 106 }, neko.Color{ .r = 16, .g = 18, .b = 22 }, true);
        neko.draw.rect(neko.Rect{ .x = vx + 180, .y = 470, .w = 160, .h = 106 }, neko.Color{ .r = 72, .g = 76, .b = 84 }, false);
        neko.draw.rect(neko.Rect{ .x = vx + 186, .y = 476, .w = 148, .h = 94 }, neko.Color{ .r = 10, .g = 15, .b = 12 }, true);
        neko.draw.rect(neko.Rect{ .x = vx + 252, .y = 576, .w = 16, .h = 40 }, neko.Color{ .r = 40, .g = 40, .b = 46 }, true);
        neko.draw.rect(neko.Rect{ .x = vx + 208, .y = 614, .w = 104, .h = 14 }, neko.Color{ .r = 46, .g = 46, .b = 52 }, true);

        // Cupcake and mug on the desk (clear of the keyboard).
        neko.draw.rect(neko.Rect{ .x = vx + 122, .y = 646, .w = 30, .h = 30 }, neko.Color{ .r = 190, .g = 120, .b = 150 }, true);
        neko.draw.rect(neko.Rect{ .x = vx + 116, .y = 642, .w = 42, .h = 10 }, neko.Color{ .r = 200, .g = 60, .b = 70 }, true);
        neko.draw.rect(neko.Rect{ .x = vx + 122, .y = 666, .w = 30, .h = 20 }, neko.Color{ .r = 150, .g = 100, .b = 60 }, true);

        neko.draw.rect(neko.Rect{ .x = vx - 162, .y = 652, .w = 24, .h = 28 }, neko.Color{ .r = 120, .g = 115, .b = 102 }, true);
        neko.draw.rect(neko.Rect{ .x = vx - 140, .y = 658, .w = 6, .h = 14 }, neko.Color{ .r = 120, .g = 115, .b = 102 }, false);
    }

    fn draw_fan(self: *Office, t: f32) void {
        const cx: i32 = self.vp_x - 330;
        const cy: i32 = 594;
        const ring_r: i32 = 36;
        const hub_r: i32 = 7;

        // Base + stem sitting on the desk.
        neko.draw.rect(neko.Rect{ .x = cx - 16, .y = 660, .w = 32, .h = 22 }, neko.Color{ .r = 55, .g = 55, .b = 60 }, true);
        neko.draw.rect(neko.Rect{ .x = cx - 8, .y = 630, .w = 16, .h = 32 }, neko.Color{ .r = 60, .g = 60, .b = 66 }, true);

        neko.draw.circle(cx, cy, ring_r, neko.Color{ .r = 70, .g = 24, .b = 24 }, true);
        neko.draw.circle(cx, cy, ring_r - 4, neko.Color{ .r = 46, .g = 46, .b = 50 }, true);

        const ft: f32 = t * 12.0;
        var i: i32 = 0;
        while (i < 4) : (i += 1) {
            const angle: f32 = ft + @as(f32, @floatFromInt(i)) * (PI / 2.0);
            const ex: i32 = cx + @as(i32, @intFromFloat(@cos(angle) * @as(f32, @floatFromInt(ring_r - 6))));
            const ey: i32 = cy + @as(i32, @intFromFloat(@sin(angle) * @as(f32, @floatFromInt(ring_r - 6))));
            neko.draw.line(cx, cy, ex, ey, neko.Color{ .r = 110, .g = 110, .b = 115 });
        }
        neko.draw.circle(cx, cy, hub_r, neko.Color{ .r = 82, .g = 82, .b = 88 }, true);
    }

    fn draw_wall_dressing(self: *Office) void {
        const sides = [2]i32{ -1, 1 };
        for (sides) |side| {
            const base_x: i32 = if (side < 0) (self.bw_left - self.hall_depth + 22) else (self.bw_right + self.hall_depth - 130);
            neko.draw.rect(neko.Rect{ .x = base_x, .y = self.bw_top + 44, .w = 108, .h = 30 }, neko.Color{ .r = 26, .g = 24, .b = 30 }, true);
            neko.draw.rect(neko.Rect{ .x = base_x + 3, .y = self.bw_top + 47, .w = 102, .h = 24 }, neko.Color{ .r = 56, .g = 18, .b = 18 }, true);
            neko.sprite.text("DOOR CTRL", base_x + 54, self.bw_top + 59, .{ .size = 11, .center = true, .color = neko.Color{ .r = 220, .g = 214, .b = 194, .a = 240 } });
        }
        var i: i32 = 0;
        while (i <= 3) : (i += 1) {
            const x0: i32 = self.vp_x - 150 + i * 92;
            const y0: i32 = self.bw_bottom - 56 - i * 4;
            neko.draw.line(x0, y0, x0 + 78, y0 - 8, neko.Color{ .r = 26, .g = 24, .b = 30, .a = 180 });
        }
    }

    fn draw_in_office(self: *Office, anim: ?AnimatronicId) void {
        if (anim) |a| {
            const w: i32 = 400;
            const h: i32 = 500;
            const x: i32 = constants.OFFICE_WIDTH / 2 - w / 2;
            const y: i32 = self.bw_bottom - h + 80;
            const ct: i32 = @intFromFloat(@as(f32, @floatFromInt(neko.time.ticks_ms())) / 1000.0 * 7.0);
            if (@mod(ct, 3) != 0) neko.sprite.draw(a.name(), x, y, w, h);
        }
    }

    fn draw_ambient(self: *Office) void {
        _ = self;
        neko.draw.rect(neko.Rect{ .x = 0, .y = 0, .w = constants.OFFICE_WIDTH, .h = constants.SCREEN_HEIGHT }, neko.Color{ .r = 0, .g = 0, .b = 0, .a = 24 }, true);
        neko.draw.rect(neko.Rect{ .x = 0, .y = 0, .w = constants.OFFICE_WIDTH, .h = 120 }, neko.Color{ .r = 0, .g = 0, .b = 0, .a = 40 }, true);
        neko.draw.rect(neko.Rect{ .x = 0, .y = constants.SCREEN_HEIGHT - 90, .w = constants.OFFICE_WIDTH, .h = 90 }, neko.Color{ .r = 0, .g = 0, .b = 0, .a = 32 }, true);
        var i: i32 = 0;
        while (i <= 6) : (i += 1) {
            const y: i32 = @intFromFloat(@as(f32, @floatFromInt(i)) * (@as(f32, @floatFromInt(constants.SCREEN_HEIGHT)) / 7.0));
            const a: i32 = 20 - i * 2;
            if (a > 0) {
                neko.draw.rect(neko.Rect{ .x = 0, .y = y, .w = constants.OFFICE_WIDTH, .h = @divTrunc(constants.SCREEN_HEIGHT, 7) }, neko.Color{ .r = 0, .g = 0, .b = 0, .a = @intCast(a) }, true);
            }
        }
    }
};

fn in_rect(r: neko.Rect, x: i32, y: i32) bool {
    return x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h;
}

fn draw_button(r: neko.Rect, label: []const u8, on: bool, on_color: neko.Color) void {
    const fill: neko.Color = if (on) on_color else colors.BUTTON_OFF;
    neko.draw.rect(r, fill, true);
    neko.draw.rect(r, neko.Color{ .r = 200, .g = 200, .b = 200 }, false);
    neko.sprite.text(label, r.x + @divTrunc(r.w, 2), r.y + @divTrunc(r.h, 2), .{
        .size = 14,
        .center = true,
        .color = if (on) colors.BLACK else neko.Color{ .r = 180, .g = 180, .b = 180 },
    });
}
