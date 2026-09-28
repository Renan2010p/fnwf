//! The camera monitor: toggle animation, mask overlay and per-camera views.

#[allow(unused_imports)]
use fnwf_core::prelude::*;

use fnwf_engine::{Engine, TextureHandle};

use fnwf_core::audio;
use fnwf_core::config;
use fnwf_core::draw;

use crate::colors;

/// Anim positions as produced by [`crate::systems::animatronics::AnimatronicManager`].
pub type Positions = [(&'static str, String)];

fn pos_of<'a>(positions: &'a Positions, name: &str) -> Option<&'a str> {
    positions
        .iter()
        .find(|(n, _)| *n == name)
        .map(|(_, p)| p.as_str())
}

/// Camera / monitor / mask controller.
pub struct CameraSystem {
    /// Whether the monitor is logically open (the animation may still be running).
    pub is_open: bool,
    /// Camera id currently selected for the monitor view, e.g. `"1A"`.
    pub current_cam: String,
    /// Whether the protective mask overlay is logically open.
    pub is_mask_open: bool,
    /// Whether the mask slide animation is still playing.
    pub is_mask_animating: bool,
    /// Whether the monitor slide animation is still playing.
    pub is_animating: bool,

    static_timer: f32,
    static_duration: f32,
    anim_progress: f32,
    anim_speed: f32,
    mask_anim_progress: f32,
    mask_anim_speed: f32,
    mouse_trigger_zone: f32,
    mouse_in_cam_zone: bool,
    mouse_in_mask_zone: bool,

    map_w: i32,
    map_h: i32,
    map_x: i32,
    map_y: i32,

    monitor_tex: Option<TextureHandle>,
    map_tex: Option<TextureHandle>,
    map_base_tex: Option<TextureHandle>,
    map_base_dirty: bool,

    cam_buttons: Vec<(String, [i32; 4])>,
}

impl CameraSystem {
    /// Creates the camera system and, when the engine supports offscreen
    /// targets, allocates the monitor and minimap render textures.
    pub fn new(eng: &mut dyn Engine) -> Self {
        let map_w = 260;
        let map_h = 300;
        let map_x = config::SCREEN_WIDTH - map_w - 20;
        let map_y = config::SCREEN_HEIGHT - map_h - 60;

        let mut system = Self {
            is_open: false,
            current_cam: "1A".to_string(),
            is_mask_open: false,
            is_mask_animating: false,
            is_animating: false,
            static_timer: 0.0,
            static_duration: 0.4,
            anim_progress: 0.0,
            anim_speed: 5.0,
            mask_anim_progress: 0.0,
            mask_anim_speed: 4.0,
            mouse_trigger_zone: 60.0,
            mouse_in_cam_zone: false,
            mouse_in_mask_zone: false,
            map_w,
            map_h,
            map_x,
            map_y,
            monitor_tex: None,
            map_tex: None,
            map_base_tex: None,
            map_base_dirty: true,
            cam_buttons: Vec::new(),
        };

        if !eng.supports_offscreen_targets() {
            return system;
        }

        system.monitor_tex = eng.create_target(config::SCREEN_WIDTH, config::SCREEN_HEIGHT);
        system.map_tex = eng.create_target(map_w, map_h);
        system.map_base_tex = eng.create_target(map_w, map_h);
        if system.monitor_tex.is_none() || system.map_tex.is_none() || system.map_base_tex.is_none()
        {
            #[cfg(feature = "std")]
            eprintln!("fnwf: failed to create camera render targets");
        }
        system
    }

    fn ease_out_cubic(v: f32) -> f32 {
        let v = v.clamp(0.0, 1.0);
        1.0 - (1.0 - v).powi(3)
    }

    /// `(mask_rect, monitor_rect)`.
    fn bottom_toggle_rects(&self) -> ([i32; 4], [i32; 4]) {
        let btn_w = 300;
        let btn_h = 28;
        let gap = 16;
        let total_w = btn_w * 2 + gap;
        let start_x = config::SCREEN_WIDTH / 2 - total_w / 2;
        let btn_y = config::SCREEN_HEIGHT - btn_h - 4;
        let mask = [start_x, btn_y, btn_w, btn_h];
        let monitor = [start_x + btn_w + gap, btn_y, btn_w, btn_h];
        (mask, monitor)
    }

