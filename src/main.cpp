// Five Nights With Friends 1 — Pure C++23 entry point.
#include "core/DrawUtils.hpp"
#include "core/GameState.hpp"
#include "core/Localization.hpp"
#include "core/MobileUI.hpp"
#include "core/SaveManager.hpp"
#include "core/SettingsManager.hpp"
#include "core/SoundManager.hpp"
#include "core/StateMachine.hpp"
#include "engine/Engine.hpp"
#include "game1/GameSettings.hpp"
#include "game1/states/ArcadeState.hpp"
#include "game1/states/ConquistasState.hpp"
#include "game1/states/CustomNightState.hpp"
#include "game1/states/ExtrasState.hpp"
#include "game1/states/GameOverState.hpp"
#include "game1/states/GameplayState.hpp"
#include "game1/states/LoadingState.hpp"
#include "game1/states/MenuState.hpp"
#include "game1/states/NewspaperState.hpp"
#include "game1/states/NightTransitionState.hpp"
#include "game1/states/OptionsState.hpp"
#include "game1/states/PaycheckState.hpp"
#include "game1/states/SixAMState.hpp"
#include "game1/states/StoryState.hpp"
#include "game1/states/WarningState.hpp"

#include <cstdio>
#include <memory>
#include <string>
#include <vector>

#ifdef __EMSCRIPTEN__
#include <emscripten.h>
#include <emscripten/html5.h>
#endif

