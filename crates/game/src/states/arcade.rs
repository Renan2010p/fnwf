//! Arcade endless mode, one of the two playable modes (alongside
//! [`crate::states::gameplay`]).
//!
//! Plays like a normal night but without a 6 AM goal: the difficulty level
//! ramps up every 30 seconds, raising the animatronic AI levels, shortening
//! their move intervals and increasing the power drain. It ends with
//! `"arcade_die"` after a jumpscare or `"menu"` when the player quits. The
//! engine is passed into each [`fnwf_core::state::GameState`] call rather than
//! stored, so this screen owns no engine handle.

#[allow(unused_imports)]
use fnwf_core::prelude::*;

use fnwf_engine::{keys, Engine, Event, EventType};

use fnwf_core::state::{GameState, StateType};
use fnwf_core::{audio, config, draw, localization, rng};

use crate::systems::animatronics::AnimatronicManager;
use crate::systems::camera::CameraSystem;
use crate::systems::doors::DoorSystem;
use crate::systems::jumpscare::JumpscareSystem;
use crate::systems::office::Office;
use crate::systems::power::PowerSystem;

/// The arcade endless-mode screen.
pub struct ArcadeState {
    office: Office,
    cameras: CameraSystem,
    doors: DoorSystem,
    power: PowerSystem,
    animatronics: AnimatronicManager,
    jumpscare: JumpscareSystem,

    time_survived: f32,
    ramp_timer: f32,
    difficulty_level: i32,

    fade_alpha: i32,
    fade_speed: i32,
    fading_in: bool,
    fading_out: bool,
    m_result: String,
    ambient_started: bool,

    mask_on: bool,
    oxygen: f32,
    max_oxygen: f32,
    oxygen_depletion_rate: f32,
    oxygen_recovery_rate: f32,

    is_blackout: bool,
    blackout_alpha: f32,
    blackout_timer: f32,

    power_out_phase: i32,
    power_out_timer: f32,
    power_out_delay: f32,
    fx_timer: f32,
    danger_level: f32,

    power_out_snd: bool,
    base_move_interval: f32,
    base_power_drain: f32,
}

impl ArcadeState {
    /// Creates the arcade run with only Cedro and Eser active at level 3 and 2.
    pub fn new(eng: &mut dyn Engine) -> Self {
        let mut animatronics = AnimatronicManager::new(1, None);
        animatronics.cedro.ai_level = 3;
        animatronics.eser.ai_level = 2;
        animatronics.alice.ai_level = 0;
        animatronics.sonk.ai_level = 0;
        animatronics.cedro.active = true;
        animatronics.eser.active = true;
        animatronics.alice.active = false;
        animatronics.sonk.active = false;

        Self {
            office: Office::new(eng),
            cameras: CameraSystem::new(eng),
            doors: DoorSystem::new(),
            power: PowerSystem::new(),
            animatronics,
            jumpscare: JumpscareSystem::new(),
            time_survived: 0.0,
            ramp_timer: 0.0,
            difficulty_level: 0,
            fade_alpha: 255,
            fade_speed: 300,
            fading_in: true,
            fading_out: false,
            m_result: String::new(),
            ambient_started: false,
            mask_on: false,
            oxygen: 100.0,
            max_oxygen: 100.0,
            oxygen_depletion_rate: 5.5,
            oxygen_recovery_rate: 8.0,
            is_blackout: false,
            blackout_alpha: 0.0,
            blackout_timer: 0.0,
            power_out_phase: 0,
            power_out_timer: 0.0,
            power_out_delay: 0.0,
            fx_timer: 0.0,
            danger_level: 0.0,
            power_out_snd: false,
            base_move_interval: 5.0,
            base_power_drain: 0.12,
        }
    }

