//! Custom Night (Night 7) configuration screen.
//!
//! Lets the player set each animatronic's AI level from 0 to 20 (40 once the
//! secret code `2025` is entered), either directly or via presets, then start
//! the night with `"start"`. Escape returns to the menu with `"menu"`. The
//! chosen levels are exposed through the state's `custom_ai_levels`.

#[allow(unused_imports)]
use fnwf_core::prelude::*;

use fnwf_engine::{keys, Engine, Event, EventType, TextureHandle};

use fnwf_core::state::{GameState, StateType};
use fnwf_core::{audio, config, draw, localization};

use crate::colors;

fn lerp(a: f32, b: f32, t: f32) -> f32 {
    a + (b - a) * t.clamp(0.0, 1.0)
}

fn digit_from_event(key: i32) -> i32 {
    if (b'0' as i32..=b'9' as i32).contains(&key) {
        return key - b'0' as i32;
    }
    keys::keypad_digit(key).map(|d| d as i32).unwrap_or(-1)
}

struct AnimData {
    name: &'static str,
    sprite: &'static str,
    size_w: i32,
    size_h: i32,
}

struct Preset {
    name: String,
    levels: Vec<i32>,
    has_levels: bool,
}

/// The Custom Night configuration screen.
pub struct CustomNightState {
    timer: f32,
    selected: usize,
    done: bool,
    m_result: String,
    ai_levels: [i32; 4],

    animatronics: Vec<AnimData>,
    sprites: Vec<(&'static str, TextureHandle)>,

    presets: Vec<Preset>,
    current_preset: usize,

    secret_code_buffer: String,
    secret_code_pending: bool,
    secret_mode_unlocked: bool,

    card_rects: Vec<[i32; 4]>,
    up_rects: Vec<[i32; 4]>,
    down_rects: Vec<[i32; 4]>,
    preset_prev: [i32; 4],
    preset_next: [i32; 4],
    preset_label: [i32; 4],
    ready_rect: [i32; 4],
    card_scales: [f32; 4],
    card_glows: [f32; 4],
}

impl CustomNightState {
    /// Creates the screen, loading the four animatronic portraits and building
    /// the preset list and layout.
    pub fn new(eng: &mut dyn Engine) -> Self {
        let animatronics = vec![
            AnimData {
                name: "Cedro",
                sprite: "cedro",
                size_w: 220,
                size_h: 220,
            },
            AnimData {
                name: "Eser",
                sprite: "eser",
                size_w: 220,
                size_h: 220,
            },
            AnimData {
                name: "Alice",
                sprite: "alice",
                size_w: 220,
                size_h: 220,
            },
            AnimData {
                name: "Sonk",
                sprite: "Sonk",
                size_w: 220,
                size_h: 220,
            },
        ];
        let mut sprites = Vec::new();
        for a in &animatronics {
            draw::load_sprite(eng, a.sprite);
            if let Some(tex) = draw::get_sprite(a.sprite) {
                sprites.push((a.sprite, tex));
            }
        }

        let presets = vec![
            Preset {
                name: "Custom".to_string(),
                levels: Vec::new(),
                has_levels: false,
            },
            Preset {
                name: localization::text("preset_1"),
                levels: vec![5, 5, 20, 8],
                has_levels: true,
            },
            Preset {
                name: localization::text("preset_2"),
                levels: vec![10, 20, 10, 10],
                has_levels: true,
            },
            Preset {
                name: localization::text("preset_3"),
                levels: vec![20, 20, 20, 20],
                has_levels: true,
            },
        ];

        let mut state = Self {
            timer: 0.0,
            selected: 1,
            done: false,
            m_result: String::new(),
            ai_levels: [0, 0, 0, 0],
            animatronics,
            sprites,
            presets,
            current_preset: 0,
            secret_code_buffer: String::new(),
            secret_code_pending: false,
            secret_mode_unlocked: false,
            card_rects: Vec::new(),
            up_rects: Vec::new(),
            down_rects: Vec::new(),
            preset_prev: [0; 4],
            preset_next: [0; 4],
            preset_label: [0; 4],
            ready_rect: [0; 4],
            card_scales: [1.0; 4],
            card_glows: [0.0; 4],
        };
        state.card_scales[0] = 1.02;
        state.card_glows[0] = 1.0;
        state.rebuild_layout();
        state
    }

    fn get_ai_cap(&self) -> i32 {
        if self.secret_mode_unlocked {
            40
        } else {
            20
        }
    }

    fn unlock_secret_mode(&mut self) {
        if !self.secret_mode_unlocked {
            self.secret_mode_unlocked = true;
            self.presets.push(Preset {
                name: localization::text("preset_secret"),
                levels: vec![40, 40, 40, 40],
                has_levels: true,
            });
        }
        self.current_preset = self.presets.len() - 1;
        self.apply_preset(self.current_preset);
    }