// --- Global state for Emscripten main loop ---
namespace {

struct GameState {
    fnwf::Engine* eng{nullptr};
    fnwf::StateMachine* sm{nullptr};
    std::string state_name;
    bool test_office{false};
    int pending_night{1};
    std::vector<int> pending_custom_ai{};
    double last_time{0.0};
    double fps_timer{0.0};
    int fps_frames{0};
    int fps_value{0};
    int completed_nights{0};
    bool has_seen_story{false};
    std::vector<std::string> achievements{};
    fnwf::GameData save_data{};
};

GameState g;

void do_switch(const std::string& name) {
    g.state_name = name;
    auto& eng = *g.eng;
    auto& sm = *g.sm;

    if (name == "warning") {
        eng.update_discord(fnwf::Localization::get_text("discord_status_menu"),
                           "Five Nights With Friends Classic Edition");
        sm.switch_state(
            "warning", [](fnwf::Engine& e) { return std::make_unique<fnwf::WarningState>(e); });
    } else if (name == "menu") {
        eng.update_discord("No Menu", "Menu Principal");
        sm.switch_state("menu", [&](fnwf::Engine& e) {
            return std::make_unique<fnwf::MenuState>(g.completed_nights, g.has_seen_story, e);
        });
    } else if (name == "options") {
        sm.switch_state(
            "options", [](fnwf::Engine& e) { return std::make_unique<fnwf::OptionsState>(e); });
    } else if (name == "custom_night") {
        eng.update_discord(fnwf::Localization::get_text("discord_status_custom_night"),
                           "Five Nights With Friends Classic Edition");
        sm.switch_state("custom_night", [](fnwf::Engine& e) {
            return std::make_unique<fnwf::CustomNightState>(e);
        });
    } else if (name == "newspaper") {
        sm.switch_state("newspaper", [](fnwf::Engine& e) {
            return std::make_unique<fnwf::NewspaperState>(e);
        });
    } else if (name == "paycheck") {
        sm.switch_state("paycheck", [](fnwf::Engine& e) {
            return std::make_unique<fnwf::PaycheckState>(e);
        });
    } else if (name == "conquistas") {
        sm.switch_state("conquistas", [&](fnwf::Engine& e) {
            return std::make_unique<fnwf::ConquistasState>(g.achievements, e);
        });
    } else if (name == "extras") {
        sm.switch_state("extras", [&](fnwf::Engine& e) {
            return std::make_unique<fnwf::ExtrasState>(g.completed_nights,
                                                       g.save_data.infinite_power,
                                                       g.save_data.fast_nights,
                                                       g.achievements,
                                                       e);
        });
    }
}

void game_loop_iter() {
    if (!g.eng || !g.eng->keeps_running()) {
#ifdef __EMSCRIPTEN__
        emscripten_cancel_main_loop();
#endif
        return;
    }

    auto& eng = *g.eng;
    auto& sm = *g.sm;
    auto& settings = fnwf::SettingsManager::instance();

    double current_time = eng.ticks() / 1000.0;
    double dt = current_time - g.last_time;
    g.last_time = current_time;
    g.fps_timer += dt;
    g.fps_frames++;
    if (g.fps_timer >= 0.25) {
        g.fps_value = static_cast<int>((g.fps_frames / g.fps_timer) + 0.5);
        g.fps_timer = 0;
        g.fps_frames = 0;
    }

    auto events = eng.poll_events();
    for (auto& ev : events) {
        if (ev.type == fnwf::EventType::Quit) {
            eng.request_stop();
        }
        sm.handle_event(ev);
    }

    sm.update(dt);

    // Check state done -> transition
    auto* cur = sm.current();
    if (cur && cur->is_done()) {
        if (g.state_name == "warning") {
            do_switch("menu");
        } else if (g.state_name == "menu") {
            auto& res = cur->result();
            if (res == "start") {
                g.pending_night = 1;
                sm.switch_state("story", [](fnwf::Engine& e) {
                    return std::make_unique<fnwf::StoryState>(1, e);
                });
                g.state_name = "story";
            } else if (res == "continue") {
                g.pending_night = std::min(g.completed_nights + 1, 6);
                sm.switch_state("story", [](fnwf::Engine& e) {
                    return std::make_unique<fnwf::StoryState>(g.pending_night, e);
                });
                g.state_name = "story";
            } else if (res == "night6") {
                g.pending_night = 6;
                sm.switch_state("story", [](fnwf::Engine& e) {
                    return std::make_unique<fnwf::StoryState>(6, e);
                });
                g.state_name = "story";
            } else if (res == "night7") {
                do_switch("custom_night");
            } else if (res == "extras") {
                do_switch("extras");
            } else if (res == "options") {
                do_switch("options");
            } else if (res == "conquistas") {
                do_switch("conquistas");
            } else if (res == "arcade") {
                sm.switch_state("arcade", [](fnwf::Engine& e) {
                    return std::make_unique<fnwf::ArcadeState>(e);
                });
                g.state_name = "arcade";
            } else if (res == "quit") {
                eng.request_stop();
            }
        } else if (g.state_name == "extras" || g.state_name == "conquistas" ||
                   g.state_name == "options") {
            do_switch("menu");
        } else if (g.state_name == "arcade") {
            auto& res = cur->result();
            if (res == "arcade_die") {
                sm.switch_state("gameover", [](fnwf::Engine& e) {
                    return std::make_unique<fnwf::GameOverState>(false, 0, e);
                });
                g.state_name = "gameover";
            } else if (res == "menu") {
                do_switch("menu");
            }
        } else if (g.state_name == "story") {
            sm.switch_state("loading", [](fnwf::Engine& e) {
                auto loader = std::make_unique<fnwf::LoadingState>(e);
                loader->set_factory([](fnwf::Engine& e2) {
                    return std::make_unique<fnwf::GameplayState>(e2, g.pending_night);
                });
                return loader;
            });
            g.state_name = "loading";
        } else if (g.state_name == "transition") {
            sm.switch_state("loading", [](fnwf::Engine& e) {
                auto loader = std::make_unique<fnwf::LoadingState>(e);
                loader->set_factory([](fnwf::Engine& e2) {
                    return std::make_unique<fnwf::GameplayState>(e2, g.pending_night);
                });
                return loader;
            });
            g.state_name = "loading";
        } else if (g.state_name == "loading") {
            sm.switch_state("game", [](fnwf::Engine& e) {
                return std::make_unique<fnwf::GameplayState>(e, g.pending_night);
            });
            g.state_name = "game";
        } else if (g.state_name == "game") {
            auto& res = cur->result();
            if (res == "win") {
                if (g.pending_night >= 1) {
                    g.achievements.push_back("survive_n1");
                }
                if (g.pending_night >= 5) {
                    g.achievements.push_back("survive_n5");
                }
                if (g.pending_night >= 6) {
                    g.achievements.push_back("survive_n6");
                }
                g.completed_nights = std::max(g.completed_nights, g.pending_night);
                g.has_seen_story = true;
                fnwf::SaveManager::save_progress(g.completed_nights,
                                                 g.has_seen_story,
                                                 g.save_data.infinite_power,
                                                 g.save_data.fast_nights,
                                                 g.achievements);
                sm.switch_state("six_am", [](fnwf::Engine& e) {
                    return std::make_unique<fnwf::SixAMState>(g.pending_night, e);
                });
                g.state_name = "six_am";
            } else if (res == "jumpscare") {
                sm.switch_state("gameover", [](fnwf::Engine& e) {
                    return std::make_unique<fnwf::GameOverState>(false, g.pending_night, e);
                });
                g.state_name = "gameover";
            } else if (res == "menu") {
                do_switch("menu");
            }
        } else if (g.state_name == "six_am") {
            auto* six = dynamic_cast<fnwf::SixAMState*>(cur);
            if (six && six->get_night() == 5) {
                do_switch("paycheck");
            } else {
                do_switch("menu");
            }
        } else if (g.state_name == "paycheck") {
            do_switch("newspaper");
        } else if (g.state_name == "newspaper") {
            do_switch("menu");
        } else if (g.state_name == "gameover") {
            auto* go = dynamic_cast<fnwf::GameOverState*>(cur);
            if (go && go->get_is_win()) {
                do_switch("menu");
            } else if (go && go->get_night() == 0) {
                do_switch("menu");
            } else {
                do_switch("newspaper");
            }
        } else if (g.state_name == "custom_night") {
            auto& res = cur->result();
            if (res == "start") {
                auto* cn = dynamic_cast<fnwf::CustomNightState*>(cur);
                if (cn) {
                    g.pending_custom_ai = cn->get_ai_levels();
                    g.pending_night = 7;
                    sm.switch_state("loading", [](fnwf::Engine& e) {
                        auto loader = std::make_unique<fnwf::LoadingState>(e);
                        loader->set_factory([](fnwf::Engine& e2) {
                            return std::make_unique<fnwf::GameplayState>(
                                e2, 7, &g.pending_custom_ai);
                        });
                        return loader;
                    });
                    g.state_name = "loading";
                }
            } else {
                do_switch("menu");
            }
        }
    }

    sm.draw();

    if (g.test_office) {
        fnwf::DrawUtils::text(eng, "TEST MODE", 60, 20, 20, 255, 70, 70);
        fnwf::DrawUtils::text(eng, "FAST OFFICE - 3D BUILD", 60, 42, 12, 255, 150, 150, 200);
    }

    if (settings.show_fps) {
        char fps_buf[64];
        std::snprintf(fps_buf,
                      sizeof(fps_buf),
                      fnwf::Localization::get_text("fps_counter").c_str(),
                      g.fps_value);
        fnwf::DrawUtils::text(
            eng, fps_buf, fnwf::GameSettings::SCREEN_WIDTH - 110, 16, 16, 130, 255, 170);
    }

    eng.present();
}

}  // namespace