    fn update_difficulty(&mut self) {
        let new_level = (self.time_survived / 30.0) as i32;
        if new_level <= self.difficulty_level {
            return;
        }
        self.difficulty_level = new_level;

        let cedro_ai = (3 + self.difficulty_level).min(20);
        let eser_ai = (2 + self.difficulty_level).min(20);
        let alice_ai = (self.difficulty_level - 2).clamp(0, 20);
        let sonk_ai = (self.difficulty_level - 3).clamp(0, 20);

        self.animatronics.cedro.ai_level = cedro_ai;
        self.animatronics.eser.ai_level = eser_ai;
        self.animatronics.alice.ai_level = alice_ai;
        self.animatronics.sonk.ai_level = sonk_ai;

        self.animatronics.alice.active = alice_ai > 0;
        self.animatronics.sonk.active = sonk_ai > 0;

        let new_interval = (self.base_move_interval - self.difficulty_level as f32 * 0.2).max(1.5);
        self.animatronics.cedro.move_interval = new_interval;
        self.animatronics.eser.move_interval = new_interval;
        self.animatronics.alice.move_interval = new_interval;
        self.animatronics.sonk.move_interval = new_interval;

        self.base_power_drain = 0.12 + self.difficulty_level as f32 * 0.008;
    }

    fn update_power_out(&mut self, eng: &mut dyn Engine, dt: f32) {
        if !self.power_out_snd {
            audio::stop_ambient(eng);
            audio::play(eng, "power_out", 0, -1);
            self.power_out_snd = true;
        }
        self.power_out_timer += dt;

        if self.power_out_phase == 0 {
            self.doors.left_closed = false;
            self.doors.right_closed = false;
            self.doors.left_light = false;
            self.doors.right_light = false;
            self.office.vent_light = false;
            self.cameras.is_open = false;
            self.mask_on = false;
            if self.power_out_timer > 3.0 {
                self.power_out_phase = 1;
                self.power_out_delay = 0.0;
            }
        } else if self.power_out_phase == 1 {
            self.power_out_delay += dt;
            if self.power_out_delay > 5.0 + rng::float_range(0.0, 10.0) {
                self.power_out_phase = 2;
            }
        } else if self.power_out_phase == 2 {
            self.jumpscare.trigger("cedro");
        }
    }

    fn draw_hud(&self, eng: &mut dyn Engine) {
        let minutes = self.time_survived as i32 / 60;
        let seconds = self.time_survived as i32 % 60;
        draw::text(
            eng,
            &format!("{minutes}:{seconds:02}"),
            config::SCREEN_WIDTH - 80,
            20,
            28,
            255,
            255,
            255,
            255,
            true,
        );
        draw::text(
            eng,
            &localization::text("arcade_time"),
            config::SCREEN_WIDTH - 80,
            52,
            14,
            180,
            180,
            180,
            255,
            true,
        );
        draw::text(
            eng,
            &format!(
                "{} {}",
                localization::text("arcade_level"),
                self.difficulty_level
            ),
            config::SCREEN_WIDTH - 80,
            76,
            16,
            255,
            200,
            80,
            255,
            true,
        );
        draw::text(
            eng,
            "\u{2501}\u{2501}\u{2501}\u{2501}\u{2501}\u{2501}\u{2501}\u{2501}",
            config::SCREEN_WIDTH - 80,
            98,
            10,
            50,
            50,
            55,
            255,
            true,
        );

        self.power.draw(eng);

        if self.mask_on || self.oxygen < self.max_oxygen {
            let bar_w = 200;
            let bar_h = 12;
            let x = 20;
            let y = 100;
            eng.draw_rect(x, y, bar_w, bar_h, 40, 40, 45, 255, true);
            let (cr, cg, cb) = if self.oxygen >= 30.0 {
                (100, 200, 255)
            } else {
                (255, 100, 100)
            };
            eng.draw_rect(
                x,
                y,
                (bar_w as f32 * (self.oxygen / self.max_oxygen)) as i32,
                bar_h,
                cr,
                cg,
                cb,
                255,
                true,
            );
            eng.draw_rect(x, y, bar_w, bar_h, 80, 80, 85, 255, false);
            draw::text(
                eng,
                &format!("{}: {}%", localization::text("oxygen"), self.oxygen as i32),
                x,
                y - 18,
                14,
                255,
                255,
                255,
                255,
                false,
            );
        }
    }

