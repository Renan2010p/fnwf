//! Security cameras monitor and map — port of `systems/CameraSystem`.
//!
//! Animatronic positions and camera ids are enums here (the C++ used strings).

const std: type = @import("std");
const fmt: type = std.fmt;
const neko: type = @import("neko");
const common: type = @import("common");

const constants: type = @import("../config/constants.zig");
const colors: type = @import("../config/colors.zig");
const locations: type = @import("../world/locations.zig");
const CameraId: type = locations.CameraId;
const Location: type = locations.Location;

/// Where the two cameras-visible animatronics are.
pub const CamPositions: type = struct {
    cedro: Location,
    eser: Location,
};

const Toggles: type = struct {
    mask: neko.Rect,
    monitor: neko.Rect,
};

const CamButton: type = struct {
    id: CameraId,
    rect: neko.Rect,
};

const MapPos: type = struct {
    id: CameraId,
    x: i32,
    y: i32,
};

const map_buttons: [9]MapPos = .{
    .{ .id = .stage, .x = 130, .y = 40 },
    .{ .id = .dining, .x = 130, .y = 80 },
    .{ .id = .backstage, .x = 60, .y = 100 },
    .{ .id = .pirate_cove, .x = 145, .y = 105 },
    .{ .id = .west_hall, .x = 90, .y = 150 },
    .{ .id = .west_corner, .x = 90, .y = 210 },
    .{ .id = .supply, .x = 50, .y = 160 },
    .{ .id = .east_hall, .x = 170, .y = 150 },
    .{ .id = .east_corner, .x = 170, .y = 210 },
};

const connections: [8][2]CameraId = .{
    .{ .stage, .dining },
    .{ .dining, .backstage },
    .{ .backstage, .pirate_cove },
    .{ .dining, .west_hall },
    .{ .west_hall, .west_corner },
    .{ .west_hall, .supply },
    .{ .dining, .east_hall },
    .{ .east_hall, .east_corner },
};

