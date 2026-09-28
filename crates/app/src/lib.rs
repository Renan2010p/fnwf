#![warn(missing_docs)]
//! Five Nights With Friends — Classic Edition (Rust).
//!
//! Application shell and top-level transition table. Owns the engine, the
//! state machine and the small amount of cross-state progress data.
//!
//! On desktop, [`run_native`] runs the classic blocking game loop. In the
//! browser, `fnwf_app::web::start` drives the same `build_app` app from
//! `requestAnimationFrame`.

use fnwf_core::state::{GameState, StateMachine};
use fnwf_core::{audio, config, draw, localization, save, settings};
use fnwf_engine::{Engine, EventType};

use fnwf_game::states::arcade::ArcadeState;
use fnwf_game::states::conquistas::ConquistasState;
use fnwf_game::states::custom_night::CustomNightState;
use fnwf_game::states::extras::ExtrasState;
use fnwf_game::states::game_over::GameOverState;
use fnwf_game::states::gameplay::GameplayState;
use fnwf_game::states::loading::LoadingState;
use fnwf_game::states::menu::MenuState;
use fnwf_game::states::newspaper::NewspaperState;
use fnwf_game::states::options::OptionsState;
use fnwf_game::states::paycheck::PaycheckState;
use fnwf_game::states::six_am::SixAMState;
use fnwf_game::states::story::StoryState;
use fnwf_game::states::warning::WarningState;

const SPRITE_PRELOAD_MENU: [&str; 5] = ["cedro", "eser", "alice", "Sonk", "mafia"];
const SPRITE_PRELOAD_GAME: [&str; 4] = ["cedro", "eser", "alice", "Sonk"];

struct App {
    eng: Box<dyn Engine>,
    sm: StateMachine,
    state_name: &'static str,

    pending_night: i32,
    pending_custom_ai: Vec<i32>,
    pending_preload: Vec<String>,

    completed_nights: i32,
    has_seen_story: bool,
    achievements: Vec<String>,
    infinite_power: bool,
    fast_nights: bool,

    testing_office: bool,
    last_time: f32,
    fps_timer: f32,
    fps_frames: i32,
    fps_value: i32,
}

impl App {
    fn switch_state(&mut self, name: &'static str, state: Box<dyn GameState>) {
        self.state_name = name;
        self.sm.switch_state(name, state);
    }

    fn make_state(&mut self, name: &'static str) -> Box<dyn GameState> {
        match name {
            "warning" => Box::new(WarningState::new()),
            "menu" => Box::new(MenuState::new(
                &mut *self.eng,
                self.completed_nights,
                self.has_seen_story,
            )),
            "options" => Box::new(OptionsState::new(&mut *self.eng)),
            "custom_night" => Box::new(CustomNightState::new(&mut *self.eng)),
            "newspaper" => Box::new(NewspaperState::new()),
            "paycheck" => Box::new(PaycheckState::new()),
            "conquistas" => Box::new(ConquistasState::new(&self.achievements)),
            "extras" => Box::new(ExtrasState::new(
                &mut *self.eng,
                self.infinite_power,
                self.fast_nights,
                &self.achievements,
            )),
            "story" => Box::new(StoryState::new(&mut *self.eng, self.pending_night)),
            "transition" => Box::new(
                fnwf_game::states::night_transition::NightTransitionState::new(
                    &mut *self.eng,
                    self.pending_night,
                ),
            ),
            "six_am" => Box::new(SixAMState::new(self.pending_night)),
            "gameover" => Box::new(GameOverState::new(false, self.pending_night)),
            "loading" => {
                let mut loader = LoadingState::new();
                loader.set_preload(self.pending_preload.clone());
                Box::new(loader)
            },
            "game" => {
                let ai = if self.pending_night == 7 && self.pending_custom_ai.len() >= 4 {
                    Some(self.pending_custom_ai.clone())
                } else {
                    None
                };
                Box::new(GameplayState::new(
                    &mut *self.eng,
                    self.pending_night,
                    ai.as_deref(),
                ))
            },
            "arcade" => Box::new(ArcadeState::new(&mut *self.eng)),
            _ => Box::new(MenuState::new(
                &mut *self.eng,
                self.completed_nights,
                self.has_seen_story,
            )),
        }
    }