    fn draw_power_out(&self, eng: &mut dyn Engine) {
        eng.clear(0, 0, 0, 255);
        if self.power_out_phase >= 1 && (eng.ticks() / 1000.0 * 2.0) as i32 % 3 != 0 {
            draw::animatronic_face(eng, "cedro", 50, config::SCREEN_HEIGHT / 2 - 120, 200, 250);
            eng.circle(
                120,
                config::SCREEN_HEIGHT / 2 - 20,
                8,
                255,
                255,
                255,
                255,
                true,
            );
            eng.circle(
                180,
                config::SCREEN_HEIGHT / 2 - 20,
                8,
                255,
                255,
                255,
                255,
                true,
            );
            eng.circle(
                120,
                config::SCREEN_HEIGHT / 2 - 20,
                4,
                30,
                30,
                200,
                255,
                true,
            );
            eng.circle(
                180,
                config::SCREEN_HEIGHT / 2 - 20,
                4,
                30,
                30,
                200,
                255,
                true,
            );
            draw::text(
                eng,
                "\u{266a} \u{266b} \u{266a}",
                150,
                config::SCREEN_HEIGHT / 2 + 140,
                20,
                60,
                60,
                100,
                255,
                true,
            );
        }
    }

    fn draw_fade(&self, eng: &mut dyn Engine) {
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
}

impl GameState for ArcadeState {
    fn handle_event(&mut self, eng: &mut dyn Engine, ev: &Event) {
        if self.jumpscare.active || self.power.is_dead || self.fading_in || self.fading_out {
            return;
        }

        if ev.kind == EventType::MouseButtonDown {
            let (mx, my) = (ev.x, ev.y);
            if self.cameras.check_toggle_click(mx, my) {
                audio::play(eng, "camera", 0, -1);
                return;
            }
            if self.cameras.check_mask_toggle_click(eng, mx, my) {
                audio::play(eng, "camera", 0, -1);
                return;
            }
            if self.cameras.is_fully_open() {
                if self.cameras.handle_click(mx, my) {
                    audio::play(eng, "camera", 0, -1);
                }
                return;
            }
            if !self.cameras.is_visible() {
                if let Some(action) = self.doors.handle_click(mx, my) {
                    audio::play(eng, action, 0, -1);
                    if action == "light"
                        && ((self.doors.left_light
                            && self.animatronics.get_at_left_door().is_some())
                            || (self.doors.right_light
                                && self.animatronics.get_at_right_door().is_some()))
                    {
                        audio::play(eng, "animatronic_door", 0, -1);
                    }
                    return;
                }
            }
        }

        if ev.kind == EventType::KeyDown {
            let key = ev.key;
            if !self.cameras.is_visible() {
                match key {
                    keys::Q => {
                        self.doors.left_closed = !self.doors.left_closed;
                        audio::play(eng, "door", 0, -1);
                    },
                    keys::E => {
                        self.doors.right_closed = !self.doors.right_closed;
                        audio::play(eng, "door", 0, -1);
                    },
                    keys::A => {
                        self.doors.left_light = !self.doors.left_light;
                        audio::play(eng, "light", 0, -1);
                        if self.doors.left_light && self.animatronics.get_at_left_door().is_some() {
                            audio::play(eng, "animatronic_door", 0, -1);
                        }
                    },
                    keys::D => {
                        self.doors.right_light = !self.doors.right_light;
                        audio::play(eng, "light", 0, -1);
                        if self.doors.right_light && self.animatronics.get_at_right_door().is_some()
                        {
                            audio::play(eng, "animatronic_door", 0, -1);
                        }
                    },
                    keys::L => {
                        self.office.vent_light = !self.office.vent_light;
                        audio::play(eng, "light", 0, -1);
                        if self.office.vent_light && self.animatronics.get_at_vent().is_some() {
                            audio::play(eng, "animatronic_door", 0, -1);
                        }
                    },
                    _ => {},
                }
            }

            if self.cameras.is_fully_open() {
                let cam = match key {
                    k if k == b'1' as i32 => Some("1A"),
                    k if k == b'2' as i32 => Some("1B"),
                    k if k == b'3' as i32 => Some("1C"),
                    k if k == b'4' as i32 => Some("2A"),
                    k if k == b'5' as i32 => Some("2B"),
                    k if k == b'6' as i32 => Some("3"),
                    k if k == b'7' as i32 => Some("4A"),
                    k if k == b'8' as i32 => Some("4B"),
                    k if k == b'9' as i32 => Some("5"),
                    _ => None,
                };
                if let Some(cam_id) = cam {
                    self.cameras.switch_camera(cam_id);
                    audio::play(eng, "camera", 0, -1);
                }
            }

            if key == keys::SPACE && !self.cameras.is_open {
                self.cameras.toggle_mask(eng);
            }
            if key == keys::ESCAPE {
                audio::stop_all(eng);
                self.m_result = "menu".to_string();
                self.fading_out = true;
                self.fade_alpha = 0;
            }
        }
    }

