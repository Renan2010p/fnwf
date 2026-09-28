//! Concrete SDL2 implementation of [`Engine`].
//!
//! This is the only module in the workspace that touches SDL. It mirrors the
//! original C++ `EngineSDL2` and documents a few implementation choices:
//!
//! - **Raw render-target FFI.** Render-to-texture targets are bound with
//!   `SDL_SetRenderTarget` through `sdl2_sys`, because the safe `sdl2` API does
//!   not expose it. The raw renderer and texture pointers come from
//!   `WindowCanvas::raw()` and `Texture::raw()`.
//! - **`unsafe_textures`.** The `sdl2` dependency enables the `unsafe_textures`
//!   feature so `Texture` carries no lifetime and can be stored in the long-lived
//!   texture and text caches.
//! - **Cached text.** TTF-rendered text is cached in a hash map keyed by an
//!   FNV-1a hash of the string plus the font index and color, avoiding
//!   re-rasterizing the same glyphs every frame.
//! - **Mixer channels.** Sound effects are played through SDL2_mixer channels so
//!   an individual effect can be stopped or gain-adjusted.
//! - **VSync toggling.** Because the safe API cannot change vsync on a live
//!   renderer, toggling it rebuilds the window and renderer and clears the shared
//!   draw cache.
//! - **Renderer fallback.** Window creation first tries an accelerated renderer
//!   and falls back to the software renderer when that fails (for example on a
//!   headless system).

use std::collections::HashMap;

use fnwf_engine::{Engine, Event, EventType, SoundHandle, TextureHandle};
use sdl2::image::LoadTexture;
use sdl2::mixer::{self, Channel, Chunk};
use sdl2::pixels::{Color, PixelFormatEnum};
use sdl2::render::{BlendMode, Texture, TextureAccess, TextureCreator, WindowCanvas};
use sdl2::ttf::{self, Font, Sdl2TtfContext};
use sdl2::video::{FullscreenType, WindowContext};
use sdl2::{EventPump, Sdl, VideoSubsystem};

/// The SDL2 desktop backend.
///
/// Owns the SDL2 context, window, renderer, and the texture, font, sound, and
/// text caches, plus audio volume state. Fields are private; create one with
/// [`Sdl2Engine::default`] and drive it through the [`Engine`] trait. Methods
/// that need a live window silently do nothing until
/// [`Engine::init`] succeeds.
#[derive(Default)]
pub struct Sdl2Engine {
    sdl: Option<Sdl>,
    video: Option<VideoSubsystem>,
    pump: Option<EventPump>,
    canvas: Option<WindowCanvas>,
    creator: Option<TextureCreator<WindowContext>>,
    ttf_ctx: Option<&'static Sdl2TtfContext>,

    textures: HashMap<u32, Texture>,
    fonts: Vec<Font<'static, 'static>>,
    chunks: HashMap<u32, Chunk>,
    text_cache: HashMap<u64, Texture>,
    active_target: Option<u32>,
    next_id: u32,

    logical_w: u32,
    logical_h: u32,
    window_title: String,
    window_w: u32,
    window_h: u32,
    fullscreen: bool,

    running: bool,
    vsync: bool,
    draw_offset: (i32, i32),

    master_vol: i32,
    sfx_vol: i32,
    music_vol: i32,
}

impl Sdl2Engine {
    fn build_window(&mut self) -> bool {
        let Some(video) = self.video.as_ref() else {
            return false;
        };
        let mut window = match video
            .window(&self.window_title, self.window_w, self.window_h)
            .position_centered()
            .build()
        {
            Ok(w) => w,
            Err(_) => return false,
        };
        if self.fullscreen {
            let _ = window.set_fullscreen(FullscreenType::Desktop);
        }
        let mut canvas = {
            let builder = window.into_canvas().accelerated();
            let builder = if self.vsync {
                builder.present_vsync()
            } else {
                builder
            };
            match builder.build() {
                Ok(c) => c,
                Err(_) => {
                    // Fallback to a software renderer (e.g. headless/offscreen).
                    let mut w2 = match video
                        .window(&self.window_title, self.window_w, self.window_h)
                        .position_centered()
                        .build()
                    {
                        Ok(w) => w,
                        Err(_) => return false,
                    };
                    if self.fullscreen {
                        let _ = w2.set_fullscreen(FullscreenType::Desktop);
                    }
                    let builder = w2.into_canvas().software();
                    let builder = if self.vsync {
                        builder.present_vsync()
                    } else {
                        builder
                    };
                    match builder.build() {
                        Ok(c) => c,
                        Err(_) => return false,
                    }
                },
            }
        };
        canvas.set_blend_mode(BlendMode::Blend);
        let _ = canvas.set_logical_size(self.logical_w, self.logical_h);
        let creator = canvas.texture_creator();
        self.canvas = Some(canvas);
        self.creator = Some(creator);
        true
    }

