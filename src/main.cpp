// Five Nights With Friends 1 — Pure C++23 entry point.
#include "engine/Engine.hpp"
#include "core/StateMachine.hpp"
#include "core/GameState.hpp"
#include "core/Localization.hpp"
#include "core/DrawUtils.hpp"
#include "core/SoundManager.hpp"
#include "core/SaveManager.hpp"
#include "core/SettingsManager.hpp"
#include "game1/GameSettings.hpp"
#include "game1/states/WarningState.hpp"
#include "game1/states/MenuState.hpp"
#include "game1/states/OptionsState.hpp"
#include "game1/states/GameplayState.hpp"
#include "game1/states/CustomNightState.hpp"
#include "game1/states/StoryState.hpp"
#include "game1/states/LoadingState.hpp"
#include "game1/states/NightTransitionState.hpp"
#include "game1/states/SixAMState.hpp"
#include "game1/states/PaycheckState.hpp"
#include "game1/states/NewspaperState.hpp"
#include "game1/states/GameOverState.hpp"
#include "game1/states/ExtrasState.hpp"
#include "game1/states/ConquistasState.hpp"

#include <cstdio>
#include <string>
#include <vector>
#include <memory>
#include <ctime>

auto main(int argc, char** argv) -> int
{
    std::srand(static_cast<unsigned>(std::time(nullptr)));

    bool test_office = false;
    for (int i = 1; i < argc; ++i)
    {
        std::string a = argv[i];
        if (a == "-o" || a == "--office") { test_office = true; }
    }

    fnwf::Engine eng;
    auto init_res = eng.new_instance("Five Nights With Friends",
        fnwf::GameSettings::SCREEN_WIDTH, fnwf::GameSettings::SCREEN_HEIGHT,
        false, true);
    if (!init_res)
    {
        std::fprintf(stderr, "Engine init failed: %s\n", init_res.error().c_str());
        return 1;
    }
    eng.set_logical_size(fnwf::GameSettings::SCREEN_WIDTH, fnwf::GameSettings::SCREEN_HEIGHT);

    fnwf::SoundManager::set_engine(&eng);
    fnwf::DrawUtils::set_fonts(eng);

    auto& settings = fnwf::SettingsManager::instance();
    fnwf::Localization::set_language(settings.language);
    fnwf::DrawUtils::set_render_quality(settings.quality);

    auto save_data = fnwf::SaveManager::load_data();
    int completed_nights = save_data.completed_nights;
    bool has_seen_story = save_data.has_seen_story;
    auto achievements = save_data.achievements;

    fnwf::StateMachine sm(eng);
    std::string state_name = "warning";

    auto do_switch = [&](const std::string& name)
    {
        state_name = name;

        if (name == "warning")
        {
            eng.update_discord(fnwf::Localization::get_text("discord_status_menu"), "Five Nights With Friends Classic Edition");
            sm.switch_state("warning", [](fnwf::Engine& e) {
                return std::make_unique<fnwf::WarningState>(e);
            });
        }
        else if (name == "menu")
        {
            eng.update_discord("No Menu", "Menu Principal");
            sm.switch_state("menu", [&](fnwf::Engine& e) {
                return std::make_unique<fnwf::MenuState>(completed_nights, has_seen_story, e);
            });
        }
        else if (name == "options")
        {
            sm.switch_state("options", [](fnwf::Engine& e) {
                return std::make_unique<fnwf::OptionsState>(e);
            });
        }
        else if (name == "custom_night")
        {
            eng.update_discord(fnwf::Localization::get_text("discord_status_custom_night"), "Five Nights With Friends Classic Edition");
            sm.switch_state("custom_night", [](fnwf::Engine& e) {
                return std::make_unique<fnwf::CustomNightState>(e);
            });
        }
        else if (name == "newspaper")
        {
            sm.switch_state("newspaper", [](fnwf::Engine& e) {
                return std::make_unique<fnwf::NewspaperState>(e);
            });
        }
        else if (name == "paycheck")
        {
            sm.switch_state("paycheck", [](fnwf::Engine& e) {
                return std::make_unique<fnwf::PaycheckState>(e);
            });
        }
        else if (name == "conquistas")
        {
            sm.switch_state("conquistas", [&](fnwf::Engine& e) {
                return std::make_unique<fnwf::ConquistasState>(achievements, e);
            });
        }
        else if (name == "extras")
        {
            sm.switch_state("extras", [&](fnwf::Engine& e) {
                return std::make_unique<fnwf::ExtrasState>(completed_nights,
                    save_data.infinite_power, save_data.fast_nights, achievements, e);
            });
        }
    };

    // Night-specific transitions stored as ints
    int pending_night = 1;
    std::vector<int> pending_custom_ai{};

    if (test_office)
    {
        state_name = "game";
        pending_night = 1;
        sm.switch_state("game", [](fnwf::Engine& e) {
            return std::make_unique<fnwf::GameplayState>(e, 1);
        });
    }
    else
    {
        do_switch("warning");
    }

    auto last_time = eng.ticks() / 1000.0;
    double fps_timer = 0.0;
    int fps_frames = 0;
    int fps_value = 0;

    while (eng.keeps_running())
    {
        double current_time = eng.ticks() / 1000.0;
        double dt = current_time - last_time;
        last_time = current_time;
        fps_timer += dt;
        fps_frames++;
        if (fps_timer >= 0.25) { fps_value = static_cast<int>((fps_frames / fps_timer) + 0.5); fps_timer = 0; fps_frames = 0; }

        auto events = eng.poll_events();
        for (auto& ev : events)
        {
            if (ev.type == fnwf::EventType::Quit) { eng.request_stop(); }
            sm.handle_event(ev);
        }

        sm.update(dt);

        // Check state done -> transition
        auto* cur = sm.current();
        if (cur && cur->is_done())
        {
            if (state_name == "warning")
            {
                do_switch("menu");
            }
            else if (state_name == "menu")
            {
                auto& res = cur->result();
                if (res == "start") { pending_night = 1; sm.switch_state("story", [](fnwf::Engine& e) { return std::make_unique<fnwf::StoryState>(1, e); }); state_name = "story"; }
                else if (res == "continue") { pending_night = std::min(completed_nights + 1, 6); sm.switch_state("story", [n=pending_night](fnwf::Engine& e) { return std::make_unique<fnwf::StoryState>(n, e); }); state_name = "story"; }
                else if (res == "night6") { pending_night = 6; sm.switch_state("story", [](fnwf::Engine& e) { return std::make_unique<fnwf::StoryState>(6, e); }); state_name = "story"; }
                else if (res == "night7") { do_switch("custom_night"); }
                else if (res == "extras") { do_switch("extras"); }
                else if (res == "options") { do_switch("options"); }
                else if (res == "conquistas") { do_switch("conquistas"); }
                else if (res == "quit") { eng.request_stop(); }
            }
            else if (state_name == "extras" || state_name == "conquistas" || state_name == "options")
            {
                do_switch("menu");
            }
            else if (state_name == "story")
            {
                // Story done -> loading -> game
                sm.switch_state("loading", [n=pending_night](fnwf::Engine& e) {
                    auto loader = std::make_unique<fnwf::LoadingState>(e);
                    loader->set_factory([n](fnwf::Engine& e2) {
                        return std::make_unique<fnwf::GameplayState>(e2, n);
                    });
                    return loader;
                });
                state_name = "loading";
            }
            else if (state_name == "transition")
            {
                sm.switch_state("loading", [n=pending_night](fnwf::Engine& e) {
                    auto loader = std::make_unique<fnwf::LoadingState>(e);
                    loader->set_factory([n](fnwf::Engine& e2) {
                        return std::make_unique<fnwf::GameplayState>(e2, n);
                    });
                    return loader;
                });
                state_name = "loading";
            }
            else if (state_name == "loading")
            {
                // Loading creates the game state internally; switch to it
                sm.switch_state("game", [n=pending_night](fnwf::Engine& e) {
                    return std::make_unique<fnwf::GameplayState>(e, n);
                });
                state_name = "game";
            }
            else if (state_name == "game")
            {
                auto& res = cur->result();
                if (res == "win")
                {
                    if (pending_night >= 1) { achievements.push_back("survive_n1"); }
                    if (pending_night >= 5) { achievements.push_back("survive_n5"); }
                    if (pending_night >= 6) { achievements.push_back("survive_n6"); }
                    completed_nights = std::max(completed_nights, pending_night);
                    has_seen_story = true;
                    fnwf::SaveManager::save_progress(completed_nights, has_seen_story,
                        save_data.infinite_power, save_data.fast_nights, achievements);
                    sm.switch_state("six_am", [n=pending_night](fnwf::Engine& e) {
                        return std::make_unique<fnwf::SixAMState>(n, e);
                    });
                    state_name = "six_am";
                }
                else if (res == "jumpscare")
                {
                    sm.switch_state("gameover", [n=pending_night](fnwf::Engine& e) {
                        return std::make_unique<fnwf::GameOverState>(false, n, e);
                    });
                    state_name = "gameover";
                }
                else if (res == "menu")
                {
                    do_switch("menu");
                }
            }
            else if (state_name == "six_am")
            {
                auto* six = dynamic_cast<fnwf::SixAMState*>(cur);
                if (six && six->get_night() == 5) { do_switch("paycheck"); }
                else { do_switch("menu"); }
            }
            else if (state_name == "paycheck")
            {
                do_switch("newspaper");
            }
            else if (state_name == "newspaper")
            {
                do_switch("menu");
            }
            else if (state_name == "gameover")
            {
                auto* go = dynamic_cast<fnwf::GameOverState*>(cur);
                if (go && go->get_is_win()) { do_switch("menu"); }
                else { do_switch("newspaper"); }
            }
            else if (state_name == "custom_night")
            {
                auto& res = cur->result();
                if (res == "start")
                {
                    auto* cn = dynamic_cast<fnwf::CustomNightState*>(cur);
                    if (cn)
                    {
                        auto ai = cn->get_ai_levels();
                        pending_night = 7;
                        pending_custom_ai = ai;
                        sm.switch_state("loading", [&ai](fnwf::Engine& e) {
                            auto loader = std::make_unique<fnwf::LoadingState>(e);
                            loader->set_factory([&ai](fnwf::Engine& e2) {
                                return std::make_unique<fnwf::GameplayState>(e2, 7, &ai);
                            });
                            return loader;
                        });
                        state_name = "loading";
                    }
                }
                else
                {
                    do_switch("menu");
                }
            }
        }

        sm.draw();

        if (test_office)
        {
            fnwf::DrawUtils::text(eng, "TEST MODE", 60, 20, 20, 255, 70, 70);
            fnwf::DrawUtils::text(eng, "FAST OFFICE - 3D BUILD", 60, 42, 12, 255, 150, 150, 200);
        }

        if (settings.show_fps)
        {
            char fps_buf[64];
            std::snprintf(fps_buf, sizeof(fps_buf), fnwf::Localization::get_text("fps_counter").c_str(), fps_value);
            fnwf::DrawUtils::text(eng, fps_buf, fnwf::GameSettings::SCREEN_WIDTH - 110, 16, 16, 130, 255, 170);
        }

        eng.present();
    }

    eng.shutdown();
    return 0;
}
