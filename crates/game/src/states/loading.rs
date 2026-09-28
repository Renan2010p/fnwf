//! Loading screen: preloads queued sprites one per frame with a progress bar.
//!
//! The screen stays up for at least its short minimum duration and until every
//! queued sprite has loaded (or eight seconds pass), then finishes. Use
//! [`LoadingState::set_preload`] before the first update to supply the sprites
//! to load; it also shows a random gameplay tip.

#[allow(unused_imports)]
use fnwf_core::prelude::*;

use fnwf_engine::Engine;

use fnwf_core::config;
use fnwf_core::draw;
use fnwf_core::localization;
use fnwf_core::rng;
use fnwf_core::state::{GameState, StateType};

/// The loading screen.
pub struct LoadingState {
    preload: Vec<String>,
    loaded: usize,
    timer: f32,
    duration: f32,
    tip: String,
    font_alpha: i32,
    loader_angle: f32,
    done: bool,
}

impl LoadingState {
    /// Creates the loading screen with a random tip and no queued sprites.
    pub fn new() -> Self {
        let tip_idx = rng::int_range(1, 12);
        Self {
            preload: Vec::new(),
            loaded: 0,
            timer: 0.0,
            duration: 0.6,
            tip: localization::text(&format!("tip_{tip_idx}")),
            font_alpha: 0,
            loader_angle: 0.0,
            done: false,
        }
    }

    /// Sprites to actually load while the screen is up (one per frame).
    pub fn set_preload(&mut self, names: Vec<String>) {
        self.preload = names;
    }
}

impl Default for LoadingState {
    fn default() -> Self {
        Self::new()
    }
}

impl GameState for LoadingState {
    fn handle_event(&mut self, _eng: &mut dyn Engine, _ev: &fnwf_engine::Event) {}

    fn update(&mut self, eng: &mut dyn Engine, dt: f32) {
        self.timer += dt;
        self.loader_angle += 360.0 * dt;

        if self.timer < 0.4 {
            self.font_alpha = ((self.timer / 0.4) * 255.0) as i32;
        } else {
            self.font_alpha = 255;
        }

        if self.loaded < self.preload.len() {
            let name = self.preload[self.loaded].clone();
            draw::load_sprite(eng, &name);
            self.loaded += 1;
        }

        let all_loaded = self.loaded >= self.preload.len() || self.timer >= 8.0;
        if all_loaded && self.timer >= self.duration {
            self.done = true;
        }
    }

    fn draw(&mut self, eng: &mut dyn Engine) {
        eng.clear(3, 3, 5, 255);
        draw::static_noise(
            eng,
            0,
            0,
            config::SCREEN_WIDTH,
            config::SCREEN_HEIGHT,
            0.012,
        );

        let ox = if rng::probability(0.05) {
            rng::int_range(-4, 4)
        } else {
            0
        };
        draw::text(
            eng,
            &self.tip,
            config::SCREEN_WIDTH / 2 + ox,
            config::SCREEN_HEIGHT / 2,
            18,
            160,
            160,
            170,
            self.font_alpha as u8,
            true,
        );

        let lx = config::SCREEN_WIDTH - 80;
        let ly = config::SCREEN_HEIGHT - 80;
        let radius = 20;
        for i in 0..8 {
            let angle = self.loader_angle.to_radians() + i as f32 * 45.0_f32.to_radians();
            let ex = lx + (angle.cos() * radius as f32) as i32;
            let ey = ly + (angle.sin() * radius as f32) as i32;
            eng.line(lx, ly, ex, ey, 120, 120, 130, 255);
        }
        eng.circle(lx, ly, radius - 6, 0, 0, 0, 255, true);
        eng.circle(lx, ly, radius - 10, 150, 150, 160, 255, false);

        draw::text(
            eng,
            &localization::text("loading"),
            lx,
            ly + 35,
            14,
            100,
            100,
            110,
            255,
            true,
        );

        if !self.preload.is_empty() {
            let p = self.loaded as f32 / self.preload.len() as f32;
            let bw = 420;
            let bh = 10;
            let bx = config::SCREEN_WIDTH / 2 - bw / 2;
            let by = config::SCREEN_HEIGHT - 60;
            eng.draw_rect(bx, by, bw, bh, 30, 30, 36, 220, true);
            eng.draw_rect(
                bx + 2,
                by + 2,
                ((bw - 4) as f32 * p) as i32,
                bh - 4,
                150,
                150,
                160,
                255,
                true,
            );
            eng.draw_rect(bx, by, bw, bh, 90, 90, 100, 255, false);
            if self.loaded < self.preload.len() {
                draw::text(
                    eng,
                    &self.preload[self.loaded],
                    config::SCREEN_WIDTH / 2,
                    by - 16,
                    12,
                    120,
                    120,
                    130,
                    self.font_alpha.min(255) as u8,
                    true,
                );
            }
        }
    }

    fn is_done(&self) -> bool {
        self.done
    }

    fn state_type(&self) -> StateType {
        StateType::Loading
    }
}