    /// Toggles the monitor open/closed and starts its slide animation.
    /// Ignored while the mask is open or animating.
    pub fn toggle(&mut self) {
        if self.is_mask_open || self.is_mask_animating {
            return;
        }
        self.is_open = !self.is_open;
        self.is_animating = true;
        if self.is_open {
            self.static_timer = self.static_duration;
        }
    }

    /// Toggles the mask overlay and starts its slide animation, playing the
    /// mask on/off sounds and breathing ambience. Ignored while the monitor is
    /// open or either animation is running.
    pub fn toggle_mask(&mut self, eng: &mut dyn Engine) {
        if self.is_open || self.is_animating || self.is_mask_animating {
            return;
        }
        self.is_mask_open = !self.is_mask_open;
        self.is_mask_animating = true;
        if self.is_mask_open {
            audio::play(eng, "mask_on", 0, -1);
            audio::play_mask_breathing(eng);
        } else {
            audio::play(eng, "mask_off", 0, -1);
            audio::stop_mask_breathing(eng);
        }
    }

    /// Immediately starts retracting the mask, e.g. when oxygen runs out.
    pub fn force_remove_mask(&mut self) {
        if !self.is_mask_open && self.mask_anim_progress <= 0.0 {
            return;
        }
        if self.is_mask_animating && !self.is_mask_open {
            return;
        }
        self.is_mask_open = false;
        self.is_mask_animating = true;
    }

    /// Switches the monitor to `cam_id` when it names a real camera, restarting
    /// the static burst on the new feed.
    pub fn switch_camera(&mut self, cam_id: &str) {
        if cam_id != self.current_cam && crate::data::camera_name(cam_id).is_some() {
            self.current_cam = cam_id.to_string();
            self.static_timer = self.static_duration;
        }
    }

    /// Returns whether the monitor is open and its slide animation has finished.
    pub fn is_fully_open(&self) -> bool {
        self.is_open && self.anim_progress >= 0.99
    }

    /// Returns whether the monitor is at least partially on screen.
    pub fn is_visible(&self) -> bool {
        self.anim_progress > 0.01
    }

    /// Handles a click on the bottom MONITOR button. Returns whether the click
    /// landed on that button and toggled the monitor.
    pub fn check_toggle_click(&mut self, mx: i32, my: i32) -> bool {
        let (_, monitor) = self.bottom_toggle_rects();
        let [rx, ry, rw, rh] = monitor;
        if mx >= rx && mx <= rx + rw && my >= ry && my <= ry + rh {
            if !self.is_animating && !self.is_mask_open && !self.is_mask_animating {
                self.toggle();
            }
            return true;
        }
        false
    }

    /// Handles a click on the bottom MASK button. Returns whether the click
    /// landed on that button and toggled the mask.
    pub fn check_mask_toggle_click(&mut self, eng: &mut dyn Engine, mx: i32, my: i32) -> bool {
        let (mask, _) = self.bottom_toggle_rects();
        let [rx, ry, rw, rh] = mask;
        if mx >= rx && mx <= rx + rw && my >= ry && my <= ry + rh {
            if !self.is_mask_animating && !self.is_open && !self.is_animating {
                self.toggle_mask(eng);
            }
            return true;
        }
        false
    }

    /// Toggles the monitor or mask when the mouse enters the edge trigger zone
    /// above their buttons. Returns whether a toggle fired this call.
    pub fn check_mouse_trigger(
        &mut self,
        eng: &mut dyn Engine,
        mouse_x: i32,
        mouse_y: i32,
    ) -> bool {
        let (mask_rect, monitor_rect) = self.bottom_toggle_rects();
        let [mx_m, my_m, mw_m, mh_m] = mask_rect;
        let [mx_c, my_c, mw_c, _] = monitor_rect;

        let gesture_h = ((mh_m + 18) as f32).max(self.mouse_trigger_zone);
        let in_mask = mouse_x >= mx_m
            && mouse_x <= mx_m + mw_m
            && (mouse_y as f32) >= (my_m - 14) as f32
            && (mouse_y as f32) <= (my_m - 14) as f32 + gesture_h;
        let in_cam = mouse_x >= mx_c
            && mouse_x <= mx_c + mw_c
            && (mouse_y as f32) >= (my_c - 14) as f32
            && (mouse_y as f32) <= (my_c - 14) as f32 + gesture_h;

        if in_cam && !self.mouse_in_cam_zone {
            if !self.is_animating && !self.is_mask_open && !self.is_mask_animating {
                self.toggle();
                self.mouse_in_cam_zone = true;
                return true;
            }
        } else if !in_cam {
            self.mouse_in_cam_zone = false;
        }

        if in_mask && !self.mouse_in_mask_zone {
            if !self.is_mask_animating && !self.is_open && !self.is_animating {
                self.toggle_mask(eng);
                self.mouse_in_mask_zone = true;
                return true;
            }
        } else if !in_mask {
            self.mouse_in_mask_zone = false;
        }

        false
    }

