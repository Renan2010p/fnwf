//! The office room: cylindrical panorama projection, doors, hallways and props.

#[allow(unused_imports)]
use fnwf_core::prelude::*;

use fnwf_engine::{Engine, TextureHandle};

use fnwf_core::{config, draw, time};

use crate::colors;
use crate::types::Color;

const PI: f32 = core::f32::consts::PI;

/// Precomputed panorama column mapping.
#[derive(Debug, Clone, Copy)]
struct ProjectionSlice {
    sx: i32,
    theta: f32,
    target_h: i32,
    src_w: i32,
}

/// The player's office.
pub struct Office {
    /// Whether the vent light is on, revealing anyone at the office vent.
    pub vent_light: bool,
    pan_x: f32,
    target_pan: f32,
    office_tex: Option<TextureHandle>,
    office_static_tex: Option<TextureHandle>,

    vp_x: i32,
    #[allow(dead_code)]
    vp_y: i32,
    bw_left: i32,
    bw_right: i32,
    bw_top: i32,
    bw_bottom: i32,
    hall_w: i32,
    hall_depth: i32,

    projection_data: Vec<ProjectionSlice>,
}

impl Office {
    /// Creates the office, allocating its cylindrical panorama and static layers
    /// when the engine supports them, then precomputing the column projection.
    pub fn new(eng: &mut dyn Engine) -> Self {
        let offscreen = eng.supports_offscreen_targets();

        let mut office_tex = None;
        let mut office_static_tex = None;

        if eng.supports_cylindrical_office() {
            office_tex = eng.create_target(config::OFFICE_WIDTH, config::SCREEN_HEIGHT);
            if office_tex.is_none() {
                #[cfg(feature = "std")]
                eprintln!("fnwf: failed to create office render target");
            }
        }
        if offscreen {
            office_static_tex = eng.create_target(config::OFFICE_WIDTH, config::SCREEN_HEIGHT);
            if office_static_tex.is_none() {
                #[cfg(feature = "std")]
                eprintln!("fnwf: failed to create office static render target");
            }
        }

        let vp_x = config::OFFICE_WIDTH / 2;
        let vp_y = config::SCREEN_HEIGHT / 2 - 30;
        let bw_left = vp_x - 240;
        let bw_right = vp_x + 240;
        let bw_top = 80;
        let bw_bottom = config::SCREEN_HEIGHT - 120;

        let mut office = Self {
            vent_light: false,
            pan_x: 0.0,
            target_pan: 0.0,
            office_tex,
            office_static_tex,
            vp_x,
            vp_y,
            bw_left,
            bw_right,
            bw_top,
            bw_bottom,
            hall_w: 100,
            hall_depth: 250,
            projection_data: Vec::new(),
        };
        office.precalculate_projection();
        if offscreen {
            office.build_static_layer(eng);
        }
        office
    }

    fn shade(c: Color, factor: f32) -> Color {
        c.shade(factor)
    }

    /// Projects a point with normalized x `nx` (from -1 to 1), depth `z`
    /// (0 near, 1 far) and world `height` into `(screen_x, screen_y, scale)`.
    ///
    /// Depth increases both the horizontal spread and the vertical floor
    /// position, which is what gives the office its one-point perspective.
    fn project_depth(&self, nx: f32, z: f32, height: f32) -> (i32, i32, f32) {
        let zc = z.clamp(0.0, 1.0);
        let scale = 0.40 + zc * 1.45;
        let world_half = 320.0;
        let sx = (self.vp_x as f32 + nx * world_half * scale) as i32;
        let floor_y = self.bw_bottom
            + ((config::SCREEN_HEIGHT - self.bw_bottom) as f32 * zc.powf(1.2)) as i32;
        let sy = (floor_y as f32 - height * scale) as i32;
        (sx, sy, scale)
    }

