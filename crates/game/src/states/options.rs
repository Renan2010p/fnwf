//! Options / settings screen.
//!
//! Edits resolution, fullscreen, quality, FPS counter, vsync, language, Discord
//! RPC and master/SFX/music volumes. Changes are applied and persisted when the
//! screen closes, which finishes the state with result `"back"`.

#[allow(unused_imports)]
use fnwf_core::prelude::*;

use fnwf_engine::{keys, Engine, Event, EventType};

use fnwf_core::settings;
use fnwf_core::state::{GameState, StateType};
use fnwf_core::{audio, config, draw, localization};

fn lerp(a: f32, b: f32, t: f32) -> f32 {
    a + (b - a) * t.clamp(0.0, 1.0)
}

#[derive(PartialEq, Eq, Clone, Copy)]
enum OptionKind {
    Toggle,
    Bool,
    Slider,
    Action,
}

struct OptionItem {
    id: &'static str,
    label: String,
    kind: OptionKind,
    values: Vec<String>,
    current: usize,
    value: bool,
    slider_value: i32,
    slider_max: i32,
    action: &'static str,
}

/// The options / settings screen.
pub struct OptionsState {
    timer: f32,
    selected: usize,
    done: bool,
    m_result: String,
    options: Vec<OptionItem>,
    max_options: usize,
    resolutions: Vec<(i32, i32)>,
    current_res_idx: usize,
    is_fullscreen: bool,
    show_fps: bool,
    vsync: bool,
    lang: String,
    discord_rpc: bool,
    master_volume: i32,
    sfx_volume: i32,
    music_volume: i32,
    bg_scroll: f32,
    highlight_y: f32,
    scroll_offset: f32,
    scroll_target: f32,
    item_glows: Vec<f32>,
}

impl OptionsState {
    /// Creates the screen from the current settings, enumerating the engine's
    /// display modes for the resolution option.
    pub fn new(eng: &mut dyn Engine) -> Self {
        let modes = eng.get_display_modes();
        let mut seen: Vec<(i32, i32)> = Vec::new();
        for m in modes {
            if !seen.iter().any(|(w, h)| *w == m[0] && *h == m[1]) {
                seen.push((m[0], m[1]));
            }
        }
        if seen.is_empty() {
            seen.push((config::SCREEN_WIDTH, config::SCREEN_HEIGHT));
        }
        seen.sort_by_key(|(w, _)| *w);

        let s = settings::get();
        let mut current_res_idx = 0;
        for (i, (w, h)) in seen.iter().enumerate() {
            if *w == s.resolution_w && *h == s.resolution_h {
                current_res_idx = i;
                break;
            }
        }

        let mut state = Self {
            timer: 0.0,
            selected: 1,
            done: false,
            m_result: String::new(),
            options: Vec::new(),
            max_options: 0,
            resolutions: seen,
            current_res_idx,
            is_fullscreen: s.fullscreen,
            show_fps: s.show_fps,
            vsync: s.vsync,
            lang: s.language,
            discord_rpc: s.discord_rpc,
            master_volume: s.master_volume,
            sfx_volume: s.sfx_volume,
            music_volume: s.music_volume,
            bg_scroll: 0.0,
            highlight_y: 150.0,
            scroll_offset: 0.0,
            scroll_target: 0.0,
            item_glows: Vec::new(),
        };
        state.rebuild_options();
        state.item_glows.resize(state.max_options, 0.0);
        if !state.item_glows.is_empty() {
            state.item_glows[0] = 1.0;
        }
        state
    }