    /// Handles clicks on the open monitor: camera buttons on the minimap and the
    /// CLOSE button. Returns whether the click was consumed.
    pub fn handle_click(&mut self, mx: i32, my: i32) -> bool {
        if !self.is_fully_open() {
            return false;
        }
        let hit = self
            .cam_buttons
            .iter()
            .find(|(_, rect)| {
                let [x, y, w, h] = *rect;
                mx >= x && mx <= x + w && my >= y && my <= y + h
            })
            .map(|(id, _)| id.clone());
        if let Some(id) = hit {
            self.switch_camera(&id);
            return true;
        }
        let (_, monitor) = self.bottom_toggle_rects();
        let [tx, ty, tw, th] = monitor;
        if mx >= tx && mx <= tx + tw && my >= ty && my <= ty + th {
            if !self.is_animating && !self.is_mask_open && !self.is_mask_animating {
                self.toggle();
            }
            return true;
        }
        false
    }

    /// Advances the monitor and mask slide animations and the static timer.
    pub fn update(&mut self, dt: f32) {
        if self.static_timer > 0.0 {
            self.static_timer -= dt;
        }

        let target = if self.is_open { 1.0 } else { 0.0 };
        if self.anim_progress != target {
            self.is_animating = true;
            if self.anim_progress < target {
                self.anim_progress = target.min(self.anim_progress + self.anim_speed * dt);
            } else {
                self.anim_progress = target.max(self.anim_progress - self.anim_speed * dt);
            }
        } else {
            self.is_animating = false;
        }

        let mask_target = if self.is_mask_open { 1.0 } else { 0.0 };
        if self.mask_anim_progress != mask_target {
            self.is_mask_animating = true;
            if self.mask_anim_progress < mask_target {
                self.mask_anim_progress =
                    mask_target.min(self.mask_anim_progress + self.mask_anim_speed * dt);
            } else {
                self.mask_anim_progress =
                    mask_target.max(self.mask_anim_progress - self.mask_anim_speed * dt);
            }
        } else {
            self.is_mask_animating = false;
        }
    }

    /// Draws the mask overlay, the monitor animation or the full camera feed,
    /// using the animatronic `positions` and Sonk's `foxy_stage`.
    pub fn draw(&mut self, eng: &mut dyn Engine, positions: &Positions, foxy_stage: i32) {
        let (mask_rect, monitor_rect) = self.bottom_toggle_rects();

        if !self.is_mask_open && !self.is_visible() {
            let pulse = 0.5 + 0.5 * (eng.ticks() / 1000.0 * 5.0).sin();
            let glow = (80.0 + 70.0 * pulse) as u8;
            eng.draw_rect(
                mask_rect[0],
                mask_rect[1],
                mask_rect[2],
                mask_rect[3],
                28,
                22,
                18,
                230,
                true,
            );
            eng.draw_rect(
                mask_rect[0],
                mask_rect[1],
                mask_rect[2],
                mask_rect[3],
                220,
                glow,
                60,
                255,
                false,
            );
            draw::text(
                eng,
                "MASK",
                mask_rect[0] + mask_rect[2] / 2,
                mask_rect[1] + mask_rect[3] / 2,
                12,
                230,
                160,
                80,
                255,
                true,
            );
        }

        if !self.is_visible() && !self.is_mask_open {
            let pulse = 0.5 + 0.5 * (eng.ticks() / 1000.0 * 4.0).sin();
            let edge_g = (160.0 + 60.0 * pulse) as u8;
            eng.draw_rect(
                monitor_rect[0],
                monitor_rect[1],
                monitor_rect[2],
                monitor_rect[3],
                12,
                18,
                12,
                220,
                true,
            );
            eng.draw_rect(
                monitor_rect[0],
                monitor_rect[1],
                monitor_rect[2],
                monitor_rect[3],
                40,
                edge_g,
                90,
                255,
                false,
            );
            draw::text(
                eng,
                "MONITOR",
                monitor_rect[0] + monitor_rect[2] / 2,
                monitor_rect[1] + monitor_rect[3] / 2,
                12,
                120,
                edge_g,
                160,
                255,
                true,
            );
        }

        if self.mask_anim_progress > 0.01 {
            self.draw_mask_overlay(eng);
        }
        if self.is_visible() {
            if self.is_fully_open() {
                self.draw_monitor(eng, positions, foxy_stage);
            } else {
                self.draw_monitor_animation(eng);
            }
        }
    }

