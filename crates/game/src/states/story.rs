//! Discord-style story dialogue state.
//!
//! Plays the intro story for the requested night as a channel conversation,
//! revealing one message per Enter/Space/click before fading out and finishing.

#[allow(unused_imports)]
use fnwf_core::prelude::*;

use fnwf_engine::{Engine, Event, EventType, TextureHandle};

use fnwf_core::state::{GameState, StateType};
use fnwf_core::{audio, config, draw, localization};

struct Message {
    typ: &'static str,
    user: String,
    avatar: &'static str,
    color: [u8; 3],
    text: String,
}

/// The Discord-style story screen.
pub struct StoryState {
    night: i32,
    done: bool,
    phase: i32,
    fade_alpha: i32,
    cedro_avatar: Option<TextureHandle>,
    renan_avatar: Option<TextureHandle>,
    messages: Vec<Message>,
    scroll_y: f32,
    target_scroll: f32,
    visible_messages: usize,
    timer: f32,
}

impl StoryState {
    /// Creates the story for `night`, loading the avatars and building its
    /// message script.
    pub fn new(eng: &mut dyn Engine, night: i32) -> Self {
        draw::load_sprite(eng, "cedro");
        draw::load_sprite(eng, "renan");
        draw::load_sprite(eng, "mafia");
        let mut state = Self {
            night,
            done: false,
            phase: 0,
            fade_alpha: 255,
            cedro_avatar: draw::get_sprite("cedro"),
            renan_avatar: draw::get_sprite("renan"),
            messages: Vec::new(),
            scroll_y: 0.0,
            target_scroll: 0.0,
            visible_messages: 0,
            timer: 0.0,
        };
        state.build_messages();
        state
    }

    fn build_messages(&mut self) {
        self.messages.clear();
        let m = |k: &str| -> String { localization::text(&format!("story_n{}_{}", self.night, k)) };
        // A message exists if the localization fallback differs from the key.
        let has = |k: &str| -> bool {
            let key = format!("story_n{}_{}", self.night, k);
            localization::get_text(&key).as_ref() != key
        };
        let cedro = || Message {
            typ: "",
            user: "Cedro".to_string(),
            avatar: "cedro",
            color: [140, 110, 80],
            text: String::new(),
        };
        let renan = || Message {
            typ: "",
            user: "Cientista".to_string(),
            avatar: "renan",
            color: [100, 180, 255],
            text: String::new(),
        };
        let row = |base: Message, key: &str| -> Message {
            Message {
                text: localization::text(&format!("story_n{}_{}", self.night, key)),
                ..base
            }
        };
        let title = |name: String| Message {
            typ: "title",
            user: String::new(),
            avatar: "",
            color: [0, 0, 0],
            text: name,
        };

        if self.night == 1 {
            self.messages.push(row(cedro(), "m0"));
            self.messages.push(row(cedro(), "m1"));
            self.messages.push(row(cedro(), "m2"));
            self.messages.push(row(renan(), "m3"));
            self.messages.push(row(cedro(), "m4"));
            self.messages
                .push(title(format!("{} 1", localization::text("night"))));
            self.messages.push(row(cedro(), "m5"));
            self.messages.push(row(cedro(), "m6"));
            self.messages.push(row(renan(), "m7"));
            self.messages.push(row(cedro(), "m8"));
            self.messages.push(row(cedro(), "m9"));
            self.messages.push(row(cedro(), "m10"));
            self.messages.push(row(renan(), "m11"));
            self.messages.push(row(cedro(), "m12"));
            self.messages.push(row(renan(), "m13"));
        } else if (2..=5).contains(&self.night) {
            self.messages.push(row(cedro(), "m0"));
            self.messages.push(row(renan(), "m1"));
            self.messages.push(row(cedro(), "m2"));
            self.messages.push(title(format!(
                "{} {}",
                localization::text("night"),
                self.night
            )));
            let mut i = 3;
            while has(&format!("m{i}")) {
                let speaker = if i % 2 == 0 { renan() } else { cedro() };
                let key = format!("m{i}");
                self.messages.push(Message {
                    text: m(&key),
                    ..speaker
                });
                i += 1;
            }
        } else if self.night == 6 {
            self.messages.push(row(cedro(), "m0"));
            self.messages.push(row(renan(), "m1"));
            self.messages.push(row(cedro(), "m2"));
            self.messages.push(row(cedro(), "m3"));
            self.messages.push(row(renan(), "m4"));
            self.messages
                .push(title(format!("{} 6", localization::text("night"))));
            self.messages.push(row(cedro(), "m5"));
        } else if self.night == 7 {
            self.messages.push(row(cedro(), "m0"));
            self.messages.push(row(renan(), "m1"));
            self.messages.push(row(cedro(), "m2"));
            self.messages
                .push(title(localization::text("custom_night")));
            self.messages.push(row(cedro(), "m3"));
            self.messages.push(row(renan(), "m4"));
            self.messages.push(row(cedro(), "m5"));
        } else {
            self.messages.push(title(format!(
                "{} {}",
                localization::text("night"),
                self.night
            )));
        }
    }

