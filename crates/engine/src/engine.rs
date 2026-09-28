//! The [`Engine`] trait — the single seam between the game and the platform.
//!
//! Backends (SDL2 today, gsKit/PS2 in the original C++ project) implement this
//! trait. The game code only ever sees `&mut dyn Engine`, so no platform header
//! leaks into the gameplay layer.

use alloc::vec::Vec;

use crate::event::Event;
use crate::handle::{SoundHandle, TextureHandle};

/// The abstract engine contract.
///
/// A backend owns the window, GPU, audio and input state; the game only ever
/// holds `&mut dyn Engine`. Unless stated otherwise, coordinates are logical
/// screen pixels in the space configured by [`Engine::set_logical_size`] (or
/// the initial size passed to [`Engine::init`]), and colors are 8-bit RGBA
/// components.
pub trait Engine {
    // ── Lifecycle ───────────────────────────────────────────────────────────
    /// Initializes the platform and opens a window of `width` × `height`
    /// logical pixels.
    ///
    /// `title` is the window caption, `fullscreen` requests desktop fullscreen
    /// and `vsync` enables vertical sync. Returns `false` if a required
    /// subsystem (video, fonts, window or event pump) cannot be started; an
    /// audio failure is reported but does not abort initialization. On success
    /// the engine runs until [`Engine::request_stop`] or a quit event.
    fn init(&mut self, title: &str, width: u32, height: u32, fullscreen: bool, vsync: bool)
        -> bool;
    /// Releases the window, renderer, textures, fonts and audio resources.
    ///
    /// The engine must be [`Engine::init`]ialized again before further use.
    fn shutdown(&mut self);
    /// Drains all input and lifecycle events queued since the previous call.
    ///
    /// Returns an empty vector if the engine is not currently running.
    fn poll_events(&mut self) -> Vec<Event>;
    /// Milliseconds since the engine started (same units as the C++ original).
    ///
    /// The value is monotonic and never wraps in practice.
    fn ticks(&self) -> f32;
    /// Whether the main loop should keep running.
    ///
    /// Stays `true` until [`Engine::request_stop`] is called or a quit event is
    /// observed. Never blocks.
    fn keeps_running(&self) -> bool;
    /// Asks the main loop to exit after the current frame.
    ///
    /// This only flips the running flag; call [`Engine::shutdown`] to release
    /// resources.
    fn request_stop(&mut self);
    /// Presents the finished frame, swapping the back buffer to the screen.
    fn present(&mut self);

    // ── Window ──────────────────────────────────────────────────────────────
    /// Sets the resolution-independent drawing space to `width` × `height`.
    ///
    /// All draw coordinates are expressed in this space and scaled by the
    /// backend to the real window. Does not resize the physical window.
    fn set_logical_size(&mut self, width: u32, height: u32);
    /// Enables or disables desktop fullscreen.
    fn set_fullscreen(&mut self, on: bool);
    /// Enables or disables vertical sync.
    ///
    /// Toggling may recreate the renderer (SDL cannot change it live), which
    /// invalidates previously obtained [`TextureHandle`]s and cached fonts.
    fn set_vsync(&mut self, on: bool);
    /// Resizes the window to `width` × `height` and makes that the logical size.
    fn set_resolution(&mut self, width: u32, height: u32);
    /// Lists every display mode as `[width, height, refresh_rate_hz]`.
    ///
    /// Entries are collected across all connected displays. Returns an empty
    /// vector if video is not initialized.
    fn get_display_modes(&mut self) -> Vec<[i32; 3]>;