    fn draw_mask_overlay(&self, eng: &mut dyn Engine) {
        let eased = Self::ease_out_cubic(self.mask_anim_progress);
        let slide_offset = ((1.0 - eased) * -(config::SCREEN_HEIGHT as f32)) as i32;

        let (mask_r, mask_g, mask_b, mask_a) = (44, 33, 22, 185);
        let y_top = slide_offset;
        let y_bottom = slide_offset + config::SCREEN_HEIGHT;
        let (eye_w, eye_h, eye_gap) = (210, 170, 90);
        let eye_y = slide_offset + config::SCREEN_HEIGHT / 2 - 88;
        let left_eye_x = config::SCREEN_WIDTH / 2 - eye_gap / 2 - eye_w;
        let right_eye_x = config::SCREEN_WIDTH / 2 + eye_gap / 2;

        eng.draw_rect(
            0,
            y_top,
            config::SCREEN_WIDTH,
            (eye_y - y_top).max(0),
            mask_r,
            mask_g,
            mask_b,
            mask_a,
            true,
        );
        eng.draw_rect(
            0,
            eye_y + eye_h,
            config::SCREEN_WIDTH,
            (y_bottom - (eye_y + eye_h)).max(0),
            mask_r,
            mask_g,
            mask_b,
            mask_a,
            true,
        );
        eng.draw_rect(
            0,
            eye_y,
            left_eye_x.max(0),
            eye_h,
            mask_r,
            mask_g,
            mask_b,
            mask_a,
            true,
        );
        let middle_x = left_eye_x + eye_w;
        let middle_w = right_eye_x - middle_x;
        eng.draw_rect(
            middle_x,
            eye_y,
            middle_w.max(0),
            eye_h,
            mask_r,
            mask_g,
            mask_b,
            mask_a,
            true,
        );
        eng.draw_rect(
            right_eye_x + eye_w,
            eye_y,
            (config::SCREEN_WIDTH - (right_eye_x + eye_w)).max(0),
            eye_h,
            mask_r,
            mask_g,
            mask_b,
            mask_a,
            true,
        );

        let nose_x = config::SCREEN_WIDTH / 2 - 34;
        let nose_y = eye_y + eye_h - 10;
        eng.draw_rect(nose_x, nose_y, 68, 120, 48, 36, 24, 210, true);

        eng.draw_rect(left_eye_x, eye_y, eye_w, eye_h, 100, 78, 50, 255, false);
        eng.draw_rect(right_eye_x, eye_y, eye_w, eye_h, 100, 78, 50, 255, false);
    }

