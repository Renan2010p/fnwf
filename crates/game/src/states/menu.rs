//! Main menu.
//!
//! Presents New Game / Continue and, once enough nights are completed, the
//! "more" sub-page with Extras, Custom Night, Arcade and Achievements. A
//! selected entry is surfaced through the state result: `"start"`,
//! `"continue"`, `"night6"`, `"options"`, `"extras"`, `"night7"`, `"arcade"`,
//! `"conquistas"`, `"back_menu"` or `"quit"`.

#[allow(unused_imports)]
use fnwf_core::prelude::*;

use fnwf_engine::{Engine, Event, EventType, TextureHandle};

use fnwf_core::audio;
use fnwf_core::config;
use fnwf_core::draw;
use fnwf_core::localization;
use fnwf_core::rng;
use fnwf_core::state::{GameState, StateType};

use fnwf_engine::keys;

struct MenuItem {
    label: String,
    action: &'static str,
}

/// The main menu screen.
pub struct MenuState {
    completed_nights: i32,
    has_seen_story: bool,
    selected: usize,
    done: bool,
    m_result: String,
    menu_page: &'static str,
    options: Vec<MenuItem>,
    timer: f32,
    highlight_y: f32,
    highlight_target_y: f32,
    menu_animatronics: Vec<Option<TextureHandle>>,
    current_anim_idx: usize,
}

fn lerp(a: f32, b: f32, t: f32) -> f32 {
    a + (b - a) * t.clamp(0.0, 1.0)
}

impl MenuState {
    /// Creates the menu, loading its animatronic art and building the entries
    /// available for `completed_nights` and `has_seen_story`.
    pub fn new(eng: &mut dyn Engine, completed_nights: i32, has_seen_story: bool) -> Self {
        for name in ["cedro", "eser", "alice", "Sonk", "mafia"] {
            draw::load_sprite(eng, name);
        }
        let menu_animatronics = vec![
            draw::get_sprite("eser"),
            draw::get_sprite("cedro"),
            draw::get_sprite("alice"),
            draw::get_sprite("Sonk"),
        ];
        let current_anim_idx = rng::int_range(0, 3) as usize;

        let mut state = Self {
            completed_nights,
            has_seen_story,
            selected: 1,
            done: false,
            m_result: String::new(),
            menu_page: "main",
            options: Vec::new(),
            timer: 0.0,
            highlight_y: 300.0,
            highlight_target_y: 300.0,
            menu_animatronics,
            current_anim_idx,
        };
        state.build_options();
        audio::play_menu_ambient(eng);
        state
    }

    fn build_options(&mut self) {
        self.options.clear();
        if self.menu_page == "main" {
            self.options.push(MenuItem {
                label: localization::text("new_game"),
                action: "start",
            });
            if self.has_seen_story || self.completed_nights > 0 {
                let next = (self.completed_nights + 1).min(6);
                self.options.push(MenuItem {
                    label: format!(
                        "{} ({} {})",
                        localization::text("continue"),
                        localization::text("night"),
                        next
                    ),
                    action: "continue",
                });
            }
            if self.completed_nights >= 5 {
                self.options.push(MenuItem {
                    label: format!("{} 6", localization::text("night")),
                    action: "night6",
                });
                self.options.push(MenuItem {
                    label: localization::text("more"),
                    action: "more",
                });
            }
            self.options.push(MenuItem {
                label: localization::text("options"),
                action: "options",
            });
            self.options.push(MenuItem {
                label: localization::text("quit"),
                action: "quit",
            });
        } else {
            if self.completed_nights >= 5 {
                self.options.push(MenuItem {
                    label: localization::text("extras"),
                    action: "extras",
                });
                self.options.push(MenuItem {
                    label: localization::text("custom_night"),
                    action: "night7",
                });
            }
            self.options.push(MenuItem {
                label: localization::text("arcade"),
                action: "arcade",
            });
            self.options.push(MenuItem {
                label: localization::text("achievements"),
                action: "conquistas",
            });
            self.options.push(MenuItem {
                label: localization::text("back"),
                action: "back_menu",
            });
        }
    }

    fn handle_action(&mut self, eng: &mut dyn Engine, action: &str) -> Option<String> {
        audio::play(eng, "select", 0, -1);
        match action {
            "more" => {
                self.menu_page = "more";
                self.selected = 1;
                self.build_options();
                None
            },
            "back_menu" => {
                self.menu_page = "main";
                self.selected = 1;
                self.build_options();
                None
            },
            "options" => Some("options".to_string()),
            other => Some(other.to_string()),
        }
    }
}