    /// Precomputes the mapping from screen columns to the cylindrical office
    /// panorama texture.
    ///
    /// For each 16-pixel column it derives the view angle `theta` from the
    /// focal length, the vertical stretch `1 / cos(theta)` and the source
    /// column width needed to counteract the cylinder's foreshortening. The
    /// resulting [`ProjectionSlice`] list lets [`Office::draw`] wrap the flat
    /// panorama around the player by sampling texture regions each frame.
    fn precalculate_projection(&mut self) {
        let screen_w = config::SCREEN_WIDTH;
        let screen_h = config::SCREEN_HEIGHT;
        let fov = PI * 100.0 / 180.0;
        let focal_length = (screen_w as f32 / 2.0) / (fov / 2.0).tan();
        let slice_w = 16;
        let pixels_per_radian = config::OFFICE_WIDTH as f32 / PI;

        let mut sx = 0;
        while sx < screen_w {
            let theta =
                ((sx as f32 + slice_w as f32 / 2.0 - screen_w as f32 / 2.0) / focal_length).atan();
            let scale_y = 1.0 / theta.cos();
            let src_w_d = slice_w as f32 * (pixels_per_radian * theta.cos().powi(2) / focal_length);
            self.projection_data.push(ProjectionSlice {
                sx,
                theta,
                target_h: (screen_h as f32 * scale_y) as i32,
                src_w: (src_d(src_w_d)).max(1),
            });
            sx += slice_w;
        }
    }

    fn build_static_layer(&mut self, eng: &mut dyn Engine) {
        eng.set_render_target(self.office_static_tex);
        eng.clear(5, 5, 8, 255);
        self.draw_ceiling(eng);
        self.draw_floor(eng);
        self.draw_back_wall_base(eng);
        self.draw_depth_structure(eng);
        self.draw_hallways_base(eng);
        self.draw_vent_base(eng);
        self.draw_side_walls(eng);
        self.draw_wall_dressing(eng);
        self.draw_office_elements(eng);
        self.draw_ambient(eng);
        eng.reset_render_target();
    }

    /// Turns the office toward the mouse, easing `pan_x` toward the target
    /// based on the mouse's horizontal position on screen.
    pub fn update(&mut self, mouse_x: i32, dt: f32) {
        let norm = mouse_x as f32 / config::SCREEN_WIDTH as f32;
        self.target_pan = (norm - 0.5) * 2.0;
        self.pan_x += (self.target_pan - self.pan_x) * 4.0 * dt;
    }

    /// Renders the office with its doors, lights, hallways, vent and any
    /// animatronic pressure.
    ///
    /// Engines that support cylindrical compositing render the panorama and
    /// slice it through the precomputed `ProjectionSlice` columns; other
    /// platforms fall back to the flat, non-cylindrical `draw_flat` path.
    /// `left_door_anim`/`right_door_anim` are 0..1 door progress values,
    /// `left_light`/`right_light` toggle hallway illumination, and the
    /// `anim_*` arguments name any animatronic at each location.
    #[allow(clippy::too_many_arguments)]
    pub fn draw(
        &mut self,
        eng: &mut dyn Engine,
        left_door_anim: f32,
        right_door_anim: f32,
        left_light: bool,
        right_light: bool,
        anim_at_left: Option<&str>,
        anim_at_right: Option<&str>,
        anim_at_vent: Option<&str>,
        anim_in_office: Option<&str>,
    ) {
        if !eng.supports_cylindrical_office() {
            self.draw_flat(
                eng,
                left_door_anim,
                right_door_anim,
                left_light,
                right_light,
                anim_at_left,
                anim_at_right,
                anim_at_vent,
                anim_in_office,
            );
            return;
        }

        let t = time::now();
        eng.set_render_target(self.office_tex);
        if let Some(tex) = self.office_static_tex {
            eng.draw_texture(
                &tex,
                0,
                0,
                config::OFFICE_WIDTH,
                config::SCREEN_HEIGHT,
                None,
            );
        }

        self.draw_back_wall_dynamic(eng, t);
        self.draw_hallways_dynamic(eng, left_light, right_light, anim_at_left, anim_at_right);
        self.draw_vent_dynamic(eng, anim_at_vent);
        self.draw_doors(eng, left_door_anim, right_door_anim);
        self.draw_fan(eng, t);
        self.draw_in_office(eng, anim_in_office);

        eng.reset_render_target();

        let screen_h = config::SCREEN_HEIGHT;
        let office_w = config::OFFICE_WIDTH;
        let pixels_per_radian = office_w as f32 / PI;
        let max_pan_angle = PI / 4.0;
        let center_angle = PI / 2.0 + self.pan_x * max_pan_angle;

        for data in &self.projection_data {
            let target_angle = center_angle + data.theta;
            let source_x = target_angle * pixels_per_radian;
            let src_w = data.src_w;
            let target_h = data.target_h;
            let src_x = (source_x - src_w as f32 / 2.0).floor() as i32;

            if src_x + src_w > 0 && src_x < office_w {
                let final_src_x = src_x.max(0);
                let final_src_w = (office_w - final_src_x).min(src_w - (final_src_x - src_x));
                if final_src_w > 0 {
                    if let Some(tex) = self.office_tex {
                        eng.draw_texture_region(
                            &tex,
                            data.sx,
                            (screen_h - target_h) / 2,
                            17,
                            target_h,
                            final_src_x,
                            0,
                            final_src_w,
                            screen_h,
                        );
                    }
                }
            }
        }
    }