    fn draw_monitor(&mut self, eng: &mut dyn Engine, positions: &Positions, foxy_stage: i32) {
        let eased = Self::ease_out_cubic(self.anim_progress);
        let slide_offset = ((1.0 - eased) * (config::SCREEN_HEIGHT - 40) as f32) as i32;
        let direct = !eng.supports_offscreen_targets();

        if direct {
            eng.set_draw_offset(0, slide_offset);
        } else {
            eng.set_render_target(self.monitor_tex);
        }
        eng.clear(5, 10, 5, 230);

        if self.static_timer > 0.0 {
            draw::static_noise(eng, 0, 0, config::SCREEN_WIDTH, config::SCREEN_HEIGHT, 0.5);
        } else {
            self.draw_camera_view(eng, positions, foxy_stage);
            self.draw_map(eng);
            draw::text(
                eng,
                &format!("CAM {}", self.current_cam),
                30,
                30,
                20,
                colors::CAM_OUTLINE.r,
                colors::CAM_OUTLINE.g,
                colors::CAM_OUTLINE.b,
                255,
                false,
            );
            draw::scanlines(eng, 0, 0, config::SCREEN_WIDTH, config::SCREEN_HEIGHT, 20);
            draw::static_noise(eng, 0, 0, config::SCREEN_WIDTH, config::SCREEN_HEIGHT, 0.02);
            if (eng.ticks() / 1000.0) as i32 % 2 == 0 {
                eng.draw_rect(
                    config::SCREEN_WIDTH - 50,
                    35,
                    12,
                    12,
                    200,
                    30,
                    30,
                    255,
                    true,
                );
                draw::text(
                    eng,
                    "REC",
                    config::SCREEN_WIDTH - 35,
                    28,
                    14,
                    200,
                    30,
                    30,
                    255,
                    false,
                );
            }
        }

        if direct {
            eng.set_draw_offset(0, 0);
        } else {
            eng.reset_render_target();
            if let Some(tex) = self.monitor_tex {
                eng.draw_texture(
                    &tex,
                    0,
                    slide_offset,
                    config::SCREEN_WIDTH,
                    config::SCREEN_HEIGHT,
                    None,
                );
            }
        }

        let btn_w = 400;
        let btn_x = config::SCREEN_WIDTH / 2 - btn_w / 2;
        let close_btn_y = slide_offset + config::SCREEN_HEIGHT - 30;
        eng.draw_rect(btn_x, close_btn_y, btn_w, 30, 20, 25, 20, 255, true);
        eng.draw_rect(btn_x, close_btn_y, btn_w, 30, 200, 60, 60, 255, false);
        draw::text(
            eng,
            "CLOSE",
            btn_x + btn_w / 2,
            close_btn_y + 15,
            12,
            200,
            60,
            60,
            255,
            true,
        );
    }

    fn draw_monitor_animation(&self, eng: &mut dyn Engine) {
        let progress = Self::ease_out_cubic(self.anim_progress);
        let slide_offset = ((1.0 - progress) * (config::SCREEN_HEIGHT - 40) as f32) as i32;

        eng.draw_rect(
            16,
            slide_offset,
            config::SCREEN_WIDTH - 32,
            config::SCREEN_HEIGHT,
            42,
            42,
            48,
            245,
            true,
        );
        eng.draw_rect(
            16,
            slide_offset,
            config::SCREEN_WIDTH - 32,
            config::SCREEN_HEIGHT,
            180,
            180,
            180,
            255,
            false,
        );

        let bar_alpha = (120.0 + 100.0 * (1.0 - progress)) as u8;
        for i in 0..=5 {
            let y = slide_offset + 40 + i * 90 + ((1.0 - progress) * 24.0) as i32;
            eng.draw_rect(
                28,
                y,
                config::SCREEN_WIDTH - 56,
                18,
                20,
                30,
                20,
                bar_alpha,
                true,
            );
        }
    }

    fn draw_camera_view(&self, eng: &mut dyn Engine, positions: &Positions, foxy_stage: i32) {
        let cx = config::SCREEN_WIDTH / 2;
        let cy = config::SCREEN_HEIGHT / 2 - 30;
        match self.current_cam.as_str() {
            "1A" => self.draw_show_stage(eng, cx, cy, positions),
            "1B" => self.draw_dining_area(eng, cx, cy, positions),
            "1C" => self.draw_backstage(eng, cx, cy, positions),
            "5" => self.draw_sonk_cove(eng, cx, cy, foxy_stage),
            "2A" | "4A" => self.draw_hallway(eng, cx, cy, positions, &self.current_cam),
            "2B" | "4B" => self.draw_hall_corner(eng, cx, cy, positions, &self.current_cam),
            "3" => self.draw_supply_closet(eng, cx, cy, positions),
            _ => {},
        }
    }

    fn draw_show_stage(&self, eng: &mut dyn Engine, cx: i32, cy: i32, ap: &Positions) {
        eng.draw_rect(cx - 300, cy - 150, 600, 350, 40, 30, 35, 255, true);
        if pos_of(ap, "cedro") == Some("1A") {
            draw::animatronic_face(eng, "cedro", cx - 130, cy - 40, 100, 120);
        }
        if pos_of(ap, "eser") == Some("1A") {
            draw::animatronic_face(eng, "eser", cx + 30, cy - 40, 100, 120);
        }
    }

    fn draw_dining_area(&self, eng: &mut dyn Engine, cx: i32, cy: i32, ap: &Positions) {
        eng.draw_rect(cx - 300, cy - 150, 600, 350, 30, 28, 32, 255, true);
        for name in ["cedro", "eser"] {
            if pos_of(ap, name) == Some("1B") {
                draw::animatronic_face(eng, name, cx - 50, cy - 60, 100, 120);
                break;
            }
        }
    }

