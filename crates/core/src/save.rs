//! Progress and in-game snapshot persistence.
//!
//! Two independent files are used on disk, matching the original:
//! * `save.dat` — completed nights, flags and achievements
//! * `game_snapshot.dat` — the full mid-night state
//!
//! On bare-metal targets there is no filesystem, so every function degrades to
//! a no-op and loading returns defaults.

use alloc::string::{String, ToString};
use alloc::vec::Vec;

/// Snapshot file magic (`"FNWF"`).
pub const SNAPSHOT_MAGIC: u32 = 0x464E_5746;
/// Snapshot file version.
pub const SNAPSHOT_VERSION: u32 = 1;

/// Persistent progress data (C++ `GameData`).
#[derive(Debug, Clone, Default)]
pub struct GameData {
    /// Highest night completed.
    pub completed_nights: i32,
    /// Whether the intro story has been seen.
    pub has_seen_story: bool,
    /// Infinite-power modifier.
    pub infinite_power: bool,
    /// Fast-nights modifier.
    pub fast_nights: bool,
    /// Unlocked achievement ids.
    pub achievements: Vec<String>,
}

/// Full in-game snapshot used for save/load mid-night.
#[derive(Debug, Clone)]
pub struct GameSnapshot {
    /// Night being played.
    pub night: i32,
    /// Custom-night AI levels, if any.
    pub custom_ai: Vec<i32>,
    /// Seconds elapsed in the night.
    pub time_elapsed: f32,
    /// Total night length in seconds.
    pub night_duration: f32,
    /// Current displayed hour.
    pub current_hour: i32,
    /// Remaining power.
    pub power: f32,
    /// Power usage level 1–5.
    pub power_usage_level: i32,
    /// Whether power is out.
    pub power_is_dead: bool,
    /// Time since power ran out.
    pub power_dead_timer: f32,
    /// Left door closed.
    pub door_left_closed: bool,
    /// Right door closed.
    pub door_right_closed: bool,
    /// Left hall light on.
    pub door_left_light: bool,
    /// Right hall light on.
    pub door_right_light: bool,
    /// Left door animation progress 0–1.
    pub door_left_anim: f32,
    /// Right door animation progress 0–1.
    pub door_right_anim: f32,
    /// Monitor open.
    pub cam_open: bool,
    /// Selected camera id.
    pub cam_current: String,
    /// Mask open.
    pub cam_mask_open: bool,
    /// Office pan 0–1.
    pub office_pan_x: f32,
    /// Vent light on.
    pub office_vent_light: bool,
    /// Mask on.
    pub mask_on: bool,
    /// Oxygen remaining.
    pub oxygen: f32,
    /// Oxygen capacity.
    pub max_oxygen: f32,
    /// Blackout active.
    pub is_blackout: bool,
    /// Blackout overlay alpha.
    pub blackout_alpha: f32,
    /// Blackout timer.
    pub blackout_timer: f32,
    /// Cedro position node.
    pub cedro_pos: String,
    /// Eser position node.
    pub eser_pos: String,
    /// Alice position node.
    pub alice_pos: String,
    /// Sonk position node.
    pub sonk_pos: String,
    /// Sonk stage.
    pub sonk_stage: i32,
    /// Sonk charging.
    pub sonk_charging: bool,
    /// Sonk charge timer.
    pub sonk_charge_timer: f32,
}

impl Default for GameSnapshot {
    fn default() -> Self {
        Self {
            night: 1,
            custom_ai: Vec::new(),
            time_elapsed: 0.0,
            night_duration: 0.0,
            current_hour: 12,
            power: 100.0,
            power_usage_level: 1,
            power_is_dead: false,
            power_dead_timer: 0.0,
            door_left_closed: false,
            door_right_closed: false,
            door_left_light: false,
            door_right_light: false,
            door_left_anim: 0.0,
            door_right_anim: 0.0,
            cam_open: false,
            cam_current: "1A".to_string(),
            cam_mask_open: false,
            office_pan_x: 0.0,
            office_vent_light: false,
            mask_on: false,
            oxygen: 100.0,
            max_oxygen: 100.0,
            is_blackout: false,
            blackout_alpha: 0.0,
            blackout_timer: 0.0,
            cedro_pos: "1A".to_string(),
            eser_pos: "1A".to_string(),
            alice_pos: "1A".to_string(),
            sonk_pos: "5".to_string(),
            sonk_stage: 0,
            sonk_charging: false,
            sonk_charge_timer: 0.0,
        }
    }
}

