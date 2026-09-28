#![warn(missing_docs)]
//! `fnwf-backend-web` — the web (wasm) backend.
//!
//! Implements [`fnwf_engine::Engine`] on top of the browser's **Canvas2D** API
//! via `web-sys`, targeting `wasm32-unknown-unknown`. It deliberately avoids
//! Emscripten and SDL: the game's immediate-mode drawing primitives map almost
//! one-to-one onto `CanvasRenderingContext2d` calls.
//!
//! Key mapping decisions:
//!
//! * **Textures** are `HtmlImageElement`s created eagerly from `assets/…` URLs.
//!   Browsers load images asynchronously, so a sprite may be blank for the first
//!   frames; `draw_image` simply does nothing until the image is decoded.
//! * **Render targets** are detached `<canvas>` elements used as image sources.
//! * **Text** is drawn with `fillText`; the family falls back to a monospace
//!   font if the project font is not registered via CSS `@font-face`.
//! * **Audio** uses `HtmlAudioElement`. Channel semantics mirror the SDL2
//!   backend (channel `-1` = fire and forget, `0` = menu ambient, `1` = office
//!   ambient, `5` = mask breathing).
//! * **Input** is push-based: DOM listeners push into a queue that
//!   [`Engine::poll_events`] drains. Key repeats are ignored so holding a key
//!   does not toggle doors repeatedly (a latent quirk of the C++ original).
//!
//! Note: persistence (`fnwf-core::save`/`settings`) still uses the standard
//! library's file API, which is a no-op in the browser. Wiring it to
//! `localStorage` is a follow-up.

use std::cell::{Cell, RefCell};
use std::collections::{HashMap, VecDeque};
use std::rc::Rc;

use fnwf_engine::keys;
use fnwf_engine::{Engine, Event, EventType, SoundHandle, TextureHandle};
use wasm_bindgen::prelude::*;
use wasm_bindgen::JsCast;
use web_sys::{
    CanvasRenderingContext2d, HtmlAudioElement, HtmlCanvasElement, HtmlImageElement, KeyboardEvent,
    MouseEvent, WheelEvent,
};

/// Font stack used for all text. Replace with `@font-face` if the project font
/// is bundled.
const FONT_FAMILY: &str = "\"FiraCode Nerd Font Mono\", monospace";

/// Canvas2D-based web engine.
#[derive(Default)]
pub struct WebEngine {
    canvas: Option<HtmlCanvasElement>,
    ctx: Option<CanvasRenderingContext2d>,
    main_ctx: Option<CanvasRenderingContext2d>,

    targets: HashMap<u32, (HtmlCanvasElement, CanvasRenderingContext2d)>,
    active_target: Option<u32>,
    textures: HashMap<u32, HtmlImageElement>,
    sounds: HashMap<u32, HtmlAudioElement>,
    playing: HashMap<i32, HtmlAudioElement>,
    next_id: u32,

    logical_w: i32,
    logical_h: i32,
    draw_offset: (i32, i32),

    running: bool,
    master_vol: i32,
    sfx_vol: i32,
    music_vol: i32,

    mouse: Rc<Cell<(i32, i32)>>,
    events: Rc<RefCell<VecDeque<Event>>>,
    // Kept alive so the DOM listeners remain registered.
    closures: Vec<Closure<dyn FnMut(web_sys::Event)>>,
}

impl WebEngine {
    fn ctx(&self) -> &CanvasRenderingContext2d {
        self.ctx.as_ref().expect("web engine not initialized")
    }

    fn set_fill(&self, r: u8, g: u8, b: u8, a: u8) {
        self.ctx()
            .set_fill_style_str(&format!("rgba({r},{g},{b},{})", a as f64 / 255.0));
    }

    fn set_stroke(&self, r: u8, g: u8, b: u8, a: u8) {
        self.ctx()
            .set_stroke_style_str(&format!("rgba({r},{g},{b},{})", a as f64 / 255.0));
    }