    fn canvas_mut(&mut self) -> &mut WindowCanvas {
        self.canvas.as_mut().expect("engine not initialized")
    }

    fn apply_sfx_volume(&mut self) {
        let eff = (self.master_vol * self.sfx_vol * mixer::MAX_VOLUME) / 10000;
        for ch in 0..32 {
            Channel(ch).set_volume(eff);
        }
    }
}

fn rgba(r: u8, g: u8, b: u8, a: u8) -> Color {
    Color::RGBA(r, g, b, a)
}

fn fnv1a(text: &str) -> u64 {
    let mut h: u64 = 0xcbf2_9ce4_8422_2325;
    for c in text.bytes() {
        h ^= c as u64;
        h = h.wrapping_mul(0x100_0000_01b3);
    }
    h
}

impl Engine for Sdl2Engine {
    fn init(&mut self, title: &str, w: u32, h: u32, fullscreen: bool, vsync: bool) -> bool {
        let Ok(sdl) = sdl2::init() else {
            return false;
        };
        let Ok(ttf_ctx) = ttf::init() else {
            return false;
        };
        let ttf_ctx: &'static Sdl2TtfContext = Box::leak(Box::new(ttf_ctx));
        if sdl2::image::init(sdl2::image::InitFlag::PNG).is_err() {
            return false;
        }
        if let Err(e) = mixer::open_audio(44100, mixer::DEFAULT_FORMAT, 2, 1024) {
            eprintln!("fnwf: audio init failed: {e}");
        }
        let _ = mixer::init(mixer::InitFlag::OGG);
        mixer::allocate_channels(32);

        let Ok(video) = sdl.video() else {
            return false;
        };
        let Ok(pump) = sdl.event_pump() else {
            return false;
        };

        self.sdl = Some(sdl);
        self.video = Some(video);
        self.pump = Some(pump);
        self.ttf_ctx = Some(ttf_ctx);
        self.logical_w = w;
        self.logical_h = h;
        self.window_title = title.to_string();
        self.window_w = w;
        self.window_h = h;
        self.fullscreen = fullscreen;
        self.vsync = vsync;
        self.draw_offset = (0, 0);
        self.master_vol = 80;
        self.sfx_vol = 100;
        self.music_vol = 70;

        if !self.build_window() {
            return false;
        }
        self.running = true;
        true
    }

    fn shutdown(&mut self) {
        self.textures.clear();
        self.text_cache.clear();
        self.chunks.clear();
        self.fonts.clear();
        self.creator = None;
        self.canvas = None;
        self.pump = None;
        self.video = None;
        mixer::close_audio();
        self.sdl = None;
    }

    fn poll_events(&mut self) -> Vec<Event> {
        let Some(pump) = self.pump.as_mut() else {
            return Vec::new();
        };
        let mut events = Vec::new();
        for e in pump.poll_iter() {
            let mut ev = Event::none();
            match e {
                sdl2::event::Event::Quit { .. } => ev.kind = EventType::Quit,
                sdl2::event::Event::KeyDown { keycode, .. } => {
                    ev.kind = EventType::KeyDown;
                    ev.key = keycode.map(|k| k.into_i32()).unwrap_or(0);
                },
                sdl2::event::Event::KeyUp { keycode, .. } => {
                    ev.kind = EventType::KeyUp;
                    ev.key = keycode.map(|k| k.into_i32()).unwrap_or(0);
                },
                sdl2::event::Event::MouseButtonDown { x, y, .. } => {
                    ev.kind = EventType::MouseButtonDown;
                    ev.x = x;
                    ev.y = y;
                },
                sdl2::event::Event::MouseButtonUp { x, y, .. } => {
                    ev.kind = EventType::MouseButtonUp;
                    ev.x = x;
                    ev.y = y;
                },
                sdl2::event::Event::MouseMotion { x, y, .. } => {
                    ev.kind = EventType::MouseMotion;
                    ev.x = x;
                    ev.y = y;
                },
                sdl2::event::Event::MouseWheel { y, .. } => {
                    ev.kind = EventType::MouseWheel;
                    ev.y = y;
                },
                _ => continue,
            }
            events.push(ev);
        }
        events
    }