    fn wrap_text(
        &self,
        eng: &mut dyn Engine,
        text: &str,
        max_width: i32,
        font_size: i32,
    ) -> Vec<String> {
        let words: Vec<&str> = text.split_whitespace().collect();
        let mut lines = Vec::new();
        let mut current = String::new();
        for w in words {
            let test = if current.is_empty() {
                w.to_string()
            } else {
                format!("{current} {w}")
            };
            let tw = eng
                .font_text_size(&test, font_size)
                .map(|(w, _)| w)
                .unwrap_or_else(|| test.len() as i32 * 10);
            if tw <= max_width {
                current = test;
            } else if !current.is_empty() {
                lines.push(current);
                current = w.to_string();
            } else {
                lines.push(w.to_string());
                current.clear();
            }
        }
        if !current.is_empty() {
            lines.push(current);
        }
        lines
    }

    fn update_scroll_target(&mut self, eng: &mut dyn Engine) {
        let cwl = config::SCREEN_WIDTH - 240 - 100;
        let mut th = 15;
        let mut prev = String::new();
        for i in 0..self.visible_messages.min(self.messages.len()) {
            let msg = &self.messages[i];
            if msg.typ == "title" {
                th += 50;
                prev.clear();
            } else {
                let lines = self.wrap_text(eng, &msg.text, cwl, 14);
                if prev == msg.user {
                    th += 24 * lines.len() as i32;
                } else {
                    th += (if prev.is_empty() { 0 } else { 8 }) + 22 + 24 * lines.len() as i32;
                }
                prev = msg.user.clone();
            }
        }
        let va = config::SCREEN_HEIGHT - 48 - 80;
        if th > va {
            self.target_scroll = (th - va) as f32;
        }
    }
}

impl GameState for StoryState {
    fn handle_event(&mut self, eng: &mut dyn Engine, ev: &Event) {
        if ev.kind == EventType::KeyDown || ev.kind == EventType::MouseButtonDown {
            if ev.kind == EventType::KeyDown && ev.key != 13 && ev.key != 32 {
                return;
            }
            if self.phase == 0 {
                self.phase = 1;
                self.fade_alpha = 0;
            } else if self.phase == 1 {
                if self.visible_messages < self.messages.len() {
                    self.visible_messages += 1;
                    self.update_scroll_target(eng);
                    audio::play(eng, "notification", 0, -1);
                } else {
                    self.phase = 2;
                    self.fade_alpha = 0;
                }
            }
        }
    }

    fn update(&mut self, eng: &mut dyn Engine, dt: f32) {
        self.timer += dt;
        if self.phase == 0 {
            self.fade_alpha = (self.fade_alpha - (250.0 * dt) as i32).max(0);
            if self.fade_alpha <= 0 {
                self.phase = 1;
            }
        } else if self.phase == 1 && self.visible_messages == 0 {
            self.visible_messages = 1;
            self.update_scroll_target(eng);
        } else if self.phase == 2 {
            self.fade_alpha = (self.fade_alpha + (200.0 * dt) as i32).min(255);
            if self.fade_alpha >= 255 {
                self.done = true;
            }
        }
        self.scroll_y += (self.target_scroll - self.scroll_y) * 6.0 * dt;
    }

