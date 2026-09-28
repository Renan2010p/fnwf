//! Drawing helpers built on top of the [`Engine`] primitives (C++ `DrawUtils`).
//!
//! Sprite/font/scanline caches are shared process-wide behind a mutex, mirroring
//! the original static caches. Callers only need `&mut dyn Engine`.

use alloc::collections::BTreeMap;
use alloc::format;
use alloc::string::{String, ToString};
use alloc::vec::Vec;
use spin::{Lazy, Mutex};

#[allow(unused_imports)]
use crate::math::FloatExt;

use fnwf_engine::{Engine, TextureHandle};

use crate::config;
use crate::rng;

struct Caches {
    sprites: BTreeMap<String, TextureHandle>,
    fonts: BTreeMap<i32, i32>,
    main_font: i32,
    quality_high: bool,
    scanlines: BTreeMap<String, Vec<i32>>,
}

impl Default for Caches {
    fn default() -> Self {
        Self {
            sprites: BTreeMap::new(),
            fonts: BTreeMap::new(),
            main_font: -1,
            quality_high: true,
            scanlines: BTreeMap::new(),
        }
    }
}

static CACHE: Lazy<Mutex<Caches>> = Lazy::new(|| Mutex::new(Caches::default()));

/// Loads and caches a sprite by name (no-op if already cached).
pub fn load_sprite(eng: &mut dyn Engine, name: &str) {
    {
        let cache = CACHE.lock();
        if cache.sprites.contains_key(name) {
            return;
        }
    }
    let path = config::asset_file(name, ".png");
    if let Some(tex) = eng.load_texture(&path) {
        CACHE.lock().sprites.insert(name.to_string(), tex);
    }
}

/// Returns a cached sprite handle, if loaded.
pub fn get_sprite(name: &str) -> Option<TextureHandle> {
    CACHE.lock().sprites.get(name).copied()
}

/// Loads the main font and seeds the cache.
pub fn set_fonts(eng: &mut dyn Engine) {
    let mut idx = eng.load_font(&config::asset_path("font/font", ".ttf"), 16);
    if idx == -1 {
        idx = 0;
    }
    let mut cache = CACHE.lock();
    cache.main_font = idx;
    cache.fonts.insert(16, idx);
}

/// Resolves (and lazily loads) a font of the given point size.
pub fn get_font_by_size(eng: &mut dyn Engine, size: i32) -> i32 {
    {
        let cache = CACHE.lock();
        if let Some(idx) = cache.fonts.get(&size) {
            return *idx;
        }
    }
    let idx = eng.load_font(&config::asset_path("font/font", ".ttf"), size);
    if idx == -1 {
        return CACHE.lock().main_font;
    }
    CACHE.lock().fonts.insert(size, idx);
    idx
}

/// Sets the render quality to `"high"` (anything else is `"low"`).
pub fn set_render_quality(level: &str) {
    CACHE.lock().quality_high = level == "high";
}

/// Whether high-quality effects are enabled.
pub fn is_high_quality() -> bool {
    CACHE.lock().quality_high
}

/// Draws text with automatic font resolution.
#[allow(clippy::too_many_arguments)]
pub fn text(
    eng: &mut dyn Engine,
    s: &str,
    x: i32,
    y: i32,
    size: i32,
    r: u8,
    g: u8,
    b: u8,
    a: u8,
    center: bool,
) {
    let font = get_font_by_size(eng, size);
    eng.draw_text(s, x, y, size, r, g, b, a, center, font);
}

/// Draws text with an explicit font index.
#[allow(clippy::too_many_arguments)]
pub fn text_at(
    eng: &mut dyn Engine,
    s: &str,
    x: i32,
    y: i32,
    size: i32,
    r: u8,
    g: u8,
    b: u8,
    a: u8,
    center: bool,
    font_idx: i32,
) {
    let font = if font_idx >= 0 {
        font_idx
    } else {
        get_font_by_size(eng, size)
    };
    eng.draw_text(s, x, y, size, r, g, b, a, center, font);
}