#[cfg(feature = "std")]
mod disk {
    use super::*;
    use std::fs;
    use std::io::Write;
    use std::path::PathBuf;

    const SAVE_FILE: &str = "save.dat";
    const SNAPSHOT_FILE: &str = "game_snapshot.dat";
    const MAX_STRING_LEN: u64 = 1024;
    const MAX_ACHIEVEMENTS: u64 = 256;
    const MAX_POS_LEN: u64 = 64;

    /// Platform-specific save directory. Desktop uses `$HOME/.fnwf`.
    pub fn save_dir() -> PathBuf {
        if let Ok(home) = std::env::var("HOME") {
            PathBuf::from(home).join(".fnwf")
        } else {
            PathBuf::from(".")
        }
    }

    fn ensure_save_dir() {
        let _ = fs::create_dir_all(save_dir());
    }

    fn save_path() -> PathBuf {
        save_dir().join(SAVE_FILE)
    }

    fn snapshot_path() -> PathBuf {
        save_dir().join(SNAPSHOT_FILE)
    }

    pub fn load_data() -> GameData {
        if let Ok(bytes) = fs::read(save_path()) {
            if let Some(data) = decode_progress(&bytes) {
                return data;
            }
        }
        if let Ok(bytes) = fs::read(SAVE_FILE) {
            if let Some(data) = decode_progress(&bytes) {
                return data;
            }
        }
        GameData::default()
    }

    pub fn save_progress(
        completed_nights: i32,
        has_seen_story: bool,
        infinite_power: bool,
        fast_nights: bool,
        achievements: &[String],
    ) {
        ensure_save_dir();
        let Ok(mut file) = fs::File::create(save_path()) else {
            return;
        };
        let _ = file.write_all(&completed_nights.to_le_bytes());
        let _ = file.write_all(&[has_seen_story as u8]);
        let _ = file.write_all(&[infinite_power as u8]);
        let _ = file.write_all(&[fast_nights as u8]);
        let _ = file.write_all(&(achievements.len() as u64).to_le_bytes());
        for s in achievements {
            let _ = file.write_all(&(s.len() as u64).to_le_bytes());
            let _ = file.write_all(s.as_bytes());
        }
    }