    #[allow(clippy::too_many_arguments)]
    fn draw_flat(
        &mut self,
        eng: &mut dyn Engine,
        left_door_anim: f32,
        right_door_anim: f32,
        left_light: bool,
        right_light: bool,
        anim_at_left: Option<&str>,
        anim_at_right: Option<&str>,
        anim_at_vent: Option<&str>,
        anim_in_office: Option<&str>,
    ) {
        let t = time::now();

        if eng.supports_offscreen_targets() {
            if let Some(tex) = self.office_static_tex {
                eng.draw_texture(
                    &tex,
                    0,
                    0,
                    config::OFFICE_WIDTH,
                    config::SCREEN_HEIGHT,
                    None,
                );
            }
        } else {
            eng.clear(5, 5, 8, 255);
            self.draw_ceiling(eng);
            self.draw_floor(eng);
            self.draw_back_wall_base(eng);
            self.draw_depth_structure(eng);
            self.draw_hallways_base(eng);
            self.draw_vent_base(eng);
            self.draw_side_walls(eng);
            self.draw_wall_dressing(eng);
            self.draw_office_elements(eng);
            self.draw_ambient(eng);
        }

        self.draw_back_wall_dynamic(eng, t);
        self.draw_hallways_dynamic(eng, left_light, right_light, anim_at_left, anim_at_right);
        self.draw_vent_dynamic(eng, anim_at_vent);
        self.draw_doors(eng, left_door_anim, right_door_anim);
        self.draw_fan(eng, t);
        self.draw_in_office(eng, anim_in_office);
    }

    fn draw_ceiling(&self, eng: &mut dyn Engine) {
        draw::trapezoid(
            eng,
            22,
            20,
            25,
            (0, 0),
            (config::OFFICE_WIDTH, 0),
            (self.bw_right + self.hall_depth, self.bw_top),
            (self.bw_left - self.hall_depth, self.bw_top),
        );
        for i in 1..10 {
            let prog = i as f32 / 10.0;
            let y = (prog * self.bw_top as f32) as i32;
            let lx = ((self.bw_left - self.hall_depth) as f32 * prog) as i32;
            let rx = (config::OFFICE_WIDTH as f32
                - (config::OFFICE_WIDTH - self.bw_right - self.hall_depth) as f32 * prog)
                as i32;
            let shade = (30.0 - prog * 20.0).max(0.0) as u8;
            eng.line(lx, y, rx, y, shade, shade, shade + 3, 255);
        }
        for i in 0..=5 {
            let frac = (i + 1) as f32 / 7.0;
            let top_x = (config::OFFICE_WIDTH as f32 * frac) as i32;
            let bot_x = ((self.bw_left - self.hall_depth) as f32
                + frac * (self.bw_right + self.hall_depth - self.bw_left + self.hall_depth) as f32)
                as i32;
            eng.line(top_x, 0, bot_x, self.bw_top, 18, 18, 22, 255);
        }
    }

