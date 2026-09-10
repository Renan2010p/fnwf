#include "game1/states/MenuState.hpp"
#include "core/DrawUtils.hpp"
#include "core/Localization.hpp"
#include "core/Rng.hpp"
#include "core/SoundManager.hpp"
#include "game1/GameSettings.hpp"
#include <algorithm>
#include <cmath>
namespace fnwf {
static float lerp(float a, float b, float t) {
    return a + (b - a) * std::min(1.0f, std::max(0.0f, t));
}
MenuState::MenuState(int cn, bool hss, Engine& eng)
    : m_eng(eng), m_completed_nights(cn), m_has_seen_story(hss) {
    SoundManager::set_engine(&eng);
    DrawUtils::load_sprite(eng, "cedro");
    DrawUtils::load_sprite(eng, "eser");
    DrawUtils::load_sprite(eng, "alice");
    DrawUtils::load_sprite(eng, "Sonk");
    DrawUtils::load_sprite(eng, "mafia");
    cedro_sprite = *DrawUtils::get_sprite("cedro");
    eser_sprite = *DrawUtils::get_sprite("eser");
    alice_sprite = *DrawUtils::get_sprite("alice");
    sonk_sprite = *DrawUtils::get_sprite("Sonk");
    mafia_logo = *DrawUtils::get_sprite("mafia");
    menu_animatronics = {eser_sprite, cedro_sprite, alice_sprite, sonk_sprite};
    current_anim_idx = Rng::int_range(0, 3);
    build_options();
    SoundManager::play_menu_ambient();
}
void MenuState::build_options() {
    options.clear();
    if (menu_page == "main") {
        options.push_back({Localization::get_text("new_game"), "start"});
        if (m_has_seen_story || m_completed_nights > 0) {
            int next = std::min(m_completed_nights + 1, 6);
            char buf[128];
            std::snprintf(buf,
                          sizeof(buf),
                          "%s (%s %d)",
                          Localization::get_text("continue").c_str(),
                          Localization::get_text("night").c_str(),
                          next);
            options.push_back({buf, "continue"});
        }
        if (m_completed_nights >= 5)
            options.push_back({Localization::get_text("night") + " 6", "night6"});
        if (m_completed_nights >= 5)
            options.push_back({Localization::get_text("more"), "more"});
        options.push_back({Localization::get_text("options"), "options"});
        options.push_back({Localization::get_text("quit"), "quit"});
    } else {
        if (m_completed_nights >= 5) {
            options.push_back({Localization::get_text("extras"), "extras"});
            options.push_back({Localization::get_text("custom_night"), "night7"});
        }
        options.push_back({Localization::get_text("arcade"), "arcade"});
        options.push_back({Localization::get_text("achievements"), "conquistas"});
        options.push_back({Localization::get_text("back"), "back_menu"});
    }
}
void MenuState::update(double dt) {
    timer += dt;
    highlight_target_y = 300 + (selected - 1) * 62 - 17;
    highlight_y = lerp(highlight_y, highlight_target_y, 12.0 * dt);
}
void MenuState::handle_event(const Event& ev) {
    if (ev.type == EventType::KeyDown) {
        if (ev.key == 1073741906 || ev.key == 'w') {
            selected = ((selected - 2 + (int)options.size()) % (int)options.size()) + 1;
            SoundManager::play_sound("blip");
        } else if (ev.key == 1073741905 || ev.key == 's') {
            selected = (selected % (int)options.size()) + 1;
            SoundManager::play_sound("blip");
        } else if (ev.key == 13 || ev.key == 32) {
            auto r = handle_action(options[selected - 1].action);
            if (!r.empty()) {
                m_result = r;
                done = true;
            }
        }
    }
    if (ev.type == EventType::MouseButtonDown) {
        for (int i = 0; i < (int)options.size(); ++i) {
            int y = 300 + i * 62 - 17;
            if (ev.y >= y && ev.y <= y + 48 && ev.x >= 54 && ev.x <= 414) {
                selected = i + 1;
                auto r = handle_action(options[i].action);
                if (!r.empty()) {
                    m_result = r;
                    done = true;
                }
            }
        }
    }
}
auto MenuState::handle_action(const std::string& action) -> std::string {
    SoundManager::play_sound("select");
    if (action == "more") {
        menu_page = "more";
        selected = 1;
        build_options();
        return {};
    }
    if (action == "back_menu") {
        menu_page = "main";
        selected = 1;
        build_options();
        return {};
    }
    if (action == "options") {
        return "options";
    }
    return action;
}
void MenuState::draw(Engine& eng) {
    eng.draw_rect(0, 0, GameSettings::SCREEN_WIDTH, GameSettings::SCREEN_HEIGHT, 4, 5, 9);
    auto cur = menu_animatronics[current_anim_idx % menu_animatronics.size()];
    float bounce = 5 * std::sin(timer * 0.8);
    DrawUtils::rounded_texture(
        eng, cur, GameSettings::SCREEN_WIDTH - 640, 70 + bounce, 560, 560, 34, 4, 5, 9);
    DrawUtils::vhs_osd(eng, "FIVE NIGHTS", 60, 64, 220, 240, 220, 46);
    DrawUtils::vhs_osd(eng, "WITH FRIENDS", 60, 116, 220, 240, 220, 46);
    int classic_alpha = static_cast<int>(120 + 100 * std::sin(timer * 3.0));
    DrawUtils::text_rotated(
        eng, "CLASSIC EDITION", 310, 155, -8.0, 20, 255, 220, 50, classic_alpha);
    DrawUtils::text(eng, "v2.0.3", 62, 176, 15, 140, 170, 200, 220);
    eng.draw_rect(60, 204, 360, 2, 100, 180, 255, static_cast<int>(120 + 40 * std::sin(timer * 2)));
    for (int i = 0; i < (int)options.size(); ++i) {
        int y = 300 + i * 62;
        bool is_sel = (i + 1 == selected);
        if (is_sel)
            eng.draw_rect(48, y - 17, 6, 48, 100, 180, 255);
        auto bri = (int)lerp(140, 255, is_sel ? 1.0f : 0.0f);
        DrawUtils::text(
            eng, options[i].label, 68, y - 5, 22, bri, bri, bri + (int)(20 * (is_sel ? 1 : 0)));
    }
    DrawUtils::text(eng,
                    "[ UP / DOWN ] SELECT     [ ENTER ] PLAY     [ ESC ] BACK",
                    60,
                    GameSettings::SCREEN_HEIGHT - 58,
                    13,
                    110,
                    130,
                    160,
                    200);
    DrawUtils::text(eng,
                    "Five Nights With Friends",
                    60,
                    GameSettings::SCREEN_HEIGHT - 38,
                    11,
                    80,
                    90,
                    110,
                    140);
}
}  // namespace fnwf