    fn apply_preset(&mut self, index: usize) {
        if index < self.presets.len() {
            self.current_preset = index;
            if self.presets[index].has_levels {
                for i in 0..4.min(self.presets[index].levels.len()) {
                    self.ai_levels[i] = self.presets[index].levels[i];
                }
            }
        }
    }

    fn cycle_preset(&mut self, eng: &mut dyn Engine, direction: i32) {
        let n = self.presets.len() as i32;
        let new_idx = ((self.current_preset as i32 + direction) % n + n) % n;
        self.apply_preset(new_idx as usize);
        audio::play(eng, "blip", 0, -1);
    }

    fn rebuild_layout(&mut self) {
        let card_w = 280;
        let card_h = 430;
        let gap = 42;
        let total_w = 4 * card_w + 3 * gap;
        let start_x = config::SCREEN_WIDTH / 2 - total_w / 2;
        let y = 120;

        self.card_rects.clear();
        self.up_rects.clear();
        self.down_rects.clear();
        for i in 0..4 {
            let x = start_x + i * (card_w + gap);
            self.card_rects.push([x, y, card_w, card_h]);
            self.up_rects.push([x + card_w / 2 - 32, y + 300, 64, 44]);
            self.down_rects.push([x + card_w / 2 - 32, y + 380, 64, 44]);
        }

        let cx = config::SCREEN_WIDTH / 2;
        self.preset_prev = [cx - 250, 580, 80, 48];
        self.preset_next = [cx + 170, 580, 80, 48];
        self.preset_label = [cx - 160, 580, 320, 48];
        self.ready_rect = [cx - 180, 642, 360, 54];
    }
}

impl GameState for CustomNightState {
    fn handle_event(&mut self, eng: &mut dyn Engine, ev: &Event) {
        if ev.kind == EventType::KeyDown {
            let k = ev.key;
            let digit = digit_from_event(k);
            if digit >= 0 {
                self.secret_code_buffer.push_str(&digit.to_string());
                if self.secret_code_buffer.len() > 4 {
                    let keep = self.secret_code_buffer.len() - 4;
                    self.secret_code_buffer = self.secret_code_buffer[keep..].to_string();
                }
                if self.secret_code_buffer == "2025" {
                    self.secret_code_pending = true;
                    self.selected = 5;
                    audio::play(eng, "notification", 0, -1);
                    self.secret_code_buffer.clear();
                }
            }

            if k == keys::ESCAPE {
                self.m_result = "menu".to_string();
                self.done = true;
                audio::play(eng, "select", 0, -1);
            } else if k == keys::LEFT || k == keys::A {
                self.selected = (((self.selected as i32 - 2) % 5 + 5) % 5 + 1) as usize;
                audio::play(eng, "blip", 0, -1);
            } else if k == keys::RIGHT || k == keys::D {
                self.selected = (self.selected % 5) + 1;
                audio::play(eng, "blip", 0, -1);
            }

            if self.selected <= 4 {
                let change = if k == keys::UP || k == keys::W {
                    1
                } else if k == keys::DOWN || k == keys::S {
                    -1
                } else {
                    0
                };
                if change != 0 {
                    let cap = self.get_ai_cap();
                    self.ai_levels[self.selected - 1] =
                        (self.ai_levels[self.selected - 1] + change).clamp(0, cap);
                    self.current_preset = 0;
                    audio::play(eng, "blip", 0, -1);
                }
            }

            if k == keys::RETURN || k == keys::SPACE {
                if self.selected == 5 {
                    if self.secret_code_pending {
                        self.secret_code_pending = false;
                        self.unlock_secret_mode();
                        audio::play(eng, "select", 0, -1);
                    } else {
                        self.m_result = "start".to_string();
                        self.done = true;
                        audio::play(eng, "select", 0, -1);
                    }
                } else {
                    self.selected = 5;
                    audio::play(eng, "blip", 0, -1);
                }
            }
        }

        if ev.kind == EventType::MouseButtonDown {
            let (mx, my) = (ev.x, ev.y);
            for i in 0..4 {
                let r = self.card_rects[i];
                if mx >= r[0] && mx <= r[0] + r[2] && my >= r[1] && my <= r[1] + r[3] {
                    self.selected = i + 1;
                }
            }
            for i in 0..4 {
                let r = self.up_rects[i];
                if mx >= r[0] && mx <= r[0] + r[2] && my >= r[1] && my <= r[1] + r[3] {
                    let cap = self.get_ai_cap();
                    self.ai_levels[i] = (self.ai_levels[i] + 1).clamp(0, cap);
                    self.current_preset = 0;
                    self.selected = i + 1;
                    audio::play(eng, "blip", 0, -1);
                }
                let d = self.down_rects[i];
                if mx >= d[0] && mx <= d[0] + d[2] && my >= d[1] && my <= d[1] + d[3] {
                    let cap = self.get_ai_cap();
                    self.ai_levels[i] = (self.ai_levels[i] - 1).clamp(0, cap);
                    self.current_preset = 0;
                    self.selected = i + 1;
                    audio::play(eng, "blip", 0, -1);
                }
            }
            if hit(self.preset_prev, mx, my) {
                self.cycle_preset(eng, -1);
            }
            if hit(self.preset_next, mx, my) {
                self.cycle_preset(eng, 1);
            }
            if hit(self.ready_rect, mx, my) {
                if self.secret_code_pending {
                    self.secret_code_pending = false;
                    self.unlock_secret_mode();
                    audio::play(eng, "select", 0, -1);
                } else {
                    self.m_result = "start".to_string();
                    self.done = true;
                    audio::play(eng, "select", 0, -1);
                }
            }
        }
    }

