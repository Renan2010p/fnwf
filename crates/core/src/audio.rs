//! Cached playback of sound effects (C++ `SoundManager`).
//!
//! Sounds are decoded once and kept in RAM so the slowest storage never
//! stutters gameplay. All functions need `&mut dyn Engine` because playback is
//! delegated to the backend.
//!
//! Callers refer to sounds by logical name; an internal table maps each name to
//! the OGG file that backs it, and unknown names fall back to `audio/<name>.ogg`.
//!
//! Mixer channels are assigned by convention so loops can be stopped reliably:
//! * `0`  — menu ambient loop
//! * `1`  — office ambient loop
//! * `5`  — mask breathing loop
//! * `-1` — any free channel, used for one-shot effects

use alloc::collections::BTreeMap;
use alloc::format;
use alloc::string::{String, ToString};
use spin::{Lazy, Mutex};

use fnwf_engine::{Engine, SoundHandle};

use crate::config;
use crate::rng;

/// Maps logical sound names to the OGG file that backs them.
const FILENAMES: &[(&str, &str)] = &[
    ("door_open", "portas.ogg"),
    ("door_close", "portas.ogg"),
    ("door", "portas.ogg"),
    ("light", "trocar_camera.ogg"),
    ("footstep", "passos.ogg"),
    ("footsteps_1", "passos.ogg"),
    ("footsteps_2", "passos.ogg"),
    ("footsteps_3", "passos.ogg"),
    ("footsteps_4", "passos.ogg"),
    ("breathing", "usando_a_mascara.ogg"),
    ("mask_on", "colocar_mascara.ogg"),
    ("mask_off", "retirar_mascara.ogg"),
    ("blip", "trocar_camera.ogg"),
    ("select", "trocar_camera.ogg"),
    ("notification", "trocar_camera.ogg"),
    ("camera", "trocar_camera.ogg"),
    ("clock", "trocar_camera.ogg"),
    ("win", "noite_concluida.ogg"),
    ("noite_concluida", "noite_concluida.ogg"),
    ("vent", "ventilacao.ogg"),
    ("window_scare", "animatronic_na_porta.ogg"),
    ("animatronic_door", "animatronic_na_porta.ogg"),
    ("jumpscare", "animatronic_na_porta.ogg"),
    ("stinger", "animatronic_na_porta.ogg"),
    ("power_out", "animatronic_na_porta.ogg"),
];

struct AudioState {
    cache: BTreeMap<String, SoundHandle>,
    menu_channel: i32,
    breathing_channel: i32,
}

impl Default for AudioState {
    fn default() -> Self {
        Self {
            cache: BTreeMap::new(),
            menu_channel: -1,
            breathing_channel: -1,
        }
    }
}

static AUDIO: Lazy<Mutex<AudioState>> = Lazy::new(|| Mutex::new(AudioState::default()));

fn filename_for(name: &str) -> String {
    FILENAMES
        .iter()
        .find(|(n, _)| *n == name)
        .map(|(_, f)| (*f).to_string())
        .unwrap_or_else(|| format!("{name}.ogg"))
}

/// Loads one sound into the cache, returning its handle on success.
fn load_cached(eng: &mut dyn Engine, name: &str) -> Option<SoundHandle> {
    if let Some(handle) = AUDIO.lock().cache.get(name) {
        return Some(*handle);
    }
    let path = config::asset_full(&format!("audio/{}", filename_for(name)));
    let handle = eng.load_sound(&path)?;
    AUDIO.lock().cache.insert(name.to_string(), handle);
    Some(handle)
}

/// Preloads every known sound, skipping those already cached.
pub fn preload_all(eng: &mut dyn Engine) {
    for (name, _) in FILENAMES {
        load_cached(eng, name);
    }
    for extra in ["ambient", "menu_ambient"] {
        if AUDIO.lock().cache.contains_key(extra) {
            continue;
        }
        let path = config::asset_full(&format!("audio/{extra}.ogg"));
        if let Some(handle) = eng.load_sound(&path) {
            AUDIO.lock().cache.insert(extra.to_string(), handle);
        }
    }
}