    fn ticks(&self) -> f32 {
        unsafe { sdl2_sys::SDL_GetTicks64() as f32 }
    }

    fn keeps_running(&self) -> bool {
        self.running
    }

    fn request_stop(&mut self) {
        self.running = false;
    }

    fn present(&mut self) {
        if let Some(canvas) = self.canvas.as_mut() {
            canvas.present();
        }
    }

    fn set_logical_size(&mut self, w: u32, h: u32) {
        self.logical_w = w;
        self.logical_h = h;
        if let Some(canvas) = self.canvas.as_mut() {
            let _ = canvas.set_logical_size(w, h);
        }
    }

    fn set_fullscreen(&mut self, on: bool) {
        self.fullscreen = on;
        if let Some(canvas) = self.canvas.as_mut() {
            let _ = canvas.window_mut().set_fullscreen(if on {
                FullscreenType::Desktop
            } else {
                FullscreenType::Off
            });
        }
    }

    fn set_vsync(&mut self, on: bool) {
        if on == self.vsync {
            return;
        }
        self.vsync = on;
        // Recreate the renderer: the safe `sdl2` API cannot change vsync live.
        self.textures.clear();
        self.text_cache.clear();
        self.creator = None;
        self.canvas = None;
        fnwf_core::draw::clear_cache();
        self.build_window();
        self.set_logical_size(self.logical_w, self.logical_h);
    }

    fn set_resolution(&mut self, w: u32, h: u32) {
        if let Some(canvas) = self.canvas.as_mut() {
            let _ = canvas.window_mut().set_size(w, h);
            let _ = canvas.set_logical_size(w, h);
        }
    }

    fn get_display_modes(&mut self) -> Vec<[i32; 3]> {
        let mut modes = Vec::new();
        let Some(video) = self.video.as_ref() else {
            return modes;
        };
        let displays = video.num_video_displays().unwrap_or(0);
        for d in 0..displays {
            let count = video.num_display_modes(d).unwrap_or(0);
            for i in 0..count {
                if let Ok(mode) = video.display_mode(d, i) {
                    modes.push([mode.w, mode.h, mode.refresh_rate]);
                }
            }
        }
        modes
    }

    fn clear(&mut self, r: u8, g: u8, b: u8, a: u8) {
        let canvas = self.canvas_mut();
        canvas.set_draw_color(rgba(r, g, b, a));
        canvas.clear();
    }

    fn draw_rect(
        &mut self,
        x: i32,
        y: i32,
        w: i32,
        h: i32,
        r: u8,
        g: u8,
        b: u8,
        a: u8,
        filled: bool,
    ) {
        let (dx, dy) = self.draw_offset;
        let canvas = self.canvas_mut();
        canvas.set_draw_color(rgba(r, g, b, a));
        let rect = sdl2::rect::Rect::new(x + dx, y + dy, w.max(0) as u32, h.max(0) as u32);
        if filled {
            let _ = canvas.fill_rect(rect);
        } else {
            let _ = canvas.draw_rect(rect);
        }
    }

    fn line(&mut self, x1: i32, y1: i32, x2: i32, y2: i32, r: u8, g: u8, b: u8, a: u8) {
        let (dx, dy) = self.draw_offset;
        let canvas = self.canvas_mut();
        canvas.set_draw_color(rgba(r, g, b, a));
        let _ = canvas.draw_line(
            sdl2::rect::Point::new(x1 + dx, y1 + dy),
            sdl2::rect::Point::new(x2 + dx, y2 + dy),
        );
    }