impl GameState for MenuState {
    fn handle_event(&mut self, eng: &mut dyn Engine, ev: &Event) {
        if ev.kind == EventType::KeyDown {
            if ev.key == keys::UP || ev.key == keys::W {
                let n = self.options.len();
                self.selected = (self.selected + n - 2) % n + 1;
                audio::play(eng, "blip", 0, -1);
            } else if ev.key == keys::DOWN || ev.key == keys::S {
                let n = self.options.len();
                self.selected = self.selected % n + 1;
                audio::play(eng, "blip", 0, -1);
            } else if ev.key == keys::RETURN || ev.key == keys::SPACE {
                let action = self.options[self.selected - 1].action;
                if let Some(result) = self.handle_action(eng, action) {
                    self.m_result = result;
                    self.done = true;
                }
            }
        }
        if ev.kind == EventType::MouseButtonDown {
            for i in 0..self.options.len() {
                let y = 300 + i as i32 * 62 - 17;
                if ev.y >= y && ev.y <= y + 48 && ev.x >= 54 && ev.x <= 414 {
                    self.selected = i + 1;
                    let action = self.options[i].action;
                    if let Some(result) = self.handle_action(eng, action) {
                        self.m_result = result;
                        self.done = true;
                    }
                }
            }
        }
    }

    fn update(&mut self, _eng: &mut dyn Engine, dt: f32) {
        self.timer += dt;
        self.highlight_target_y = 300.0 + (self.selected as f32 - 1.0) * 62.0 - 17.0;
        self.highlight_y = lerp(self.highlight_y, self.highlight_target_y, 12.0 * dt);
    }

    fn draw(&mut self, eng: &mut dyn Engine) {
        eng.clear(4, 5, 9, 255);
        eng.draw_rect(
            0,
            0,
            config::SCREEN_WIDTH,
            config::SCREEN_HEIGHT,
            4,
            5,
            9,
            255,
            true,
        );
        if !self.menu_animatronics.is_empty() {
            let cur = self.menu_animatronics[self.current_anim_idx % self.menu_animatronics.len()];
            let bounce = 5.0 * (self.timer * 0.8).sin();
            if let Some(tex) = cur {
                draw::rounded_texture(
                    eng,
                    &tex,
                    config::SCREEN_WIDTH - 640,
                    (70.0 + bounce) as i32,
                    560,
                    560,
                    34,
                    4,
                    5,
                    9,
                    255,
                );
            }
        }
        draw::vhs_osd(eng, "FIVE NIGHTS", 60, 64, 220, 240, 220, 46);
        draw::vhs_osd(eng, "WITH FRIENDS", 60, 116, 220, 240, 220, 46);
        let classic_alpha = (120.0 + 100.0 * (self.timer * 3.0).sin()) as u8;
        draw::text_rotated(
            eng,
            "CLASSIC EDITION",
            310,
            155,
            -8.0,
            20,
            255,
            220,
            50,
            classic_alpha,
            false,
        );
        draw::text(eng, "v2.1.0", 62, 176, 15, 140, 170, 200, 220, false);
        eng.draw_rect(
            60,
            204,
            360,
            2,
            100,
            180,
            255,
            (120.0 + 40.0 * (self.timer * 2.0).sin()) as u8,
            true,
        );
        for (i, item) in self.options.iter().enumerate() {
            let y = 300 + i as i32 * 62;
            let is_sel = i + 1 == self.selected;
            if is_sel {
                eng.draw_rect(48, y - 17, 6, 48, 100, 180, 255, 255, true);
            }
            let bri = lerp(140.0, 255.0, if is_sel { 1.0 } else { 0.0 }) as i32 as u8;
            draw::text(
                eng,
                &item.label,
                68,
                y - 5,
                22,
                bri,
                bri,
                (bri as i32 + if is_sel { 20 } else { 0 }).min(255) as u8,
                255,
                false,
            );
        }
        draw::text(
            eng,
            "[ UP / DOWN ] SELECT     [ ENTER ] PLAY     [ ESC ] BACK",
            60,
            config::SCREEN_HEIGHT - 58,
            13,
            110,
            130,
            160,
            200,
            false,
        );
        draw::text(
            eng,
            "Five Nights With Friends",
            60,
            config::SCREEN_HEIGHT - 38,
            11,
            80,
            90,
            110,
            140,
            false,
        );
    }

    fn is_done(&self) -> bool {
        self.done
    }

    fn result(&self) -> &str {
        &self.m_result
    }

    fn state_type(&self) -> StateType {
        StateType::Menu
    }
}
