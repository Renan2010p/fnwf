//! Power drain and its HUD gauge.

#[allow(unused_imports)]
use fnwf_core::prelude::*;

use fnwf_engine::Engine;

use fnwf_core::config;
use fnwf_core::draw;
use fnwf_core::localization;

use crate::colors;

/// Tracks remaining power and the current usage level.
pub struct PowerSystem {
    /// Remaining power as a percentage from 0 to 100.
    pub power: f32,
    /// Current usage level from 1 to 5, which scales the drain rate.
    pub usage_level: i32,
    /// Whether the office has run out of power.
    pub is_dead: bool,
    /// Seconds elapsed since the power ran out.
    pub dead_timer: f32,
}

impl Default for PowerSystem {
    fn default() -> Self {
        Self::new()
    }
}

impl PowerSystem {
    /// Creates a full battery at the base usage level.
    pub fn new() -> Self {
        Self {
            power: config::MAX_POWER,
            usage_level: 1,
            is_dead: false,
            dead_timer: 0.0,
        }
    }

    /// Drains power based on `door_usage` devices plus an extra unit while the
    /// camera `camera_open`. Once power hits zero the system latches `is_dead`.
    pub fn update(&mut self, dt: f32, door_usage: i32, camera_open: bool) {
        if self.is_dead {
            self.dead_timer += dt;
            return;
        }
        self.usage_level = (1 + door_usage + if camera_open { 1 } else { 0 }).min(5);
        const DRAIN_MULS: [f32; 5] = [1.0, 1.55, 2.35, 3.4, 4.8];
        let mul = DRAIN_MULS[(self.usage_level - 1).clamp(0, 4) as usize];
        self.power -= config::BASE_POWER_DRAIN * mul * dt;
        if self.power <= 0.0 {
            self.power = 0.0;
            self.is_dead = true;
            self.dead_timer = 0.0;
        }
    }

    /// Draws the power percentage label and the five-segment usage gauge.
    pub fn draw(&self, eng: &mut dyn Engine) {
        let x = 24;
        let y = config::SCREEN_HEIGHT - 78;
        let pct = self.power.max(0.0) as i32;

        let label = localization::text("power_left").replace("%d", &pct.to_string());
        draw::text(eng, &label, x, y, 18, 255, 255, 255, 255, false);

        let uy = y + 28;
        draw::text(
            eng,
            &localization::text("usage"),
            x,
            uy,
            16,
            200,
            200,
            200,
            255,
            false,
        );
        for i in 0..5 {
            let ux = x + 78 + i * 16;
            let c = if i < self.usage_level {
                colors::MONITOR_GREEN
            } else {
                crate::types::Color::new(40, 40, 45)
            };
            eng.draw_rect(ux, uy + 4, 10, 16, c.r, c.g, c.b, 255, true);
            eng.draw_rect(ux, uy + 4, 10, 16, 75, 75, 80, 255, false);
        }
    }
}