/// Draws rotated text.
#[allow(clippy::too_many_arguments)]
pub fn text_rotated(
    eng: &mut dyn Engine,
    s: &str,
    x: i32,
    y: i32,
    angle: f32,
    size: i32,
    r: u8,
    g: u8,
    b: u8,
    a: u8,
    center: bool,
) {
    let font = get_font_by_size(eng, size);
    eng.draw_text_rotated(s, x, y, size, angle, r, g, b, a, center, font);
}

/// Random TV static (a translucent gray rectangle applied with low chance).
pub fn static_noise(eng: &mut dyn Engine, x: i32, y: i32, w: i32, h: i32, intensity: f32) {
    let mut ci = intensity;
    if !is_high_quality() {
        ci *= 0.55;
    }
    if rng::probability(ci) {
        eng.draw_rect(x, y, w, h, 100, 100, 100, 20, true);
    }
}

/// Horizontal CRT scanlines.
pub fn scanlines(eng: &mut dyn Engine, x: i32, y: i32, w: i32, h: i32, alpha: u8) {
    let high = is_high_quality();
    let mut a = alpha;
    let mut step = 4;
    if !high {
        a = (a as f32 * 0.6) as u8;
        step = 6;
    } else if alpha < 20 {
        step = 5;
    }

    let key = format!("{x}_{y}_{h}_{step}");
    let rows = {
        let mut cache = CACHE.lock();
        cache
            .scanlines
            .entry(key)
            .or_insert_with(|| {
                let mut rows = Vec::new();
                let mut py = y;
                while py <= y + h {
                    rows.push(py);
                    py += step;
                }
                rows
            })
            .clone()
    };
    for py in rows {
        eng.draw_rect(x, py, w, 1, 0, 0, 0, a, true);
    }
}

/// A simple outlined button with a centered label.
#[allow(clippy::too_many_arguments)]
pub fn button_box(
    eng: &mut dyn Engine,
    x: i32,
    y: i32,
    w: i32,
    h: i32,
    label: &str,
    active: bool,
    r_on: u8,
    g_on: u8,
    b_on: u8,
    r_off: u8,
    g_off: u8,
    b_off: u8,
) {
    let (r, g, b) = if active {
        (r_on, g_on, b_on)
    } else {
        (r_off, g_off, b_off)
    };
    eng.draw_rect(x, y, w, h, r, g, b, 255, true);
    eng.draw_rect(x, y, w, h, 255, 255, 255, 255, false);
    text(
        eng,
        label,
        x + w / 2,
        y + h / 2,
        14,
        255,
        255,
        255,
        255,
        true,
    );
}

/// Draws an animatronic sprite, falling back to a labeled gray box.
pub fn animatronic_sprite(eng: &mut dyn Engine, name: &str, x: i32, y: i32, w: i32, h: i32) {
    if let Some(tex) = get_sprite(name) {
        eng.draw_texture(&tex, x, y, w, h, None);
    } else {
        eng.draw_rect(x, y, w, h, 100, 100, 100, 255, true);
        let upper = name.to_uppercase();
        text(
            eng,
            &upper,
            x + w / 2,
            y + h / 2,
            14,
            255,
            255,
            255,
            255,
            true,
        );
    }
}

/// Fills a four-point trapezoid.
#[allow(clippy::too_many_arguments)]
pub fn trapezoid(
    eng: &mut dyn Engine,
    r: u8,
    g: u8,
    b: u8,
    p1: (i32, i32),
    p2: (i32, i32),
    p3: (i32, i32),
    p4: (i32, i32),
) {
    eng.fill_quad(p1, p2, p3, p4, r, g, b);
}

/// A chunky four-pointed star made of two rectangles.
pub fn star(eng: &mut dyn Engine, cx: i32, cy: i32, outer_r: i32, r: u8, g: u8, b: u8) {
    let size = outer_r;
    eng.draw_rect(
        cx - size / 4,
        cy - size / 2,
        size / 2,
        size,
        r,
        g,
        b,
        255,
        true,
    );
    eng.draw_rect(
        cx - size / 2,
        cy - size / 4,
        size,
        size / 2,
        r,
        g,
        b,
        255,
        true,
    );
}

