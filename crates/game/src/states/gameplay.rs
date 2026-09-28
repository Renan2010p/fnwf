//! The core gameplay state: office, cameras, doors, power and animatronics.
//!
//! This is one of the two playable modes (alongside [`crate::states::arcade`]).
//! A run lasts six in-game hours; the player survives by closing doors,
//! toggling lights, watching cameras and wearing the mask to manage oxygen.
//! The state finishes with `"win"` when the night is survived, `"jumpscare"`
//! when an animatronic catches the player, or `"menu"` when the player presses
//! Escape. The engine is passed into each [`fnwf_core::state::GameState`] call
//! rather than stored, so this screen owns no engine handle.

#[allow(unused_imports)]
use fnwf_core::prelude::*;

use fnwf_engine::{keys, Engine, Event, EventType};

use fnwf_core::save::{self, GameSnapshot};
use fnwf_core::state::{GameState, StateType};
use fnwf_core::{audio, config, draw, localization, rng};

use crate::systems::animatronics::AnimatronicManager;
use crate::systems::camera::CameraSystem;
use crate::systems::doors::DoorSystem;
use crate::systems::jumpscare::JumpscareSystem;
use crate::systems::office::Office;
use crate::systems::power::PowerSystem;

/// The main night-survival gameplay screen.
pub struct GameplayState {
    night: i32,
    custom_ai_data: Vec<i32>,

    office: Office,
    cameras: CameraSystem,
    doors: DoorSystem,
    power: PowerSystem,
    animatronics: AnimatronicManager,
    jumpscare: JumpscareSystem,

    time_elapsed: f32,
    night_duration: f32,
    current_hour: i32,
    prev_hour: i32,

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

    win_triggered: bool,
    power_out_snd: bool,
    secret_mode: bool,

    save_notify: bool,
    save_notify_timer: f32,
}

impl GameplayState {
    /// Creates the gameplay state for `night`, using optional per-animatronic
    /// `custom_ai` levels (applied, unlike in the original C++).
    pub fn new(eng: &mut dyn Engine, night: i32, custom_ai: Option<&[i32]>) -> Self {
        // NOTE: unlike the original C++, custom-night AI levels are actually
        // applied here (the original accidentally ignored them).
        let ai = custom_ai.filter(|a| a.len() >= 4);
        let animatronics = AnimatronicManager::new(night, ai);
        let secret_mode = animatronics.is_secret_mode();

        Self {
            night,
            custom_ai_data: ai.map(|a| a[..4].to_vec()).unwrap_or_default(),
            office: Office::new(eng),
            cameras: CameraSystem::new(eng),
            doors: DoorSystem::new(),
            power: PowerSystem::new(),
            animatronics,
            jumpscare: JumpscareSystem::new(),
            time_elapsed: 0.0,
            night_duration: config::HOUR_DURATION * 6.0,
            current_hour: 0,
            prev_hour: 0,
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
            win_triggered: false,
            power_out_snd: false,
            secret_mode,
            save_notify: false,
            save_notify_timer: 0.0,
        }
    }

    fn current_snapshot(&self) -> GameSnapshot {
        let mut s = GameSnapshot {
            night: self.night,
            custom_ai: self.custom_ai_data.clone(),
            time_elapsed: self.time_elapsed,
            night_duration: self.night_duration,
            current_hour: self.current_hour,
            power: self.power.power,
            power_usage_level: self.power.usage_level,
            power_is_dead: self.power.is_dead,
            power_dead_timer: self.power.dead_timer,
            door_left_closed: self.doors.left_closed,
            door_right_closed: self.doors.right_closed,
            door_left_light: self.doors.left_light,
            door_right_light: self.doors.right_light,
            door_left_anim: self.doors.left_anim,
            door_right_anim: self.doors.right_anim,
            cam_open: self.cameras.is_open,
            cam_current: self.cameras.current_cam.clone(),
            cam_mask_open: self.cameras.is_mask_open,
            office_vent_light: self.office.vent_light,
            mask_on: self.mask_on,
            oxygen: self.oxygen,
            max_oxygen: self.max_oxygen,
            is_blackout: self.is_blackout,
            blackout_alpha: self.blackout_alpha,
            blackout_timer: self.blackout_timer,
            cedro_pos: self.animatronics.cedro.position.clone(),
            eser_pos: self.animatronics.eser.position.clone(),
            alice_pos: self.animatronics.alice.position.clone(),
            sonk_pos: self.animatronics.sonk.position.clone(),
            sonk_stage: self.animatronics.sonk.stage,
            sonk_charging: self.animatronics.sonk.is_charging,
            sonk_charge_timer: self.animatronics.sonk.charge_timer,
            ..Default::default()
        };
        s.office_pan_x = 0.0;
        s
    }