    fn draw_floor(&self, eng: &mut dyn Engine) {
        let floor_left_far = self.bw_left - self.hall_depth;
        let floor_right_far = self.bw_right + self.hall_depth;
        draw::trapezoid(
            eng,
            colors::FLOOR_COLOR.r,
            colors::FLOOR_COLOR.g,
            colors::FLOOR_COLOR.b,
            (floor_left_far, self.bw_bottom),
            (floor_right_far, self.bw_bottom),
            (config::OFFICE_WIDTH + 100, config::SCREEN_HEIGHT),
            (-100, config::SCREEN_HEIGHT),
        );

        let rows = 4;
        let cols = 8;
        for r in 0..rows {
            let py0 = r as f32 / rows as f32;
            let py1 = (r + 1) as f32 / rows as f32;
            let y0 = (self.bw_bottom as f32 + py0 * (config::SCREEN_HEIGHT - self.bw_bottom) as f32)
                as i32;
            let y1 = (self.bw_bottom as f32 + py1 * (config::SCREEN_HEIGHT - self.bw_bottom) as f32)
                as i32;
            let lx0 = (floor_left_far as f32 + (-100 - floor_left_far) as f32 * py0) as i32;
            let rx0 = (floor_right_far as f32
                + (config::OFFICE_WIDTH + 100 - floor_right_far) as f32 * py0)
                as i32;
            let lx1 = (floor_left_far as f32 + (-100 - floor_left_far) as f32 * py1) as i32;
            let rx1 = (floor_right_far as f32
                + (config::OFFICE_WIDTH + 100 - floor_right_far) as f32 * py1)
                as i32;
            for c in 0..cols {
                let px0 = lx0 + (c as f32 / cols as f32 * (rx0 - lx0) as f32) as i32;
                let px1 = lx0 + ((c + 1) as f32 / cols as f32 * (rx0 - lx0) as f32) as i32;
                let px0b = lx1 + (c as f32 / cols as f32 * (rx1 - lx1) as f32) as i32;
                let px1b = lx1 + ((c + 1) as f32 / cols as f32 * (rx1 - lx1) as f32) as i32;
                let color = if (r + c) % 2 == 0 {
                    colors::FLOOR_TILE_1
                } else {
                    colors::FLOOR_TILE_2
                };
                let fade = (1.0 - (1.0 - py0) * 0.6).max(0.3);
                let shaded = color.shade(fade);
                draw::trapezoid(
                    eng,
                    shaded.r,
                    shaded.g,
                    shaded.b,
                    (px0, y0),
                    (px1, y0),
                    (px1b, y1),
                    (px0b, y1),
                );
            }
        }
    }

    fn draw_back_wall_base(&self, eng: &mut dyn Engine) {
        eng.draw_rect(
            self.bw_left,
            self.bw_top,
            self.bw_right - self.bw_left,
            self.bw_bottom - self.bw_top,
            colors::WALL_COLOR.r,
            colors::WALL_COLOR.g,
            colors::WALL_COLOR.b,
            255,
            true,
        );
        eng.draw_rect(
            self.bw_left + 10,
            self.bw_top + 16,
            self.bw_right - self.bw_left - 20,
            22,
            34,
            32,
            40,
            190,
            true,
        );
        for i in 0..=6 {
            let yy = self.bw_top + 14 + i * 4;
            eng.line(
                self.bw_left + 16,
                yy,
                self.bw_right - 16,
                yy,
                52,
                48,
                58,
                70,
            );
        }
        eng.draw_rect(
            self.bw_left,
            self.bw_bottom - 20,
            self.bw_right - self.bw_left,
            20,
            35,
            30,
            38,
            255,
            true,
        );
        eng.line(
            self.bw_left,
            self.bw_bottom - 20,
            self.bw_right,
            self.bw_bottom - 20,
            50,
            45,
            55,
            255,
        );

        let p1x = self.vp_x - 64;
        let p1y = self.bw_top + 36;
        eng.draw_rect(p1x, p1y, 128, 128, 40, 36, 46, 255, true);
        eng.draw_rect(p1x + 2, p1y + 2, 124, 124, 22, 22, 24, 255, true);
        eng.draw_rect(p1x + 8, p1y + 10, 112, 108, 14, 14, 18, 255, true);
        eng.draw_rect(
            p1x,
            p1y,
            128,
            128,
            colors::WALL_ACCENT.r,
            colors::WALL_ACCENT.g,
            colors::WALL_ACCENT.b,
            255,
            false,
        );
        draw::text(
            eng,
            "MAFIA",
            p1x + 64,
            p1y + 52,
            24,
            255,
            255,
            100,
            255,
            true,
        );
        draw::text(
            eng,
            "NIGHT SHIFT",
            p1x + 64,
            p1y + 82,
            11,
            160,
            150,
            72,
            220,
            true,
        );
        for i in 0..=5 {
            eng.line(
                p1x + 10,
                p1y + 96 + i * 3,
                p1x + 118,
                p1y + 90 + i * 3,
                45,
                42,
                50,
                120,
            );
        }

        let flyer_x = self.bw_left + 42;
        let flyer_y = self.bw_top + 70;
        eng.draw_rect(flyer_x, flyer_y, 84, 104, 64, 58, 62, 255, true);
        eng.draw_rect(flyer_x + 5, flyer_y + 8, 74, 88, 38, 34, 40, 255, true);
        draw::text(
            eng,
            "RULES",
            flyer_x + 42,
            flyer_y + 26,
            12,
            188,
            182,
            168,
            245,
            true,
        );
        for i in 0..=5 {
            eng.line(
                flyer_x + 12,
                flyer_y + 40 + i * 9,
                flyer_x + 70,
                flyer_y + 40 + i * 9,
                74,
                70,
                64,
                180,
            );
        }

        let clock_x = self.vp_x + 120;
        let clock_y = self.bw_top + 30;
        eng.circle(clock_x, clock_y, 18, 50, 48, 55, 255, true);
        eng.circle(
            clock_x,
            clock_y,
            18,
            colors::WALL_ACCENT.r,
            colors::WALL_ACCENT.g,
            colors::WALL_ACCENT.b,
            255,
            false,
        );

        for i in 0..=7 {
            let gx = self.bw_left + 40 + i * 58;
            eng.line(
                gx,
                self.bw_top + 44,
                gx + 8,
                self.bw_bottom - 26,
                30,
                26,
                33,
                90,
            );
        }
        eng.line(
            self.vp_x,
            self.bw_top,
            self.vp_x,
            self.bw_bottom,
            60,
            55,
            65,
            120,
        );
    }

