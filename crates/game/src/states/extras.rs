//! Extras: animatronic bios, credits, modifiers and achievements.
//!
//! A four-tab gallery navigated with the arrow keys. The third tab toggles the
//! infinite-power and fast-night modifiers, which are reported through the
//! state's `extras_cheats`. Escape or a click on the bottom bar returns to the
//! menu with result `"menu"`.

#[allow(unused_imports)]
use fnwf_core::prelude::*;

use fnwf_engine::{keys, Engine, Event, EventType, TextureHandle};

use fnwf_core::state::{GameState, StateType};
use fnwf_core::{audio, config, draw, localization};

use crate::colors;

struct AnimData {
    name: &'static str,
    sprite: &'static str,
    desc: String,
}

struct AchData {
    id: &'static str,
    name: String,
    desc: String,
}

/// The extras gallery screen.
pub struct ExtrasState {
    timer: f32,
    done: bool,
    m_result: String,
    category: usize,
    anim_idx: usize,
    selected: usize,

    categories: Vec<String>,
    animatronics: Vec<AnimData>,
    sprites: Vec<(&'static str, TextureHandle)>,
    achievements_list: Vec<AchData>,

    infinite_power: bool,
    fast_nights: bool,
    unlocked_achievements: Vec<String>,
}

impl ExtrasState {
    /// Creates the screen, loading bios/portraits and seeding the current cheat
    /// toggles and unlocked achievement ids.
    pub fn new(
        eng: &mut dyn Engine,
        infinite_power: bool,
        fast_nights: bool,
        achievements: &[String],
    ) -> Self {
        let categories = vec![
            localization::text("cat_animatronics"),
            localization::text("cat_credits"),
            localization::text("cat_cheats"),
            localization::text("cat_achievements"),
        ];
        let animatronics = vec![
            AnimData {
                name: "Cedro",
                sprite: "cedro",
                desc: localization::text("cedro_desc"),
            },
            AnimData {
                name: "Eser",
                sprite: "eser",
                desc: localization::text("eser_desc"),
            },
            AnimData {
                name: "Alice",
                sprite: "alice",
                desc: localization::text("alice_desc"),
            },
            AnimData {
                name: "Renan",
                sprite: "renan",
                desc: localization::text("renan_desc"),
            },
        ];
        let mut sprites = Vec::new();
        for a in &animatronics {
            draw::load_sprite(eng, a.sprite);
            if let Some(tex) = draw::get_sprite(a.sprite) {
                sprites.push((a.sprite, tex));
            }
        }

        let achievements_list = vec![
            AchData {
                id: "survive_n1",
                name: localization::text("night_1_ach_title"),
                desc: localization::text("night_1_ach_desc"),
            },
            AchData {
                id: "survive_n5",
                name: localization::text("night_5_ach_title"),
                desc: localization::text("night_5_ach_desc"),
            },
            AchData {
                id: "survive_n6",
                name: localization::text("night_6_ach_title"),
                desc: localization::text("night_6_ach_desc"),
            },
            AchData {
                id: "survive_n7",
                name: localization::text("night_7_ach_title"),
                desc: localization::text("night_7_ach_desc"),
            },
        ];

        Self {
            timer: 0.0,
            done: false,
            m_result: String::new(),
            category: 1,
            anim_idx: 1,
            selected: 1,
            categories,
            animatronics,
            sprites,
            achievements_list,
            infinite_power,
            fast_nights,
            unlocked_achievements: achievements.to_vec(),
        }
    }
}

impl GameState for ExtrasState {
    fn handle_event(&mut self, eng: &mut dyn Engine, ev: &Event) {
        if ev.kind == EventType::KeyDown {
            let k = ev.key;
            let ncat = self.categories.len();
            if k == keys::ESCAPE {
                self.m_result = "menu".to_string();
                self.done = true;
                audio::play(eng, "select", 0, -1);
            } else if k == keys::LEFT || k == keys::A {
                self.category = (self.category + ncat - 2) % ncat + 1;
                self.selected = 1;
                audio::play(eng, "blip", 0, -1);
            } else if k == keys::RIGHT || k == keys::D {
                self.category = self.category % ncat + 1;
                self.selected = 1;
                audio::play(eng, "blip", 0, -1);
            }

            if self.category == 1 {
                let n = self.animatronics.len();
                if k == keys::UP || k == keys::W {
                    self.anim_idx = (self.anim_idx + n - 2) % n + 1;
                    audio::play(eng, "blip", 0, -1);
                } else if k == keys::DOWN || k == keys::S {
                    self.anim_idx = self.anim_idx % n + 1;
                    audio::play(eng, "blip", 0, -1);
                }
            } else if self.category == 3 {
                if k == keys::UP || k == keys::W {
                    self.selected = (self.selected + 1) % 2 + 1;
                    audio::play(eng, "blip", 0, -1);
                } else if k == keys::DOWN || k == keys::S {
                    self.selected = self.selected % 2 + 1;
                    audio::play(eng, "blip", 0, -1);
                } else if k == keys::RETURN || k == keys::SPACE {
                    if self.selected == 1 {
                        self.infinite_power = !self.infinite_power;
                    } else {
                        self.fast_nights = !self.fast_nights;
                    }
                    audio::play(eng, "select", 0, -1);
                }
            }
        }

        if ev.kind == EventType::MouseButtonDown {
            if ev.y >= config::SCREEN_HEIGHT - 50 {
                self.m_result = "menu".to_string();
                self.done = true;
                audio::play(eng, "select", 0, -1);
                return;
            }
            let ncat = self.categories.len();
            if ev.x < config::SCREEN_WIDTH / 2 {
                self.category = (self.category + ncat - 2) % ncat + 1;
            } else {
                self.category = self.category % ncat + 1;
            }
            self.selected = 1;
            audio::play(eng, "blip", 0, -1);
        }
    }