    fn attach_listeners(&mut self) {
        let window = web_sys::window().expect("no window");
        let mouse = self.mouse.clone();
        let events = self.events.clone();

        let make = |target: &web_sys::EventTarget,
                    events: Rc<RefCell<VecDeque<Event>>>,
                    name: &'static str,
                    down: bool| {
            let closure = Closure::wrap(Box::new(move |e: web_sys::Event| {
                if let Ok(ke) = e.dyn_into::<KeyboardEvent>() {
                    if ke.repeat() {
                        return;
                    }
                    let mut ev = Event::none();
                    ev.kind = if down {
                        EventType::KeyDown
                    } else {
                        EventType::KeyUp
                    };
                    ev.key = map_key(&ke);
                    events.borrow_mut().push_back(ev);
                }
            }) as Box<dyn FnMut(web_sys::Event)>);
            let _ = target.add_event_listener_with_callback(name, closure.as_ref().unchecked_ref());
            closure
        };

        self.closures
            .push(make(&window, events.clone(), "keydown", true));
        self.closures
            .push(make(&window, events.clone(), "keyup", false));

        // Mouse listeners are attached to the canvas (offset coordinates).
        if let Some(canvas) = self.canvas.clone() {
            let mouse_move = mouse.clone();
            let events_move = events.clone();
            let canvas_move = canvas.clone();
            let closure = Closure::wrap(Box::new(move |e: web_sys::Event| {
                if let Ok(me) = e.dyn_into::<MouseEvent>() {
                    let (x, y) = scaled(&canvas_move, &me);
                    mouse_move.set((x, y));
                    let mut ev = Event::none();
                    ev.kind = EventType::MouseMotion;
                    ev.x = x;
                    ev.y = y;
                    events_move.borrow_mut().push_back(ev);
                }
            }) as Box<dyn FnMut(web_sys::Event)>);
            let _ = canvas
                .add_event_listener_with_callback("mousemove", closure.as_ref().unchecked_ref());
            self.closures.push(closure);

            let events_down = events.clone();
            let canvas_down = canvas.clone();
            self.closures
                .push(mouse_button_listener(&canvas_down, events_down, true));
            let events_up = events.clone();
            let canvas_up = canvas.clone();
            self.closures
                .push(mouse_button_listener(&canvas_up, events_up, false));

            let events_wheel = events.clone();
            let closure = Closure::wrap(Box::new(move |e: web_sys::Event| {
                if let Ok(we) = e.dyn_into::<WheelEvent>() {
                    let mut ev = Event::none();
                    ev.kind = EventType::MouseWheel;
                    ev.y = -we.delta_y() as i32;
                    events_wheel.borrow_mut().push_back(ev);
                }
            }) as Box<dyn FnMut(web_sys::Event)>);
            let _ =
                canvas.add_event_listener_with_callback("wheel", closure.as_ref().unchecked_ref());
            self.closures.push(closure);
        }
    }
}

fn mouse_button_listener(
    canvas: &HtmlCanvasElement,
    events: Rc<RefCell<VecDeque<Event>>>,
    down: bool,
) -> Closure<dyn FnMut(web_sys::Event)> {
    let listener_canvas = canvas.clone();
    let closure = Closure::wrap(Box::new(move |e: web_sys::Event| {
        if let Ok(me) = e.dyn_into::<MouseEvent>() {
            let (x, y) = scaled(&listener_canvas, &me);
            let mut ev = Event::none();
            ev.kind = if down {
                EventType::MouseButtonDown
            } else {
                EventType::MouseButtonUp
            };
            ev.x = x;
            ev.y = y;
            events.borrow_mut().push_back(ev);
        }
    }) as Box<dyn FnMut(web_sys::Event)>);
    let _ = canvas.add_event_listener_with_callback(
        if down { "mousedown" } else { "mouseup" },
        closure.as_ref().unchecked_ref(),
    );
    closure
}

/// Converts a mouse event to logical canvas coordinates (accounting for CSS
/// scaling of the element).
fn scaled(canvas: &HtmlCanvasElement, e: &MouseEvent) -> (i32, i32) {
    let rect = canvas.get_bounding_client_rect();
    let scale_x = if rect.width() > 0.0 {
        canvas.width() as f64 / rect.width()
    } else {
        1.0
    };
    let scale_y = if rect.height() > 0.0 {
        canvas.height() as f64 / rect.height()
    } else {
        1.0
    };
    (
        ((e.client_x() as f64 - rect.left()) * scale_x) as i32,
        ((e.client_y() as f64 - rect.top()) * scale_y) as i32,
    )
}

/// Maps a browser keyboard event to the SDL-style key code the game expects.
fn map_key(e: &KeyboardEvent) -> i32 {
    match e.key().as_str() {
        "ArrowUp" => keys::UP,
        "ArrowDown" => keys::DOWN,
        "ArrowLeft" => keys::LEFT,
        "ArrowRight" => keys::RIGHT,
        "Enter" => keys::RETURN,
        "Escape" => keys::ESCAPE,
        " " => keys::SPACE,
        "Tab" => keys::TAB,
        "Backspace" => keys::BACKSPACE,
        "F5" => keys::F5,
        "F8" => keys::F8,
        other => {
            let mut chars = other.chars();
            match (chars.next(), chars.next()) {
                (Some(c), None) => c.to_ascii_lowercase() as i32,
                _ => e.key_code() as i32,
            }
        },
    }
}

