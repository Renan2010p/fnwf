//! Short Discord-style transition between nights.
//!
//! Reveals a channel conversation message by message (for nights 2 and 3) as
//! the player presses Enter, Space or the mouse; once all messages are shown it
//! advances to the next night and finishes.

#[allow(unused_imports)]
use fnwf_core::prelude::*;

use fnwf_engine::{Engine, Event, EventType, TextureHandle};

use fnwf_core::state::{GameState, StateType};
use fnwf_core::{audio, config, draw, localization};

struct Message {
    user: String,
    avatar: &'static str,
    color: [u8; 3],
    text: String,
}

/// The between-nights Discord transition screen.
pub struct NightTransitionState {
    night: i32,
    timer: f32,
    done: bool,
    phase: i32,
    fade_alpha: i32,
    cedro_avatar: Option<TextureHandle>,
    renan_avatar: Option<TextureHandle>,
    messages: Vec<Message>,
    visible_messages: usize,
    scroll_y: f32,
    target_scroll: f32,
}

impl NightTransitionState {
    /// Creates the transition for `night`, loading the avatars and building the
    /// message list for that night.
    pub fn new(eng: &mut dyn Engine, night: i32) -> Self {
        draw::load_sprite(eng, "cedro");
        draw::load_sprite(eng, "renan");
        let cedro_avatar = draw::get_sprite("cedro");
        let renan_avatar = draw::get_sprite("renan");

        let server = localization::text("discord_server");
        let raw: Vec<(&str, String)> = if night == 2 {
            vec![
                (&server, localization::text("transition_n2_m0")),
                (&server, localization::text("transition_n2_m1")),
                (&server, localization::text("transition_n2_m2")),
                ("Renan", localization::text("transition_n2_m3")),
                (&server, localization::text("transition_n2_m4")),
                (&server, localization::text("transition_n2_m5")),
            ]
        } else if night == 3 {
            vec![
                (&server, localization::text("transition_n3_m0")),
                (&server, localization::text("transition_n3_m1")),
                (&server, localization::text("transition_n3_m2")),
                ("Renan", localization::text("transition_n3_m3")),
                (&server, localization::text("transition_n3_m4")),
            ]
        } else {
            Vec::new()
        };

        let messages = raw
            .into_iter()
            .map(|(user, text)| {
                let is_renan = user == "Renan";
                Message {
                    user: user.to_string(),
                    avatar: if is_renan { "renan" } else { "cedro" },
                    color: if is_renan {
                        [100, 180, 255]
                    } else {
                        [140, 110, 80]
                    },
                    text,
                }
            })
            .collect();

        Self {
            night,
            timer: 0.0,
            done: false,
            phase: 0,
            fade_alpha: 255,
            cedro_avatar,
            renan_avatar,
            messages,
            visible_messages: 0,
            scroll_y: 0.0,
            target_scroll: 0.0,
        }
    }

    fn update_scroll(&mut self) {
        let mut th = 15;
        let mut prev = String::new();
        for i in 0..self.visible_messages.min(self.messages.len()) {
            let m = &self.messages[i];
            if prev == m.user {
                th += 24;
            } else {
                th += if prev.is_empty() { 0 } else { 8 };
                th += 48;
            }
            prev = m.user.clone();
        }
        let va = config::SCREEN_HEIGHT - 128;
        if th > va {
            self.target_scroll = (th - va) as f32;
        }
    }

    fn advance(&mut self, eng: &mut dyn Engine) {
        if self.phase == 0 {
            self.phase = 1;
            self.fade_alpha = 0;
        } else if self.phase == 1 {
            if self.visible_messages < self.messages.len() {
                self.visible_messages += 1;
                self.update_scroll();
                audio::play(eng, "notification", 0, -1);
            } else {
                self.phase = 2;
                self.fade_alpha = 0;
            }
        }
    }
}

impl GameState for NightTransitionState {
    #[allow(clippy::if_same_then_else)]
    fn handle_event(&mut self, eng: &mut dyn Engine, ev: &Event) {
        if ev.kind == EventType::KeyDown && (ev.key == 13 || ev.key == 32) {
            self.advance(eng);
        } else if ev.kind == EventType::MouseButtonDown {
            self.advance(eng);
        }
    }

