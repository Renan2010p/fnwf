//! Game over (newspaper clipping) and win screen.
//!
//! Shows the loss newspaper or the victory message depending on `is_win`. After
//! a short delay any key or click finishes the state with result `"next"` on a
//! win (to advance to the next night) or `"menu"` on a loss.

#[allow(unused_imports)]
use fnwf_core::prelude::*;

use fnwf_engine::{Engine, Event, EventType};

use fnwf_core::config;
use fnwf_core::draw;
use fnwf_core::localization;
use fnwf_core::state::{GameState, StateType};

use crate::colors;

/// The game-over / win screen.
pub struct GameOverState {
    is_win: bool,
    night: i32,
    timer: f32,
    text_alpha: i32,
    show_text: bool,
    m_result: String,
}

impl GameOverState {
    /// Creates the screen for `night`, choosing the win or loss variant from
    /// `is_win`.
    pub fn new(is_win: bool, night: i32) -> Self {
        Self {
            is_win,
            night,
            timer: 0.0,
            text_alpha: 0,
            show_text: false,
            m_result: String::new(),
        }
    }
}

impl GameState for GameOverState {
    fn handle_event(&mut self, _eng: &mut dyn Engine, ev: &Event) {
        if self.timer < 2.0 {
            return;
        }
        if ev.kind == EventType::KeyDown || ev.kind == EventType::MouseButtonDown {
            self.m_result = if self.is_win { "next" } else { "menu" }.to_string();
        }
    }

    fn update(&mut self, _eng: &mut dyn Engine, dt: f32) {
        self.timer += dt;
        if self.timer > 0.5 {
            self.show_text = true;
            self.text_alpha = (self.text_alpha + (200.0 * dt) as i32).min(255);
        }
    }

    fn draw(&mut self, eng: &mut dyn Engine) {
        if self.is_win {
            self.draw_win(eng);
        } else {
            self.draw_game_over(eng);
        }
    }

    fn is_done(&self) -> bool {
        self.timer > 3.0
    }

    fn result(&self) -> &str {
        &self.m_result
    }

    fn state_type(&self) -> StateType {
        StateType::GameOver
    }

    fn game_over_win(&self) -> Option<bool> {
        Some(self.is_win)
    }

    fn game_over_night(&self) -> Option<i32> {
        Some(self.night)
    }
}

impl GameOverState {
    fn draw_game_over(&self, eng: &mut dyn Engine) {
        eng.clear(5, 0, 0, 255);
        draw::static_noise(eng, 0, 0, config::SCREEN_WIDTH, config::SCREEN_HEIGHT, 0.08);
        if !self.show_text {
            return;
        }

        let pw = 500;
        let ph = 350;
        let px = config::SCREEN_WIDTH / 2 - pw / 2;
        let py = config::SCREEN_HEIGHT / 2 - ph / 2 - 30;
        eng.draw_rect(px, py, pw, ph, 180, 170, 150, self.text_alpha as u8, true);

        if self.text_alpha > 100 {
            draw::text(
                eng,
                &localization::text("news_title"),
                config::SCREEN_WIDTH / 2,
                py + 20,
                18,
                40,
                40,
                40,
                255,
                true,
            );
            eng.line(px + 20, py + 45, px + pw - 20, py + 45, 40, 40, 40, 255);
            draw::text(
                eng,
                &localization::text("news_headline_1"),
                config::SCREEN_WIDTH / 2,
                py + 70,
                32,
                30,
                30,
                30,
                255,
                true,
            );
            draw::text(
                eng,
                &localization::text("news_headline_2"),
                config::SCREEN_WIDTH / 2,
                py + 110,
                38,
                150,
                20,
                20,
                255,
                true,
            );

            let nl = format!("{} {}", localization::text("night"), self.night);
            let lines = [
                localization::text("news_body_1"),
                localization::text("news_body_2"),
                localization::text("news_body_3"),
                String::new(),
                format!("{} {}", localization::text("news_body_4"), nl),
                localization::text("news_body_5"),
            ];
            for (i, line) in lines.iter().enumerate() {
                draw::text(
                    eng,
                    line,
                    config::SCREEN_WIDTH / 2,
                    py + 165 + i as i32 * 22,
                    13,
                    50,
                    50,
                    50,
                    255,
                    true,
                );
            }
        }

        draw::scanlines(eng, 0, 0, config::SCREEN_WIDTH, config::SCREEN_HEIGHT, 15);
        if self.timer > 3.0 && ((self.timer * 2.0) as i32) % 2 == 1 {
            draw::text(
                eng,
                &localization::text("press_any_key"),
                config::SCREEN_WIDTH / 2,
                config::SCREEN_HEIGHT - 50,
                16,
                100,
                100,
                100,
                255,
                true,
            );
        }
    }

    fn draw_win(&self, eng: &mut dyn Engine) {
        eng.clear(0, 0, 0, 255);
        if !self.show_text {
            return;
        }

        draw::text(
            eng,
            &localization::text("gameover_win"),
            config::SCREEN_WIDTH / 2,
            config::SCREEN_HEIGHT / 2 - 40,
            80,
            255,
            255,
            255,
            255,
            true,
        );

        if self.timer > 1.5 {
            let a = (((self.timer - 1.5) * 80.0) as i32).min(100) as u8;
            eng.draw_rect(
                0,
                0,
                config::SCREEN_WIDTH,
                config::SCREEN_HEIGHT,
                255,
                255,
                200,
                a,
                true,
            );
        }

        if self.timer > 2.0 {
            let nl = format!("{} {}", localization::text("night"), self.night);
            draw::text(
                eng,
                &format!("{} {}", localization::text("night_complete"), nl),
                config::SCREEN_WIDTH / 2,
                config::SCREEN_HEIGHT / 2 + 50,
                24,
                200,
                200,
                200,
                255,
                true,
            );
            for i in 0..self.night.min(7) {
                draw::star(
                    eng,
                    config::SCREEN_WIDTH / 2 - 75 + i * 25,
                    config::SCREEN_HEIGHT / 2 + 100,
                    10,
                    colors::STAR_COLOR.r,
                    colors::STAR_COLOR.g,
                    colors::STAR_COLOR.b,
                );
            }
        }

        if self.timer > 3.5 && ((self.timer * 2.0) as i32) % 2 == 1 {
            draw::text(
                eng,
                &localization::text("press_any_key_continue"),
                config::SCREEN_WIDTH / 2,
                config::SCREEN_HEIGHT - 50,
                16,
                100,
                100,
                100,
                255,
                true,
            );
        }
    }
}