    fn do_switch(&mut self, name: &'static str) {
        let state = self.make_state(name);
        self.switch_state(name, state);
    }

    fn switch_loading(&mut self, preload: &[&str]) {
        self.pending_preload = preload.iter().map(|s| s.to_string()).collect();
        self.do_switch("loading");
    }

    fn transition(&mut self) {
        let (result, six_am_night, go_win, go_night, custom_ai) = {
            let cur = self.sm.current().expect("no current state");
            (
                cur.result().to_string(),
                cur.six_am_night(),
                cur.game_over_win(),
                cur.game_over_night(),
                cur.custom_ai_levels(),
            )
        };

        match self.state_name {
            "warning" => {
                self.switch_loading(&SPRITE_PRELOAD_MENU);
                self.state_name = "loading_menu";
            },
            "loading_menu" => {
                audio::stop_menu_ambient(&mut *self.eng);
                self.do_switch("menu");
            },
            "menu" => match result.as_str() {
                "start" => {
                    self.pending_night = 1;
                    self.do_switch("story");
                },
                "continue" => {
                    self.pending_night = (self.completed_nights + 1).min(6);
                    self.do_switch("story");
                },
                "night6" => {
                    self.pending_night = 6;
                    self.do_switch("story");
                },
                "night7" => self.do_switch("custom_night"),
                "extras" => self.do_switch("extras"),
                "options" => self.do_switch("options"),
                "conquistas" => self.do_switch("conquistas"),
                "arcade" => self.do_switch("arcade"),
                "quit" => self.eng.request_stop(),
                _ => {},
            },
            "extras" | "conquistas" | "options" => {
                let cheats = self.sm.current().and_then(|c| c.extras_cheats());
                if let Some((ip, fst)) = cheats {
                    self.infinite_power = ip;
                    self.fast_nights = fst;
                    self.persist_progress();
                }
                self.do_switch("menu");
            },
            "arcade" => match result.as_str() {
                "arcade_die" => {
                    self.pending_night = 0;
                    self.do_switch("gameover");
                },
                _ => self.do_switch("menu"),
            },
            "story" => {
                self.switch_loading(&SPRITE_PRELOAD_GAME);
            },
            "transition" => {
                self.switch_loading(&SPRITE_PRELOAD_GAME);
            },
            "loading" => {
                self.do_switch("game");
            },
            "game" => match result.as_str() {
                "win" => {
                    if self.pending_night >= 1 {
                        push_unique(&mut self.achievements, "survive_n1");
                    }
                    if self.pending_night >= 5 {
                        push_unique(&mut self.achievements, "survive_n5");
                    }
                    if self.pending_night >= 6 {
                        push_unique(&mut self.achievements, "survive_n6");
                    }
                    if self.pending_night >= 7 {
                        push_unique(&mut self.achievements, "survive_n7");
                    }
                    self.completed_nights = self.completed_nights.max(self.pending_night);
                    self.has_seen_story = true;
                    self.persist_progress();
                    self.do_switch("six_am");
                },
                "jumpscare" => {
                    self.do_switch("gameover");
                },
                "menu" => self.do_switch("menu"),
                _ => {},
            },
            "six_am" => {
                if six_am_night == Some(5) {
                    self.do_switch("paycheck");
                } else {
                    self.do_switch("menu");
                }
            },
            "paycheck" => self.do_switch("newspaper"),
            "newspaper" => self.do_switch("menu"),
            "gameover" => {
                if go_win == Some(true) || go_night == Some(0) {
                    self.do_switch("menu");
                } else {
                    self.do_switch("newspaper");
                }
            },
            "custom_night" => {
                if result == "start" {
                    self.pending_custom_ai = custom_ai.unwrap_or_default();
                    self.pending_night = 7;
                    self.switch_loading(&SPRITE_PRELOAD_GAME);
                } else {
                    self.do_switch("menu");
                }
            },
            _ => {},
        }
    }

    fn persist_progress(&self) {
        save::save_progress(
            self.completed_nights,
            self.has_seen_story,
            self.infinite_power,
            self.fast_nights,
            &self.achievements,
        );
    }