    fn update(&mut self, eng: &mut dyn Engine, dt: f32) {
        self.fx_timer += dt;

        if self.fading_in {
            self.fade_alpha = (self.fade_alpha - (self.fade_speed as f32 * dt) as i32).max(0);
            if self.fade_alpha <= 0 {
                self.fading_in = false;
                if !self.ambient_started {
                    audio::play_ambient_loop(eng);
                    self.ambient_started = true;
                }
            }
            return;
        }
        if self.fading_out {
            self.fade_alpha = (self.fade_alpha + (self.fade_speed as f32 * dt) as i32).min(255);
            return;
        }
        if self.jumpscare.active {
            self.jumpscare.update(dt);
            if self.jumpscare.is_done() {
                self.m_result = "arcade_die".to_string();
                self.fading_out = true;
                self.fade_alpha = 0;
                audio::stop_all(eng);
            }
            return;
        }
        if self.power.is_dead {
            self.update_power_out(eng, dt);
            return;
        }

        self.time_survived += dt;
        self.ramp_timer += dt;
        self.update_difficulty();

        let (mouse_x, mouse_y) = eng.mouse_pos();
        if !self.cameras.is_animating {
            self.cameras.check_mouse_trigger(eng, mouse_x, mouse_y);
        }

        if !self.cameras.is_visible() {
            self.office.update(mouse_x, dt);
        }
        self.cameras.update(dt);
        self.doors.update(dt);
        self.mask_on = self.cameras.is_mask_open || self.cameras.is_mask_animating;
        self.power
            .update(dt, self.doors.get_power_usage(), self.cameras.is_open);

        let cam_looking = if self.cameras.is_fully_open() {
            Some(self.cameras.current_cam.clone())
        } else {
            None
        };
        self.animatronics.update(
            eng,
            dt,
            cam_looking.as_deref(),
            self.doors.left_closed,
            self.doors.right_closed,
            self.mask_on,
        );

        if self.mask_on {
            self.oxygen = (self.oxygen - self.oxygen_depletion_rate * dt).max(0.0);
            if self.oxygen <= 0.0 {
                self.cameras.force_remove_mask();
                self.mask_on = self.cameras.is_mask_open || self.cameras.is_mask_animating;
            }
        } else {
            self.oxygen = (self.oxygen + self.oxygen_recovery_rate * dt).min(self.max_oxygen);
        }

        if self.animatronics.check_alice_just_left() {
            self.is_blackout = true;
            self.blackout_alpha = 255.0;
            self.blackout_timer = 0.5;
        }

        if self.is_blackout {
            if self.blackout_timer > 0.0 {
                self.blackout_timer -= dt;
            } else {
                self.blackout_alpha = (self.blackout_alpha - 250.0 * dt).max(0.0);
                if self.blackout_alpha <= 0.0 {
                    self.is_blackout = false;
                }
            }
        }

        if let Some(attacker) = self.animatronics.get_attacker() {
            audio::stop_all(eng);
            audio::play(eng, "jumpscare", 0, -1);
            self.jumpscare.trigger(attacker);
        }

        let mut danger: f32 = 0.0;
        if self.animatronics.get_at_left_door().is_some() {
            danger += 0.22;
        }
        if self.animatronics.get_at_right_door().is_some() {
            danger += 0.22;
        }
        if self.animatronics.get_at_vent().is_some() {
            danger += 0.18;
        }
        if self.animatronics.get_in_office().is_some() {
            danger += 0.35;
        }
        if self.power.power <= 25.0 {
            danger += 0.15;
        }
        if self.oxygen <= 35.0 {
            danger += 0.1;
        }
        self.danger_level = danger.clamp(0.0, 1.0);
    }