/// Plays a sound by logical name. `loops`: `0` = once, `-1` = forever.
pub fn play(eng: &mut dyn Engine, name: &str, loops: i32, channel: i32) -> i32 {
    if let Some(handle) = load_cached(eng, name) {
        eng.play_sound(&handle, loops, channel)
    } else {
        channel
    }
}

/// Stops whatever is currently playing on one mixer channel.
pub fn stop_channel(eng: &mut dyn Engine, channel: i32) {
    eng.stop_channel(channel);
}

/// Stops every channel at once (used when leaving a scene).
pub fn stop_all(eng: &mut dyn Engine) {
    eng.stop_all_sounds();
}

/// Starts the looping menu ambience on the reserved channel `0`.
pub fn play_menu_ambient(eng: &mut dyn Engine) {
    AUDIO.lock().menu_channel = 0;
    play(eng, "menu_ambient", -1, 0);
}

/// Stops the menu ambience if it was started on this thread.
pub fn stop_menu_ambient(eng: &mut dyn Engine) {
    let channel = AUDIO.lock().menu_channel;
    if channel != -1 {
        stop_channel(eng, channel);
    }
}

/// Starts the looping office ambience on the reserved channel `1`.
pub fn play_ambient_loop(eng: &mut dyn Engine) {
    play(eng, "ambient", -1, 1);
}

/// Stops the office ambience on channel `1`.
pub fn stop_ambient(eng: &mut dyn Engine) {
    stop_channel(eng, 1);
}

/// Plays a one-shot horror stinger on any free channel.
pub fn play_scary_stinger(eng: &mut dyn Engine) {
    play(eng, "stinger", 0, -1);
}

/// Plays the short blip used when switching cameras.
pub fn play_camera_switch(eng: &mut dyn Engine) {
    play(eng, "blip", 0, -1);
}

/// Plays the door open/close effect.
pub fn play_door(eng: &mut dyn Engine) {
    play(eng, "door", 0, -1);
}

/// Plays the door-light toggle effect.
pub fn play_light(eng: &mut dyn Engine) {
    play(eng, "light", 0, -1);
}

/// Plays the jumpscare scream.
pub fn play_jumpscare(eng: &mut dyn Engine) {
    play(eng, "jumpscare", 0, -1);
}

/// Plays the window-scare effect.
pub fn play_window_scare(eng: &mut dyn Engine) {
    play(eng, "window_scare", 0, -1);
}

/// Plays one of the four footstep variants, picked uniformly at random.
pub fn play_footstep_random(eng: &mut dyn Engine) {
    let idx = rng::int_range(1, 4);
    play(eng, &format!("footsteps_{idx}"), 0, -1);
}

/// Starts (or restarts) the looping mask breathing on dedicated channel `5`.
pub fn play_mask_breathing(eng: &mut dyn Engine) {
    let mut state = AUDIO.lock();
    if state.breathing_channel == -1 {
        state.breathing_channel = 5;
    }
    let channel = state.breathing_channel;
    drop(state);
    play(eng, "breathing", -1, channel);
}

/// Stops the mask breathing loop and frees its channel for reuse.
pub fn stop_mask_breathing(eng: &mut dyn Engine) {
    let mut state = AUDIO.lock();
    if state.breathing_channel != -1 {
        let channel = state.breathing_channel;
        state.breathing_channel = -1;
        drop(state);
        stop_channel(eng, channel);
    }
}

/// Sets the master output volume (backend-defined scale).
pub fn set_master_volume(eng: &mut dyn Engine, vol: i32) {
    eng.set_master_volume(vol);
}

/// Sets the sound-effects volume (backend-defined scale).
pub fn set_sfx_volume(eng: &mut dyn Engine, vol: i32) {
    eng.set_sfx_volume(vol);
}

/// Sets the music volume (backend-defined scale).
pub fn set_music_volume(eng: &mut dyn Engine, vol: i32) {
    eng.set_music_volume(vol);
}
