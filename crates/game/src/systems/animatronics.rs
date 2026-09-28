//! Animatronic AI: movement graphs, door/vent pressure and Sonk's charge.

#[allow(unused_imports)]
use fnwf_core::prelude::*;

use fnwf_engine::Engine;

use fnwf_core::audio;
use fnwf_core::rng;

use crate::data::{self, PathMap};

/// A standard hallway/vent animatronic.
pub struct Animatronic {
    /// Short identifier used in sounds and HUD lookups, e.g. `"cedro"`.
    pub name: &'static str,
    /// AI difficulty from 0 to 20. Level 0 means the animatronic is inactive
    /// and never moves.
    pub ai_level: i32,
    /// Current node name in the path graph (`"1A"`, `"LEFT_DOOR"`, `"OFFICE_VENT"`, …).
    pub position: String,
    /// Graph of nodes this animatronic may traverse.
    pub path_map: PathMap,
    /// Seconds accumulated since the last movement attempt.
    pub move_timer: f32,
    /// Whether this animatronic participates in the night; set from `ai_level > 0`.
    pub active: bool,
    /// Door node the animatronic waits at (`"LEFT_DOOR"`/`"RIGHT_DOOR"`), empty otherwise.
    pub at_door: String,
    /// Whether the animatronic currently waits at `"OFFICE_VENT"`.
    pub at_vent: bool,
    /// Whether the animatronic has slipped in and is about to jumpscare the player.
    pub attacking: bool,
    /// Whether the animatronic is inside the office (reached `"OFFICE_VENT"`).
    pub in_office: bool,
    /// Set for one frame right after the animatronic is forced back out of the office.
    pub just_left_office: bool,
    /// Seconds the player has been staring at (or beside) the animatronic.
    pub stare_timer: f32,
    /// Seconds of staring tolerated before the animatronic attacks or leaves.
    pub max_stare: f32,
    /// Seconds between movement rolls.
    pub move_interval: f32,
}

impl Animatronic {
    /// Creates an animatronic at `start` with the given AI level and path graph.
    pub fn new(name: &'static str, ai_level: i32, start: &str, path_map: PathMap) -> Self {
        Self {
            name,
            ai_level,
            position: start.to_string(),
            path_map,
            move_timer: 0.0,
            active: ai_level > 0,
            at_door: String::new(),
            at_vent: false,
            attacking: false,
            in_office: false,
            just_left_office: false,
            stare_timer: 0.0,
            max_stare: 4.0,
            move_interval: 5.0,
        }
    }

    /// Advances the animatronic by `dt` seconds.
    ///
    /// Movement is roll-based: every [`Animatronic::move_interval`] seconds a
    /// random roll in `1..=20` is compared against [`Animatronic::ai_level`];
    /// when the roll is greater than the AI level the animatronic stays put
    /// (`rng::int_range(1, 20) > ai_level` means "stays"), otherwise it moves
    /// to one of its reachable nodes. Door closures and a raised mask send a
    /// waiting animatronic back along its path.
    pub fn update(
        &mut self,
        eng: &mut dyn Engine,
        dt: f32,
        _camera_looking_at: Option<&str>,
        left_door_closed: bool,
        right_door_closed: bool,
        mask_on: bool,
    ) {
        if !self.active || self.attacking {
            return;
        }
        self.just_left_office = false;
        self.move_timer += dt;

        if !self.at_door.is_empty() || self.at_vent || self.in_office {
            self.stare_timer += dt;
            let target_max = if self.in_office { 3.0 } else { self.max_stare };
            if self.stare_timer >= target_max && (self.position == "OFFICE_VENT" || self.in_office)
            {
                if !mask_on {
                    self.attacking = true;
                } else {
                    let next = data::next_positions(self.path_map, "OFFICE_VENT");
                    self.position = next.first().copied().unwrap_or("1A").to_string();
                    self.at_vent = false;
                    self.in_office = false;
                    self.just_left_office = true;
                    self.stare_timer = 0.0;
                }
            }
        }

        if self.move_timer >= self.move_interval {
            self.move_timer = 0.0;
            self.try_move(eng, left_door_closed, right_door_closed);
        }
    }