    // ── Drawing primitives ──────────────────────────────────────────────────
    /// Clears the current render target to the given RGBA color.
    fn clear(&mut self, r: u8, g: u8, b: u8, a: u8);
    /// Draws an axis-aligned rectangle with its top-left corner at `(x, y)`.
    ///
    /// `w` and `h` are clamped to non-negative. When `filled` is `false` only
    /// the one-pixel outline is drawn.
    #[allow(clippy::too_many_arguments)]
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
    );
    /// Draws a one-pixel line from `(x1, y1)` to `(x2, y2)` in the given RGBA
    /// color.
    #[allow(clippy::too_many_arguments)]
    fn line(&mut self, x1: i32, y1: i32, x2: i32, y2: i32, r: u8, g: u8, b: u8, a: u8);

    /// Fills the convex quad `p1 -> p2 -> p3 -> p4`.
    ///
    /// The default implementation scanline-fills between the `p1 -> p4` (left)
    /// and `p2 -> p3` (right) edges. Backends with a native polygon primitive
    /// may override it. The fill is fully opaque regardless of the requested
    /// alpha.
    #[allow(clippy::too_many_arguments)]
    fn fill_quad(
        &mut self,
        p1: (i32, i32),
        p2: (i32, i32),
        p3: (i32, i32),
        p4: (i32, i32),
        r: u8,
        g: u8,
        b: u8,
    ) {
        let (x1, y1) = p1;
        let (x2, y2) = p2;
        let (x3, y3) = p3;
        let (x4, y4) = p4;

        let y0 = y1.min(y2);
        let y_end = y3.max(y4);
        if y_end <= y0 {
            return;
        }
        let span = (y_end - y0) as f32;
        for py in y0..=y_end {
            let t = (py - y0) as f32 / span;
            let xl = x1 as f32 + (x4 - x1) as f32 * t;
            let xr = x2 as f32 + (x3 - x2) as f32 * t;
            let (xl, xr) = (xl as i32, xr as i32);
            if xr > xl {
                self.line(xl, py, xr, py, r, g, b, 255);
            }
        }
    }

    /// Draws a circle centered at `(cx, cy)` with the given `radius`.
    ///
    /// A non-positive `radius` is a no-op. When `filled` is `false` only the
    /// outline is drawn.
    #[allow(clippy::too_many_arguments)]
    fn circle(&mut self, cx: i32, cy: i32, radius: i32, r: u8, g: u8, b: u8, a: u8, filled: bool);

    // ── Textures ────────────────────────────────────────────────────────────
    /// Draws an entire texture scaled to the destination rect `(dx, dy, dw, dh)`.
    ///
    /// When `alpha` is `Some(a)` the texture is alpha-modulated by `a` for this
    /// call only; `None` keeps the texture's own alpha. A handle whose texture
    /// no longer exists is ignored.
    fn draw_texture(
        &mut self,
        tex: &TextureHandle,
        dx: i32,
        dy: i32,
        dw: i32,
        dh: i32,
        alpha: Option<u8>,
    );

    /// Draws the sub-region `(sx, sy, sw, sh)` of `tex` scaled into
    /// `(dx, dy, dw, dh)`.
    ///
    /// Source and destination dimensions are clamped to non-negative; a missing
    /// texture is ignored.
    #[allow(clippy::too_many_arguments)]
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
    );

    /// Draws a whole texture scaled to `(dx, dy, dw, dh)` and rotated `angle`
    /// degrees about the destination center.
    ///
    /// `alpha` behaves as in [`Engine::draw_texture`].
    #[allow(clippy::too_many_arguments)]
    fn draw_texture_rotated(
        &mut self,
        tex: &TextureHandle,
        dx: i32,
        dy: i32,
        dw: i32,
        dh: i32,
        angle: f32,
        alpha: Option<u8>,
    );

    // ── Text ────────────────────────────────────────────────────────────────
    /// Draws `text` at `(x, y)` in a `size`-point font and the given RGBA color.
    ///
    /// When `font_idx` is `-1` the backend resolves the font from `size` (and
    /// falls back to the main font); otherwise it must name a font returned by
    /// [`Engine::load_font`]. When `center` is `true`, `(x, y)` is the text
    /// center instead of its top-left. Empty text and unknown fonts are treated
    /// as no-ops; the reference SDL2 backend returns `true` even in those
    /// cases, so treat the result as advisory.
    #[allow(clippy::too_many_arguments)]
    fn draw_text(
        &mut self,
        text: &str,
        x: i32,
        y: i32,
        size: i32,
        r: u8,
        g: u8,
        b: u8,
        a: u8,
        center: bool,
        font_idx: i32,
    ) -> bool;

    /// Draws `text` rotated `angle` degrees about its anchor.
    ///
    /// Color, centering and `font_idx` behave as in [`Engine::draw_text`].
    #[allow(clippy::too_many_arguments)]
    fn draw_text_rotated(
        &mut self,
        text: &str,
        x: i32,
        y: i32,
        size: i32,
        angle: f32,
        r: u8,
        g: u8,
        b: u8,
        a: u8,
        center: bool,
        font_idx: i32,
    ) -> bool;

    // ── Resources ───────────────────────────────────────────────────────────
    /// Loads an image file (PNG) as a texture with alpha blending enabled.
    ///
    /// Returns `None` if the file cannot be read or decoded.
    fn load_texture(&mut self, path: &str) -> Option<TextureHandle>;
    /// Creates an empty RGBA8888 offscreen render target `w` × `h`.
    ///
    /// Returns `None` on failure. Draw into it by passing the handle to
    /// [`Engine::set_render_target`].
    fn create_target(&mut self, w: i32, h: i32) -> Option<TextureHandle>;
    /// Decodes an audio file into a sound ready for [`Engine::play_sound`].
    ///
    /// Returns `None` if the file cannot be read or decoded.
    fn load_sound(&mut self, path: &str) -> Option<SoundHandle>;
    /// Loads a font and returns its index, or `-1` on failure.
    ///
    /// Indices are assigned by insertion order and are used with
    /// [`Engine::draw_text`] and [`Engine::font_text_size`]. The requested size
    /// is clamped to at least 1.
    fn load_font(&mut self, path: &str, size: i32) -> i32;
    /// Measures `text` in the font at `font_idx`, returning `(width, height)` in
    /// pixels.
    ///
    /// Returns `None` for an out-of-range index or if measurement fails.
    fn font_text_size(&mut self, text: &str, font_idx: i32) -> Option<(i32, i32)>;
    /// Returns the `(width, height)` of the texture with the given raw `id`.
    ///
    /// Returns `(0, 0)` when the id is unknown.
    fn texture_size(&self, id: u32) -> (i32, i32);

    // ── Render targets ──────────────────────────────────────────────────────
    /// Directs subsequent draw calls into `target`, or into the back buffer
    /// when `None`.
    ///
    /// Passing an unknown handle is ignored. Selecting a target also adapts the
    /// drawing viewport to its size.
    fn set_render_target(&mut self, target: Option<TextureHandle>);
    /// Binds the back buffer again.
    ///
    /// Equivalent to [`Engine::set_render_target`]`(None)`.
    fn reset_render_target(&mut self);

    // ── Sound ───────────────────────────────────────────────────────────────
    /// Plays `snd` on `channel`, repeating it `loops` times.
    ///
    /// `loops == 0` plays once, `loops < 0` loops forever; `-1` is the usual
    /// "infinite" value. Returns the channel actually used so callers can stop
    /// it later with [`Engine::stop_channel`].
    fn play_sound(&mut self, snd: &SoundHandle, loops: i32, channel: i32) -> i32;
    /// Stops whatever is playing on `channel`.
    fn stop_channel(&mut self, channel: i32);
    /// Stops every sound on every channel.
    fn stop_all_sounds(&mut self);

    // ── Input ───────────────────────────────────────────────────────────────
    /// Returns the current mouse cursor position in logical screen pixels.
    fn mouse_pos(&mut self) -> (i32, i32);

    // ── Volume ──────────────────────────────────────────────────────────────
    /// Sets the master volume as a percentage (`0`..=`100`).
    ///
    /// The master volume scales both sound effects and music. Values outside
    /// the range are not clamped by the backend.
    fn set_master_volume(&mut self, vol: i32);
    /// Sets the sound-effect volume as a percentage (`0`..=`100`).
    fn set_sfx_volume(&mut self, vol: i32);
    /// Sets the music volume as a percentage (`0`..=`100`).
    fn set_music_volume(&mut self, vol: i32);

    // ── Misc ────────────────────────────────────────────────────────────────
    /// Updates the external Discord Rich Presence with the given `details` and
    /// `state` strings.
    ///
    /// This is a no-op in the desktop port; the hook exists for parity with the
    /// original C++ engine.
    fn update_discord(&mut self, details: &str, state: &str);

    /// Whether this platform can composite the office's cylindrical panorama.
    ///
    /// When `false` the office is drawn flat; defaults to `true`. The planned
    /// PS2/gsKit backend is expected to return `false`.
    fn supports_cylindrical_office(&self) -> bool {
        true
    }

    /// Whether offscreen render targets are cheap on this platform.
    ///
    /// When `false` the game draws effects directly to the screen instead of
    /// compositing through [`Engine::create_target`]; defaults to `true`.
    fn supports_offscreen_targets(&self) -> bool {
        true
    }

    /// Temporary translation applied to every logical draw coordinate.
    ///
    /// Used for direct-to-screen parallax/slide effects. Defaults to a no-op;
    /// callers must reset it to `(0, 0)` when done.
    fn set_draw_offset(&mut self, _dx: i32, _dy: i32) {}
}
