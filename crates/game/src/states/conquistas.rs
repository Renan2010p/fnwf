//! Achievements screen.
//!
//! Lists the four survival achievements and marks the `unlocked` ones passed to
//! [`ConquistasState::new`]. Any key press or mouse click returns to the menu
//! with result `"menu"`.

#[allow(unused_imports)]
use fnwf_core::prelude::*;

use fnwf_engine::{Engine, Event, EventType};

use fnwf_core::audio;
use fnwf_core::config;
use fnwf_core::draw;
use fnwf_core::localization;
use fnwf_core::state::{GameState, StateType};

use crate::colors;

struct AchData {
    id: &'static str,
    name: String,
    desc: String,
}

/// The achievements ("conquistas") screen.
pub struct ConquistasState {
    unlocked: Vec<String>,
    done: bool,
    m_result: String,
    timer: f32,
    achievements: Vec<AchData>,
}

impl ConquistasState {
    /// Creates the screen, marking the achievement ids in `achievements` as
    /// unlocked.
    pub fn new(achievements: &[String]) -> Self {
        let list = vec![
            AchData {
                id: "survive_n1",
                name: localization::text("night_1_ach_title"),
                desc: localization::text("night_1_ach_desc"),
            },
            AchData {
                id: "survive_n5",
                name: localization::text("night_5_ach_title"),
                desc: localization::text("night_5_ach_desc"),
            },
            AchData {
                id: "survive_n6",
                name: localization::text("night_6_ach_title"),
                desc: localization::text("night_6_ach_desc"),
            },
            AchData {
                id: "survive_n7",
                name: localization::text("night_7_ach_title"),
                desc: localization::text("night_7_ach_desc"),
            },
        ];
        Self {
            unlocked: achievements.to_vec(),
            done: false,
            m_result: String::new(),
            timer: 0.0,
            achievements: list,
        }
    }
}

impl GameState for ConquistasState {
    fn handle_event(&mut self, eng: &mut dyn Engine, ev: &Event) {
        if ev.kind == EventType::KeyDown && [27, 13, 32].contains(&ev.key) {
            self.done = true;
            self.m_result = "menu".to_string();
            audio::play(eng, "select", 0, -1);
        }
        if ev.kind == EventType::MouseButtonDown {
            self.done = true;
            self.m_result = "menu".to_string();
            audio::play(eng, "select", 0, -1);
        }
    }

    fn update(&mut self, _eng: &mut dyn Engine, dt: f32) {
        self.timer += dt;
    }

    fn draw(&mut self, eng: &mut dyn Engine) {
        eng.clear(10, 10, 15, 255);
        draw::static_noise(eng, 0, 0, config::SCREEN_WIDTH, config::SCREEN_HEIGHT, 0.01);
        draw::text(
            eng,
            &localization::text("ach_title_screen"),
            80,
            60,
            40,
            colors::TITLE_COLOR.r,
            colors::TITLE_COLOR.g,
            colors::TITLE_COLOR.b,
            255,
            false,
        );
        eng.draw_rect(
            80,
            110,
            600,
            2,
            colors::STAR_COLOR.r,
            colors::STAR_COLOR.g,
            colors::STAR_COLOR.b,
            255,
            true,
        );

        for (i, ach) in self.achievements.iter().enumerate() {
            let y = 180 + i as i32 * 100;
            let unlocked = self.unlocked.iter().any(|id| id == ach.id);
            let (cr, cg, cb) = if unlocked {
                (255, 255, 255)
            } else {
                (60, 60, 70)
            };
            let (bg_r, bg_g, bg_b) = if unlocked { (20, 20, 30) } else { (15, 15, 20) };

            eng.draw_rect(
                80,
                y - 10,
                config::SCREEN_WIDTH - 160,
                80,
                bg_r,
                bg_g,
                bg_b,
                255,
                true,
            );
            if unlocked {
                eng.draw_rect(
                    80,
                    y - 10,
                    config::SCREEN_WIDTH - 160,
                    80,
                    40,
                    40,
                    60,
                    255,
                    false,
                );
            }

            let star = if unlocked { "\u{2605}" } else { "\u{2606}" };
            let (sr, sg, sb) = if unlocked {
                (
                    colors::STAR_COLOR.r,
                    colors::STAR_COLOR.g,
                    colors::STAR_COLOR.b,
                )
            } else {
                (40, 40, 50)
            };
            draw::text(eng, star, 100, y + 10, 40, sr, sg, sb, 255, false);
            draw::text(eng, &ach.name, 160, y, 28, cr, cg, cb, 255, false);
            let (dr, dg, db) = if unlocked {
                (120, 120, 130)
            } else {
                (40, 40, 45)
            };
            draw::text(eng, &ach.desc, 160, y + 35, 18, dr, dg, db, 255, false);
        }

        draw::text(
            eng,
            &localization::text("ach_help"),
            config::SCREEN_WIDTH / 2,
            config::SCREEN_HEIGHT - 60,
            16,
            180,
            180,
            180,
            255,
            true,
        );
        draw::scanlines(eng, 0, 0, config::SCREEN_WIDTH, config::SCREEN_HEIGHT, 10);
    }

    fn is_done(&self) -> bool {
        self.done
    }

    fn result(&self) -> &str {
        &self.m_result
    }

    fn state_type(&self) -> StateType {
        StateType::Conquistas
    }
}