    fn try_move(&mut self, eng: &mut dyn Engine, left_door_closed: bool, right_door_closed: bool) {
        let roll = rng::int_range(1, 20);
        if roll > self.ai_level {
            return;
        }

        if self.position == "LEFT_DOOR" {
            if !left_door_closed {
                self.attacking = true;
            } else {
                let next = data::next_positions(self.path_map, "LEFT_DOOR");
                self.position = next.first().copied().unwrap_or("1A").to_string();
                self.at_door.clear();
            }
            return;
        }
        if self.position == "RIGHT_DOOR" {
            if !right_door_closed {
                self.attacking = true;
            } else {
                let next = data::next_positions(self.path_map, "RIGHT_DOOR");
                self.position = next.first().copied().unwrap_or("1A").to_string();
                self.at_door.clear();
            }
            return;
        }
        if self.position == "OFFICE_VENT" {
            return;
        }

        let possible = data::next_positions(self.path_map, &self.position);
        if possible.is_empty() {
            return;
        }
        let next_pos = possible[rng::int_range(0, possible.len() as i32 - 1) as usize];
        let old_pos = self.position.clone();
        self.position = next_pos.to_string();

        if old_pos != next_pos {
            if self.name == "alice" {
                if next_pos == "V" || next_pos == "OFFICE_VENT" {
                    audio::play(eng, "vent", 0, -1);
                } else {
                    audio::play_footstep_random(eng);
                }
            } else {
                audio::play_footstep_random(eng);
            }
        }

        match next_pos {
            "LEFT_DOOR" | "RIGHT_DOOR" => {
                self.at_door = next_pos.to_string();
                self.at_vent = false;
            },
            "V" => {
                self.at_vent = false;
            },
            "OFFICE_VENT" => {
                self.at_vent = true;
                self.in_office = true;
                self.at_door.clear();
                self.stare_timer = 0.0;
            },
            _ => {
                self.at_door.clear();
                self.at_vent = false;
                self.in_office = false;
                self.stare_timer = 0.0;
            },
        }
    }

    /// Returns whether the animatronic is waiting at the left door.
    pub fn is_at_left_door(&self) -> bool {
        self.position == "LEFT_DOOR"
    }

    /// Returns whether the animatronic is waiting at the right door.
    pub fn is_at_right_door(&self) -> bool {
        self.position == "RIGHT_DOOR"
    }
}

/// Sonk's special state machine (staged approach + charge).
pub struct SonkAnimatronic {
    /// Display/identifier name, always `"Sonk"`.
    pub name: &'static str,
    /// AI difficulty from 0 to 20; level 0 leaves Sonk inactive in his cove.
    pub ai_level: i32,
    /// Whether Sonk participates in the night; set from `ai_level > 0`.
    pub active: bool,
    /// Current node name, e.g. `"5"` (cove) or `"LEFT_DOOR"`.
    pub position: String,
    /// Cove stage from 0 (hidden) to 3 (about to charge).
    pub stage: i32,
    /// Seconds accumulated since the last movement roll.
    pub move_timer: f32,
    /// Door node Sonk waits at, empty while he is not at a door.
    pub at_door: String,
    /// Whether Sonk is at the office vent (unused in his current route).
    pub at_vent: bool,
    /// Whether Sonk is inside the office.
    pub in_office: bool,
    /// Whether Sonk has caught the player and is about to jumpscare them.
    pub attacking: bool,
    /// Seconds the player has been staring at Sonk.
    pub stare_timer: f32,
    /// Whether Sonk is mid-charge sprint toward the left door.
    pub is_charging: bool,
    /// Seconds elapsed in the current charge.
    pub charge_timer: f32,
    /// Seconds a charge lasts before Sonk arrives at the left door.
    pub charge_duration: f32,
    /// Seconds between movement rolls.
    pub move_interval: f32,
}

impl SonkAnimatronic {
    /// Creates Sonk with the given AI level, starting hidden in his cove (`"5"`).
    pub fn new(ai_level: i32) -> Self {
        Self {
            name: "Sonk",
            ai_level,
            active: ai_level > 0,
            position: "5".to_string(),
            stage: 0,
            move_timer: 0.0,
            at_door: String::new(),
            at_vent: false,
            in_office: false,
            attacking: false,
            stare_timer: 0.0,
            is_charging: false,
            charge_timer: 0.0,
            charge_duration: 1.1,
            move_interval: 5.0,
        }
    }

