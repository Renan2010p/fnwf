//! Screen constants and asset path helpers (the C++ `GameSettings`).

use alloc::string::String;

/// Screen width in logical pixels.
pub const SCREEN_WIDTH: i32 = 1280;
/// Screen height in logical pixels.
pub const SCREEN_HEIGHT: i32 = 720;
/// Target refresh rate.
pub const FPS: i32 = 60;
/// Directory (relative to the working directory) that holds game assets.
pub const ASSETS_DIR: &str = "assets";

/// Real-time minutes per in-game hour.
pub const HOUR_DURATION: f32 = 60.0;
/// Starting power, in percent.
pub const MAX_POWER: f32 = 100.0;
/// Base power drain per second at usage level 1.
pub const BASE_POWER_DRAIN: f32 = 0.12;
/// Width of the office panorama render target.
pub const OFFICE_WIDTH: i32 = 1280;

/// Office look sensitivity.
pub const PAN_SPEED: f32 = 8.0;
/// Horizontal pan margin in pixels.
pub const PAN_MARGIN: i32 = 200;
/// Default animatronic movement interval, in seconds.
pub const MOVE_INTERVAL: f32 = 5.0;

/// Base directory that contains the `assets/` folder.
///
/// With `std`, this prefers `./assets` (running from the repository root) and
/// falls back to `assets` next to the executable, so a packaged build or a
/// macOS `.app` opens correctly regardless of the working directory. Without
/// `std` it is always the relative `assets` path.
pub fn assets_root() -> String {
    #[cfg(feature = "std")]
    {
        if std::path::Path::new(ASSETS_DIR).exists() {
            return String::from(ASSETS_DIR);
        }
        if let Ok(exe) = std::env::current_exe() {
            if let Some(dir) = exe.parent() {
                let candidate = dir.join(ASSETS_DIR);
                if candidate.exists() {
                    return candidate.to_string_lossy().into_owned();
                }
            }
        }
    }
    String::from(ASSETS_DIR)
}

/// `assets/<sub><ext>` — e.g. `asset_path("font/font", ".ttf")`.
pub fn asset_path(sub: &str, ext: &str) -> String {
    alloc::format!("{}/{sub}{ext}", assets_root())
}

/// `assets/<name><ext>` — e.g. `asset_file("cedro", ".png")`.
pub fn asset_file(name: &str, ext: &str) -> String {
    alloc::format!("{}/{name}{ext}", assets_root())
}

/// `assets/<rel>` — e.g. `asset_full("audio/passos.ogg")`.
pub fn asset_full(rel: &str) -> String {
    alloc::format!("{}/{rel}", assets_root())
}
