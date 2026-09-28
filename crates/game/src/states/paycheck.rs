//! The end-of-week paycheck shown after Night 5.
//!
//! Fades in a payslip and finishes once the player presses a key or clicks.

#[allow(unused_imports)]
use fnwf_core::prelude::*;

use fnwf_engine::{Engine, Event, EventType};

use fnwf_core::audio;
use fnwf_core::config;
use fnwf_core::draw;
use fnwf_core::localization;
use fnwf_core::state::{GameState, StateType};

/// The paycheck screen.
pub struct PaycheckState {
    timer: f32,
    done: bool,
    fade_alpha: i32,
    fading_in: bool,
    fading_out: bool,
    name: String,
    amount: String,
    date: String,
}

impl PaycheckState {
    /// Creates the screen with the default employee name, amount and date.
    pub fn new() -> Self {
        Self {
            timer: 0.0,
            done: false,
            fade_alpha: 255,
            fading_in: true,
            fading_out: false,
            name: "Renan Lucas".to_string(),
            amount: "1.621,00".to_string(),
            date: "15/02/2026".to_string(),
        }
    }
}

impl Default for PaycheckState {
    fn default() -> Self {
        Self::new()
    }
}

impl GameState for PaycheckState {
    fn handle_event(&mut self, eng: &mut dyn Engine, ev: &Event) {
        if (ev.kind == EventType::KeyDown || ev.kind == EventType::MouseButtonDown)
            && !self.fading_in
            && !self.fading_out
        {
            self.fading_out = true;
            audio::play(eng, "select", 0, -1);
        }
    }

    fn update(&mut self, _eng: &mut dyn Engine, dt: f32) {
        self.timer += dt;
        if self.fading_in {
            self.fade_alpha = (self.fade_alpha - (150.0 * dt) as i32).max(0);
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
        eng.clear(20, 20, 25, 255);
        draw::static_noise(eng, 0, 0, config::SCREEN_WIDTH, config::SCREEN_HEIGHT, 0.01);

        let cw = 700;
        let ch = 350;
        let cx = (config::SCREEN_WIDTH - cw) / 2;
        let cy = (config::SCREEN_HEIGHT - ch) / 2;
        eng.draw_rect(cx, cy, cw, ch, 245, 245, 230, 255, true);
        eng.draw_rect(cx, cy, cw, ch, 50, 50, 50, 255, false);

        draw::text(
            eng,
            &localization::text("company_name"),
            cx + 30,
            cy + 30,
            24,
            40,
            40,
            50,
            255,
            false,
        );
        draw::text(
            eng,
            &localization::text("pay_services"),
            cx + 30,
            cy + 65,
            14,
            60,
            60,
            70,
            255,
            false,
        );

        eng.draw_rect(cx + cw - 220, cy + 30, 190, 40, 255, 255, 255, 255, true);
        eng.draw_rect(cx + cw - 220, cy + 30, 190, 40, 0, 0, 0, 255, false);

        let prefix = localization::text("currency_br");
        draw::text(
            eng,
            &format!("{prefix} {}", self.amount),
            cx + cw - 210,
            cy + 38,
            22,
            0,
            0,
            0,
            255,
            false,
        );

        draw::text(
            eng,
            &localization::text("pay_to"),
            cx + 30,
            cy + 130,
            16,
            60,
            60,
            70,
            255,
            false,
        );
        draw::text(
            eng,
            &self.name,
            cx + 50,
            cy + 160,
            38,
            20,
            20,
            30,
            255,
            false,
        );
        eng.line(
            cx + 50,
            cy + 205,
            cx + cw - 50,
            cy + 205,
            100,
            100,
            110,
            255,
        );

        draw::text(
            eng,
            &format!("{} {}", localization::text("pay_date"), self.date),
            cx + 30,
            cy + 250,
            16,
            60,
            60,
            70,
            255,
            false,
        );
        draw::text(
            eng,
            &localization::text("pay_signed"),
            cx + cw - 250,
            cy + 250,
            14,
            60,
            60,
            70,
            255,
            false,
        );
        draw::text(
            eng,
            "Cedro (Big Boss)",
            cx + cw - 250,
            cy + 280,
            22,
            30,
            30,
            40,
            255,
            false,
        );
        eng.line(
            cx + cw - 260,
            cy + 275,
            cx + cw - 30,
            cy + 275,
            0,
            0,
            0,
            255,
        );

        draw::text(
            eng,
            &localization::text("pay_congrats_5"),
            config::SCREEN_WIDTH / 2,
            cy + ch + 50,
            20,
            255,
            255,
            255,
            255,
            true,
        );
        draw::text(
            eng,
            &localization::text("click_continue"),
            config::SCREEN_WIDTH / 2,
            config::SCREEN_HEIGHT - 40,
            14,
            180,
            180,
            180,
            255,
            true,
        );

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
        StateType::Paycheck
    }
}