    fn draw_back_wall_dynamic(&self, eng: &mut dyn Engine, t: f32) {
        let clock_x = self.vp_x + 120;
        let clock_y = self.bw_top + 30;
        eng.line(
            clock_x,
            clock_y,
            clock_x + (t.cos() * 10.0) as i32,
            clock_y + (t.sin() * 10.0) as i32,
            140,
            130,
            120,
            255,
        );
        let pulse = 0.45 + 0.55 * (t * 2.8).sin();
        let lamp_a = (26.0 + pulse * 38.0) as u8;
        eng.draw_rect(
            self.vp_x - 120,
            self.bw_top + 6,
            240,
            16,
            220,
            210,
            165,
            lamp_a,
            true,
        );
    }

    fn draw_depth_structure(&self, eng: &mut dyn Engine) {
        for z in [0.12, 0.24, 0.36, 0.50, 0.66, 0.82] {
            let (lx, y, _) = self.project_depth(-1.0, z, 0.0);
            let (rx, _ry, _) = self.project_depth(1.0, z, 0.0);
            let shade_val = (70.0 - z * 28.0) as u8;
            eng.line(lx, y, rx, y, shade_val, shade_val, shade_val + 4, 120);
        }

        for side in [-1.0_f32, 1.0] {
            for z in [0.18, 0.42, 0.70] {
                let (x0, y0, s0) = self.project_depth(0.82 * side, z, 0.0);
                let (_x1, y1, _) = self.project_depth(0.82 * side, z, 150.0);
                let w = (16.0 * s0) as i32;
                let w = w.max(8);
                let col = Self::shade(Color::new(48, 45, 52), 1.05 - z * 0.35);
                eng.draw_rect(
                    x0 - w / 2,
                    y1,
                    w,
                    (y0 - y1).max(8),
                    col.r,
                    col.g,
                    col.b,
                    150,
                    true,
                );
            }
        }
    }

    fn draw_side_walls(&self, eng: &mut dyn Engine) {
        draw::trapezoid(
            eng,
            38,
            35,
            42,
            (self.bw_left - self.hall_depth, 0),
            (self.bw_left, self.bw_top),
            (self.bw_left, self.bw_bottom),
            (self.bw_left - self.hall_depth, config::SCREEN_HEIGHT),
        );
        draw::trapezoid(
            eng,
            38,
            35,
            42,
            (self.bw_right, self.bw_top),
            (self.bw_right + self.hall_depth, 0),
            (self.bw_right + self.hall_depth, config::SCREEN_HEIGHT),
            (self.bw_right, self.bw_bottom),
        );
    }