    fn update(&mut self, eng: &mut dyn Engine, dt: f32) {
        self.timer += dt;
        if self.phase == 0 {
            self.fade_alpha = (self.fade_alpha - (250.0 * dt) as i32).max(0);
            if self.fade_alpha <= 0 {
                self.phase = 1;
                audio::play(eng, "notification", 0, -1);
            }
        } else if self.phase == 1 && self.visible_messages == 0 {
            self.visible_messages = 1;
            self.update_scroll();
        } else if self.phase == 2 {
            self.fade_alpha = (self.fade_alpha + (250.0 * dt) as i32).min(255);
            if self.fade_alpha >= 255 {
                self.done = true;
            }
        }
        self.scroll_y += (self.target_scroll - self.scroll_y) * 6.0 * dt;
    }

    fn draw(&mut self, eng: &mut dyn Engine) {
        eng.clear(54, 57, 63, 255);
        if self.phase >= 1 {
            self.draw_discord(eng);
        }
        draw::static_noise(
            eng,
            0,
            0,
            config::SCREEN_WIDTH,
            config::SCREEN_HEIGHT,
            0.005,
        );

        if self.phase == 1 && ((self.timer * 2.0) as i32) % 2 == 0 {
            let txt = if self.visible_messages < self.messages.len() {
                localization::text("story_skip")
            } else {
                format!("{} {}", localization::text("story_start_night"), self.night)
            };
            draw::text(
                eng,
                &txt,
                config::SCREEN_WIDTH / 2,
                config::SCREEN_HEIGHT - 20,
                11,
                130,
                130,
                140,
                255,
                true,
            );
        }
        if self.fade_alpha > 0 {
            eng.draw_rect(
                0,
                0,
                config::SCREEN_WIDTH,
                config::SCREEN_HEIGHT,
                54,
                57,
                63,
                self.fade_alpha as u8,
                true,
            );
        }
    }

    fn is_done(&self) -> bool {
        self.done
    }

    fn state_type(&self) -> StateType {
        StateType::NightTransition
    }
}

impl NightTransitionState {
    fn draw_discord(&self, eng: &mut dyn Engine) {
        let sw = 240;
        eng.draw_rect(0, 0, sw, config::SCREEN_HEIGHT, 47, 49, 54, 255, true);
        eng.draw_rect(0, 0, sw, 48, 40, 43, 48, 255, true);
        draw::text(
            eng,
            &localization::text("discord_server"),
            15,
            14,
            14,
            220,
            220,
            220,
            255,
            false,
        );
        eng.line(0, 48, sw, 48, 30, 33, 36, 255);

        let cx = sw;
        let cw = config::SCREEN_WIDTH - sw;
        eng.draw_rect(cx, 0, cw, 48, 54, 57, 63, 255, true);
        draw::text(
            eng,
            &localization::text("chan_security"),
            cx + 18,
            14,
            15,
            220,
            220,
            220,
            255,
            false,
        );

        let mut my = 63 - self.scroll_y as i32;
        draw::text(
            eng,
            &format!("--- {} {} ---", localization::text("night"), self.night),
            cx + cw / 2,
            my,
            12,
            130,
            130,
            140,
            255,
            true,
        );
        my += 30;

        let mut prev_user = String::new();
        for i in 0..self.visible_messages.min(self.messages.len()) {
            let m = &self.messages[i];
            if prev_user == m.user {
                draw::text(eng, &m.text, cx + 75, my, 14, 220, 220, 220, 255, false);
                my += 24;
            } else {
                if !prev_user.is_empty() {
                    my += 8;
                }
                eng.circle(cx + 40, my + 20, 20, 80, 80, 90, 255, true);
                let av = if m.avatar == "cedro" {
                    self.cedro_avatar
                } else {
                    self.renan_avatar
                };
                if let Some(tex) = av {
                    eng.draw_texture(&tex, cx + 20, my, 40, 40, None);
                }
                draw::text(
                    eng,
                    &m.user,
                    cx + 75,
                    my,
                    14,
                    m.color[0],
                    m.color[1],
                    m.color[2],
                    255,
                    false,
                );
                my += 22;
                draw::text(eng, &m.text, cx + 75, my, 14, 220, 220, 220, 255, false);
                my += 24;
            }
            prev_user = m.user.clone();
        }

        eng.draw_rect(
            cx + 16,
            config::SCREEN_HEIGHT - 65,
            cw - 32,
            44,
            64,
            68,
            75,
            255,
            true,
        );
        draw::text(
            eng,
            &localization::text("discord_input"),
            cx + 30,
            config::SCREEN_HEIGHT - 52,
            13,
            100,
            100,
            110,
            255,
            false,
        );
    }
}