    fn rebuild_options(&mut self) {
        self.options.clear();
        let res_vals: Vec<String> = self
            .resolutions
            .iter()
            .map(|(w, h)| format!("{w}x{h}"))
            .collect();
        let quality_vals = vec![localization::text("low"), localization::text("high")];

        self.options.push(OptionItem {
            id: "resolution",
            label: localization::text("resolution"),
            kind: OptionKind::Toggle,
            values: res_vals,
            current: self.current_res_idx,
            value: false,
            slider_value: 0,
            slider_max: 100,
            action: "",
        });
        self.options.push(OptionItem {
            id: "fullscreen",
            label: localization::text("fullscreen"),
            kind: OptionKind::Bool,
            values: Vec::new(),
            current: 0,
            value: self.is_fullscreen,
            slider_value: 0,
            slider_max: 100,
            action: "",
        });
        self.options.push(OptionItem {
            id: "language",
            label: localization::text("language"),
            kind: OptionKind::Toggle,
            values: vec!["Português".to_string(), "English".to_string()],
            current: if self.lang == "pt" { 0 } else { 1 },
            value: false,
            slider_value: 0,
            slider_max: 100,
            action: "",
        });
        self.options.push(OptionItem {
            id: "master_volume",
            label: localization::text("master_volume"),
            kind: OptionKind::Slider,
            values: Vec::new(),
            current: 0,
            value: false,
            slider_value: self.master_volume,
            slider_max: 100,
            action: "",
        });
        self.options.push(OptionItem {
            id: "sfx_volume",
            label: localization::text("sfx_volume"),
            kind: OptionKind::Slider,
            values: Vec::new(),
            current: 0,
            value: false,
            slider_value: self.sfx_volume,
            slider_max: 100,
            action: "",
        });
        self.options.push(OptionItem {
            id: "music_volume",
            label: localization::text("music_volume"),
            kind: OptionKind::Slider,
            values: Vec::new(),
            current: 0,
            value: false,
            slider_value: self.music_volume,
            slider_max: 100,
            action: "",
        });
        self.options.push(OptionItem {
            id: "show_fps",
            label: localization::text("show_fps"),
            kind: OptionKind::Bool,
            values: Vec::new(),
            current: 0,
            value: self.show_fps,
            slider_value: 0,
            slider_max: 100,
            action: "",
        });
        self.options.push(OptionItem {
            id: "vsync",
            label: localization::text("vsync"),
            kind: OptionKind::Bool,
            values: Vec::new(),
            current: 0,
            value: self.vsync,
            slider_value: 0,
            slider_max: 100,
            action: "",
        });
        self.options.push(OptionItem {
            id: "quality",
            label: localization::text("quality"),
            kind: OptionKind::Toggle,
            values: quality_vals,
            current: if settings::get().quality == "low" {
                0
            } else {
                1
            },
            value: false,
            slider_value: 0,
            slider_max: 100,
            action: "",
        });
        self.options.push(OptionItem {
            id: "discord_rpc",
            label: localization::text("discord_rpc"),
            kind: OptionKind::Bool,
            values: Vec::new(),
            current: 0,
            value: self.discord_rpc,
            slider_value: 0,
            slider_max: 100,
            action: "",
        });
        self.options.push(OptionItem {
            id: "back",
            label: localization::text("back"),
            kind: OptionKind::Action,
            values: Vec::new(),
            current: 0,
            value: false,
            slider_value: 0,
            slider_max: 100,
            action: "back",
        });
        self.max_options = self.options.len();
        self.item_glows.resize(self.max_options, 0.0);
        if self.selected > self.max_options {
            self.selected = self.max_options;
        }
    }

    fn change_option(&mut self, index: usize, dir: i32) {
        let opt = &mut self.options[index];
        match opt.kind {
            OptionKind::Toggle => {
                let n = opt.values.len() as i32;
                opt.current = (((opt.current as i32 + dir) % n + n) % n) as usize;
                if opt.id == "language" {
                    self.lang = if opt.current == 0 { "pt" } else { "en" }.to_string();
                    localization::set_language(&self.lang);
                    self.rebuild_options();
                }
            },
            OptionKind::Bool => opt.value = !opt.value,
            OptionKind::Slider => {
                opt.slider_value = (opt.slider_value + dir * 5).clamp(0, opt.slider_max);
            },
            OptionKind::Action => {},
        }
    }