    fn update(&mut self, _eng: &mut dyn Engine, dt: f32) {
        self.timer += dt;
        for i in 0..4 {
            let is_sel = i + 1 == self.selected;
            let target_scale = if is_sel { 1.02 } else { 1.0 };
            let target_glow = if is_sel { 1.0 } else { 0.0 };
            self.card_scales[i] += (target_scale - self.card_scales[i]) * (8.0 * dt).min(1.0);
            self.card_glows[i] += (target_glow - self.card_glows[i]) * (6.0 * dt).min(1.0);
        }
    }

    fn draw(&mut self, eng: &mut dyn Engine) {
        eng.clear(6, 9, 18, 255);
        let mut i = 0;
        while i < config::SCREEN_HEIGHT {
            let a = if (i / 90) % 2 == 0 { 12 } else { 7 };
            eng.draw_rect(0, i, config::SCREEN_WIDTH, 90, 10, 14, 26, a, true);
            i += 90;
        }
        draw::static_noise(eng, 0, 0, config::SCREEN_WIDTH, config::SCREEN_HEIGHT, 0.01);
        eng.draw_rect(
            24,
            24,
            config::SCREEN_WIDTH - 48,
            76,
            80,
            110,
            160,
            70,
            false,
        );
        draw::text(
            eng,
            &localization::text("custom_night"),
            config::SCREEN_WIDTH / 2,
            38,
            54,
            colors::TITLE_COLOR.r,
            colors::TITLE_COLOR.g,
            colors::TITLE_COLOR.b,
            255,
            true,
        );

        for i in 0..4 {
            let a = &self.animatronics[i];
            let r = self.card_rects[i];
            let cx = r[0] + r[2] / 2;
            let glow = self.card_glows[i];
            let scale = self.card_scales[i];
            let dw = (r[2] as f32 * scale) as i32;
            let dh = (r[3] as f32 * scale) as i32;
            let dx = r[0] - (dw - r[2]) / 2;
            let dy = r[1] - (dh - r[3]) / 2;

            if glow > 0.05 {
                let pulse = 0.5 + 0.5 * (self.timer * 6.0).sin();
                let edge = lerp(120.0, 230.0, glow) as i32;
                let blue = (130.0 + pulse * 110.0 * glow) as u8;
                eng.draw_rect(dx - 3, dy - 3, dw + 6, dh + 6, 90, 120, blue, 255, false);
                eng.draw_rect(
                    dx,
                    dy,
                    dw,
                    dh,
                    edge as u8,
                    edge as u8,
                    (edge + 45).min(255) as u8,
                    255,
                    false,
                );
            } else {
                eng.draw_rect(dx, dy, dw, dh, 70, 85, 115, 255, false);
            }

            let img_x = dx + 18;
            let img_y = dy + 18;
            let img_w = dw - 36;
            let img_h = 220;
            if let Some((_, tex)) = self.sprites.iter().find(|(n, _)| *n == a.sprite) {
                let sw = a.size_w.min(img_w - 8);
                let sh = a.size_h.min(img_h - 8);
                let sx = img_x + (img_w - sw) / 2;
                let sy = img_y + (img_h - sh) / 2;
                draw::rounded_texture(eng, tex, sx, sy, sw, sh, 12, 12, 12, 16, 255);
            }

            draw::text(eng, a.name, cx, r[1] + 260, 30, 255, 255, 255, 255, true);

            let up = self.up_rects[i];
            let dn = self.down_rects[i];
            let (btn_r, btn_g, btn_b) = if glow > 0.2 {
                (150, 170, 210)
            } else {
                (90, 90, 105)
            };
            eng.draw_rect(up[0], up[1], up[2], up[3], btn_r, btn_g, btn_b, 255, false);
            draw::text(
                eng,
                "\u{25b2}",
                up[0] + up[2] / 2,
                up[1] + up[3] / 2 + 1,
                26,
                255,
                255,
                255,
                255,
                true,
            );

            let lvl = self.ai_levels[i];
            let (vr, vg, vb) = if lvl >= 20 {
                (255, 60, 60)
            } else if lvl == 0 {
                (80, 220, 110)
            } else {
                (255, 255, 255)
            };
            draw::text(
                eng,
                &lvl.to_string(),
                cx,
                r[1] + 360,
                52,
                vr,
                vg,
                vb,
                255,
                true,
            );

            eng.draw_rect(dn[0], dn[1], dn[2], dn[3], btn_r, btn_g, btn_b, 255, false);
            draw::text(
                eng,
                "\u{25bc}",
                dn[0] + dn[2] / 2,
                dn[1] + dn[3] / 2 + 1,
                26,
                255,
                255,
                255,
                255,
                true,
            );
        }

        let pulse = 0.5 + 0.5 * (self.timer * 4.0).sin();
        let (ar, ag, ab) = (200, 200, (140.0 + 70.0 * pulse) as u8);
        eng.draw_rect(
            self.preset_prev[0],
            self.preset_prev[1],
            self.preset_prev[2],
            self.preset_prev[3],
            120,
            120,
            140,
            255,
            false,
        );
        draw::text(
            eng,
            "<<",
            self.preset_prev[0] + self.preset_prev[2] / 2,
            self.preset_prev[1] + self.preset_prev[3] / 2,
            28,
            ar,
            ag,
            ab,
            255,
            true,
        );
        eng.draw_rect(
            self.preset_label[0],
            self.preset_label[1],
            self.preset_label[2],
            self.preset_label[3],
            100,
            100,
            120,
            255,
            false,
        );
        let p_name = self.presets[self.current_preset].name.clone();
        let label_size = if p_name.len() >= 22 {
            20
        } else if p_name.len() >= 16 {
            24
        } else {
            30
        };
        draw::text(
            eng,
            &p_name,
            self.preset_label[0] + self.preset_label[2] / 2,
            self.preset_label[1] + self.preset_label[3] / 2,
            label_size,
            255,
            255,
            120,
            255,
            true,
        );
        eng.draw_rect(
            self.preset_next[0],
            self.preset_next[1],
            self.preset_next[2],
            self.preset_next[3],
            120,
            120,
            140,
            255,
            false,
        );
        draw::text(
            eng,
            ">>",
            self.preset_next[0] + self.preset_next[2] / 2,
            self.preset_next[1] + self.preset_next[3] / 2,
            28,
            ar,
            ag,
            ab,
            255,
            true,
        );

        let rs = self.selected == 5;
        if rs {
            let glow = (100.0 + 100.0 * (0.5 + 0.5 * (self.timer * 7.0).sin())) as u8;
            eng.draw_rect(
                self.ready_rect[0],
                self.ready_rect[1],
                self.ready_rect[2],
                self.ready_rect[3],
                glow,
                glow,
                80,
                255,
                false,
            );
        } else {
            eng.draw_rect(
                self.ready_rect[0],
                self.ready_rect[1],
                self.ready_rect[2],
                self.ready_rect[3],
                120,
                120,
                130,
                255,
                false,
            );
        }

        let ready_label = if self.secret_code_pending {
            localization::text("apply_code")
        } else {
            localization::text("ready")
        };
        let prefix = if rs { ">> " } else { "" };
        draw::text(
            eng,
            &format!("{prefix}{ready_label}"),
            self.ready_rect[0] + self.ready_rect[2] / 2,
            self.ready_rect[1] + self.ready_rect[3] / 2,
            40,
            if rs { 255 } else { 150 },
            if rs { 255 } else { 150 },
            if rs { 255 } else { 160 },
            255,
            true,
        );

        draw::text(
            eng,
            &localization::text("custom_controls_help"),
            config::SCREEN_WIDTH / 2,
            config::SCREEN_HEIGHT - 22,
            14,
            100,
            100,
            110,
            255,
            true,
        );
        draw::scanlines(eng, 0, 0, config::SCREEN_WIDTH, config::SCREEN_HEIGHT, 15);
    }

    fn is_done(&self) -> bool {
        self.done
    }

    fn result(&self) -> &str {
        &self.m_result
    }

    fn state_type(&self) -> StateType {
        StateType::CustomNight
    }

    fn custom_ai_levels(&self) -> Option<Vec<i32>> {
        Some(self.ai_levels.to_vec())
    }
}

fn hit(rect: [i32; 4], mx: i32, my: i32) -> bool {
    mx >= rect[0] && mx <= rect[0] + rect[2] && my >= rect[1] && my <= rect[1] + rect[3]
}
