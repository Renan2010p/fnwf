//! The jumpscare cutscene.

#[allow(unused_imports)]
use fnwf_core::prelude::*;

use fnwf_engine::Engine;

use fnwf_core::config;
use fnwf_core::draw;
use fnwf_core::rng;

/// Plays the jumpscare animation when an animatronic catches the player.
pub struct JumpscareSystem {
    /// Whether the jumpscare cutscene is currently playing.
    pub active: bool,
    /// Name of the animatronic performing the jumpscare.
    pub animatronic: String,
    /// Seconds elapsed in the cutscene.
    pub timer: f32,
    /// Total length of the cutscene in seconds.
    pub duration: f32,
    /// Whether the cutscene has reached its end.
    pub done: bool,
}

impl Default for JumpscareSystem {
    fn default() -> Self {
        Self::new()
    }
}

impl JumpscareSystem {
    /// Creates an idle jumpscare system.
    pub fn new() -> Self {
        Self {
            active: false,
            animatronic: String::new(),
            timer: 0.0,
            duration: 1.2,
            done: false,
        }
    }

    /// Starts the cutscene for `animatronic`. Does nothing if already active.
    pub fn trigger(&mut self, animatronic: &str) {
        if self.active {
            return;
        }
        self.active = true;
        self.animatronic = animatronic.to_string();
        self.timer = 0.0;
        self.done = false;
    }

    /// Advances the cutscene timer and marks it done once `duration` elapses.
    pub fn update(&mut self, dt: f32) {
        if !self.active {
            return;
        }
        self.timer += dt;
        if self.timer >= self.duration {
            self.done = true;
        }
    }

    /// Draws the shaking animatronic face, static and red flash for the
    /// current cutscene progress.
    pub fn draw(&self, eng: &mut dyn Engine) {
        if !self.active {
            return;
        }
        let prog = (self.timer / self.duration).min(1.0);
        eng.draw_rect(
            0,
            0,
            config::SCREEN_WIDTH,
            config::SCREEN_HEIGHT,
            0,
            0,
            0,
            255,
            true,
        );

        let mut sx = rng::int_range(-20, 20);
        let mut sy = rng::int_range(-20, 20);
        sx = (sx as f32 * (1.0 - prog * 0.5)) as i32;
        sy = (sy as f32 * (1.0 - prog * 0.5)) as i32;

        if prog < 0.1 {
            eng.draw_rect(
                0,
                0,
                config::SCREEN_WIDTH,
                config::SCREEN_HEIGHT,
                255,
                255,
                255,
                (255.0 * (1.0 - prog / 0.1)) as u8,
                true,
            );
        }

        let fw = (config::SCREEN_WIDTH as f32 * 0.6 * (1.0 + prog * 0.3)) as i32;
        let fh = (config::SCREEN_HEIGHT as f32 * 0.7 * (1.0 + prog * 0.3)) as i32;
        draw::animatronic_face(
            eng,
            &self.animatronic,
            config::SCREEN_WIDTH / 2 - fw / 2 + sx,
            config::SCREEN_HEIGHT / 2 - fh / 2 + sy - 30,
            fw,
            fh,
        );
        draw::static_noise(
            eng,
            0,
            0,
            config::SCREEN_WIDTH,
            config::SCREEN_HEIGHT,
            0.1 + prog * 0.2,
        );

        let red_a = (80.0 * (self.timer * 20.0).sin().powi(2)) as u8;
        eng.draw_rect(
            0,
            0,
            config::SCREEN_WIDTH,
            config::SCREEN_HEIGHT,
            200,
            0,
            0,
            red_a,
            true,
        );
    }

    /// Returns the system to its idle state.
    pub fn reset(&mut self) {
        self.active = false;
        self.animatronic.clear();
        self.timer = 0.0;
        self.done = false;
    }

    /// Returns whether the cutscene has finished.
    pub fn is_done(&self) -> bool {
        self.done
    }
}