    fn circle(&mut self, cx: i32, cy: i32, radius: i32, r: u8, g: u8, b: u8, a: u8, filled: bool) {
        if radius <= 0 {
            return;
        }
        let (ddx, ddy) = self.draw_offset;
        let canvas = self.canvas_mut();
        canvas.set_draw_color(rgba(r, g, b, a));
        let r2 = (radius as i64) * (radius as i64);
        for dy in -radius..=radius {
            let dy2 = (dy as i64) * (dy as i64);
            let diff = r2 - dy2;
            if diff < 0 {
                continue;
            }
            let half = (diff as f32).sqrt() as i32;
            let w = half * 2 + 1;
            if w > 0 {
                if filled {
                    let rect = sdl2::rect::Rect::new(cx - half + ddx, cy + dy + ddy, w as u32, 1);
                    let _ = canvas.fill_rect(rect);
                } else {
                    let _ = canvas.draw_point(sdl2::rect::Point::new(cx + ddx, cy + dy + ddy));
                }
            }
        }
    }

    fn draw_texture(
        &mut self,
        tex: &TextureHandle,
        dx: i32,
        dy: i32,
        dw: i32,
        dh: i32,
        alpha: Option<u8>,
    ) {
        let EngineFields {
            canvas, textures, ..
        } = self.split();
        let Some(canvas) = canvas else { return };
        let Some(texture) = textures.get_mut(&tex.id) else {
            return;
        };
        if let Some(a) = alpha {
            texture.set_alpha_mod(a);
        }
        let dst = sdl2::rect::Rect::new(dx, dy, dw.max(0) as u32, dh.max(0) as u32);
        let _ = canvas.copy(texture, None, Some(dst));
        if alpha.is_some() {
            texture.set_alpha_mod(255);
        }
    }

    fn draw_texture_region(
        &mut self,
        tex: &TextureHandle,
        dx: i32,
        dy: i32,
        dw: i32,
        dh: i32,
        sx: i32,
        sy: i32,
        sw: i32,
        sh: i32,
    ) {
        let EngineFields {
            canvas, textures, ..
        } = self.split();
        let Some(canvas) = canvas else { return };
        let Some(texture) = textures.get(&tex.id) else {
            return;
        };
        let src = sdl2::rect::Rect::new(sx, sy, sw.max(0) as u32, sh.max(0) as u32);
        let dst = sdl2::rect::Rect::new(dx, dy, dw.max(0) as u32, dh.max(0) as u32);
        let _ = canvas.copy(texture, Some(src), Some(dst));
    }

    fn draw_texture_rotated(
        &mut self,
        tex: &TextureHandle,
        dx: i32,
        dy: i32,
        dw: i32,
        dh: i32,
        angle: f32,
        alpha: Option<u8>,
    ) {
        let EngineFields {
            canvas, textures, ..
        } = self.split();
        let Some(canvas) = canvas else { return };
        let Some(texture) = textures.get_mut(&tex.id) else {
            return;
        };
        if let Some(a) = alpha {
            texture.set_alpha_mod(a);
        }
        let dst = sdl2::rect::Rect::new(dx, dy, dw.max(0) as u32, dh.max(0) as u32);
        let _ = canvas.copy_ex(texture, None, Some(dst), angle as f64, None, false, false);
        if alpha.is_some() {
            texture.set_alpha_mod(255);
        }
    }