    fn update(&mut self, _eng: &mut dyn Engine, dt: f32) {
        self.timer += dt;
    }

    fn draw(&mut self, eng: &mut dyn Engine) {
        eng.clear(5, 5, 10, 255);
        draw::static_noise(eng, 0, 0, config::SCREEN_WIDTH, config::SCREEN_HEIGHT, 0.01);

        for (i, cat) in self.categories.iter().enumerate() {
            let is_sel = i + 1 == self.category;
            let (r, g, b) = if is_sel {
                (255, 255, 255)
            } else {
                (100, 100, 110)
            };
            draw::text(eng, cat, 80 + i as i32 * 230, 40, 20, r, g, b, 255, false);
            if is_sel {
                eng.draw_rect(80 + i as i32 * 230, 65, 80, 2, 255, 255, 255, 255, true);
            }
        }

        match self.category {
            1 => self.draw_animatronics(eng),
            2 => draw_credits(eng),
            3 => self.draw_cheats(eng),
            4 => self.draw_achievements(eng),
            _ => {},
        }

        draw::text(
            eng,
            &localization::text("extras_help"),
            80,
            config::SCREEN_HEIGHT - 40,
            14,
            150,
            150,
            160,
            255,
            false,
        );
        draw::scanlines(eng, 0, 0, config::SCREEN_WIDTH, config::SCREEN_HEIGHT, 10);
    }

    fn is_done(&self) -> bool {
        self.done
    }

    fn result(&self) -> &str {
        &self.m_result
    }

    fn state_type(&self) -> StateType {
        StateType::Extras
    }

    fn extras_cheats(&self) -> Option<(bool, bool)> {
        Some((self.infinite_power, self.fast_nights))
    }
}

impl ExtrasState {
    fn draw_animatronics(&mut self, eng: &mut dyn Engine) {
        let a = &self.animatronics[self.anim_idx - 1];
        let img_x = 90;
        let img_y = 140;
        let img_w = 520;
        let img_h = 520;
        let text_x = 660;
        let text_w = config::SCREEN_WIDTH - text_x - 80;

        eng.draw_rect(
            img_x - 8,
            img_y - 8,
            img_w + 16,
            img_h + 16,
            65,
            80,
            110,
            255,
            false,
        );
        if let Some((_, tex)) = self.sprites.iter().find(|(n, _)| *n == a.sprite) {
            draw::rounded_texture(eng, tex, img_x, img_y, img_w, img_h, 20, 10, 10, 16, 255);
        }

        draw::text(
            eng,
            a.name,
            text_x,
            160,
            56,
            colors::TITLE_COLOR.r,
            colors::TITLE_COLOR.g,
            colors::TITLE_COLOR.b,
            255,
            false,
        );

        let words: Vec<&str> = a.desc.split(' ').collect();
        let mut line = String::new();
        let mut ly = 250;
        let mut count = 0;
        for word in words {
            let test = if line.is_empty() {
                word.to_string()
            } else {
                format!("{line} {word}")
            };
            let tw = eng
                .font_text_size(&test, 20)
                .map(|(w, _)| w)
                .unwrap_or_else(|| test.len() as i32 * 10);
            if tw <= text_w {
                line = test;
            } else {
                draw::text(eng, &line, text_x, ly, 20, 255, 255, 255, 255, false);
                ly += 34;
                line = word.to_string();
                count += 1;
                if count >= 7 {
                    break;
                }
            }
        }
        if !line.is_empty() && count < 8 {
            draw::text(eng, &line, text_x, ly, 20, 255, 255, 255, 255, false);
        }

        draw::text(
            eng,
            &format!("{} / {}", self.anim_idx, self.animatronics.len()),
            img_x,
            img_y + img_h + 18,
            16,
            180,
            180,
            180,
            255,
            false,
        );
    }