    fn apply_settings(&mut self, eng: &mut dyn Engine) {
        for opt in &self.options {
            match opt.id {
                "resolution" => {
                    let (w, h) = self.resolutions[opt.current];
                    settings::with(|s| {
                        s.resolution_w = w;
                        s.resolution_h = h;
                    });
                    eng.set_resolution(w as u32, h as u32);
                    eng.set_logical_size(config::SCREEN_WIDTH as u32, config::SCREEN_HEIGHT as u32);
                },
                "fullscreen" => {
                    settings::with(|s| s.fullscreen = opt.value);
                    eng.set_fullscreen(opt.value);
                },
                "language" => {
                    let lang = if opt.current == 0 { "pt" } else { "en" };
                    settings::with(|s| s.language = lang.to_string());
                },
                "show_fps" => settings::with(|s| s.show_fps = opt.value),
                "vsync" => {
                    settings::with(|s| s.vsync = opt.value);
                    eng.set_vsync(opt.value);
                },
                "quality" => {
                    let q = if opt.current == 0 { "low" } else { "high" };
                    settings::with(|s| s.quality = q.to_string());
                    draw::set_render_quality(q);
                },
                "discord_rpc" => settings::with(|s| s.discord_rpc = opt.value),
                "master_volume" => {
                    settings::with(|s| s.master_volume = opt.slider_value);
                    audio::set_master_volume(eng, opt.slider_value);
                },
                "sfx_volume" => {
                    settings::with(|s| s.sfx_volume = opt.slider_value);
                    audio::set_sfx_volume(eng, opt.slider_value);
                },
                "music_volume" => {
                    settings::with(|s| s.music_volume = opt.slider_value);
                    audio::set_music_volume(eng, opt.slider_value);
                },
                _ => {},
            }
        }
        settings::save();
    }

    fn close(&mut self, eng: &mut dyn Engine) {
        audio::play(eng, "select", 0, -1);
        self.apply_settings(eng);
        self.m_result = "back".to_string();
        self.done = true;
    }

    fn handle_click(&mut self, eng: &mut dyn Engine, mx: i32, my: i32) {
        let panel_x = 40;
        let panel_w = config::SCREEN_WIDTH - 80;

        for i in 0..self.max_options {
            let y = 150 + i as i32 * 50 - self.scroll_offset as i32;
            if my >= y - 9 && my <= y + 40 && mx >= panel_x + 25 && mx <= panel_x + panel_w - 25 {
                self.selected = i + 1;
                if self.options[i].kind == OptionKind::Action && self.options[i].action == "back" {
                    self.close(eng);
                    return;
                }
                let value_x = 500;
                if self.options[i].kind == OptionKind::Toggle {
                    let n = self.options[i].values.len() as i32;
                    if mx < value_x {
                        self.options[i].current =
                            (((self.options[i].current as i32 - 1) % n + n) % n) as usize;
                    } else {
                        self.options[i].current = (self.options[i].current + 1) % n as usize;
                    }
                    if self.options[i].id == "language" {
                        self.lang = if self.options[i].current == 0 {
                            "pt"
                        } else {
                            "en"
                        }
                        .to_string();
                        localization::set_language(&self.lang);
                        self.rebuild_options();
                    }
                    audio::play(eng, "blip", 0, -1);
                } else if self.options[i].kind == OptionKind::Bool {
                    self.options[i].value = !self.options[i].value;
                    audio::play(eng, "blip", 0, -1);
                } else if self.options[i].kind == OptionKind::Slider {
                    let bar_x = value_x - 10;
                    let bar_w = 200;
                    let ratio = ((mx - bar_x) as f32 / bar_w as f32).clamp(0.0, 1.0);
                    self.options[i].slider_value =
                        (ratio * self.options[i].slider_max as f32) as i32;
                    audio::play(eng, "blip", 0, -1);
                }
                return;
            }
        }
    }
}

