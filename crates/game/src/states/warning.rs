//! Epilespy / flashing-lights warning screen.
//!
//! Fades in the flashing-lights warning, waits a moment, then fades out and
//! finishes. A key press or click skips straight to the fade-out.

#[allow(unused_imports)]
use fnwf_core::prelude::*;

use fnwf_engine::{Engine, Event, EventType};

use fnwf_core::config;
use fnwf_core::draw;
use fnwf_core::localization;
use fnwf_core::state::{GameState, StateType};

/// The epilepsy / flashing-lights warning screen.
#[derive(Default)]
pub struct WarningState {
    timer: f32,
    alpha: f32,
    phase: i32,
    done: bool,
}

impl WarningState {
    /// Creates the warning screen at the start of its fade-in.
    pub fn new() -> Self {
        Self::default()
    }
}

impl GameState for WarningState {
    fn handle_event(&mut self, _eng: &mut dyn Engine, ev: &Event) {
        if (ev.kind == EventType::KeyDown || ev.kind == EventType::MouseButtonDown)
            && self.phase < 2
        {
            self.phase = 2;
            self.alpha = 255.0;
        }
    }

    fn update(&mut self, _eng: &mut dyn Engine, dt: f32) {
        self.timer += dt;
        match self.phase {
            0 => {
                self.alpha += 600.0 * dt;
                if self.alpha >= 255.0 {
                    self.alpha = 255.0;
                    self.phase = 1;
                    self.timer = 0.0;
                }
            },
            1 => {
                if self.timer >= 1.0 {
                    self.phase = 2;
                }
            },
            _ => {
                self.alpha -= 600.0 * dt;
                if self.alpha <= 0.0 {
                    self.alpha = 0.0;
                    self.done = true;
                }
            },
        }
    }

    fn draw(&mut self, eng: &mut dyn Engine) {
        eng.clear(0, 0, 0, 255);
        let cx = config::SCREEN_WIDTH / 2;
        let cy = config::SCREEN_HEIGHT / 2;
        let a = self.alpha as u8;
        draw::text(
            eng,
            &localization::text("warning_title"),
            cx,
            cy - 80,
            40,
            200,
            50,
            50,
            a,
            true,
        );
        for (i, key) in [
            "warning_line1",
            "warning_line2",
            "warning_line3",
            "warning_line4",
        ]
        .iter()
        .enumerate()
        {
            draw::text(
                eng,
                &localization::text(key),
                cx,
                cy - 20 + i as i32 * 30,
                24,
                255,
                255,
                255,
                a,
                true,
            );
        }
    }

    fn is_done(&self) -> bool {
        self.done
    }

    fn state_type(&self) -> StateType {
        StateType::Warning
    }
}