    fn iteration(&mut self) {
        if !self.eng.keeps_running() {
            return;
        }

        let current_time = self.eng.ticks() / 1000.0;
        let dt = current_time - self.last_time;
        self.last_time = current_time;
        self.fps_timer += dt;
        self.fps_frames += 1;
        if self.fps_timer >= 0.25 {
            self.fps_value = (self.fps_frames as f32 / self.fps_timer + 0.5) as i32;
            self.fps_timer = 0.0;
            self.fps_frames = 0;
        }

        let events = self.eng.poll_events();
        for ev in &events {
            if ev.kind == EventType::Quit {
                self.eng.request_stop();
            }
            self.sm.handle_event(&mut *self.eng, ev);
        }

        self.sm.update(&mut *self.eng, dt);

        if self.sm.current().map(|c| c.is_done()).unwrap_or(false) {
            self.transition();
        }

        self.sm.draw(&mut *self.eng);

        if self.testing_office {
            draw::text(
                &mut *self.eng,
                "TEST MODE",
                60,
                20,
                20,
                255,
                70,
                70,
                255,
                false,
            );
            draw::text(
                &mut *self.eng,
                "FAST OFFICE - 3D BUILD",
                60,
                42,
                12,
                255,
                150,
                150,
                200,
                false,
            );
        }

        if settings::get().show_fps {
            let label =
                localization::text("fps_counter").replace("%d", &self.fps_value.to_string());
            draw::text(
                &mut *self.eng,
                &label,
                config::SCREEN_WIDTH - 110,
                16,
                16,
                130,
                255,
                170,
                255,
                false,
            );
        }

        self.eng.present();
    }
}

fn push_unique(list: &mut Vec<String>, value: &str) {
    if !list.iter().any(|v| v == value) {
        list.push(value.to_string());
    }
}

fn show_startup_spinner(eng: &mut dyn Engine) {
    let cx = config::SCREEN_WIDTH / 2;
    let cy = config::SCREEN_HEIGHT / 2;
    for frame in 0..4 {
        eng.clear(3, 3, 5, 255);
        let base = frame as f32 * 30.0_f32.to_radians();
        for i in 0..8 {
            let t = base + i as f32 * 45.0_f32.to_radians();
            eng.line(
                cx + (t.cos() * 26.0) as i32,
                cy - 20 + (t.sin() * 26.0) as i32,
                cx + (t.cos() * 34.0) as i32,
                cy - 20 + (t.sin() * 34.0) as i32,
                170,
                170,
                180,
                255,
            );
        }
        eng.draw_rect(cx - 160, cy + 40, 320, 10, 30, 30, 36, 255, true);
        eng.draw_rect(
            cx - 158,
            cy + 42,
            (316.0 * (frame + 1) as f32 / 4.0) as i32,
            6,
            150,
            150,
            160,
            255,
            true,
        );
        eng.draw_rect(cx - 160, cy + 40, 320, 10, 90, 90, 100, 255, false);
        eng.present();
    }
}

fn preload_assets(eng: &mut dyn Engine) {
    let sprites = ["cedro", "eser", "alice", "Sonk", "mafia", "renan"];
    let total = sprites.len() as i32;
    let cx = config::SCREEN_WIDTH / 2;
    let cy = config::SCREEN_HEIGHT / 2;
    for (i, name) in sprites.iter().enumerate() {
        eng.clear(3, 3, 5, 255);
        draw::text(
            eng,
            "FIVE NIGHTS WITH FRIENDS",
            cx,
            cy - 60,
            30,
            220,
            220,
            220,
            255,
            true,
        );
        draw::text(
            eng,
            &localization::text("loading"),
            cx,
            cy,
            18,
            170,
            170,
            180,
            255,
            true,
        );
        let bw = 420;
        let bh = 10;
        let bx = cx - bw / 2;
        let by = cy + 50;
        eng.draw_rect(bx, by, bw, bh, 30, 30, 36, 220, true);
        eng.draw_rect(
            bx + 2,
            by + 2,
            (bw - 4) * (i as i32 + 1) / total,
            bh - 4,
            150,
            150,
            160,
            255,
            true,
        );
        eng.draw_rect(bx, by, bw, bh, 90, 90, 100, 255, false);
        eng.present();
        draw::load_sprite(eng, name);
    }
    audio::preload_all(eng);
}