    fn draw_cheats(&self, eng: &mut dyn Engine) {
        let cl = [
            (localization::text("cheat_energy"), self.infinite_power),
            (localization::text("cheat_fast"), self.fast_nights),
        ];
        for (i, (label, on)) in cl.iter().enumerate() {
            let is_sel = i + 1 == self.selected;
            let (r, g, b) = if is_sel {
                (255, 255, 255)
            } else {
                (120, 120, 130)
            };
            let prefix = if is_sel { ">> " } else { "   " };
            draw::text(
                eng,
                &format!("{prefix}{label}"),
                100,
                250 + i as i32 * 60,
                28,
                r,
                g,
                b,
                255,
                false,
            );

            let (sr, sg, sb) = if *on {
                (100, 255, 100)
            } else {
                (255, 100, 100)
            };
            let st = if *on {
                localization::text("on")
            } else {
                localization::text("off")
            };
            let (dr, dg, db) = if is_sel { (sr, sg, sb) } else { (r, g, b) };
            draw::text(
                eng,
                &st,
                450,
                250 + i as i32 * 60,
                28,
                dr,
                dg,
                db,
                255,
                false,
            );
        }
    }

    fn draw_achievements(&self, eng: &mut dyn Engine) {
        for (i, ach) in self.achievements_list.iter().enumerate() {
            let y = 220 + i as i32 * 80;
            let un = self.unlocked_achievements.iter().any(|id| id == ach.id);
            let (sr, sg, sb) = if un {
                (
                    colors::STAR_COLOR.r,
                    colors::STAR_COLOR.g,
                    colors::STAR_COLOR.b,
                )
            } else {
                (50, 50, 60)
            };
            let star = if un { "\u{2605}" } else { "\u{2606}" };
            draw::text(eng, star, 80, y, 30, sr, sg, sb, 255, false);
            let (nr, ng, nb) = if un { (255, 255, 255) } else { (60, 60, 70) };
            draw::text(eng, &ach.name, 130, y, 24, nr, ng, nb, 255, false);
            let (dr, dg, db) = if un { (120, 120, 130) } else { (40, 40, 45) };
            draw::text(eng, &ach.desc, 130, y + 30, 16, dr, dg, db, 255, false);
        }
    }
}

fn draw_credits(eng: &mut dyn Engine) {
    let y = 200;
    draw::text(
        eng,
        "FIVE NIGHTS WITH FRIENDS",
        config::SCREEN_WIDTH / 2,
        y,
        40,
        colors::TITLE_COLOR.r,
        colors::TITLE_COLOR.g,
        colors::TITLE_COLOR.b,
        255,
        true,
    );
    draw::text(
        eng,
        &localization::text("created_by"),
        config::SCREEN_WIDTH / 2,
        y + 60,
        24,
        255,
        255,
        255,
        255,
        true,
    );
    draw::text(
        eng,
        "Renan Lucas",
        config::SCREEN_WIDTH / 2,
        y + 110,
        50,
        100,
        200,
        255,
        255,
        true,
    );
    draw::text(
        eng,
        &localization::text("special_thanks"),
        config::SCREEN_WIDTH / 2,
        y + 300,
        18,
        180,
        180,
        180,
        255,
        true,
    );
    draw::text(
        eng,
        "Scott Cawthon (FNAF Original)",
        config::SCREEN_WIDTH / 2,
        y + 330,
        18,
        255,
        255,
        255,
        255,
        true,
    );
}