impl GameState for OptionsState {
    fn handle_event(&mut self, eng: &mut dyn Engine, ev: &Event) {
        if ev.kind == EventType::KeyDown {
            let key = ev.key;
            if key == keys::UP || key == keys::W {
                let n = self.max_options;
                self.selected = (self.selected + n - 2) % n + 1;
                audio::play(eng, "blip", 0, -1);
            } else if key == keys::DOWN || key == keys::S {
                let n = self.max_options;
                self.selected = self.selected % n + 1;
                audio::play(eng, "blip", 0, -1);
            } else if key == keys::LEFT || key == keys::A || key == keys::RIGHT || key == keys::D {
                let dir = if key == keys::RIGHT || key == keys::D {
                    1
                } else {
                    -1
                };
                self.change_option(self.selected - 1, dir);
                audio::play(eng, "blip", 0, -1);
            } else if key == keys::RETURN || key == keys::SPACE {
                let idx = self.selected - 1;
                if self.options[idx].kind == OptionKind::Action
                    && self.options[idx].action == "back"
                {
                    self.close(eng);
                } else if self.options[idx].kind == OptionKind::Bool {
                    self.options[idx].value = !self.options[idx].value;
                    audio::play(eng, "blip", 0, -1);
                } else if self.options[idx].kind == OptionKind::Toggle {
                    let n = self.options[idx].values.len();
                    self.options[idx].current = (self.options[idx].current + 1) % n;
                    if self.options[idx].id == "language" {
                        self.lang = if self.options[idx].current == 0 {
                            "pt"
                        } else {
                            "en"
                        }
                        .to_string();
                        localization::set_language(&self.lang);
                        self.rebuild_options();
                    }
                    audio::play(eng, "blip", 0, -1);
                }
            } else if key == keys::ESCAPE {
                self.close(eng);
            }
        }
        if ev.kind == EventType::MouseButtonDown {
            self.handle_click(eng, ev.x, ev.y);
        }
    }

    fn update(&mut self, _eng: &mut dyn Engine, dt: f32) {
        self.timer += dt;
        self.bg_scroll += dt * 35.0;

        let item_h = 50;
        let visible_h = config::SCREEN_HEIGHT - 200;
        let content_h = self.max_options as i32 * item_h;
        let target_item_y = (self.selected as i32 - 1) * item_h;

        if content_h > visible_h {
            let max_scroll = content_h - visible_h;
            if target_item_y < self.scroll_offset as i32 {
                self.scroll_target = target_item_y as f32;
            } else if target_item_y + item_h > self.scroll_offset as i32 + visible_h {
                self.scroll_target = (target_item_y - visible_h + item_h) as f32;
            }
            self.scroll_target = self.scroll_target.clamp(0.0, max_scroll as f32);
        } else {
            self.scroll_target = 0.0;
        }

        self.scroll_offset += (self.scroll_target - self.scroll_offset) * (12.0 * dt).min(1.0);
        self.highlight_y =
            150.0 + (self.selected as f32 - 1.0) * item_h as f32 - 9.0 - self.scroll_offset;

        for i in 0..self.max_options {
            let target = if i + 1 == self.selected { 1.0 } else { 0.0 };
            self.item_glows[i] += (target - self.item_glows[i]) * (8.0 * dt).min(1.0);
        }
    }