impl Engine for WebEngine {
    fn init(&mut self, title: &str, w: u32, h: u32, _fullscreen: bool, _vsync: bool) -> bool {
        let Some(window) = web_sys::window() else {
            return false;
        };
        let Ok(document) = window.document().ok_or(()) else {
            return false;
        };
        if let Some(title_el) = document.get_element_by_id("fnwf-title") {
            title_el.set_text_content(Some(title));
        }

        let canvas = match document.get_element_by_id("fnwf-canvas") {
            Some(el) => match el.dyn_into::<HtmlCanvasElement>() {
                Ok(c) => c,
                Err(_) => return false,
            },
            None => match document.create_element("canvas") {
                Ok(el) => match el.dyn_into::<HtmlCanvasElement>() {
                    Ok(c) => {
                        if let Some(body) = document.body() {
                            let _ = body.append_child(&c);
                        }
                        c
                    },
                    Err(_) => return false,
                },
                Err(_) => return false,
            },
        };
        canvas.set_width(w);
        canvas.set_height(h);

        let ctx = match canvas
            .get_context("2d")
            .ok()
            .flatten()
            .and_then(|o| o.dyn_into::<CanvasRenderingContext2d>().ok())
        {
            Some(c) => c,
            None => return false,
        };
        ctx.set_image_smoothing_enabled(false);

        self.canvas = Some(canvas);
        self.main_ctx = Some(ctx.clone());
        self.ctx = Some(ctx);
        self.logical_w = w as i32;
        self.logical_h = h as i32;
        self.draw_offset = (0, 0);
        self.next_id = 1;
        self.master_vol = 80;
        self.sfx_vol = 100;
        self.music_vol = 70;
        self.running = true;
        self.attach_listeners();
        true
    }

    fn shutdown(&mut self) {
        self.closures.clear();
        self.textures.clear();
        self.sounds.clear();
        self.targets.clear();
        self.ctx = None;
        self.main_ctx = None;
        self.canvas = None;
    }

    fn poll_events(&mut self) -> Vec<Event> {
        self.events.borrow_mut().drain(..).collect()
    }

    fn ticks(&self) -> f32 {
        web_sys::window()
            .and_then(|w| w.performance())
            .map(|p| p.now() as f32)
            .unwrap_or(0.0)
    }

    fn keeps_running(&self) -> bool {
        self.running
    }

    fn request_stop(&mut self) {
        self.running = false;
    }

    fn present(&mut self) {
        // Canvas2D draws immediately; nothing to flush.
    }

    fn set_logical_size(&mut self, w: u32, h: u32) {
        self.logical_w = w as i32;
        self.logical_h = h as i32;
    }

    fn set_fullscreen(&mut self, on: bool) {
        let Some(canvas) = self.canvas.as_ref() else {
            return;
        };
        if on {
            let _ = canvas.request_fullscreen();
        } else if let Some(doc) = web_sys::window().and_then(|w| w.document()) {
            doc.exit_fullscreen();
        }
    }

    fn set_vsync(&mut self, _on: bool) {
        // The browser drives presentation; nothing to change.
    }

    fn set_resolution(&mut self, w: u32, h: u32) {
        if let Some(canvas) = self.canvas.as_ref() {
            canvas.set_width(w);
            canvas.set_height(h);
        }
    }

    fn get_display_modes(&mut self) -> Vec<[i32; 3]> {
        let (w, h) = web_sys::window()
            .and_then(|w| w.inner_width().ok())
            .and_then(|v| v.as_f64())
            .map(|w| {
                let h = web_sys::window()
                    .and_then(|win| win.inner_height().ok())
                    .and_then(|v| v.as_f64())
                    .unwrap_or(720.0);
                (w as i32, h as i32)
            })
            .unwrap_or((self.logical_w, self.logical_h));
        vec![[w, h, 60]]
    }

