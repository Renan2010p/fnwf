//! The 6 AM "night survived" screen.
//!
//! Rolls the clock from 5 to 6 AM with a chime, then finishes when any key or
//! click is pressed (or after ten seconds). The completed night is reported
//! through the state's `six_am_night`.

#[allow(unused_imports)]
use fnwf_core::prelude::*;

use fnwf_engine::{Engine, Event, EventType};

use fnwf_core::audio;
use fnwf_core::config;
use fnwf_core::draw;
use fnwf_core::localization;
use fnwf_core::state::{GameState, StateType};

/// The 6 AM night-complete screen.
pub struct SixAMState {
    night: i32,
    timer: f32,
    done: bool,
    hour: i32,
    show_six: bool,
    played_chime: bool,
}

impl SixAMState {
    /// Creates the screen for the just-completed `night`.
    pub fn new(night: i32) -> Self {
        Self {
            night,
            timer: 0.0,
            done: false,
            hour: 5,
            show_six: false,
            played_chime: false,
        }
    }
}

impl GameState for SixAMState {
    fn handle_event(&mut self, _eng: &mut dyn Engine, ev: &Event) {
        if self.timer > 2.0
            && (ev.kind == EventType::KeyDown || ev.kind == EventType::MouseButtonDown)
        {
            self.done = true;
        }
    }

    fn update(&mut self, eng: &mut dyn Engine, dt: f32) {
        self.timer += dt;
        if !self.show_six && self.timer > 2.0 {
            self.hour = 6;
            self.show_six = true;
        }
        if self.show_six && !self.played_chime {
            audio::play(eng, "noite_concluida", 0, -1);
            self.played_chime = true;
        }
        if self.timer > 10.0 {
            self.done = true;
        }
    }

    fn draw(&mut self, eng: &mut dyn Engine) {
        eng.clear(0, 0, 0, 255);
        let cx = config::SCREEN_WIDTH / 2;
        let cy = config::SCREEN_HEIGHT / 2;
        draw::text(
            eng,
            &self.hour.to_string(),
            cx - 40,
            cy - 20,
            120,
            255,
            255,
            255,
            255,
            true,
        );
        draw::text(eng, "AM", cx + 80, cy - 10, 50, 255, 255, 255, 255, true);

        if self.timer > 8.0 && ((self.timer * 2.0) as i32) % 2 == 1 {
            draw::text(
                eng,
                &localization::text("press_any_key"),
                cx,
                config::SCREEN_HEIGHT - 50,
                16,
                150,
                150,
                150,
                255,
                true,
            );
        }
    }

    fn is_done(&self) -> bool {
        self.done
    }

    fn state_type(&self) -> StateType {
        StateType::SixAM
    }

    fn six_am_night(&self) -> Option<i32> {
        Some(self.night)
    }
}
