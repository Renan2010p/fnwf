//! Newspaper epilogue screen.
//!
//! Fades in a newspaper page recounting the events, then lets any key or click
//! fade it out and finish the state.

#[allow(unused_imports)]
use fnwf_core::prelude::*;

use fnwf_engine::{Engine, Event, EventType};

use fnwf_core::audio;
use fnwf_core::config;
use fnwf_core::draw;
use fnwf_core::localization;
use fnwf_core::state::{GameState, StateType};

/// The newspaper epilogue screen.
pub struct NewspaperState {
    timer: f32,
    done: bool,
    fade_alpha: i32,
    fading_in: bool,
    fading_out: bool,
}

impl NewspaperState {
    /// Creates the screen at the start of its fade-in.
    pub fn new() -> Self {
        Self {
            timer: 0.0,
            done: false,
            fade_alpha: 255,
            fading_in: true,
            fading_out: false,
        }
    }
}

impl Default for NewspaperState {
    fn default() -> Self {
        Self::new()
    }
}

impl GameState for NewspaperState {
    fn handle_event(&mut self, eng: &mut dyn Engine, ev: &Event) {
        if (ev.kind == EventType::KeyDown || ev.kind == EventType::MouseButtonDown)
            && !self.fading_in
            && !self.fading_out
            && self.timer > 3.0
        {
            self.fading_out = true;
            audio::play(eng, "select", 0, -1);
        }
    }

    fn update(&mut self, _eng: &mut dyn Engine, dt: f32) {
        self.timer += dt;
        if self.fading_in {
            self.fade_alpha = (self.fade_alpha - (100.0 * dt) as i32).max(0);
            if self.fade_alpha <= 0 {
                self.fading_in = false;
            }
        }
        if self.fading_out {
            self.fade_alpha = (self.fade_alpha + (150.0 * dt) as i32).min(255);
            if self.fade_alpha >= 255 {
                self.done = true;
            }
        }
    }

    fn draw(&mut self, eng: &mut dyn Engine) {
        eng.clear(10, 10, 15, 255);
        draw::static_noise(
            eng,
            0,
            0,
            config::SCREEN_WIDTH,
            config::SCREEN_HEIGHT,
            0.015,
        );

        let pw = 600;
        let ph = 450;
        let px = (config::SCREEN_WIDTH - pw) / 2;
        let py = (config::SCREEN_HEIGHT - ph) / 2;
        eng.draw_rect(px, py, pw, ph, 160, 155, 140, 255, true);
        eng.draw_rect(px, py, pw, ph, 30, 30, 30, 255, false);

        draw::text(
            eng,
            &localization::text("newspaper_name"),
            px + 30,
            py + 20,
            20,
            40,
            40,
            40,
            255,
            false,
        );
        eng.line(px + 20, py + 45, px + pw - 20, py + 45, 40, 40, 40, 255);
        draw::text(
            eng,
            &localization::text("newspaper_h1"),
            px + pw / 2,
            py + 80,
            34,
            20,
            20,
            20,
            255,
            true,
        );
        draw::text(
            eng,
            &localization::text("newspaper_h2"),
            px + pw / 2,
            py + 120,
            16,
            50,
            50,
            50,
            255,
            true,
        );

        let txt = [
            localization::text("newspaper_p1"),
            localization::text("newspaper_p2"),
            localization::text("newspaper_p3"),
            localization::text("newspaper_p4"),
            String::new(),
            localization::text("newspaper_p5"),
            localization::text("newspaper_p6"),
            String::new(),
            localization::text("newspaper_p7"),
        ];
        for (i, line) in txt.iter().enumerate() {
            draw::text(
                eng,
                line,
                px + pw / 2,
                py + 170 + i as i32 * 22,
                14,
                30,
                30,
                30,
                255,
                true,
            );
        }

        if self.timer > 3.0 && ((self.timer * 2.0) as i32) % 2 == 1 {
            draw::text(
                eng,
                &localization::text("click_continue"),
                config::SCREEN_WIDTH / 2,
                config::SCREEN_HEIGHT - 50,
                16,
                255,
                255,
                255,
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
                0,
                0,
                0,
                self.fade_alpha as u8,
                true,
            );
        }
    }

    fn is_done(&self) -> bool {
        self.done
    }

    fn state_type(&self) -> StateType {
        StateType::Newspaper
    }
}