    /// Advances Sonk by `dt` seconds.
    ///
    /// While hidden in the cove (`"5"`) his effective AI level is reduced by 7
    /// when the player is watching camera `"5"`. Once the movement roll
    /// succeeds at stage 3 he charges the left door over
    /// [`SonkAnimatronic::charge_duration`] seconds.
    pub fn update(&mut self, eng: &mut dyn Engine, dt: f32, camera_looking_at: Option<&str>) {
        if !self.active || self.attacking {
            return;
        }

        if self.is_charging {
            self.charge_timer += dt;
            if self.charge_timer >= self.charge_duration {
                self.is_charging = false;
                self.position = "LEFT_DOOR".to_string();
                self.at_door = "LEFT_DOOR".to_string();
                self.stare_timer = 0.0;
                audio::play(eng, "animatronic_door", 0, -1);
            }
            return;
        }

        self.move_timer += dt;

        if self.position == "LEFT_DOOR" {
            self.stare_timer += dt;
            if self.stare_timer >= 1.0 {
                self.position = "5".to_string();
                self.stage = 0;
                self.at_door.clear();
                self.stare_timer = 0.0;
            }
            return;
        }

        if self.move_timer < self.move_interval {
            return;
        }
        self.move_timer = 0.0;

        let mut effective_ai = self.ai_level;
        if camera_looking_at == Some("5") {
            effective_ai = (effective_ai - 7).max(0);
        }

        let roll = rng::int_range(1, 20);
        if roll > effective_ai {
            return;
        }

        if self.stage < 3 {
            self.stage += 1;
        } else {
            self.is_charging = true;
            self.charge_timer = 0.0;
            audio::play(eng, "footstep", 0, -1);
        }
    }

    /// Returns whether Sonk is waiting at the left door.
    pub fn is_at_left_door(&self) -> bool {
        self.position == "LEFT_DOOR"
    }

    /// Sonk never uses the right door, so this is always `false`.
    pub fn is_at_right_door(&self) -> bool {
        false
    }
}

/// Owns all four animatronics and answers the gameplay queries.
pub struct AnimatronicManager {
    /// Cedro, the left-door animatronic.
    pub cedro: Animatronic,
    /// Eser, the right-door animatronic.
    pub eser: Animatronic,
    /// Alice, the vent animatronic.
    pub alice: Animatronic,
    /// Sonk, the staged cove/charge animatronic.
    pub sonk: SonkAnimatronic,
    /// Whether Night 7 "secret mode" (all AI at 40+) is active.
    pub secret_mode: bool,
}

impl AnimatronicManager {
    /// Builds the manager for `night`.
    ///
    /// Uses [`data::night_ai_levels`] unless `custom_ai` supplies at least four
    /// levels. Secret mode is enabled on night 7, or when every custom AI level
    /// is 40 or higher; it shortens move intervals, swaps in
    /// [`data::any_door_path`] and raises the AI ceiling to 40.
    pub fn new(night: i32, custom_ai: Option<&[i32]>) -> Self {
        let levels = match custom_ai {
            Some(ai) if ai.len() >= 4 => [ai[0], ai[1], ai[2], ai[3]],
            _ => data::night_ai_levels(night),
        };

        let mut is_secret = night == 7;
        if is_secret {
            if let Some(ai) = custom_ai.filter(|a| a.len() >= 4) {
                for v in &ai[..4] {
                    if *v < 40 {
                        is_secret = false;
                        break;
                    }
                }
            }
        }
        let secret_mode = is_secret;

        let move_int = if secret_mode {
            1.6
        } else {
            fnwf_core::config::MOVE_INTERVAL
        };

        let cp = if secret_mode {
            data::any_door_path()
        } else {
            data::cedro_path()
        };
        let ep = if secret_mode {
            data::any_door_path()
        } else {
            data::eser_path()
        };

        let mut cedro = Animatronic::new("cedro", levels[0], "1A", cp);
        let mut eser = Animatronic::new("eser", levels[1], "1A", ep);
        let mut alice = Animatronic::new("alice", levels[2], "1A", data::alice_path());

        cedro.move_interval = move_int;
        eser.move_interval = move_int;
        alice.move_interval = move_int;
        if secret_mode {
            cedro.max_stare = 2.3;
            eser.max_stare = 2.3;
            alice.max_stare = 2.3;
        }

        let mut sonk_ai = levels[3];
        if custom_ai.is_none() && night >= 3 && sonk_ai <= 0 {
            sonk_ai = 5;
        }
        let mut sonk = SonkAnimatronic::new(sonk_ai);
        sonk.move_interval = if secret_mode {
            1.25
        } else {
            fnwf_core::config::MOVE_INTERVAL
        };
        if secret_mode {
            sonk.charge_duration = 0.65;
        }

        Self {
            cedro,
            eser,
            alice,
            sonk,
            secret_mode,
        }
    }

