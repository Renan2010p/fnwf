//! Door + light state and the on-screen control panels.

#[allow(unused_imports)]
use fnwf_core::prelude::*;

use fnwf_engine::Engine;

use fnwf_core::config;
use fnwf_core::draw;
use fnwf_core::localization;

/// Left/right door and light panel.
pub struct DoorSystem {
    /// Whether the left door is closed.
    pub left_closed: bool,
    /// Whether the right door is closed.
    pub right_closed: bool,
    /// Whether the left hallway light is on.
    pub left_light: bool,
    /// Whether the right hallway light is on.
    pub right_light: bool,
    /// Left door animation progress from 0 (open) to 1 (closed).
    pub left_anim: f32,
    /// Right door animation progress from 0 (open) to 1 (closed).
    pub right_anim: f32,
    anim_speed: f32,
    button_rects: Vec<(&'static str, [i32; 4])>,
}

impl Default for DoorSystem {
    fn default() -> Self {
        Self::new()
    }
}

impl DoorSystem {
    /// Creates the system with both doors open and both lights off.
    pub fn new() -> Self {
        Self {
            left_closed: false,
            right_closed: false,
            left_light: false,
            right_light: false,
            left_anim: 0.0,
            right_anim: 0.0,
            anim_speed: 4.0,
            button_rects: Vec::new(),
        }
    }

    /// Advances the door opening/closing animations by `dt` seconds.
    pub fn update(&mut self, dt: f32) {
        let tl = if self.left_closed { 1.0 } else { 0.0 };
        if self.left_anim < tl {
            self.left_anim = tl.min(self.left_anim + self.anim_speed * dt);
        } else if self.left_anim > tl {
            self.left_anim = tl.max(self.left_anim - self.anim_speed * dt);
        }

        let tr = if self.right_closed { 1.0 } else { 0.0 };
        if self.right_anim < tr {
            self.right_anim = tr.min(self.right_anim + self.anim_speed * dt);
        } else if self.right_anim > tr {
            self.right_anim = tr.max(self.right_anim - self.anim_speed * dt);
        }
    }

    /// Draws the left/right door and light control panels, storing their button
    /// rectangles for hit-testing. Skipped while the camera monitor is open.
    pub fn draw_buttons(&mut self, eng: &mut dyn Engine, camera_open: bool) {
        if camera_open {
            return;
        }
        self.button_rects.clear();
        let panel_w = 96;
        let panel_h = 106;
        let bw = 78;
        let bh = 34;
        let gap = 8;
        let panel_y = (config::SCREEN_HEIGHT as f32 * 0.50) as i32 - panel_h / 2;

        // Left panel
        let lx = 14;
        eng.draw_rect(lx, panel_y, panel_w, panel_h, 12, 12, 16, 210, true);
        eng.draw_rect(lx, panel_y, panel_w, panel_h, 60, 60, 70, 255, false);
        draw::text(
            eng,
            &localization::text("door_left"),
            lx + panel_w / 2,
            panel_y - 12,
            11,
            80,
            80,
            90,
            255,
            true,
        );
        let l_btn_x = lx + 9;
        let l_btn_y = panel_y + 10;
        let l_label = if self.left_closed {
            localization::text("door_open")
        } else {
            localization::text("door_close")
        };
        draw::button_box(
            eng,
            l_btn_x,
            l_btn_y,
            bw,
            bh,
            &l_label,
            self.left_closed,
            200,
            40,
            40,
            60,
            60,
            65,
        );
        self.button_rects
            .push(("left_door", [l_btn_x, l_btn_y, bw, bh]));
        draw::button_box(
            eng,
            l_btn_x,
            l_btn_y + bh + gap,
            bw,
            bh,
            &localization::text("light"),
            self.left_light,
            30,
            180,
            60,
            60,
            60,
            65,
        );
        self.button_rects
            .push(("left_light", [l_btn_x, l_btn_y + bh + gap, bw, bh]));

        // Right panel
        let rx = config::SCREEN_WIDTH - panel_w - 14;
        eng.draw_rect(rx, panel_y, panel_w, panel_h, 12, 12, 16, 210, true);
        eng.draw_rect(rx, panel_y, panel_w, panel_h, 60, 60, 70, 255, false);
        draw::text(
            eng,
            &localization::text("door_right"),
            rx + panel_w / 2,
            panel_y - 12,
            11,
            80,
            80,
            90,
            255,
            true,
        );
        let r_btn_x = rx + 9;
        let r_btn_y = panel_y + 10;
        let r_label = if self.right_closed {
            localization::text("door_open")
        } else {
            localization::text("door_close")
        };
        draw::button_box(
            eng,
            r_btn_x,
            r_btn_y,
            bw,
            bh,
            &r_label,
            self.right_closed,
            200,
            40,
            40,
            60,
            60,
            65,
        );
        self.button_rects
            .push(("right_door", [r_btn_x, r_btn_y, bw, bh]));
        draw::button_box(
            eng,
            r_btn_x,
            r_btn_y + bh + gap,
            bw,
            bh,
            &localization::text("light"),
            self.right_light,
            30,
            180,
            60,
            60,
            60,
            65,
        );
        self.button_rects
            .push(("right_light", [r_btn_x, r_btn_y + bh + gap, bw, bh]));
    }

    /// Returns `Some("door")` or `Some("light")` when a button was hit.
    pub fn handle_click(&mut self, mx: i32, my: i32) -> Option<&'static str> {
        for (name, rect) in &self.button_rects {
            let [x, y, w, h] = *rect;
            if mx >= x && mx <= x + w && my >= y && my <= y + h {
                if name.contains("door") {
                    if name.contains("left") {
                        self.left_closed = !self.left_closed;
                    } else {
                        self.right_closed = !self.right_closed;
                    }
                    return Some("door");
                }
                if name.contains("light") {
                    if name.contains("left") {
                        self.left_light = !self.left_light;
                        if self.left_light {
                            self.right_light = false;
                        }
                    } else {
                        self.right_light = !self.right_light;
                        if self.right_light {
                            self.left_light = false;
                        }
                    }
                    return Some("light");
                }
            }
        }
        None
    }

    /// Number of power-drawing devices currently on (doors + lights).
    pub fn get_power_usage(&self) -> i32 {
        let mut usage = 0;
        if self.left_closed {
            usage += 1;
        }
        if self.right_closed {
            usage += 1;
        }
        if self.left_light {
            usage += 1;
        }
        if self.right_light {
            usage += 1;
        }
        usage
    }
}