/// Draws an animatronic face (sprite), silently skipping if missing.
pub fn animatronic_face(eng: &mut dyn Engine, name: &str, x: i32, y: i32, w: i32, h: i32) {
    if let Some(tex) = get_sprite(name) {
        eng.draw_texture(&tex, x, y, w, h, None);
    }
}

/// Draws a texture with rounded corners carved out in the background color.
#[allow(clippy::too_many_arguments)]
pub fn rounded_texture(
    eng: &mut dyn Engine,
    tex: &TextureHandle,
    x: i32,
    y: i32,
    w: i32,
    h: i32,
    radius: i32,
    bg_r: u8,
    bg_g: u8,
    bg_b: u8,
    alpha: u8,
) {
    let radius = radius.max(1);
    eng.draw_texture(tex, x, y, w, h, Some(alpha));

    for i in 0..=radius {
        let diff = radius * radius - (radius - i) * (radius - i);
        let off = if diff < 0 {
            0
        } else {
            (radius as f32 - (diff as f32).sqrt()).floor() as i32
        };
        if off > 0 {
            eng.draw_rect(x, y + i, off, 1, bg_r, bg_g, bg_b, 255, true);
            eng.draw_rect(x + w - off, y + i, off, 1, bg_r, bg_g, bg_b, 255, true);
            eng.draw_rect(x, y + h - i - 1, off, 1, bg_r, bg_g, bg_b, 255, true);
            eng.draw_rect(
                x + w - off,
                y + h - i - 1,
                off,
                1,
                bg_r,
                bg_g,
                bg_b,
                255,
                true,
            );
        }
    }
}

/// Full-screen camera (VHS) effect: scanlines plus static.
pub fn apply_camera_effect(eng: &mut dyn Engine, noise_intensity: f32, scanline_alpha: u8) {
    scanlines(
        eng,
        0,
        0,
        config::SCREEN_WIDTH,
        config::SCREEN_HEIGHT,
        scanline_alpha,
    );
    static_noise(
        eng,
        0,
        0,
        config::SCREEN_WIDTH,
        config::SCREEN_HEIGHT,
        noise_intensity,
    );
}

/// Darkens the screen edges with concentric unfilled rectangles.
pub fn vignette(eng: &mut dyn Engine, intensity: f32, r: u8, g: u8, b: u8) {
    let intensity = intensity.clamp(0.0, 1.0);
    let layers = if is_high_quality() { 22 } else { 10 };
    let max_a = (150.0 * intensity) as u8;
    let w = config::SCREEN_WIDTH;
    let h = config::SCREEN_HEIGHT;

    for i in 1..=layers {
        let t = i as f32 / layers as f32;
        let inset = (t * 64.0).floor() as i32;
        let a = ((1.0 - t) * max_a as f32) as u8;
        eng.draw_rect(
            inset,
            inset,
            w - inset * 2,
            h - inset * 2,
            r,
            g,
            b,
            a,
            false,
        );
    }
}

/// A flat translucent color overlay over the whole screen.
pub fn tone_overlay(eng: &mut dyn Engine, r: u8, g: u8, b: u8, alpha: u8) {
    if alpha == 0 {
        return;
    }
    eng.draw_rect(
        0,
        0,
        config::SCREEN_WIDTH,
        config::SCREEN_HEIGHT,
        r,
        g,
        b,
        alpha,
        true,
    );
}

/// VHS-style on-screen text with a dark drop shadow.
#[allow(clippy::too_many_arguments)]
pub fn vhs_osd(eng: &mut dyn Engine, s: &str, x: i32, y: i32, r: u8, g: u8, b: u8, scale: i32) {
    text(eng, s, x + 1, y + 1, scale, 0, 0, 0, 255, false);
    text(eng, s, x, y, scale, r, g, b, 255, false);
}

/// Clears every cached resource (called when the renderer is recreated).
pub fn clear_cache() {
    let mut cache = CACHE.lock();
    cache.sprites.clear();
    cache.fonts.clear();
    cache.scanlines.clear();
}