    fn draw(&mut self, eng: &mut dyn Engine) {
        let high_fx = draw::is_high_quality();

        if self.jumpscare.active {
            self.jumpscare.draw(eng);
            self.draw_fade(eng);
            return;
        }
        if self.power.is_dead {
            self.draw_power_out(eng);
            self.draw_fade(eng);
            return;
        }

        let at_left = self.animatronics.get_at_left_door();
        let at_right = self.animatronics.get_at_right_door();
        let at_vent = self.animatronics.get_at_vent();
        let in_office = self.animatronics.get_in_office();
        self.office.draw(
            eng,
            self.doors.left_anim,
            self.doors.right_anim,
            self.doors.left_light,
            self.doors.right_light,
            at_left,
            at_right,
            at_vent,
            in_office,
        );

        if !self.cameras.is_visible() {
            self.doors.draw_buttons(eng, false);
        }
        let positions = self.animatronics.get_positions();
        self.cameras
            .draw(eng, &positions, self.animatronics.get_foxy_stage());

        if high_fx && !self.cameras.is_visible() {
            let light_pulse = 0.55 + 0.45 * (self.fx_timer * 8.0).sin();
            if self.doors.left_light {
                for i in 1..=5 {
                    let w = 100 + i * 58;
                    let a = ((50 - i * 7) as f32 * light_pulse) as u8;
                    eng.draw_rect(0, 0, w, config::SCREEN_HEIGHT, 205, 210, 235, a, true);
                }
            }
            if self.doors.right_light {
                for i in 1..=5 {
                    let w = 100 + i * 58;
                    let a = ((50 - i * 7) as f32 * light_pulse) as u8;
                    eng.draw_rect(
                        config::SCREEN_WIDTH - w,
                        0,
                        w,
                        config::SCREEN_HEIGHT,
                        205,
                        210,
                        235,
                        a,
                        true,
                    );
                }
            }
            if self.office.vent_light {
                for i in 1..=4 {
                    let h = 70 + i * 30;
                    let a = (38 - i * 6) as u8;
                    eng.draw_rect(0, 0, config::SCREEN_WIDTH, h, 185, 210, 230, a, true);
                }
            }
        }

        draw::tone_overlay(eng, 8, 18, 32, if high_fx { 12 } else { 8 });
        if high_fx {
            draw::vignette(eng, 0.20 + self.danger_level * 0.35, 0, 0, 0);
        }

        if high_fx {
            let lp = 0.6 + 0.4 * (self.time_survived * 1.2).sin();
            let cx = config::SCREEN_WIDTH / 2;
            let cy = (config::SCREEN_HEIGHT as f32 * 0.64) as i32;
            eng.draw_rect(
                cx - 320,
                cy - 150,
                640,
                300,
                220,
                200,
                150,
                (7.0 + 6.0 * lp) as u8,
                true,
            );
            eng.draw_rect(
                cx - 140,
                cy - 78,
                280,
                156,
                245,
                235,
                200,
                (4.0 + 3.0 * lp) as u8,
                true,
            );
        }
        eng.draw_rect(0, 0, 64, config::SCREEN_HEIGHT, 30, 45, 90, 22, true);
        eng.draw_rect(
            config::SCREEN_WIDTH - 64,
            0,
            64,
            config::SCREEN_HEIGHT,
            30,
            45,
            90,
            22,
            true,
        );

        self.draw_hud(eng);

        if !self.is_blackout || self.blackout_alpha < 150.0 {
            let noise = (if high_fx { 0.008 } else { 0.003 })
                + self.danger_level * (if high_fx { 0.02 } else { 0.008 });
            let scan = ((if high_fx { 10.0 } else { 6.0 })
                + self.danger_level * (if high_fx { 16.0 } else { 8.0 }))
                as u8;
            draw::apply_camera_effect(eng, noise, scan);
        }

        let any_pressure =
            at_left.is_some() || at_right.is_some() || at_vent.is_some() || in_office.is_some();
        if any_pressure && !self.is_blackout && rng::probability(0.08) {
            eng.draw_rect(
                0,
                0,
                config::SCREEN_WIDTH,
                config::SCREEN_HEIGHT,
                0,
                0,
                0,
                (50 + rng::int_range(0, 130)) as u8,
                true,
            );
        }

        if self.blackout_alpha > 0.0 {
            eng.draw_rect(
                0,
                0,
                config::SCREEN_WIDTH,
                config::SCREEN_HEIGHT,
                0,
                0,
                0,
                self.blackout_alpha as u8,
                true,
            );
        }

        self.draw_fade(eng);
    }

    fn is_done(&self) -> bool {
        !self.m_result.is_empty() && self.fade_alpha >= 255
    }

    fn result(&self) -> &str {
        &self.m_result
    }

    fn state_type(&self) -> StateType {
        StateType::Arcade
    }
}