    pub fn save_game(snap: &GameSnapshot) -> bool {
        ensure_save_dir();
        let Ok(mut file) = fs::File::create(snapshot_path()) else {
            return false;
        };
        let w = |r: std::io::Result<()>| r.is_ok();
        w(file.write_all(&SNAPSHOT_MAGIC.to_le_bytes()));
        w(file.write_all(&SNAPSHOT_VERSION.to_le_bytes()));
        w(file.write_all(&snap.night.to_le_bytes()));
        w(file.write_all(&(snap.custom_ai.len() as u32).to_le_bytes()));
        for v in &snap.custom_ai {
            w(file.write_all(&v.to_le_bytes()));
        }
        w(file.write_all(&snap.time_elapsed.to_le_bytes()));
        w(file.write_all(&snap.night_duration.to_le_bytes()));
        w(file.write_all(&snap.current_hour.to_le_bytes()));
        w(file.write_all(&snap.power.to_le_bytes()));
        w(file.write_all(&snap.power_usage_level.to_le_bytes()));
        w(file.write_all(&[snap.power_is_dead as u8]));
        w(file.write_all(&snap.power_dead_timer.to_le_bytes()));
        w(file.write_all(&[snap.door_left_closed as u8]));
        w(file.write_all(&[snap.door_right_closed as u8]));
        w(file.write_all(&[snap.door_left_light as u8]));
        w(file.write_all(&[snap.door_right_light as u8]));
        w(file.write_all(&snap.door_left_anim.to_le_bytes()));
        w(file.write_all(&snap.door_right_anim.to_le_bytes()));
        w(file.write_all(&[snap.cam_open as u8]));
        let cam = snap.cam_current.as_bytes();
        w(file.write_all(&(cam.len() as u32).to_le_bytes()));
        w(file.write_all(cam));
        w(file.write_all(&[snap.cam_mask_open as u8]));
        w(file.write_all(&snap.office_pan_x.to_le_bytes()));
        w(file.write_all(&[snap.office_vent_light as u8]));
        w(file.write_all(&[snap.mask_on as u8]));
        w(file.write_all(&snap.oxygen.to_le_bytes()));
        w(file.write_all(&snap.max_oxygen.to_le_bytes()));
        w(file.write_all(&[snap.is_blackout as u8]));
        w(file.write_all(&snap.blackout_alpha.to_le_bytes()));
        w(file.write_all(&snap.blackout_timer.to_le_bytes()));
        for pos in [
            &snap.cedro_pos,
            &snap.eser_pos,
            &snap.alice_pos,
            &snap.sonk_pos,
        ] {
            w(file.write_all(&(pos.len() as u32).to_le_bytes()));
            w(file.write_all(pos.as_bytes()));
        }
        w(file.write_all(&snap.sonk_stage.to_le_bytes()));
        w(file.write_all(&[snap.sonk_charging as u8]));
        w(file.write_all(&snap.sonk_charge_timer.to_le_bytes()));
        file.flush().is_ok()
    }

    pub fn load_game() -> Option<GameSnapshot> {
        let bytes = fs::read(snapshot_path())
            .or_else(|_| fs::read(SNAPSHOT_FILE))
            .ok()?;
        decode_snapshot(&bytes)
    }

    pub fn has_saved_game() -> bool {
        snapshot_path().exists() || std::path::Path::new(SNAPSHOT_FILE).exists()
    }

    pub fn delete_saved_game() {
        let _ = fs::remove_file(snapshot_path());
        let _ = fs::remove_file(SNAPSHOT_FILE);
    }