    fn draw_backstage(&self, eng: &mut dyn Engine, cx: i32, cy: i32, ap: &Positions) {
        eng.draw_rect(cx - 300, cy - 150, 600, 350, 25, 20, 28, 255, true);
        if pos_of(ap, "cedro") == Some("1C") {
            draw::animatronic_face(eng, "cedro", cx - 60, cy - 40, 120, 150);
        }
    }

    fn draw_hallway(&self, eng: &mut dyn Engine, cx: i32, cy: i32, ap: &Positions, cam_id: &str) {
        eng.draw_rect(cx - 300, cy - 150, 600, 350, 35, 32, 38, 255, true);
        for name in ["cedro", "eser"] {
            if pos_of(ap, name) == Some(cam_id) {
                draw::animatronic_face(eng, name, cx - 50, cy - 50, 100, 130);
                break;
            }
        }
    }

    fn draw_hall_corner(
        &self,
        eng: &mut dyn Engine,
        cx: i32,
        cy: i32,
        ap: &Positions,
        cam_id: &str,
    ) {
        eng.draw_rect(cx - 300, cy - 150, 600, 350, 20, 18, 22, 255, true);
        for name in ["cedro", "eser"] {
            if pos_of(ap, name) == Some(cam_id) {
                draw::animatronic_face(eng, name, cx - 80, cy - 100, 160, 200);
                break;
            }
        }
    }

    fn draw_supply_closet(&self, eng: &mut dyn Engine, cx: i32, cy: i32, ap: &Positions) {
        eng.draw_rect(cx - 300, cy - 150, 600, 350, 28, 25, 30, 255, true);
        if pos_of(ap, "cedro") == Some("3") {
            draw::animatronic_face(eng, "cedro", cx - 60, cy - 40, 120, 150);
        }
    }

    fn draw_sonk_cove(&self, eng: &mut dyn Engine, cx: i32, cy: i32, foxy_stage: i32) {
        eng.draw_rect(cx - 300, cy - 150, 600, 350, 15, 12, 20, 255, true);
        eng.draw_rect(cx - 280, cy - 130, 560, 310, 35, 30, 45, 120, true);

        let label = match foxy_stage {
            0 => "EMPTY",
            1 => "RUSTLING...",
            2 => "MOVING...",
            _ => "GONE",
        };

        draw::text(
            eng,
            "SONK COVE",
            cx - 240,
            cy - 120,
            22,
            170,
            170,
            190,
            255,
            false,
        );
        draw::text(eng, label, cx - 240, cy - 86, 16, 120, 120, 140, 255, false);

        if foxy_stage <= 2 {
            let face_w = 220 + foxy_stage * 30;
            let face_h = 250 + foxy_stage * 20;
            let fx = cx + 40 - face_w / 2;
            let fy = cy + 10 - face_h / 2;
            let alpha = 145 + foxy_stage * 40;
            draw::animatronic_face(eng, "Sonk", fx, fy, face_w, face_h);
            eng.draw_rect(
                fx,
                fy,
                face_w,
                face_h,
                0,
                0,
                0,
                (240 - alpha).max(0) as u8,
                true,
            );
        }
    }