    /// Updates all four animatronics for one frame, forwarding `camera_looking_at`,
    /// the door states and `mask_on` to each of them.
    pub fn update(
        &mut self,
        eng: &mut dyn Engine,
        dt: f32,
        camera_looking_at: Option<&str>,
        left_door_closed: bool,
        right_door_closed: bool,
        mask_on: bool,
    ) {
        self.cedro.update(
            eng,
            dt,
            camera_looking_at,
            left_door_closed,
            right_door_closed,
            mask_on,
        );
        self.eser.update(
            eng,
            dt,
            camera_looking_at,
            left_door_closed,
            right_door_closed,
            mask_on,
        );
        self.alice.update(
            eng,
            dt,
            camera_looking_at,
            left_door_closed,
            right_door_closed,
            mask_on,
        );
        self.sonk.update(eng, dt, camera_looking_at);
    }

    /// Returns each animatronic's `(name, position)` pair for the camera views.
    pub fn get_positions(&self) -> Vec<(&'static str, String)> {
        vec![
            ("cedro", self.cedro.position.clone()),
            ("eser", self.eser.position.clone()),
            ("alice", self.alice.position.clone()),
            ("sonk", self.sonk.position.clone()),
        ]
    }

    /// Returns the name of the first animatronic currently attacking, if any.
    pub fn get_attacker(&self) -> Option<&'static str> {
        if self.cedro.attacking {
            return Some("cedro");
        }
        if self.eser.attacking {
            return Some("eser");
        }
        if self.alice.attacking {
            return Some("alice");
        }
        if self.sonk.attacking {
            return Some("Sonk");
        }
        None
    }

    /// Returns the name of an animatronic waiting at the left door, if any.
    pub fn get_at_left_door(&self) -> Option<&'static str> {
        if self.cedro.is_at_left_door() && !self.cedro.attacking {
            return Some("cedro");
        }
        if self.eser.is_at_left_door() && !self.eser.attacking {
            return Some("eser");
        }
        if self.alice.is_at_left_door() && !self.alice.attacking {
            return Some("alice");
        }
        if self.sonk.is_at_left_door() && !self.sonk.attacking {
            return Some("Sonk");
        }
        None
    }

    /// Returns the name of an animatronic waiting at the right door, if any.
    pub fn get_at_right_door(&self) -> Option<&'static str> {
        if self.cedro.is_at_right_door() && !self.cedro.attacking {
            return Some("cedro");
        }
        if self.eser.is_at_right_door() && !self.eser.attacking {
            return Some("eser");
        }
        if self.alice.is_at_right_door() && !self.alice.attacking {
            return Some("alice");
        }
        if self.sonk.is_at_right_door() && !self.sonk.attacking {
            return Some("Sonk");
        }
        None
    }

    /// Returns the name of an animatronic at the office vent, if any.
    pub fn get_at_vent(&self) -> Option<&'static str> {
        if self.cedro.at_vent && !self.cedro.attacking {
            return Some("cedro");
        }
        if self.eser.at_vent && !self.eser.attacking {
            return Some("eser");
        }
        if self.alice.at_vent && !self.alice.attacking {
            return Some("alice");
        }
        if self.sonk.at_vent && !self.sonk.attacking {
            return Some("Sonk");
        }
        None
    }

    /// Returns the name of an animatronic inside the office, if any.
    pub fn get_in_office(&self) -> Option<&'static str> {
        if self.cedro.in_office && !self.cedro.attacking {
            return Some("cedro");
        }
        if self.eser.in_office && !self.eser.attacking {
            return Some("eser");
        }
        if self.alice.in_office && !self.alice.attacking {
            return Some("alice");
        }
        if self.sonk.in_office && !self.sonk.attacking {
            return Some("Sonk");
        }
        None
    }

    /// Returns whether Alice was just driven out of the office this frame,
    /// which prompts the office blackout effect.
    pub fn check_alice_just_left(&self) -> bool {
        self.alice.just_left_office
    }

    /// Returns Sonk's current cove stage (the `foxy_stage` camera view value).
    pub fn get_foxy_stage(&self) -> i32 {
        self.sonk.stage
    }

    /// Returns whether secret mode is active.
    pub fn is_secret_mode(&self) -> bool {
        self.secret_mode
    }
}