    #[allow(clippy::too_many_arguments)]
    fn draw_text(
        &mut self,
        text: &str,
        x: i32,
        y: i32,
        font_size: i32,
        r: u8,
        g: u8,
        b: u8,
        a: u8,
        center: bool,
        font_idx: i32,
    ) -> bool {
        if text.is_empty() {
            return true;
        }
        let mut fidx = font_idx;
        if fidx < 0 {
            fidx = self.load_font(
                &fnwf_core::config::asset_path("font/font", ".ttf"),
                font_size,
            );
            if fidx < 0 {
                return true;
            }
        }
        if fidx as usize >= self.fonts.len() {
            return true;
        }

        let mut key = fnv1a(text);
        key ^= ((fidx as u64) << 32)
            | ((r as u64) << 16)
            | ((g as u64) << 8)
            | (b as u64)
            | ((a as u64) << 24);

        let EngineFields {
            canvas,
            fonts,
            text_cache,
            creator,
            ..
        } = self.split();
        let (Some(canvas), Some(creator)) = (canvas, creator) else {
            return true;
        };

        if !text_cache.contains_key(&key) {
            if text_cache.len() > 2048 {
                text_cache.clear();
            }
            let surface = match fonts[fidx as usize].render(text).blended(rgba(r, g, b, a)) {
                Ok(s) => s,
                Err(_) => return true,
            };
            let mut texture = match creator.create_texture_from_surface(&surface) {
                Ok(t) => t,
                Err(_) => return true,
            };
            texture.set_blend_mode(BlendMode::Blend);
            text_cache.insert(key, texture);
        }

        let Some(texture) = text_cache.get(&key) else {
            return true;
        };
        let q = texture.query();
        let (tw, th) = (q.width as i32, q.height as i32);
        let px = if center { x - tw / 2 } else { x };
        let py = if center { y - th / 2 } else { y };
        let dst = sdl2::rect::Rect::new(px, py, q.width, q.height);
        let _ = canvas.copy(texture, None, Some(dst));
        true
    }

    #[allow(clippy::too_many_arguments)]
    fn draw_text_rotated(
        &mut self,
        text: &str,
        x: i32,
        y: i32,
        font_size: i32,
        angle: f32,
        r: u8,
        g: u8,
        b: u8,
        a: u8,
        center: bool,
        font_idx: i32,
    ) -> bool {
        if text.is_empty() {
            return true;
        }
        let mut fidx = font_idx;
        if fidx < 0 {
            fidx = self.load_font(
                &fnwf_core::config::asset_path("font/font", ".ttf"),
                font_size,
            );
            if fidx < 0 {
                return true;
            }
        }
        if fidx as usize >= self.fonts.len() {
            return true;
        }

        let EngineFields {
            canvas,
            fonts,
            creator,
            ..
        } = self.split();
        let (Some(canvas), Some(creator)) = (canvas, creator) else {
            return true;
        };
        let surface = match fonts[fidx as usize].render(text).blended(rgba(r, g, b, a)) {
            Ok(s) => s,
            Err(_) => return true,
        };
        let tw = surface.width() as i32;
        let th = surface.height() as i32;
        let mut texture = match creator.create_texture_from_surface(&surface) {
            Ok(t) => t,
            Err(_) => return true,
        };
        texture.set_blend_mode(BlendMode::Blend);
        let px = if center { x - tw / 2 } else { x };
        let py = if center { y - th / 2 } else { y };
        let dst = sdl2::rect::Rect::new(px, py, tw.max(0) as u32, th.max(0) as u32);
        let _ = canvas.copy_ex(&texture, None, Some(dst), angle as f64, None, false, false);
        true
    }

    fn load_texture(&mut self, path: &str) -> Option<TextureHandle> {
        let creator = self.creator.as_ref()?;
        let mut texture = creator.load_texture(path).ok()?;
        texture.set_blend_mode(BlendMode::Blend);
        let id = self.next_id;
        self.next_id += 1;
        self.textures.insert(id, texture);
        Some(TextureHandle::new(id))
    }

    fn create_target(&mut self, w: i32, h: i32) -> Option<TextureHandle> {
        let creator = self.creator.as_ref()?;
        let texture = creator
            .create_texture(
                PixelFormatEnum::RGBA8888,
                TextureAccess::Target,
                w.max(0) as u32,
                h.max(0) as u32,
            )
            .ok()?;
        let id = self.next_id;
        self.next_id += 1;
        self.textures.insert(id, texture);
        Some(TextureHandle::new(id))
    }

    fn load_sound(&mut self, path: &str) -> Option<SoundHandle> {
        let chunk = Chunk::from_file(path).ok()?;
        let id = self.next_id;
        self.next_id += 1;
        self.chunks.insert(id, chunk);
        Some(SoundHandle::new(id))
    }

    fn load_font(&mut self, path: &str, size: i32) -> i32 {
        let Some(ctx) = self.ttf_ctx else {
            return -1;
        };
        match ctx.load_font(path, size.max(1) as u16) {
            Ok(font) => {
                let idx = self.fonts.len() as i32;
                self.fonts.push(font);
                idx
            },
            Err(_) => -1,
        }
    }