/// The security camera system.
pub const CameraSystem: type = struct {
    map_w: i32 = 260,
    map_h: i32 = 300,
    map_x: i32 = 0,
    map_y: i32 = 0,

    is_open: bool = false,
    current_cam: CameraId = .stage,
    is_mask_open: bool = false,
    is_mask_animating: bool = false,
    is_animating: bool = false,

    static_timer: f32 = 0,
    static_duration: f32 = 0.4,
    anim_progress: f32 = 0,
    anim_speed: f32 = 5.0,
    mask_anim_progress: f32 = 0,
    mask_anim_speed: f32 = 4.0,
    mouse_trigger_zone: f32 = 60.0,
    mouse_in_cam_zone: bool = false,
    mouse_in_mask_zone: bool = false,

    monitor_tex: neko.TextureHandle = neko.TextureHandle{ .id = 0 },
    map_tex: neko.TextureHandle = neko.TextureHandle{ .id = 0 },
    map_base_tex: neko.TextureHandle = neko.TextureHandle{ .id = 0 },
    map_base_dirty: bool = true,

    cam_buttons: [16]CamButton = undefined,
    cam_button_count: usize = 0,

    pub fn init(self: *CameraSystem) void {
        self.map_x = constants.SCREEN_WIDTH - self.map_w - 20;
        self.map_y = constants.SCREEN_HEIGHT - self.map_h - 60;

        if (!neko.screen.supports_offscreen_targets()) return;

        self.monitor_tex = neko.texture.create_target(@intCast(constants.SCREEN_WIDTH), @intCast(constants.SCREEN_HEIGHT)) orelse return;
        self.map_tex = neko.texture.create_target(@intCast(self.map_w), @intCast(self.map_h)) orelse return;
        self.map_base_tex = neko.texture.create_target(@intCast(self.map_w), @intCast(self.map_h)) orelse return;
    }

    pub fn toggle(self: *CameraSystem) void {
        // If the mask is up, lift it and raise the monitor in one step, so the
        // cameras are never blocked by the mask overlay.
        if (self.is_mask_open or self.is_mask_animating) {
            self.is_mask_open = false;
            self.is_mask_animating = false;
            self.is_open = true;
            self.is_animating = true;
            self.static_timer = self.static_duration;
            common.sound.stop_mask_breathing();
            return;
        }
        self.is_open = !self.is_open;
        self.is_animating = true;
        if (self.is_open) self.static_timer = self.static_duration;
    }

    pub fn toggle_mask(self: *CameraSystem) void {
        if (self.is_open or self.is_animating or self.is_mask_animating) return;
        self.is_mask_open = !self.is_mask_open;
        self.is_mask_animating = true;
        if (self.is_mask_open) {
            common.sound.play("mask_on", 0, -1);
            common.sound.play_mask_breathing();
        } else {
            common.sound.play("mask_off", 0, -1);
            common.sound.stop_mask_breathing();
        }
    }

    pub fn force_remove_mask(self: *CameraSystem) void {
        if (!self.is_mask_open and self.mask_anim_progress <= 0.0) return;
        if (self.is_mask_animating and !self.is_mask_open) return;
        self.is_mask_open = false;
        self.is_mask_animating = true;
    }

    pub fn switch_camera(self: *CameraSystem, cam_id: CameraId) void {
        if (cam_id != self.current_cam) {
            self.current_cam = cam_id;
            self.static_timer = self.static_duration;
        }
    }

    pub fn is_fully_open(self: *const CameraSystem) bool {
        return self.is_open and self.anim_progress >= 0.99;
    }

    pub fn is_visible(self: *const CameraSystem) bool {
        return self.anim_progress > 0.01;
    }

    fn bottom_toggles(self: *const CameraSystem) Toggles {
        _ = self;
        const btn_w: i32 = 300;
        const btn_h: i32 = 28;
        const gap: i32 = 16;
        const total_w: i32 = btn_w * 2 + gap;
        const start_x: i32 = @divTrunc(constants.SCREEN_WIDTH, 2) - @divTrunc(total_w, 2);
        const btn_y: i32 = constants.SCREEN_HEIGHT - btn_h - 4;
        return Toggles{
            .mask = neko.Rect{ .x = start_x, .y = btn_y, .w = btn_w, .h = btn_h },
            .monitor = neko.Rect{ .x = start_x + btn_w + gap, .y = btn_y, .w = btn_w, .h = btn_h },
        };
    }

    pub fn check_toggle_click(self: *CameraSystem, mx: i32, my: i32) bool {
        const t = self.bottom_toggles();
        const r = t.monitor;
        if (in_rect(r, mx, my)) {
            if (!self.is_animating and !self.is_mask_open and !self.is_mask_animating) self.toggle();
            return true;
        }
        return false;
    }

    pub fn check_mask_toggle_click(self: *CameraSystem, mx: i32, my: i32) bool {
        const t = self.bottom_toggles();
        const r = t.mask;
        if (in_rect(r, mx, my)) {
            if (!self.is_mask_animating and !self.is_open and !self.is_animating) self.toggle_mask();
            return true;
        }
        return false;
    }

    pub fn check_mouse_trigger(self: *CameraSystem, mouse_x: i32, mouse_y: i32) bool {
        const t = self.bottom_toggles();
        const m = t.mask;
        const c = t.monitor;

        const gesture_h: f32 = @max(@as(f32, @floatFromInt(m.h + 18)), self.mouse_trigger_zone);
        const in_mask = mouse_x >= m.x and mouse_x <= m.x + m.w and @as(f32, @floatFromInt(mouse_y)) >= @as(f32, @floatFromInt(m.y)) - 14.0 and @as(f32, @floatFromInt(mouse_y)) <= @as(f32, @floatFromInt(m.y)) - 14.0 + gesture_h;
        const in_cam = mouse_x >= c.x and mouse_x <= c.x + c.w and @as(f32, @floatFromInt(mouse_y)) >= @as(f32, @floatFromInt(c.y)) - 14.0 and @as(f32, @floatFromInt(mouse_y)) <= @as(f32, @floatFromInt(c.y)) - 14.0 + gesture_h;

        if (in_cam and !self.mouse_in_cam_zone) {
            if (!self.is_animating and !self.is_mask_open and !self.is_mask_animating) {
                self.toggle();
                self.mouse_in_cam_zone = true;
                return true;
            }
        } else if (!in_cam) {
            self.mouse_in_cam_zone = false;
        }

        if (in_mask and !self.mouse_in_mask_zone) {
            if (!self.is_mask_animating and !self.is_open and !self.is_animating) {
                self.toggle_mask();
                self.mouse_in_mask_zone = true;
                return true;
            }
        } else if (!in_mask) {
            self.mouse_in_mask_zone = false;
        }

        return false;
    }

    pub fn handle_click(self: *CameraSystem, mx: i32, my: i32) bool {
        if (!self.is_fully_open()) return false;

        var i: usize = 0;
        while (i < self.cam_button_count) : (i += 1) {
            const b = self.cam_buttons[i];
            if (in_rect(b.rect, mx, my)) {
                self.switch_camera(b.id);
                return true;
            }
        }

        const t = self.bottom_toggles();
        if (in_rect(t.monitor, mx, my)) {
            if (!self.is_animating and !self.is_mask_open and !self.is_mask_animating) self.toggle();
            return true;
        }
        return false;
    }

    pub fn update(self: *CameraSystem, dt: f32) void {
        if (self.static_timer > 0) self.static_timer -= dt;

        const target: f32 = if (self.is_open) 1.0 else 0.0;
        if (self.anim_progress != target) {
            self.is_animating = true;
            if (self.anim_progress < target) {
                self.anim_progress = @min(target, self.anim_progress + self.anim_speed * dt);
            } else {
                self.anim_progress = @max(target, self.anim_progress - self.anim_speed * dt);
            }
        } else {
            self.is_animating = false;
        }

        const mask_target: f32 = if (self.is_mask_open) 1.0 else 0.0;
        if (self.mask_anim_progress != mask_target) {
            self.is_mask_animating = true;
            if (self.mask_anim_progress < mask_target) {
                self.mask_anim_progress = @min(mask_target, self.mask_anim_progress + self.mask_anim_speed * dt);
            } else {
                self.mask_anim_progress = @max(mask_target, self.mask_anim_progress - self.mask_anim_speed * dt);
            }
        } else {
            self.is_mask_animating = false;
        }
    }

    pub fn draw(self: *CameraSystem, anim: CamPositions, sonk_stage: i32) void {
        const t = self.bottom_toggles();

        if (!self.is_mask_open and !self.is_visible()) {
            const pulse: f32 = 0.5 + 0.5 * @sin(@as(f32, @floatFromInt(neko.time.ticks_ms())) / 1000.0 * 5.0);
            const glow: u8 = @intFromFloat(80.0 + 70.0 * pulse);
            neko.draw.rect(t.mask, neko.Color{ .r = 28, .g = 22, .b = 18, .a = 230 }, true);
            neko.draw.rect(t.mask, neko.Color{ .r = 220, .g = glow, .b = 60 }, false);
            neko.sprite.text("MASK", t.mask.x + @divTrunc(t.mask.w, 2), t.mask.y + @divTrunc(t.mask.h, 2), neko.sprite.Options{
                .size = 12,
                .center = true,
                .color = neko.Color{ .r = 230, .g = 160, .b = 80 },
            });
        }

        if (!self.is_visible() and !self.is_mask_open) {
            const pulse: f32 = 0.5 + 0.5 * @sin(@as(f32, @floatFromInt(neko.time.ticks_ms())) / 1000.0 * 4.0);
            const edge_g: u8 = @intFromFloat(160.0 + 60.0 * pulse);
            neko.draw.rect(t.monitor, neko.Color{ .r = 12, .g = 18, .b = 12, .a = 220 }, true);
            neko.draw.rect(t.monitor, neko.Color{ .r = 40, .g = edge_g, .b = 90 }, false);
            neko.sprite.text("MONITOR", t.monitor.x + @divTrunc(t.monitor.w, 2), t.monitor.y + @divTrunc(t.monitor.h, 2), neko.sprite.Options{
                .size = 12,
                .center = true,
                .color = neko.Color{ .r = 120, .g = edge_g, .b = 160 },
            });
        }

        if (self.mask_anim_progress > 0.01) self.draw_mask_overlay();
        if (self.is_visible()) {
            if (self.is_fully_open()) {
                self.draw_monitor(anim, sonk_stage);
            } else {
                self.draw_monitor_animation();
            }
        }
    }

    fn draw_mask_overlay(self: *CameraSystem) void {
        const eased = ease_out_cubic(self.mask_anim_progress);
        const slide_offset: i32 = @intFromFloat((1.0 - eased) * @as(f32, @floatFromInt(-constants.SCREEN_HEIGHT)));

        const mr: u8 = 44;
        const mg: u8 = 33;
        const mb: u8 = 22;
        const ma: u8 = 185;
        const y_top: i32 = slide_offset;
        const y_bottom: i32 = slide_offset + constants.SCREEN_HEIGHT;
        const eye_w: i32 = 210;
        const eye_h: i32 = 170;
        const eye_gap: i32 = 90;
        const eye_y: i32 = slide_offset + @divTrunc(constants.SCREEN_HEIGHT, 2) - 88;
        const left_eye_x: i32 = @divTrunc(constants.SCREEN_WIDTH, 2) - @divTrunc(eye_gap, 2) - eye_w;
        const right_eye_x: i32 = @divTrunc(constants.SCREEN_WIDTH, 2) + @divTrunc(eye_gap, 2);

        const mc = neko.Color{ .r = mr, .g = mg, .b = mb, .a = ma };
        neko.draw.rect(neko.Rect{ .x = 0, .y = y_top, .w = constants.SCREEN_WIDTH, .h = @max(0, eye_y - y_top) }, mc, true);
        neko.draw.rect(neko.Rect{ .x = 0, .y = eye_y + eye_h, .w = constants.SCREEN_WIDTH, .h = @max(0, y_bottom - (eye_y + eye_h)) }, mc, true);
        neko.draw.rect(neko.Rect{ .x = 0, .y = eye_y, .w = @max(0, left_eye_x), .h = eye_h }, mc, true);
        const middle_x: i32 = left_eye_x + eye_w;
        const middle_w: i32 = right_eye_x - middle_x;
        neko.draw.rect(neko.Rect{ .x = middle_x, .y = eye_y, .w = @max(0, middle_w), .h = eye_h }, mc, true);
        neko.draw.rect(neko.Rect{ .x = right_eye_x + eye_w, .y = eye_y, .w = @max(0, constants.SCREEN_WIDTH - (right_eye_x + eye_w)), .h = eye_h }, mc, true);

        neko.draw.rect(neko.Rect{ .x = @divTrunc(constants.SCREEN_WIDTH, 2) - 34, .y = eye_y + eye_h - 10, .w = 68, .h = 120 }, neko.Color{ .r = 48, .g = 36, .b = 24, .a = 210 }, true);
        neko.draw.rect(neko.Rect{ .x = left_eye_x, .y = eye_y, .w = eye_w, .h = eye_h }, neko.Color{ .r = 100, .g = 78, .b = 50 }, false);
        neko.draw.rect(neko.Rect{ .x = right_eye_x, .y = eye_y, .w = eye_w, .h = eye_h }, neko.Color{ .r = 100, .g = 78, .b = 50 }, false);
    }

    fn draw_monitor(self: *CameraSystem, anim: CamPositions, sonk_stage: i32) void {
        const eased = ease_out_cubic(self.anim_progress);
        const slide_offset: i32 = @intFromFloat((1.0 - eased) * @as(f32, @floatFromInt(constants.SCREEN_HEIGHT - 40)));
        const direct = !neko.screen.supports_offscreen_targets();

        if (direct) {
            neko.screen.set_draw_offset(0, slide_offset);
        } else {
            neko.texture.set_target(self.monitor_tex);
        }
        neko.draw.clear(neko.Color{ .r = 5, .g = 10, .b = 5, .a = 230 });

        if (self.static_timer > 0) {
            neko.effect.noise(0, 0, constants.SCREEN_WIDTH, constants.SCREEN_HEIGHT, 0.5);
        } else {
            self.draw_camera_view(anim, sonk_stage);
            self.draw_map();
            var buf: [16]u8 = undefined;
            const label = fmt.bufPrint(&buf, "CAM {s}", .{self.current_cam.code()}) catch "CAM";
            neko.sprite.text(label, 30, 30, neko.sprite.Options{ .size = 20, .color = colors.CAM_OUTLINE });
            neko.effect.scanlines(0, 0, constants.SCREEN_WIDTH, constants.SCREEN_HEIGHT, 20);
            neko.effect.noise(0, 0, constants.SCREEN_WIDTH, constants.SCREEN_HEIGHT, 0.02);

            if ((neko.time.ticks_ms() / 1000) % 2 == 0) {
                neko.draw.rect(neko.Rect{ .x = constants.SCREEN_WIDTH - 50, .y = 35, .w = 12, .h = 12 }, neko.Color{ .r = 200, .g = 30, .b = 30 }, true);
                neko.sprite.text("REC", constants.SCREEN_WIDTH - 35, 28, neko.sprite.Options{ .size = 14, .color = neko.Color{ .r = 200, .g = 30, .b = 30 } });
            }
        }

        if (direct) {
            neko.screen.set_draw_offset(0, 0);
        } else {
            neko.texture.reset_target();
            neko.texture.draw(self.monitor_tex, neko.Rect{ .x = 0, .y = slide_offset, .w = constants.SCREEN_WIDTH, .h = constants.SCREEN_HEIGHT }, null, null);
        }

        const btn_w: i32 = 400;
        const btn_x: i32 = @divTrunc(constants.SCREEN_WIDTH, 2) - @divTrunc(btn_w, 2);
        const close_btn_y: i32 = slide_offset + constants.SCREEN_HEIGHT - 30;
        neko.draw.rect(neko.Rect{ .x = btn_x, .y = close_btn_y, .w = btn_w, .h = 30 }, neko.Color{ .r = 20, .g = 25, .b = 20 }, true);
        neko.draw.rect(neko.Rect{ .x = btn_x, .y = close_btn_y, .w = btn_w, .h = 30 }, neko.Color{ .r = 200, .g = 60, .b = 60 }, false);
        neko.sprite.text("CLOSE", btn_x + @divTrunc(btn_w, 2), close_btn_y + 15, neko.sprite.Options{ .size = 12, .center = true, .color = neko.Color{ .r = 200, .g = 60, .b = 60 } });
    }

    fn draw_monitor_animation(self: *CameraSystem) void {
        const progress = ease_out_cubic(self.anim_progress);
        const slide_offset: i32 = @intFromFloat((1.0 - progress) * @as(f32, @floatFromInt(constants.SCREEN_HEIGHT - 40)));

        neko.draw.rect(neko.Rect{ .x = 16, .y = slide_offset, .w = constants.SCREEN_WIDTH - 32, .h = constants.SCREEN_HEIGHT }, neko.Color{ .r = 42, .g = 42, .b = 48, .a = 245 }, true);
        neko.draw.rect(neko.Rect{ .x = 16, .y = slide_offset, .w = constants.SCREEN_WIDTH - 32, .h = constants.SCREEN_HEIGHT }, neko.Color{ .r = 180, .g = 180, .b = 180 }, false);

        const bar_alpha: u8 = @intFromFloat(120.0 + 100.0 * (1.0 - progress));
        var i: i32 = 0;
        while (i <= 5) : (i += 1) {
            const y: i32 = slide_offset + 40 + i * 90 + @as(i32, @intFromFloat((1.0 - progress) * 24.0));
            neko.draw.rect(neko.Rect{ .x = 28, .y = y, .w = constants.SCREEN_WIDTH - 56, .h = 18 }, neko.Color{ .r = 20, .g = 30, .b = 20, .a = bar_alpha }, true);
        }
    }

    fn draw_camera_view(self: *CameraSystem, anim: CamPositions, sonk_stage: i32) void {
        const cx: i32 = @divTrunc(constants.SCREEN_WIDTH, 2);
        const cy: i32 = @divTrunc(constants.SCREEN_HEIGHT, 2) - 30;
        switch (self.current_cam) {
            .stage => self.draw_show_stage(cx, cy, anim),
            .dining => self.draw_dining_area(cx, cy, anim),
            .backstage => self.draw_backstage(cx, cy, anim),
            .pirate_cove => self.draw_sonk_cove(cx, cy, sonk_stage),
            .west_hall, .east_hall => self.draw_hallway(cx, cy, anim),
            .west_corner, .east_corner => self.draw_hall_corner(cx, cy, anim),
            .supply => self.draw_supply_closet(cx, cy, anim),
            .vent => {},
        }
    }

    fn draw_show_stage(self: *CameraSystem, cx: i32, cy: i32, anim: CamPositions) void {
        _ = self;
        neko.draw.rect(neko.Rect{ .x = cx - 300, .y = cy - 150, .w = 600, .h = 350 }, neko.Color{ .r = 40, .g = 30, .b = 35 }, true);
        if (anim.cedro == .stage) neko.sprite.face("cedro", cx - 130, cy - 40, 100, 120);
        if (anim.eser == .stage) neko.sprite.face("eser", cx + 30, cy - 40, 100, 120);
    }

    fn draw_dining_area(self: *CameraSystem, cx: i32, cy: i32, anim: CamPositions) void {
        _ = self;
        neko.draw.rect(neko.Rect{ .x = cx - 300, .y = cy - 150, .w = 600, .h = 350 }, neko.Color{ .r = 30, .g = 28, .b = 32 }, true);
        if (anim.cedro == .dining) {
            neko.sprite.face("cedro", cx - 50, cy - 60, 100, 120);
        } else if (anim.eser == .dining) {
            neko.sprite.face("eser", cx - 50, cy - 60, 100, 120);
        }
    }

    fn draw_backstage(self: *CameraSystem, cx: i32, cy: i32, anim: CamPositions) void {
        _ = self;
        neko.draw.rect(neko.Rect{ .x = cx - 300, .y = cy - 150, .w = 600, .h = 350 }, neko.Color{ .r = 25, .g = 20, .b = 28 }, true);
        if (anim.cedro == .backstage) neko.sprite.face("cedro", cx - 60, cy - 40, 120, 150);
    }

    fn draw_hallway(self: *CameraSystem, cx: i32, cy: i32, anim: CamPositions) void {
        neko.draw.rect(neko.Rect{ .x = cx - 300, .y = cy - 150, .w = 600, .h = 350 }, neko.Color{ .r = 35, .g = 32, .b = 38 }, true);
        const loc = Location.from_camera(self.current_cam);
        if (anim.cedro == loc) {
            neko.sprite.face("cedro", cx - 50, cy - 50, 100, 130);
        } else if (anim.eser == loc) {
            neko.sprite.face("eser", cx - 50, cy - 50, 100, 130);
        }
    }

    fn draw_hall_corner(self: *CameraSystem, cx: i32, cy: i32, anim: CamPositions) void {
        neko.draw.rect(neko.Rect{ .x = cx - 300, .y = cy - 150, .w = 600, .h = 350 }, neko.Color{ .r = 20, .g = 18, .b = 22 }, true);
        const loc = Location.from_camera(self.current_cam);
        if (anim.cedro == loc) {
            neko.sprite.face("cedro", cx - 80, cy - 100, 160, 200);
        } else if (anim.eser == loc) {
            neko.sprite.face("eser", cx - 80, cy - 100, 160, 200);
        }
    }

    fn draw_supply_closet(self: *CameraSystem, cx: i32, cy: i32, anim: CamPositions) void {
        _ = self;
        neko.draw.rect(neko.Rect{ .x = cx - 300, .y = cy - 150, .w = 600, .h = 350 }, neko.Color{ .r = 28, .g = 25, .b = 30 }, true);
        if (anim.cedro == .supply) neko.sprite.face("cedro", cx - 60, cy - 40, 120, 150);
    }

    fn draw_sonk_cove(self: *CameraSystem, cx: i32, cy: i32, sonk_stage: i32) void {
        _ = self;
        neko.draw.rect(neko.Rect{ .x = cx - 300, .y = cy - 150, .w = 600, .h = 350 }, neko.Color{ .r = 15, .g = 12, .b = 20 }, true);
        neko.draw.rect(neko.Rect{ .x = cx - 280, .y = cy - 130, .w = 560, .h = 310 }, neko.Color{ .r = 35, .g = 30, .b = 45, .a = 120 }, true);

        var label: []const u8 = "EMPTY";
        if (sonk_stage == 1) {
            label = "RUSTLING...";
        } else if (sonk_stage == 2) {
            label = "MOVING...";
        } else if (sonk_stage >= 3) {
            label = "GONE";
        }

        neko.sprite.text("SONK COVE", cx - 240, cy - 120, neko.sprite.Options{ .size = 22, .color = neko.Color{ .r = 170, .g = 170, .b = 190 } });
        neko.sprite.text(label, cx - 240, cy - 86, neko.sprite.Options{ .size = 16, .color = neko.Color{ .r = 120, .g = 120, .b = 140 } });

        if (sonk_stage <= 2) {
            const face_w: i32 = 220 + sonk_stage * 30;
            const face_h: i32 = 250 + sonk_stage * 20;
            const fx: i32 = cx + 40 - @divTrunc(face_w, 2);
            const fy: i32 = cy + 10 - @divTrunc(face_h, 2);
            const alpha: i32 = 145 + sonk_stage * 40;
            neko.sprite.face("Sonk", fx, fy, face_w, face_h);
            neko.draw.rect(neko.Rect{ .x = fx, .y = fy, .w = face_w, .h = face_h }, neko.Color{ .r = 0, .g = 0, .b = 0, .a = @intCast(@max(0, 240 - alpha)) }, true);
        }
    }

    fn draw_map(self: *CameraSystem) void {
        if (!neko.screen.supports_offscreen_targets()) {
            self.draw_map_direct(self.map_x, self.map_y);
            return;
        }

        if (self.map_base_dirty) {
            neko.texture.set_target(self.map_base_tex);
            neko.draw.clear(neko.Color{ .r = 10, .g = 20, .b = 10, .a = 180 });
            neko.draw.rect(neko.Rect{ .x = 0, .y = 0, .w = self.map_w, .h = self.map_h }, colors.CAM_OUTLINE, false);
            self.draw_connections(0, 0);
            self.map_base_dirty = false;
        }

        neko.texture.set_target(self.map_tex);
        neko.draw.clear(neko.Color{ .r = 0, .g = 0, .b = 0, .a = 0 });
        neko.texture.draw(self.map_base_tex, neko.Rect{ .x = 0, .y = 0, .w = self.map_w, .h = self.map_h }, null, null);
        self.draw_map_buttons(0, 0);
        self.draw_you(0, 0);
        neko.texture.reset_target();

        // Back to the monitor target and blit the map into it.
        neko.texture.set_target(self.monitor_tex);
        neko.texture.draw(self.map_tex, neko.Rect{ .x = self.map_x, .y = self.map_y, .w = self.map_w, .h = self.map_h }, null, null);

        // The map was drawn at local (0,0) inside `map_tex`; record the buttons
        // in *screen* coordinates so clicks line up with what is shown.
        self.record_buttons(self.map_x, self.map_y);
    }

    fn draw_map_direct(self: *CameraSystem, ox: i32, oy: i32) void {
        neko.draw.rect(neko.Rect{ .x = ox, .y = oy, .w = self.map_w, .h = self.map_h }, neko.Color{ .r = 10, .g = 20, .b = 10, .a = 180 }, true);
        neko.draw.rect(neko.Rect{ .x = ox, .y = oy, .w = self.map_w, .h = self.map_h }, colors.CAM_OUTLINE, false);
        self.draw_connections(ox, oy);
        self.draw_map_buttons(ox, oy);
        self.draw_you(ox, oy);
    }

    fn draw_connections(self: *CameraSystem, ox: i32, oy: i32) void {
        _ = self;
        for (connections) |c| {
            const p1 = map_pos(c[0]);
            const p2 = map_pos(c[1]);
            neko.draw.line(ox + p1.x, oy + p1.y, ox + p2.x, oy + p2.y, neko.Color{ .r = 0, .g = 255, .b = 0 });
        }
    }

    fn draw_map_buttons(self: *CameraSystem, ox: i32, oy: i32) void {
        self.record_buttons(ox, oy);
        for (map_buttons) |mp| {
            const btn_w: i32 = 36;
            const btn_h: i32 = 22;
            const px: i32 = mp.x - @divTrunc(btn_w, 2);
            const py: i32 = mp.y - @divTrunc(btn_h, 2);

            const is_active = mp.id == self.current_cam;
            const bg = if (is_active) neko.Color{ .r = 20, .g = 80, .b = 20 } else neko.Color{ .r = 5, .g = 20, .b = 5 };
            neko.draw.rect(neko.Rect{ .x = ox + px, .y = oy + py, .w = btn_w, .h = btn_h }, bg, true);
            neko.draw.rect(neko.Rect{ .x = ox + px, .y = oy + py, .w = btn_w, .h = btn_h }, neko.Color{ .r = 0, .g = 255, .b = 0 }, false);
            neko.sprite.text(mp.id.code(), ox + mp.x, oy + mp.y, neko.sprite.Options{ .size = 11, .center = true, .color = neko.Color{ .r = 0, .g = 255, .b = 0 } });
        }
    }

    /// Records each map button's clickable rect at `(ox, oy)`.
    fn record_buttons(self: *CameraSystem, ox: i32, oy: i32) void {
        self.cam_button_count = 0;
        for (map_buttons) |mp| {
            const btn_w: i32 = 36;
            const btn_h: i32 = 22;
            const px: i32 = mp.x - @divTrunc(btn_w, 2);
            const py: i32 = mp.y - @divTrunc(btn_h, 2);
            if (self.cam_button_count < self.cam_buttons.len) {
                self.cam_buttons[self.cam_button_count] = CamButton{
                    .id = mp.id,
                    .rect = neko.Rect{ .x = ox + px, .y = oy + py, .w = btn_w, .h = btn_h },
                };
                self.cam_button_count += 1;
            }
        }
    }

    fn draw_you(self: *CameraSystem, ox: i32, oy: i32) void {
        const cx = ox + @divTrunc(self.map_w, 2);
        const cyf = oy + self.map_h - 30;
        neko.sprite.text("YOU", cx, cyf, neko.sprite.Options{ .size = 12, .center = true, .color = neko.Color{ .r = 0, .g = 255, .b = 0 } });
        neko.draw.line(cx, oy + self.map_h - 45, cx, oy + self.map_h - 55, neko.Color{ .r = 0, .g = 255, .b = 0 });
    }
};

fn in_rect(r: neko.Rect, mx: i32, my: i32) bool {
    return mx >= r.x and mx <= r.x + r.w and my >= r.y and my <= r.y + r.h;
}

fn map_pos(id: CameraId) neko.Point {
    for (map_buttons) |mp| {
        if (mp.id == id) return neko.Point{ .x = mp.x, .y = mp.y };
    }
    return neko.Point{ .x = 0, .y = 0 };
}

fn ease_out_cubic(v_in: f32) f32 {
    const v = @max(0.0, @min(1.0, v_in));
    return 1.0 - std.math.pow(f32, 1.0 - v, 3.0);
}