    fn clear(&mut self, r: u8, g: u8, b: u8, a: u8) {
        let (w, h) = self
            .ctx()
            .canvas()
            .and_then(|c| c.dyn_into::<HtmlCanvasElement>().ok())
            .map(|c| (c.width() as f64, c.height() as f64))
            .unwrap_or((self.logical_w as f64, self.logical_h as f64));
        self.set_fill(r, g, b, a);
        self.ctx().fill_rect(0.0, 0.0, w, h);
    }

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
    ) {
        let (dx, dy) = self.draw_offset;
        let (x, y, w, h) = (
            (x + dx) as f64,
            (y + dy) as f64,
            w.max(0) as f64,
            h.max(0) as f64,
        );
        if filled {
            self.set_fill(r, g, b, a);
            self.ctx().fill_rect(x, y, w, h);
        } else {
            self.set_stroke(r, g, b, a);
            self.ctx().set_line_width(1.0);
            self.ctx().stroke_rect(x, y, w, h);
        }
    }

    #[allow(clippy::too_many_arguments)]
    fn line(&mut self, x1: i32, y1: i32, x2: i32, y2: i32, r: u8, g: u8, b: u8, a: u8) {
        let (dx, dy) = self.draw_offset;
        self.set_stroke(r, g, b, a);
        self.ctx().set_line_width(1.0);
        self.ctx().begin_path();
        self.ctx().move_to((x1 + dx) as f64, (y1 + dy) as f64);
        self.ctx().line_to((x2 + dx) as f64, (y2 + dy) as f64);
        self.ctx().stroke();
    }

    fn circle(&mut self, cx: i32, cy: i32, radius: i32, r: u8, g: u8, b: u8, a: u8, filled: bool) {
        if radius <= 0 {
            return;
        }
        let (dx, dy) = self.draw_offset;
        self.ctx().begin_path();
        let _ = self.ctx().arc(
            (cx + dx) as f64,
            (cy + dy) as f64,
            radius as f64,
            0.0,
            std::f64::consts::TAU,
        );
        if filled {
            self.set_fill(r, g, b, a);
            self.ctx().fill();
        } else {
            self.set_stroke(r, g, b, a);
            self.ctx().set_line_width(1.0);
            self.ctx().stroke();
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
        let Some(image) = self.textures.get(&tex.id) else {
            return;
        };
        let (ox, oy) = self.draw_offset;
        let _ = self.ctx().draw_image_with_html_image_element_and_dw_and_dh(
            image,
            (dx + ox) as f64,
            (dy + oy) as f64,
            dw.max(0) as f64,
            dh.max(0) as f64,
        );
        let _ = alpha;
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
        let Some(image) = self.textures.get(&tex.id) else {
            return;
        };
        let (ox, oy) = self.draw_offset;
        let _ = self
            .ctx()
            .draw_image_with_html_image_element_and_sw_and_sh_and_dx_and_dy_and_dw_and_dh(
                image,
                sx as f64,
                sy as f64,
                sw as f64,
                sh as f64,
                (dx + ox) as f64,
                (dy + oy) as f64,
                dw.max(0) as f64,
                dh.max(0) as f64,
            );
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
        let Some(image) = self.textures.get(&tex.id) else {
            return;
        };
        let (ox, oy) = self.draw_offset;
        let cx = (dx + ox) as f64 + dw as f64 / 2.0;
        let cy = (dy + oy) as f64 + dh as f64 / 2.0;
        self.ctx().save();
        self.ctx().translate(cx, cy).ok();
        self.ctx()
            .rotate(angle as f64 * std::f64::consts::PI / 180.0)
            .ok();
        let _ = self.ctx().draw_image_with_html_image_element_and_dw_and_dh(
            image,
            -(dw as f64) / 2.0,
            -(dh as f64) / 2.0,
            dw.max(0) as f64,
            dh.max(0) as f64,
        );
        self.ctx().restore();
        let _ = alpha;
    }

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
        _font_idx: i32,
    ) -> bool {
        let (dx, dy) = self.draw_offset;
        self.ctx().set_font(&format!("{size}px {FONT_FAMILY}"));
        self.ctx()
            .set_text_align(if center { "center" } else { "left" });
        self.ctx()
            .set_text_baseline(if center { "middle" } else { "top" });
        self.set_fill(r, g, b, a);
        let _ = self.ctx().fill_text(text, (x + dx) as f64, (y + dy) as f64);
        true
    }

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
        _font_idx: i32,
    ) -> bool {
        let (dx, dy) = self.draw_offset;
        self.ctx().save();
        self.ctx().translate((x + dx) as f64, (y + dy) as f64).ok();
        self.ctx()
            .rotate(angle as f64 * std::f64::consts::PI / 180.0)
            .ok();
        self.ctx().set_font(&format!("{size}px {FONT_FAMILY}"));
        self.ctx()
            .set_text_align(if center { "center" } else { "left" });
        self.ctx()
            .set_text_baseline(if center { "middle" } else { "top" });
        self.set_fill(r, g, b, a);
        let _ = self.ctx().fill_text(text, 0.0, 0.0);
        self.ctx().restore();
        true
    }

    fn load_texture(&mut self, path: &str) -> Option<TextureHandle> {
        let image = HtmlImageElement::new().ok()?;
        image.set_src(path);
        let id = self.next_id;
        self.next_id += 1;
        self.textures.insert(id, image);
        Some(TextureHandle::new(id))
    }

    fn create_target(&mut self, w: i32, h: i32) -> Option<TextureHandle> {
        let document = web_sys::window()?.document()?;
        let canvas = document
            .create_element("canvas")
            .ok()?
            .dyn_into::<HtmlCanvasElement>()
            .ok()?;
        canvas.set_width(w.max(0) as u32);
        canvas.set_height(h.max(0) as u32);
        let ctx = canvas
            .get_context("2d")
            .ok()?
            .and_then(|o| o.dyn_into::<CanvasRenderingContext2d>().ok())?;
        let id = self.next_id;
        self.next_id += 1;
        self.targets.insert(id, (canvas, ctx));
        Some(TextureHandle::new(id))
    }

    fn load_sound(&mut self, path: &str) -> Option<SoundHandle> {
        let audio = HtmlAudioElement::new_with_src(path).ok()?;
        let id = self.next_id;
        self.next_id += 1;
        self.sounds.insert(id, audio);
        Some(SoundHandle::new(id))
    }

    fn load_font(&mut self, _path: &str, _size: i32) -> i32 {
        // A single family is configured via CSS; index 0 always exists.
        0
    }

    fn font_text_size(&mut self, text: &str, _font_idx: i32) -> Option<(i32, i32)> {
        // Measure with the last-used font size is not tracked here, so size the
        // string with a neutral metric. Callers use this only for wrapping.
        self.ctx().set_font(&format!("14px {FONT_FAMILY}"));
        let metrics = self.ctx().measure_text(text).ok()?;
        Some((metrics.width() as i32, 16))
    }

    fn texture_size(&self, id: u32) -> (i32, i32) {
        self.textures
            .get(&id)
            .map(|t| (t.natural_width() as i32, t.natural_height() as i32))
            .unwrap_or((0, 0))
    }

    fn set_render_target(&mut self, target: Option<TextureHandle>) {
        match target {
            Some(handle) => {
                if let Some((_, ctx)) = self.targets.get(&handle.id) {
                    self.active_target = Some(handle.id);
                    self.ctx = Some(ctx.clone());
                }
            },
            None => {
                self.active_target = None;
                self.ctx = self.main_ctx.clone();
            },
        }
    }

    fn reset_render_target(&mut self) {
        self.set_render_target(None);
    }

    fn play_sound(&mut self, snd: &SoundHandle, loops: i32, channel: i32) -> i32 {
        let Some(base) = self.sounds.get(&snd.id) else {
            return channel;
        };
        // Clone so overlapping plays are possible.
        let Ok(node) = base.clone_node().and_then(|n| {
            n.dyn_into::<HtmlAudioElement>()
                .map_err(|_| wasm_bindgen::JsValue::NULL)
        }) else {
            return channel;
        };
        node.set_loop(loops != 0);
        node.set_volume(self.effective_sfx_volume());
        let _ = node.play();
        if channel >= 0 {
            if let Some(old) = self.playing.insert(channel, node.clone()) {
                old.pause().ok();
            }
        }
        channel
    }

    fn stop_channel(&mut self, channel: i32) {
        if let Some(audio) = self.playing.remove(&channel) {
            audio.pause().ok();
        }
    }

    fn stop_all_sounds(&mut self) {
        for (_, audio) in self.playing.drain() {
            audio.pause().ok();
        }
        for audio in self.sounds.values() {
            audio.pause().ok();
        }
    }

    fn mouse_pos(&mut self) -> (i32, i32) {
        self.mouse.get()
    }

    fn set_master_volume(&mut self, vol: i32) {
        self.master_vol = vol;
    }

    fn set_sfx_volume(&mut self, vol: i32) {
        self.sfx_vol = vol;
    }

    fn set_music_volume(&mut self, vol: i32) {
        self.music_vol = vol;
    }

    fn update_discord(&mut self, _details: &str, _state: &str) {}

    fn set_draw_offset(&mut self, dx: i32, dy: i32) {
        self.draw_offset = (dx, dy);
    }
}

impl WebEngine {
    fn effective_sfx_volume(&self) -> f64 {
        ((self.master_vol * self.sfx_vol) as f64 / 10000.0).clamp(0.0, 1.0)
    }
}

/// Creates the web engine. The returned engine is uninitialized until
/// [`Engine::init`] is called.
pub fn create_engine() -> Box<dyn Engine> {
    Box::new(WebEngine::default())
}