    fn draw_map(&mut self, eng: &mut dyn Engine) {
        let map_w = self.map_w;
        let map_h = self.map_h;
        let cam_positions: [(&str, i32, i32); 9] = [
            ("1A", map_w / 2, 40),
            ("1B", map_w / 2, 80),
            ("1C", 60, 100),
            ("5", 145, 105),
            ("2A", 90, 150),
            ("2B", 90, 210),
            ("3", 50, 160),
            ("4A", map_w - 90, 150),
            ("4B", map_w - 90, 210),
        ];
        let connections: [(&str, &str); 8] = [
            ("1A", "1B"),
            ("1B", "1C"),
            ("1C", "5"),
            ("1B", "2A"),
            ("2A", "2B"),
            ("2A", "3"),
            ("1B", "4A"),
            ("4A", "4B"),
        ];

        let cam_pos = |id: &str| -> (i32, i32) {
            let (_, x, y) = cam_positions.iter().find(|(c, _, _)| *c == id).unwrap();
            (*x, *y)
        };

        if !eng.supports_offscreen_targets() {
            let (map_x, map_y) = (self.map_x, self.map_y);
            eng.draw_rect(map_x, map_y, map_w, map_h, 10, 20, 10, 180, true);
            eng.draw_rect(
                map_x,
                map_y,
                map_w,
                map_h,
                colors::CAM_OUTLINE.r,
                colors::CAM_OUTLINE.g,
                colors::CAM_OUTLINE.b,
                255,
                false,
            );
            for (a, b) in connections {
                let p1 = cam_pos(a);
                let p2 = cam_pos(b);
                eng.line(
                    map_x + p1.0,
                    map_y + p1.1,
                    map_x + p2.0,
                    map_y + p2.1,
                    0,
                    255,
                    0,
                    255,
                );
            }

            self.cam_buttons.clear();
            for (cam_id, px, py) in cam_positions {
                let (btn_w, btn_h) = (36, 22);
                let bx = px - btn_w / 2;
                let by = py - btn_h / 2;
                self.cam_buttons
                    .push((cam_id.to_string(), [map_x + bx, map_y + by, btn_w, btn_h]));
                let is_active = cam_id == self.current_cam;
                let (bg_r, bg_g, bg_b) = if is_active { (20, 80, 20) } else { (5, 20, 5) };
                eng.draw_rect(
                    map_x + bx,
                    map_y + by,
                    btn_w,
                    btn_h,
                    bg_r,
                    bg_g,
                    bg_b,
                    255,
                    true,
                );
                eng.draw_rect(map_x + bx, map_y + by, btn_w, btn_h, 0, 255, 0, 255, false);
                draw::text(
                    eng,
                    cam_id,
                    map_x + px,
                    map_y + py,
                    11,
                    0,
                    255,
                    0,
                    255,
                    true,
                );
            }
            draw::text(
                eng,
                "YOU",
                map_x + map_w / 2,
                map_y + map_h - 30,
                12,
                0,
                255,
                0,
                255,
                true,
            );
            eng.line(
                map_x + map_w / 2,
                map_y + map_h - 45,
                map_x + map_w / 2,
                map_y + map_h - 55,
                0,
                255,
                0,
                255,
            );
            return;
        }

        if self.map_base_dirty {
            eng.set_render_target(self.map_base_tex);
            eng.clear(10, 20, 10, 180);
            eng.draw_rect(
                0,
                0,
                map_w,
                map_h,
                colors::CAM_OUTLINE.r,
                colors::CAM_OUTLINE.g,
                colors::CAM_OUTLINE.b,
                255,
                false,
            );
            for (a, b) in connections {
                let p1 = cam_pos(a);
                let p2 = cam_pos(b);
                eng.line(p1.0, p1.1, p2.0, p2.1, 0, 255, 0, 255);
            }
            self.map_base_dirty = false;
        }

        eng.set_render_target(self.map_tex);
        eng.clear(0, 0, 0, 0);
        if let Some(base) = self.map_base_tex {
            eng.draw_texture(&base, 0, 0, map_w, map_h, None);
        }

        self.cam_buttons.clear();
        for (cam_id, px, py) in cam_positions {
            let (btn_w, btn_h) = (36, 22);
            let (map_x, map_y) = (self.map_x, self.map_y);
            self.cam_buttons.push((
                cam_id.to_string(),
                [map_x + px - btn_w / 2, map_y + py - btn_h / 2, btn_w, btn_h],
            ));
            let is_active = cam_id == self.current_cam;
            let (bg_r, bg_g, bg_b) = if is_active { (20, 80, 20) } else { (5, 20, 5) };
            eng.draw_rect(
                px - btn_w / 2,
                py - btn_h / 2,
                btn_w,
                btn_h,
                bg_r,
                bg_g,
                bg_b,
                255,
                true,
            );
            eng.draw_rect(
                px - btn_w / 2,
                py - btn_h / 2,
                btn_w,
                btn_h,
                0,
                255,
                0,
                255,
                false,
            );
            draw::text(eng, cam_id, px, py, 11, 0, 255, 0, 255, true);
        }

        draw::text(eng, "YOU", map_w / 2, map_h - 30, 12, 0, 255, 0, 255, true);
        eng.line(map_w / 2, map_h - 45, map_w / 2, map_h - 55, 0, 255, 0, 255);

        eng.set_render_target(self.monitor_tex);
        if let Some(map) = self.map_tex {
            eng.draw_texture(&map, self.map_x, self.map_y, map_w, map_h, None);
        }
    }
}