    struct Cursor<'a> {
        data: &'a [u8],
        pos: usize,
    }

    impl<'a> Cursor<'a> {
        fn new(data: &'a [u8]) -> Self {
            Self { data, pos: 0 }
        }
        fn take(&mut self, n: usize) -> Option<&'a [u8]> {
            if self.pos + n > self.data.len() {
                return None;
            }
            let slice = &self.data[self.pos..self.pos + n];
            self.pos += n;
            Some(slice)
        }
        fn u32(&mut self) -> Option<u32> {
            let b = self.take(4)?;
            Some(u32::from_le_bytes([b[0], b[1], b[2], b[3]]))
        }
        fn i32(&mut self) -> Option<i32> {
            self.u32().map(|v| v as i32)
        }
        fn u64(&mut self) -> Option<u64> {
            let b = self.take(8)?;
            Some(u64::from_le_bytes(b.try_into().ok()?))
        }
        fn f32(&mut self) -> Option<f32> {
            self.u32().map(f32::from_bits)
        }
        fn bool(&mut self) -> Option<bool> {
            Some(self.take(1)?[0] != 0)
        }
        fn string(&mut self, len: u64) -> Option<String> {
            let b = self.take(len as usize)?;
            Some(String::from_utf8_lossy(b).into_owned())
        }
    }

    #[allow(clippy::field_reassign_with_default)]
    fn decode_progress(bytes: &[u8]) -> Option<GameData> {
        let mut cursor = Cursor::new(bytes);
        let mut data = GameData::default();
        data.completed_nights = cursor.i32()?;
        data.has_seen_story = cursor.bool()?;
        data.infinite_power = cursor.bool()?;
        data.fast_nights = cursor.bool()?;
        let count = cursor.u64()?;
        if count > MAX_ACHIEVEMENTS {
            return Some(data);
        }
        for _ in 0..count {
            let len = cursor.u64()?;
            if len > MAX_STRING_LEN {
                break;
            }
            data.achievements.push(cursor.string(len)?);
        }
        Some(data)
    }

    #[allow(clippy::field_reassign_with_default)]
    fn decode_snapshot(bytes: &[u8]) -> Option<GameSnapshot> {
        let mut c = Cursor::new(bytes);
        if c.u32()? != SNAPSHOT_MAGIC || c.u32()? != SNAPSHOT_VERSION {
            return None;
        }
        let mut s = GameSnapshot::default();
        s.night = c.i32()?;
        let ai_count = c.u32()?;
        for _ in 0..ai_count {
            s.custom_ai.push(c.i32()?);
        }
        s.time_elapsed = c.f32()?;
        s.night_duration = c.f32()?;
        s.current_hour = c.i32()?;
        s.power = c.f32()?;
        s.power_usage_level = c.i32()?;
        s.power_is_dead = c.bool()?;
        s.power_dead_timer = c.f32()?;
        s.door_left_closed = c.bool()?;
        s.door_right_closed = c.bool()?;
        s.door_left_light = c.bool()?;
        s.door_right_light = c.bool()?;
        s.door_left_anim = c.f32()?;
        s.door_right_anim = c.f32()?;
        s.cam_open = c.bool()?;
        let cam_len = c.u32()? as u64;
        s.cam_current = c.string(cam_len)?;
        s.cam_mask_open = c.bool()?;
        s.office_pan_x = c.f32()?;
        s.office_vent_light = c.bool()?;
        s.mask_on = c.bool()?;
        s.oxygen = c.f32()?;
        s.max_oxygen = c.f32()?;
        s.is_blackout = c.bool()?;
        s.blackout_alpha = c.f32()?;
        s.blackout_timer = c.f32()?;
        for field in [
            &mut s.cedro_pos,
            &mut s.eser_pos,
            &mut s.alice_pos,
            &mut s.sonk_pos,
        ] {
            let len = c.u32()? as u64;
            if len > MAX_POS_LEN {
                return None;
            }
            *field = c.string(len)?;
        }
        s.sonk_stage = c.i32()?;
        s.sonk_charging = c.bool()?;
        s.sonk_charge_timer = c.f32()?;
        Some(s)
    }
}

/// Loads progress. Returns defaults when unavailable.
pub fn load_data() -> GameData {
    #[cfg(feature = "std")]
    {
        disk::load_data()
    }
    #[cfg(not(feature = "std"))]
    {
        GameData::default()
    }
}

/// Persists progress (no-op on bare metal).
pub fn save_progress(
    completed_nights: i32,
    has_seen_story: bool,
    infinite_power: bool,
    fast_nights: bool,
    achievements: &[String],
) {
    #[cfg(feature = "std")]
    disk::save_progress(
        completed_nights,
        has_seen_story,
        infinite_power,
        fast_nights,
        achievements,
    );
    #[cfg(not(feature = "std"))]
    {
        let _ = (
            completed_nights,
            has_seen_story,
            infinite_power,
            fast_nights,
            achievements,
        );
    }
}

/// Saves a mid-night snapshot. Returns `false` on bare metal.
pub fn save_game(snap: &GameSnapshot) -> bool {
    #[cfg(feature = "std")]
    {
        disk::save_game(snap)
    }
    #[cfg(not(feature = "std"))]
    {
        let _ = snap;
        false
    }
}

/// Loads a mid-night snapshot, if any.
pub fn load_game() -> Option<GameSnapshot> {
    #[cfg(feature = "std")]
    {
        disk::load_game()
    }
    #[cfg(not(feature = "std"))]
    {
        None
    }
}

/// Whether a snapshot exists.
pub fn has_saved_game() -> bool {
    #[cfg(feature = "std")]
    {
        disk::has_saved_game()
    }
    #[cfg(not(feature = "std"))]
    {
        false
    }
}

/// Deletes any saved snapshot (no-op on bare metal).
pub fn delete_saved_game() {
    #[cfg(feature = "std")]
    disk::delete_saved_game();
}