/// Builds the engine for the current target.
#[cfg(not(target_arch = "wasm32"))]
fn make_engine() -> Box<dyn Engine> {
    fnwf_backend_sdl2::create_engine()
}

/// Builds the engine for the current target.
#[cfg(target_arch = "wasm32")]
fn make_engine() -> Box<dyn Engine> {
    fnwf_backend_web::create_engine()
}

/// Initializes the engine, preloads assets and creates the app ready to run.
///
/// Returns `None` if the engine could not be initialized.
fn build_app(testing_office: bool) -> Option<App> {
    let mut eng = make_engine();
    if !eng.init(
        "Five Nights With Friends",
        config::SCREEN_WIDTH as u32,
        config::SCREEN_HEIGHT as u32,
        false,
        true,
    ) {
        return None;
    }
    eng.set_logical_size(config::SCREEN_WIDTH as u32, config::SCREEN_HEIGHT as u32);
    show_startup_spinner(&mut *eng);
    draw::set_fonts(&mut *eng);

    let settings_data = settings::get();
    localization::set_language(&settings_data.language);
    draw::set_render_quality(&settings_data.quality);

    preload_assets(&mut *eng);

    let data = save::load_data();

    let mut app = App {
        eng,
        sm: StateMachine::new(),
        state_name: "warning",
        pending_night: 1,
        pending_custom_ai: Vec::new(),
        pending_preload: Vec::new(),
        completed_nights: data.completed_nights,
        has_seen_story: data.has_seen_story,
        achievements: data.achievements,
        infinite_power: data.infinite_power,
        fast_nights: data.fast_nights,
        testing_office,
        last_time: 0.0,
        fps_timer: 0.0,
        fps_frames: 0,
        fps_value: 0,
    };

    app.last_time = app.eng.ticks() / 1000.0;

    if testing_office {
        app.pending_night = 1;
        app.do_switch("game");
    } else {
        app.do_switch("warning");
    }

    Some(app)
}

/// Runs the game with the native blocking loop (desktop).
#[cfg(not(target_arch = "wasm32"))]
pub fn run_native() {
    let testing_office = std::env::args()
        .skip(1)
        .any(|a| a == "-o" || a == "--office");

    let Some(mut app) = build_app(testing_office) else {
        eprintln!("Engine init failed");
        return;
    };

    while app.eng.keeps_running() {
        app.iteration();
    }
    app.eng.shutdown();
}

/// Web entry point: drives the game from `requestAnimationFrame` instead of a
/// blocking loop, since the browser owns the event loop.
/// Web entry point.
#[cfg(target_arch = "wasm32")]
pub mod web {
    use super::*;
    use std::cell::RefCell;
    use std::rc::Rc;
    use wasm_bindgen::prelude::*;
    use wasm_bindgen::JsCast;

    /// Self-referential holder for the `requestAnimationFrame` callback.
    type FrameCallback = Rc<RefCell<Option<Closure<dyn FnMut()>>>>;

    /// Boots the game and schedules the first animation frame.
    #[wasm_bindgen(start)]
    pub fn start() -> Result<(), JsValue> {
        let Some(app) = build_app(false) else {
            return Err(JsValue::from_str("engine init failed"));
        };
        let app = Rc::new(RefCell::new(app));

        // The closure owns `f`, which keeps it alive for the lifetime of the
        // page (the standard wasm-bindgen rAF pattern).
        let f: FrameCallback = Rc::new(RefCell::new(None));
        let g = f.clone();
        *g.borrow_mut() = Some(Closure::wrap(Box::new(move || {
            let mut app = app.borrow_mut();
            if !app.eng.keeps_running() {
                return;
            }
            app.iteration();
            drop(app);
            request_animation_frame(f.borrow().as_ref().unwrap());
        }) as Box<dyn FnMut()>));

        request_animation_frame(g.borrow().as_ref().unwrap());
        Ok(())
    }

    fn request_animation_frame(callback: &Closure<dyn FnMut()>) {
        if let Some(window) = web_sys::window() {
            let _ = window.request_animation_frame(callback.as_ref().unchecked_ref());
        }
    }
}