    fn draw(&mut self, eng: &mut dyn Engine) {
        eng.clear(5, 5, 12, 255);

        let grid_size = 80;
        let off_x = (self.bg_scroll % grid_size as f32) as i32;
        let off_y = (self.bg_scroll * 0.4 % grid_size as f32) as i32;

        let mut y = off_y;
        while y < config::SCREEN_HEIGHT {
            let a = (12.0 + 8.0 * (self.timer * 0.5 + y as f32 * 0.01).sin()) as u8;
            eng.line(0, y, config::SCREEN_WIDTH, y, 90, 130, 255, a);
            y += grid_size;
        }
        let mut x = off_x;
        while x < config::SCREEN_WIDTH {
            let a = (12.0 + 8.0 * (self.timer * 0.5 + x as f32 * 0.01).cos()) as u8;
            eng.line(x, 0, x, config::SCREEN_HEIGHT, 90, 130, 255, a);
            x += grid_size;
        }

        draw::static_noise(
            eng,
            0,
            0,
            config::SCREEN_WIDTH,
            config::SCREEN_HEIGHT,
            0.006,
        );

        let panel_x = 40;
        let panel_y = 30;
        let panel_w = config::SCREEN_WIDTH - 80;
        let panel_h = config::SCREEN_HEIGHT - 70;
        eng.draw_rect(panel_x, panel_y, panel_w, panel_h, 20, 25, 45, 180, true);
        let border_pulse = 0.5 + 0.5 * (self.timer * 1.2).sin();
        let border_a = (30.0 + 15.0 * border_pulse) as u8;
        eng.draw_rect(
            panel_x - 2,
            panel_y - 2,
            panel_w + 4,
            panel_h + 4,
            100,
            180,
            255,
            border_a,
            false,
        );

        draw::text(
            eng,
            &localization::text("options"),
            70,
            56,
            42,
            255,
            255,
            255,
            255,
            false,
        );
        draw::text(
            eng,
            "SYSTEM CONFIGURATION",
            72,
            98,
            12,
            100,
            180,
            255,
            180,
            false,
        );

        let hl_y = self.highlight_y as i32;
        let hl_pulse = 0.8 + 0.2 * (self.timer * 5.0).sin();
        eng.draw_rect(
            65,
            hl_y,
            panel_w - 50,
            46,
            100,
            180,
            255,
            (35.0 * hl_pulse) as u8,
            false,
        );
        eng.draw_rect(65, hl_y, 4, 46, 100, 180, 255, 255, true);

        for i in 0..self.max_options {
            let y = 150 + i as i32 * 50 - self.scroll_offset as i32;
            if !(130..=config::SCREEN_HEIGHT - 80).contains(&y) {
                continue;
            }
            let glow = self.item_glows[i];
            let tc = lerp(140.0, 255.0, glow) as i32 as u8;
            let opt = &self.options[i];
            draw::text(
                eng,
                &opt.label,
                80,
                y,
                24,
                tc,
                tc,
                tc.saturating_add((20.0 * glow) as u8),
                255,
                false,
            );

            match opt.kind {
                OptionKind::Toggle => {
                    let val_text = format!("< {} >", opt.values[opt.current]);
                    let (vr, vg, vb) = if i + 1 == self.selected {
                        (100, 220, 255)
                    } else {
                        (70, 150, 180)
                    };
                    draw::text(eng, &val_text, 500, y + 2, 22, vr, vg, vb, 255, false);
                },
                OptionKind::Bool => {
                    let (mut vr, mut vg, mut vb) = if opt.value {
                        (100, 255, 150)
                    } else {
                        (255, 100, 120)
                    };
                    if i + 1 != self.selected {
                        vr = (vr as f32 * 0.6) as u8;
                        vg = (vg as f32 * 0.6) as u8;
                        vb = (vb as f32 * 0.6) as u8;
                    }
                    let val_text = if opt.value {
                        localization::text("on")
                    } else {
                        localization::text("off")
                    };
                    draw::text(eng, &val_text, 500, y + 2, 22, vr, vg, vb, 255, false);
                },
                OptionKind::Slider => {
                    let bar_x = 500;
                    let bar_w = 200;
                    let bar_h = 10;
                    let bar_y = y + 12;
                    eng.draw_rect(bar_x, bar_y, bar_w, bar_h, 40, 50, 70, 255, true);
                    let fill_w =
                        (bar_w as f32 * opt.slider_value as f32 / opt.slider_max as f32) as i32;
                    let (sr, sg, sb) = if i + 1 == self.selected {
                        (140, 230, 255)
                    } else {
                        (100, 180, 220)
                    };
                    eng.draw_rect(bar_x, bar_y, fill_w, bar_h, sr, sg, sb, 255, true);
                    eng.draw_rect(
                        bar_x + fill_w - 4,
                        bar_y - 3,
                        8,
                        16,
                        255,
                        255,
                        255,
                        255,
                        true,
                    );
                    draw::text(
                        eng,
                        &format!("{}%", opt.slider_value),
                        bar_x + bar_w + 15,
                        y + 2,
                        20,
                        tc,
                        tc,
                        tc.saturating_add((20.0 * glow) as u8),
                        255,
                        false,
                    );
                },
                OptionKind::Action => {},
            }
        }

        draw::text(
            eng,
            &localization::text("help_input"),
            70,
            config::SCREEN_HEIGHT - 55,
            14,
            90,
            110,
            140,
            180,
            false,
        );
        draw::scanlines(eng, 0, 0, config::SCREEN_WIDTH, config::SCREEN_HEIGHT, 14);
    }

    fn is_done(&self) -> bool {
        self.done
    }

    fn result(&self) -> &str {
        &self.m_result
    }

    fn state_type(&self) -> StateType {
        StateType::Options
    }
}