    fn draw(&mut self, eng: &mut dyn Engine) {
        eng.clear(54, 57, 63, 255);
        if self.phase >= 1 {
            self.draw_discord_ui(eng);
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
                localization::text("story_start_night")
            };
            draw::text(
                eng,
                &txt,
                config::SCREEN_WIDTH / 2,
                config::SCREEN_HEIGHT - 20,
                12,
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
        StateType::Story
    }
}

impl StoryState {
    fn draw_discord_ui(&mut self, eng: &mut dyn Engine) {
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

        let chans = [
            localization::text("chan_general"),
            localization::text("chan_announcements"),
            localization::text("chan_security"),
            localization::text("chan_cameras"),
        ];
        for (idx, ch) in chans.iter().enumerate() {
            let y = 65 + idx as i32 * 32;
            let (r, g, b) = if idx == 2 {
                (220, 220, 220)
            } else {
                (130, 130, 140)
            };
            if idx == 2 {
                eng.draw_rect(8, y - 4, sw - 16, 28, 60, 63, 69, 255, true);
            }
            draw::text(eng, ch, 18, y, 13, r, g, b, 255, false);
        }

        let cx = sw;
        let cw = config::SCREEN_WIDTH - sw;
        eng.draw_rect(cx, 0, cw, 48, 54, 57, 63, 255, true);
        draw::text(
            eng,
            &localization::text("discord_channel"),
            cx + 18,
            14,
            15,
            220,
            220,
            220,
            255,
            false,
        );
        eng.line(cx, 48, config::SCREEN_WIDTH, 48, 40, 43, 48, 255);

        let mut my = 63 - self.scroll_y as i32;
        let mut prev_user = String::new();
        for i in 0..self.visible_messages.min(self.messages.len()) {
            let msg = &self.messages[i];
            if msg.typ == "title" {
                eng.line(
                    cx + 20,
                    my + 10,
                    config::SCREEN_WIDTH - 20,
                    my + 10,
                    72,
                    75,
                    81,
                    255,
                );
                draw::text(
                    eng,
                    &msg.text,
                    cx + cw / 2,
                    my + 10,
                    12,
                    130,
                    130,
                    140,
                    255,
                    true,
                );
                my += 50;
                prev_user.clear();
            } else {
                let lines = self.wrap_text(eng, &msg.text, cw - 100, 14);
                if prev_user == msg.user {
                    for line in &lines {
                        draw::text(eng, line, cx + 75, my, 14, 220, 220, 220, 255, false);
                        my += 24;
                    }
                } else {
                    if !prev_user.is_empty() {
                        my += 8;
                    }
                    let av_size = 40;
                    eng.circle(
                        cx + 20 + av_size / 2,
                        my + av_size / 2,
                        av_size / 2,
                        80,
                        80,
                        90,
                        255,
                        true,
                    );
                    let av = if msg.avatar == "cedro" {
                        self.cedro_avatar
                    } else {
                        self.renan_avatar
                    };
                    if let Some(tex) = av {
                        eng.draw_texture(&tex, cx + 20, my, av_size, av_size, None);
                    }
                    draw::text(
                        eng,
                        &msg.user,
                        cx + 75,
                        my,
                        14,
                        msg.color[0],
                        msg.color[1],
                        msg.color[2],
                        255,
                        false,
                    );
                    my += 22;
                    for line in &lines {
                        draw::text(eng, line, cx + 75, my, 14, 220, 220, 220, 255, false);
                        my += 24;
                    }
                }
                prev_user = msg.user.clone();
            }
        }

        let iy = config::SCREEN_HEIGHT - 65;
        eng.draw_rect(cx + 16, iy, cw - 32, 44, 64, 68, 75, 255, true);
        draw::text(
            eng,
            &localization::text("discord_input"),
            cx + 30,
            iy + 13,
            13,
            100,
            100,
            110,
            255,
            false,
        );
    }
}