    fn draw_hallways_base(&self, eng: &mut dyn Engine) {
        let ht = self.bw_top + 15;
        let hb = self.bw_bottom - 15;
        let lx = self.bw_left - self.hall_depth - self.hall_w;
        let lw = self.hall_w + 10;
        let lh = hb - ht;
        eng.draw_rect(lx, ht, lw, lh, 8, 8, 10, 255, true);
        eng.draw_rect(
            lx,
            ht,
            lw,
            lh,
            colors::DOOR_FRAME_COLOR.r,
            colors::DOOR_FRAME_COLOR.g,
            colors::DOOR_FRAME_COLOR.b,
            255,
            false,
        );
        for i in 0..=8 {
            let y = ht + i * (lh / 9);
            let (r, g, b) = if i % 2 == 0 {
                (168, 138, 42)
            } else {
                (35, 30, 28)
            };
            eng.line(lx + lw - 10, y, lx + lw, y, r, g, b, 210);
        }

        let rx = self.bw_right + self.hall_depth - 10;
        let rw = self.hall_w + 10;
        eng.draw_rect(rx, ht, rw, lh, 8, 8, 10, 255, true);
        eng.draw_rect(
            rx,
            ht,
            rw,
            lh,
            colors::DOOR_FRAME_COLOR.r,
            colors::DOOR_FRAME_COLOR.g,
            colors::DOOR_FRAME_COLOR.b,
            255,
            false,
        );
        for i in 0..=8 {
            let y = ht + i * (lh / 9);
            let (r, g, b) = if i % 2 == 0 {
                (168, 138, 42)
            } else {
                (35, 30, 28)
            };
            eng.line(rx, y, rx + 10, y, r, g, b, 210);
        }
    }

    fn draw_hallways_dynamic(
        &self,
        eng: &mut dyn Engine,
        left_light: bool,
        right_light: bool,
        anim_left: Option<&str>,
        anim_right: Option<&str>,
    ) {
        let ht = self.bw_top + 15;
        let hb = self.bw_bottom - 15;
        let lx = self.bw_left - self.hall_depth - self.hall_w;
        let lw = self.hall_w + 10;
        let lh = hb - ht;
        let rx = self.bw_right + self.hall_depth - 10;
        let rw = self.hall_w + 10;

        if left_light {
            eng.draw_rect(
                lx,
                ht,
                lw,
                lh,
                colors::HALL_LIGHT.r,
                colors::HALL_LIGHT.g,
                colors::HALL_LIGHT.b,
                70,
                true,
            );
            eng.draw_rect(lx + 6, ht + 8, lw - 12, lh - 16, 226, 214, 170, 24, true);
            if let Some(name) = anim_left {
                draw::animatronic_face(eng, name, lx + 10, ht + 20, lw - 20, 160);
            }
        }
        if right_light {
            eng.draw_rect(
                rx,
                ht,
                rw,
                lh,
                colors::HALL_LIGHT.r,
                colors::HALL_LIGHT.g,
                colors::HALL_LIGHT.b,
                70,
                true,
            );
            eng.draw_rect(rx + 6, ht + 8, rw - 12, lh - 16, 226, 214, 170, 24, true);
            if let Some(name) = anim_right {
                draw::animatronic_face(eng, name, rx + 10, ht + 20, rw - 20, 160);
            }
        }
    }

    fn draw_vent_base(&self, eng: &mut dyn Engine) {
        let vx = self.vp_x - 60;
        let vy = self.bw_bottom - 110;
        eng.draw_rect(vx, vy, 120, 80, 5, 5, 7, 255, true);
        eng.draw_rect(vx, vy, 120, 80, 40, 40, 45, 255, false);
        for i in 1..=3 {
            let by = vy + i * (80 / 4);
            eng.line(vx, by, vx + 120, by, 35, 35, 40, 255);
        }
    }

    fn draw_vent_dynamic(&self, eng: &mut dyn Engine, anim_vent: Option<&str>) {
        let vx = self.vp_x - 60;
        let vy = self.bw_bottom - 110;
        if self.vent_light {
            eng.draw_rect(vx, vy, 120, 80, 200, 200, 220, 90, true);
            if let Some(name) = anim_vent {
                draw::animatronic_face(eng, name, vx + 20, vy + 10, 80, 60);
            }
        } else if let Some(_name) = anim_vent {
            eng.circle(vx + 45, vy + 30, 4, 255, 200, 220, 255, true);
            eng.circle(vx + 75, vy + 30, 4, 255, 200, 220, 255, true);
        }
    }

    fn draw_doors(&self, eng: &mut dyn Engine, left_anim_val: f32, right_anim_val: f32) {
        let ht = self.bw_top + 15;
        let hb = self.bw_bottom - 15;
        let door_h = hb - ht;
        if left_anim_val > 0.01 {
            self.draw_single_door(
                eng,
                self.bw_left - self.hall_depth - self.hall_w,
                ht,
                self.hall_w + 10,
                (door_h as f32 * left_anim_val) as i32,
            );
        }
        if right_anim_val > 0.01 {
            self.draw_single_door(
                eng,
                self.bw_right + self.hall_depth - 10,
                ht,
                self.hall_w + 10,
                (door_h as f32 * right_anim_val) as i32,
            );
        }
    }