    fn restore_snapshot(&mut self, s: &GameSnapshot) {
        self.night = s.night;
        self.custom_ai_data = s.custom_ai.clone();
        self.time_elapsed = s.time_elapsed;
        self.night_duration = s.night_duration;
        self.current_hour = s.current_hour;

        self.power.power = s.power;
        self.power.usage_level = s.power_usage_level;
        self.power.is_dead = s.power_is_dead;
        self.power.dead_timer = s.power_dead_timer;

        self.doors.left_closed = s.door_left_closed;
        self.doors.right_closed = s.door_right_closed;
        self.doors.left_light = s.door_left_light;
        self.doors.right_light = s.door_right_light;
        self.doors.left_anim = s.door_left_anim;
        self.doors.right_anim = s.door_right_anim;

        self.cameras.is_open = s.cam_open;
        self.cameras.current_cam = s.cam_current.clone();
        self.cameras.is_mask_open = s.cam_mask_open;

        self.office.vent_light = s.office_vent_light;

        self.mask_on = s.mask_on;
        self.oxygen = s.oxygen;
        self.max_oxygen = s.max_oxygen;

        self.is_blackout = s.is_blackout;
        self.blackout_alpha = s.blackout_alpha;
        self.blackout_timer = s.blackout_timer;

        self.animatronics.cedro.position = s.cedro_pos.clone();
        self.animatronics.eser.position = s.eser_pos.clone();
        self.animatronics.alice.position = s.alice_pos.clone();
        self.animatronics.sonk.position = s.sonk_pos.clone();
        self.animatronics.sonk.stage = s.sonk_stage;
        self.animatronics.sonk.is_charging = s.sonk_charging;
        self.animatronics.sonk.charge_timer = s.sonk_charge_timer;

        self.fading_in = true;
        self.fade_alpha = 255;
        self.win_triggered = false;
        self.power_out_snd = false;
        self.m_result.clear();
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
                if self.time_elapsed >= self.night_duration {
                    self.m_result = "win".to_string();
                    self.fading_out = true;
                } else {
                    self.power_out_phase = 2;
                }
            }
        } else if self.power_out_phase == 2 {
            self.jumpscare.trigger("cedro");
        }
    }

    fn draw_hud(&self, eng: &mut dyn Engine) {
        let suffix = localization::text("am");
        let hour_str = format!("{} {}", self.current_hour, suffix);
        draw::text(
            eng,
            &hour_str,
            config::SCREEN_WIDTH - 80,
            20,
            28,
            255,
            255,
            255,
            255,
            true,
        );

        let night_label = if self.night == 7 {
            localization::text("custom_night")
        } else {
            format!("{} {}", localization::text("night"), self.night)
        };
        draw::text(
            eng,
            &night_label,
            config::SCREEN_WIDTH - 80,
            52,
            18,
            180,
            180,
            180,
            255,
            true,
        );
        draw::text(
            eng,
            "\u{2501}\u{2501}\u{2501}\u{2501}\u{2501}\u{2501}\u{2501}\u{2501}",
            config::SCREEN_WIDTH - 80,
            74,
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

    fn draw_save_notify(&self, eng: &mut dyn Engine) {
        if !self.save_notify {
            return;
        }
        let alpha = (200.0 * self.save_notify_timer.min(1.0)) as u8;
        draw::text(
            eng,
            "\u{24c1}  GAME SAVED!",
            config::SCREEN_WIDTH / 2,
            10,
            18,
            255,
            255,
            255,
            alpha,
            true,
        );
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

impl GameState for GameplayState {
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
            if key == keys::TAB {
                self.cameras.toggle();
                audio::play(eng, "camera", 0, -1);
            }
            if key == keys::ESCAPE {
                audio::stop_all(eng);
                self.m_result = "menu".to_string();
                self.fading_out = true;
                self.fade_alpha = 0;
            }
            // F5 = save game, F8 = load game (the original used the wrong codes).
            if key == keys::F5 {
                let snap = self.current_snapshot();
                if save::save_game(&snap) {
                    self.save_notify = true;
                    self.save_notify_timer = 2.0;
                }
            }
            if key == keys::F8 {
                if let Some(loaded) = save::load_game() {
                    // Restore in place and keep playing the same night.
                    self.restore_snapshot(&loaded);
                }
            }
            if key == keys::P {
                self.time_elapsed = self.night_duration;
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
                self.m_result = "jumpscare".to_string();
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

        self.time_elapsed += dt;
        let mut new_hour = 12 + ((self.time_elapsed / self.night_duration) * 6.0) as i32;
        if new_hour > 12 {
            new_hour %= 12;
        }
        if new_hour == 0 {
            new_hour = 12;
        }
        if new_hour != self.prev_hour {
            self.prev_hour = new_hour;
            audio::play(eng, "clock", 0, -1);
        }
        self.current_hour = new_hour;

        if self.time_elapsed >= self.night_duration {
            if !self.win_triggered {
                self.win_triggered = true;
                audio::stop_all(eng);
                audio::play(eng, "win", 0, -1);
                self.m_result = "win".to_string();
                self.fading_out = true;
                self.fade_alpha = 0;
            }
            return;
        }

        let (mouse_x, mouse_y) = eng.mouse_pos();
        if !self.cameras.is_animating {
            self.cameras.check_mouse_trigger(eng, mouse_x, mouse_y);
        }

        if self.save_notify {
            self.save_notify_timer -= dt;
            if self.save_notify_timer <= 0.0 {
                self.save_notify = false;
            }
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

        if self.secret_mode {
            let pulse = 0.5 + 0.5 * (self.time_elapsed * 2.4).sin();
            let alpha = (36.0 + 24.0 * pulse) as u8;
            eng.draw_rect(
                0,
                0,
                config::SCREEN_WIDTH,
                config::SCREEN_HEIGHT,
                120,
                8,
                8,
                alpha,
                true,
            );
        }

        draw::tone_overlay(eng, 8, 18, 32, if high_fx { 12 } else { 8 });
        if high_fx {
            draw::vignette(eng, 0.20 + self.danger_level * 0.35, 0, 0, 0);
        }

        if high_fx {
            let lp = 0.6 + 0.4 * (self.time_elapsed * 1.2).sin();
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
        self.draw_save_notify(eng);

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
        StateType::Gameplay
    }
}