    fn font_text_size(&mut self, text: &str, font_idx: i32) -> Option<(i32, i32)> {
        if font_idx < 0 || font_idx as usize >= self.fonts.len() {
            return None;
        }
        self.fonts[font_idx as usize]
            .size_of(text)
            .ok()
            .map(|(w, h)| (w as i32, h as i32))
    }

    fn texture_size(&self, id: u32) -> (i32, i32) {
        match self.textures.get(&id) {
            Some(t) => {
                let q = t.query();
                (q.width as i32, q.height as i32)
            },
            None => (0, 0),
        }
    }

    fn set_render_target(&mut self, target: Option<TextureHandle>) {
        let logical_w = self.logical_w;
        let logical_h = self.logical_h;
        match target {
            Some(handle) => {
                let raw_ctx = match self.canvas.as_ref() {
                    Some(c) => c.raw(),
                    None => return,
                };
                let raw_tex = match self.textures.get(&handle.id) {
                    Some(t) => t.raw(),
                    None => return,
                };
                self.active_target = Some(handle.id);
                unsafe {
                    sdl2_sys::SDL_SetRenderTarget(raw_ctx, raw_tex);
                }
            },
            None => {
                let raw_ctx = match self.canvas.as_ref() {
                    Some(c) => c.raw(),
                    None => return,
                };
                self.active_target = None;
                unsafe {
                    sdl2_sys::SDL_SetRenderTarget(raw_ctx, std::ptr::null_mut());
                }
                if let Some(canvas) = self.canvas.as_mut() {
                    let _ = canvas.set_logical_size(logical_w, logical_h);
                }
            },
        }
    }

    fn reset_render_target(&mut self) {
        self.set_render_target(None);
    }

    fn play_sound(&mut self, snd: &SoundHandle, loops: i32, channel: i32) -> i32 {
        if let Some(chunk) = self.chunks.get(&snd.id) {
            let _ = Channel(channel).play(chunk, loops);
        }
        channel
    }

    fn stop_channel(&mut self, channel: i32) {
        Channel(channel).halt();
    }

    fn stop_all_sounds(&mut self) {
        Channel::all().halt();
    }

    fn mouse_pos(&mut self) -> (i32, i32) {
        let mut x = 0;
        let mut y = 0;
        unsafe {
            sdl2_sys::SDL_GetMouseState(&mut x, &mut y);
        }
        (x, y)
    }

    fn set_master_volume(&mut self, vol: i32) {
        self.master_vol = vol;
        self.apply_sfx_volume();
        let music_eff = (self.master_vol * self.music_vol * mixer::MAX_VOLUME) / 10000;
        mixer::Music::set_volume(music_eff);
    }

    fn set_sfx_volume(&mut self, vol: i32) {
        self.sfx_vol = vol;
        self.apply_sfx_volume();
    }

    fn set_music_volume(&mut self, vol: i32) {
        self.music_vol = vol;
        let eff = (self.master_vol * self.music_vol * mixer::MAX_VOLUME) / 10000;
        mixer::Music::set_volume(eff);
    }

    fn update_discord(&mut self, _details: &str, _state: &str) {
        // Discord RPC is intentionally a no-op in this port.
    }

    fn set_draw_offset(&mut self, dx: i32, dy: i32) {
        self.draw_offset = (dx, dy);
    }
}

impl Sdl2Engine {
    /// Splits the engine into disjoint field borrows for calls into the canvas.
    fn split(&mut self) -> EngineFields<'_> {
        EngineFields {
            canvas: self.canvas.as_mut(),
            creator: self.creator.as_ref(),
            textures: &mut self.textures,
            fonts: &self.fonts,
            text_cache: &mut self.text_cache,
        }
    }
}

/// A bundle of disjoint borrows of [`Sdl2Engine`]'s fields.
struct EngineFields<'a> {
    canvas: Option<&'a mut WindowCanvas>,
    creator: Option<&'a TextureCreator<WindowContext>>,
    textures: &'a mut HashMap<u32, Texture>,
    fonts: &'a [Font<'static, 'static>],
    text_cache: &'a mut HashMap<u64, Texture>,
}