    fn draw_single_door(&self, eng: &mut dyn Engine, x: i32, y: i32, w: i32, v_h: i32) {
        eng.draw_rect(
            x,
            y,
            w,
            v_h,
            colors::DOOR_COLOR.r,
            colors::DOOR_COLOR.g,
            colors::DOOR_COLOR.b,
            255,
            true,
        );
        let mut i = 0;
        while i < v_h {
            eng.line(x, y + i, x + w, y + i, 85, 80, 78, 255);
            i += 14;
        }
        let sh = 12;
        let mut i = 0;
        while i <= w + sh {
            eng.line(x + i, y, x + i - sh, y + sh.min(v_h), 200, 180, 40, 255);
            i += sh;
        }
        if v_h > 80 {
            eng.draw_rect(x + w / 2 - 18, y + 35, 36, 28, 15, 25, 15, 255, true);
            eng.draw_rect(x + w / 2 - 18, y + 35, 36, 28, 95, 90, 85, 255, false);
        }
        eng.draw_rect(x, y, w, v_h, 95, 90, 85, 255, false);
    }

    fn draw_office_elements(&self, eng: &mut dyn Engine) {
        let (bl_x, bl_y, _) = self.project_depth(-0.70, 0.58, 0.0);
        let (br_x, br_y, _) = self.project_depth(0.70, 0.58, 0.0);
        let (fl_x, fl_y, _) = self.project_depth(-1.00, 0.92, 0.0);
        let (fr_x, fr_y, _) = self.project_depth(1.00, 0.92, 0.0);
        draw::trapezoid(
            eng,
            colors::DESK_TOP.r,
            colors::DESK_TOP.g,
            colors::DESK_TOP.b,
            (bl_x, bl_y),
            (br_x, br_y),
            (fr_x, fr_y),
            (fl_x, fl_y),
        );
        let col_desk = Self::shade(colors::DESK_COLOR, 0.85);
        draw::trapezoid(
            eng,
            col_desk.r,
            col_desk.g,
            col_desk.b,
            (fl_x, fl_y),
            (fr_x, fr_y),
            (fr_x, fr_y + 46),
            (fl_x, fl_y + 46),
        );
        eng.line(fl_x, fl_y, fr_x, fr_y, 120, 104, 86, 255);
        eng.draw_rect(fl_x + 30, fl_y + 8, 120, 18, 72, 64, 60, 255, true);
        eng.draw_rect(fr_x - 170, fr_y + 12, 145, 16, 74, 66, 62, 255, true);
        for i in 0..=4 {
            eng.line(
                fl_x + 36 + i * 7,
                fl_y + 11,
                fl_x + 130 + i * 7,
                fl_y + 11,
                96,
                90,
                84,
                160,
            );
        }

        let (mx, my, ms) = self.project_depth(0.42, 0.64, 66.0);
        let mw = (85.0 * ms) as i32;
        let mh = (56.0 * ms) as i32;
        let mw = mw.max(42);
        let mh = mh.max(28);
        eng.draw_rect(mx - mw / 2, my - mh / 2, mw, mh, 18, 20, 24, 255, true);
        eng.draw_rect(mx - mw / 2, my - mh / 2, mw, mh, 65, 70, 78, 255, false);
        eng.draw_rect(
            mx - 4,
            my + mh / 2,
            8,
            (15.0 * ms) as i32,
            45,
            45,
            48,
            255,
            true,
        );
        eng.draw_rect(
            mx - (24.0 * ms) as i32,
            my + mh / 2 + (15.0 * ms) as i32,
            (48.0 * ms) as i32,
            (5.0 * ms) as i32,
            55,
            55,
            60,
            255,
            true,
        );

        let (cx, cy, cs) = self.project_depth(-0.34, 0.70, 32.0);
        let cw = ((14.0 * cs) as i32).max(8);
        let ch = ((28.0 * cs) as i32).max(12);
        eng.draw_rect(cx - cw / 2, cy - ch, cw, ch, 180, 25, 25, 255, true);
        eng.draw_rect(
            cx - cw / 2 - 1,
            cy - ch - 3,
            cw + 2,
            5,
            210,
            45,
            45,
            255,
            true,
        );

        let (mug_x, mug_y, mug_s) = self.project_depth(0.08, 0.73, 28.0);
        let mug_w = ((18.0 * mug_s) as i32).max(10);
        let mug_h = ((12.0 * mug_s) as i32).max(8);
        eng.draw_rect(
            mug_x - mug_w / 2,
            mug_y - mug_h,
            mug_w,
            mug_h,
            120,
            115,
            102,
            255,
            true,
        );
        eng.draw_rect(
            mug_x + mug_w / 2 - 1,
            mug_y - mug_h + 2,
            5,
            mug_h - 4,
            120,
            115,
            102,
            255,
            false,
        );
    }

