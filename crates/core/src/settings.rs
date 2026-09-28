//! User settings, persisted to `config.dat` next to the executable.
//!
//! On bare-metal targets there is no filesystem; the settings live in RAM and
//! `save()` is a no-op.

use alloc::string::{String, ToString};
use core::sync::atomic::{AtomicBool, Ordering};

use spin::Mutex;

/// The persisted settings (mirrors the C++ `GameSettingsData`).
#[derive(Debug, Clone)]
pub struct Settings {
    /// Language code (`"pt"` or `"en"`).
    pub language: String,
    /// Whether the FPS counter is drawn.
    pub show_fps: bool,
    /// Whether VSync is requested.
    pub vsync: bool,
    /// Requested window width.
    pub resolution_w: i32,
    /// Requested window height.
    pub resolution_h: i32,
    /// Whether to start fullscreen.
    pub fullscreen: bool,
    /// Render quality (`"high"` or `"low"`).
    pub quality: String,
    /// Whether Discord RPC is enabled.
    pub discord_rpc: bool,
    /// Master volume, 0–100.
    pub master_volume: i32,
    /// SFX volume, 0–100.
    pub sfx_volume: i32,
    /// Music volume, 0–100.
    pub music_volume: i32,
}

impl Default for Settings {
    fn default() -> Self {
        Self {
            language: "en".to_string(),
            show_fps: false,
            vsync: true,
            resolution_w: 1280,
            resolution_h: 720,
            fullscreen: false,
            quality: "high".to_string(),
            discord_rpc: true,
            master_volume: 80,
            sfx_volume: 100,
            music_volume: 70,
        }
    }
}

#[cfg(feature = "std")]
const CONFIG_FILE: &str = "config.dat";
#[cfg(feature = "std")]
const MAX_STRING_LEN: u64 = 1024;

static SETTINGS: Mutex<Settings> = Mutex::new(Settings {
    language: String::new(),
    show_fps: false,
    vsync: true,
    resolution_w: 1280,
    resolution_h: 720,
    fullscreen: false,
    quality: String::new(),
    discord_rpc: true,
    master_volume: 80,
    sfx_volume: 100,
    music_volume: 70,
});
static LOADED: AtomicBool = AtomicBool::new(false);

fn ensure_loaded() {
    if LOADED.swap(true, Ordering::Relaxed) {
        return;
    }
    #[cfg(feature = "std")]
    if let Some(loaded) = load_from_disk() {
        *SETTINGS.lock() = loaded;
    }
}

/// Returns a snapshot of the current settings (loading them on first use).
pub fn get() -> Settings {
    ensure_loaded();
    SETTINGS.lock().clone()
}

/// Mutates the settings in place.
pub fn with<R>(f: impl FnOnce(&mut Settings) -> R) -> R {
    ensure_loaded();
    f(&mut SETTINGS.lock())
}

/// Persists the current settings to disk (no-op on bare metal).
pub fn save() {
    ensure_loaded();
    #[cfg(feature = "std")]
    {
        let snapshot = SETTINGS.lock().clone();
        let _ = save_to_disk(&snapshot);
    }
}

#[cfg(feature = "std")]
mod disk {
    use super::*;
    use std::io::{Read, Write};

    fn read_string<R: Read>(reader: &mut R) -> Option<String> {
        let mut len_buf = [0u8; 8];
        reader.read_exact(&mut len_buf).ok()?;
        let len = u64::from_le_bytes(len_buf);
        if len > MAX_STRING_LEN {
            return None;
        }
        let mut buf = alloc::vec![0u8; len as usize];
        reader.read_exact(&mut buf).ok()?;
        String::from_utf8(buf).ok()
    }

    fn read_bool<R: Read>(reader: &mut R) -> Option<bool> {
        let mut b = [0u8; 1];
        reader.read_exact(&mut b).ok()?;
        Some(b[0] != 0)
    }

    fn read_i32<R: Read>(reader: &mut R) -> Option<i32> {
        let mut b = [0u8; 4];
        reader.read_exact(&mut b).ok()?;
        Some(i32::from_le_bytes(b))
    }

    #[allow(clippy::field_reassign_with_default)]
    pub fn load() -> Option<Settings> {
        let mut file = std::fs::File::open(CONFIG_FILE).ok()?;
        let mut data = Settings::default();
        data.language = read_string(&mut file)?;
        data.show_fps = read_bool(&mut file)?;
        data.vsync = read_bool(&mut file)?;
        data.resolution_w = read_i32(&mut file)?;
        data.resolution_h = read_i32(&mut file)?;
        data.fullscreen = read_bool(&mut file)?;
        data.quality = read_string(&mut file)?;
        data.discord_rpc = read_bool(&mut file)?;
        if let (Some(master), Some(sfx), Some(music)) = (
            read_i32(&mut file),
            read_i32(&mut file),
            read_i32(&mut file),
        ) {
            data.master_volume = master;
            data.sfx_volume = sfx;
            data.music_volume = music;
        }
        Some(data)
    }

    pub fn save(data: &Settings) -> std::io::Result<()> {
        let mut file = std::fs::File::create(CONFIG_FILE)?;
        fn write_string<W: Write>(writer: &mut W, s: &str) -> std::io::Result<()> {
            writer.write_all(&(s.len() as u64).to_le_bytes())?;
            writer.write_all(s.as_bytes())
        }
        write_string(&mut file, &data.language)?;
        file.write_all(&[data.show_fps as u8])?;
        file.write_all(&[data.vsync as u8])?;
        file.write_all(&data.resolution_w.to_le_bytes())?;
        file.write_all(&data.resolution_h.to_le_bytes())?;
        file.write_all(&[data.fullscreen as u8])?;
        write_string(&mut file, &data.quality)?;
        file.write_all(&[data.discord_rpc as u8])?;
        file.write_all(&data.master_volume.to_le_bytes())?;
        file.write_all(&data.sfx_volume.to_le_bytes())?;
        file.write_all(&data.music_volume.to_le_bytes())?;
        Ok(())
    }
}

#[cfg(feature = "std")]
fn load_from_disk() -> Option<Settings> {
    disk::load()
}

#[cfg(feature = "std")]
fn save_to_disk(data: &Settings) -> std::io::Result<()> {
    disk::save(data)
}