auto main(int argc, char** argv) -> int {

    bool test_office = false;
    for (int i = 1; i < argc; ++i) {
        std::string a = argv[i];
        if (a == "-o" || a == "--office") {
            test_office = true;
        }
    }

    fnwf::Engine eng;
    auto init_res = eng.new_instance("Five Nights With Friends",
                                     fnwf::GameSettings::SCREEN_WIDTH,
                                     fnwf::GameSettings::SCREEN_HEIGHT,
                                     false,
                                     true);
    if (!init_res) {
        std::fprintf(stderr, "Engine init failed: %s\n", init_res.error().c_str());
        return 1;
    }
    eng.set_logical_size(fnwf::GameSettings::SCREEN_WIDTH, fnwf::GameSettings::SCREEN_HEIGHT);

    fnwf::SoundManager::set_engine(&eng);
    fnwf::DrawUtils::set_fonts(eng);

    auto& settings = fnwf::SettingsManager::instance();
    fnwf::Localization::set_language(settings.language);
    fnwf::DrawUtils::set_render_quality(settings.quality);

#ifdef __EMSCRIPTEN__
    int is_touch = EM_ASM_INT({
        return ('ontouchstart' in window || navigator.maxTouchPoints > 0) ? 1 : 0;
    });
    fnwf::MobileUI::set_mobile(is_touch == 1);
#else
    fnwf::MobileUI::set_mobile(false);
#endif

    g.eng = &eng;
    g.test_office = test_office;
    g.save_data = fnwf::SaveManager::load_data();
    g.completed_nights = g.save_data.completed_nights;
    g.has_seen_story = g.save_data.has_seen_story;
    g.achievements = g.save_data.achievements;

    fnwf::StateMachine sm(eng);
    g.sm = &sm;
    g.state_name = "warning";

    if (test_office) {
        g.state_name = "game";
        g.pending_night = 1;
        sm.switch_state(
            "game", [](fnwf::Engine& e) { return std::make_unique<fnwf::GameplayState>(e, 1); });
    } else {
        do_switch("warning");
    }

    g.last_time = eng.ticks() / 1000.0;

#ifdef __EMSCRIPTEN__
    emscripten_set_main_loop(game_loop_iter, 0, 1);
#else
    while (eng.keeps_running()) {
        game_loop_iter();
    }
    eng.shutdown();
#endif

    return 0;
}