    fn draw_fan(&self, eng: &mut dyn Engine, t: f32) {
        let (fx, fy, fs) = self.project_depth(-0.46, 0.66, 34.0);
        let cx = fx;
        let cy = fy;
        let hub_r = ((5.0 * fs) as i32).max(3);
        let ring_r = ((24.0 * fs) as i32).max(12);
        eng.draw_rect(cx - 10, cy + 2, 20, 22, 55, 55, 60, 255, true);
        eng.draw_rect(cx - 16, cy + 22, 32, 6, 65, 65, 70, 255, true);
        eng.circle(cx, cy - 5, ring_r, 70, 24, 24, 255, true);
        eng.circle(cx, cy - 5, (ring_r - 2).max(8), 48, 48, 52, 255, true);
        let ft = t * 12.0;
        for i in 0..4 {
            let angle = ft + i as f32 * (PI / 2.0);
            let ex = cx + (angle.cos() * (ring_r - 5) as f32) as i32;
            let ey = cy - 5 + (angle.sin() * (ring_r - 5) as f32) as i32;
            eng.line(cx, cy - 5, ex, ey, 110, 110, 115, 255);
        }
        eng.circle(cx, cy - 5, hub_r, 80, 80, 85, 255, true);
    }

    fn draw_wall_dressing(&self, eng: &mut dyn Engine) {
        for side in [-1, 1] {
            let base_x = if side < 0 {
                self.bw_left - self.hall_depth + 22
            } else {
                self.bw_right + self.hall_depth - 130
            };
            eng.draw_rect(base_x, self.bw_top + 44, 108, 30, 26, 24, 30, 255, true);
            eng.draw_rect(base_x + 3, self.bw_top + 47, 102, 24, 56, 18, 18, 255, true);
            draw::text(
                eng,
                "DOOR CTRL",
                base_x + 54,
                self.bw_top + 59,
                11,
                220,
                214,
                194,
                240,
                true,
            );
        }
        for i in 0..=3 {
            let x0 = self.vp_x - 150 + i * 92;
            let y0 = self.bw_bottom - 56 - i * 4;
            eng.line(x0, y0, x0 + 78, y0 - 8, 26, 24, 30, 180);
        }
    }

    fn draw_in_office(&self, eng: &mut dyn Engine, anim_name: Option<&str>) {
        let Some(name) = anim_name else {
            return;
        };
        let w = 400;
        let h = 500;
        let x = self.vp_x - w / 2;
        let y = self.bw_bottom - h + 80;
        let ct = (time::now() * 7.0) as i32;
        if ct % 3 != 0 {
            draw::animatronic_sprite(eng, name, x, y, w, h);
        }
    }

    fn draw_ambient(&self, eng: &mut dyn Engine) {
        eng.draw_rect(
            0,
            0,
            config::OFFICE_WIDTH,
            config::SCREEN_HEIGHT,
            0,
            0,
            0,
            24,
            true,
        );
        eng.draw_rect(0, 0, config::OFFICE_WIDTH, 120, 0, 0, 0, 40, true);
        eng.draw_rect(
            0,
            config::SCREEN_HEIGHT - 90,
            config::OFFICE_WIDTH,
            90,
            0,
            0,
            0,
            32,
            true,
        );
        for i in 0..=6 {
            let y = (i as f32 * (config::SCREEN_HEIGHT as f32 / 7.0)) as i32;
            let a = 20 - i * 2;
            if a > 0 {
                eng.draw_rect(
                    0,
                    y,
                    config::OFFICE_WIDTH,
                    (config::SCREEN_HEIGHT as f32 / 7.0) as i32,
                    0,
                    0,
                    0,
                    a as u8,
                    true,
                );
            }
        }
    }
}

/// Helper: truncate a float to an int like C++ `static_cast<int>`.
fn src_d(v: f32) -> i32 {
    v as i32
}
