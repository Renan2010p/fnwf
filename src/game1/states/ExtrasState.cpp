#include "game1/states/ExtrasState.hpp"
#include "core/DrawUtils.hpp"
#include "core/Localization.hpp"
#include "core/SoundManager.hpp"
#include "game1/GameSettings.hpp"
#include <algorithm>

namespace fnwf {

ExtrasState::ExtrasState(
    int /*cn*/, bool ip, bool fn, const std::vector<std::string>& ach, Engine& eng)
    : m_eng(eng), infinite_power(ip), fast_nights(fn), unlocked_achievements(ach) {
    categories = {Localization::get_text("cat_animatronics"),
                  Localization::get_text("cat_credits"),
                  Localization::get_text("cat_cheats"),
                  Localization::get_text("cat_achievements")};

    animatronics = {{"Cedro", "cedro", Localization::get_text("cedro_desc")},
                    {"Eser", "eser", Localization::get_text("eser_desc")},
                    {"Alice", "alice", Localization::get_text("alice_desc")},
                    {"Renan", "renan", Localization::get_text("renan_desc")}};
    for (auto& a : animatronics) {
        DrawUtils::load_sprite(eng, a.sprite);
        sprites[a.sprite] = *DrawUtils::get_sprite(a.sprite);
    }

    achievements_list = {{"survive_n1",
                          Localization::get_text("night_1_ach_title"),
                          Localization::get_text("night_1_ach_desc")},
                         {"survive_n5",
                          Localization::get_text("night_5_ach_title"),
                          Localization::get_text("night_5_ach_desc")},
                         {"survive_n6",
                          Localization::get_text("night_6_ach_title"),
                          Localization::get_text("night_6_ach_desc")},
                         {"survive_n7",
                          Localization::get_text("night_7_ach_title"),
                          Localization::get_text("night_7_ach_desc")}};
}

void ExtrasState::update(double dt) {
    timer += dt;
}

void ExtrasState::handle_event(const Event& ev) {
    if (ev.type == EventType::KeyDown) {
        int k = ev.key;
        if (k == 27) {
            m_result = "menu";
            done = true;
            SoundManager::play_sound("select");
        } else if (k == 1073741904 || k == 'a') {
            category = ((category - 2 + (int)categories.size()) % (int)categories.size()) + 1;
            selected = 1;
            SoundManager::play_sound("blip");
        } else if (k == 1073741903 || k == 'd') {
            category = (category % (int)categories.size()) + 1;
            selected = 1;
            SoundManager::play_sound("blip");
        }

        if (category == 1) {
            if (k == 1073741906 || k == 'w') {
                anim_idx =
                    ((anim_idx - 2 + (int)animatronics.size()) % (int)animatronics.size()) + 1;
                SoundManager::play_sound("blip");
            } else if (k == 1073741905 || k == 's') {
                anim_idx = (anim_idx % (int)animatronics.size()) + 1;
                SoundManager::play_sound("blip");
            }
        } else if (category == 3) {
            if (k == 1073741906 || k == 'w') {
                selected = ((selected - 2 + 2) % 2) + 1;
                SoundManager::play_sound("blip");
            } else if (k == 1073741905 || k == 's') {
                selected = (selected % 2) + 1;
                SoundManager::play_sound("blip");
            } else if (k == 13 || k == 32) {
                if (selected == 1)
                    infinite_power = !infinite_power;
                else
                    fast_nights = !fast_nights;
                SoundManager::play_sound("select");
            }
        }
    }
}

void ExtrasState::draw(Engine& eng) {
    using namespace GameSettings;
    eng.clear(5, 5, 10, 255);
    DrawUtils::static_noise(eng, 0, 0, SCREEN_WIDTH, SCREEN_HEIGHT, 0.01f);

    for (int i = 0; i < (int)categories.size(); ++i) {
        bool is_sel = (i + 1 == category);
        int r = is_sel ? 255 : 100, g = is_sel ? 255 : 100, b = is_sel ? 255 : 110;
        DrawUtils::text(eng, categories[i], 80 + i * 230, 40, 20, r, g, b);
        if (is_sel)
            eng.draw_rect(80 + i * 230, 65, 80, 2, 255, 255, 255, 255);
    }

    if (category == 1)
        draw_animatronics(eng);
    else if (category == 2)
        draw_credits(eng);
    else if (category == 3)
        draw_cheats(eng);
    else if (category == 4)
        draw_achievements(eng);

    DrawUtils::text(
        eng, Localization::get_text("extras_help"), 80, SCREEN_HEIGHT - 40, 14, 150, 150, 160);
    DrawUtils::scanlines(eng, 0, 0, SCREEN_WIDTH, SCREEN_HEIGHT, 10);
}

void ExtrasState::draw_animatronics(Engine& eng) {
    using namespace GameSettings;
    auto& a = animatronics[anim_idx - 1];
    auto it = sprites.find(a.sprite);
    int img_x = 90, img_y = 140, img_w = 520, img_h = 520;
    int text_x = 660, text_w = SCREEN_WIDTH - text_x - 80;

    eng.draw_rect(img_x - 8, img_y - 8, img_w + 16, img_h + 16, 65, 80, 110, 255, false);
    if (it != sprites.end())
        DrawUtils::rounded_texture(eng, it->second, img_x, img_y, img_w, img_h, 20, 10, 10, 16);

    DrawUtils::text(eng, a.name, text_x, 160, 56, TITLE_COLOR.r, TITLE_COLOR.g, TITLE_COLOR.b);

    // Simple wrap
    auto words = std::vector<std::string>{};
    std::string tmp;
    for (char c : a.desc) {
        if (c == ' ') {
            if (!tmp.empty()) {
                words.push_back(tmp);
                tmp.clear();
            }
        } else
            tmp += c;
    }
    if (!tmp.empty())
        words.push_back(tmp);
    std::string line;
    int ly = 250;
    int count = 0;
    for (auto& w : words) {
        std::string test = line.empty() ? w : line + " " + w;
        auto sz = m_eng.font_text_size(test, 20);
        int tw = sz ? (*sz)[0] : (int)test.size() * 10;
        if (tw <= text_w)
            line = test;
        else {
            DrawUtils::text(eng, line, text_x, ly, 20, 255, 255, 255);
            ly += 34;
            line = w;
            count++;
            if (count >= 7)
                break;
        }
    }
    if (!line.empty() && count < 8)
        DrawUtils::text(eng, line, text_x, ly, 20, 255, 255, 255);

    DrawUtils::text(eng,
                    std::to_string(anim_idx) + " / " + std::to_string(animatronics.size()),
                    img_x,
                    img_y + img_h + 18,
                    16,
                    180,
                    180,
                    180);
}

void ExtrasState::draw_credits(Engine& eng) {
    using namespace GameSettings;
    int y = 200;
    DrawUtils::text(eng,
                    "FIVE NIGHTS WITH FRIENDS",
                    SCREEN_WIDTH / 2,
                    y,
                    40,
                    TITLE_COLOR.r,
                    TITLE_COLOR.g,
                    TITLE_COLOR.b,
                    255,
                    true);
    DrawUtils::text(eng,
                    Localization::get_text("created_by"),
                    SCREEN_WIDTH / 2,
                    y + 60,
                    24,
                    255,
                    255,
                    255,
                    255,
                    true);
    DrawUtils::text(eng, "Renan Lucas", SCREEN_WIDTH / 2, y + 110, 50, 100, 200, 255, 255, true);
    DrawUtils::text(eng,
                    Localization::get_text("special_thanks"),
                    SCREEN_WIDTH / 2,
                    y + 300,
                    18,
                    180,
                    180,
                    180,
                    255,
                    true);
    DrawUtils::text(eng,
                    "Scott Cawthon (FNAF Original)",
                    SCREEN_WIDTH / 2,
                    y + 330,
                    18,
                    255,
                    255,
                    255,
                    255,
                    true);
}

void ExtrasState::draw_cheats(Engine& eng) {
    using namespace GameSettings;
    auto cl = std::vector<std::pair<std::string, bool*>>{
        {Localization::get_text("cheat_energy"), &infinite_power},
        {Localization::get_text("cheat_fast"), &fast_nights}};
    for (int i = 0; i < (int)cl.size(); ++i) {
        bool is_sel = (i + 1 == selected);
        int r = is_sel ? 255 : 120, g = is_sel ? 255 : 120, b = is_sel ? 255 : 130;
        std::string prefix = is_sel ? ">> " : "   ";
        DrawUtils::text(eng, prefix + cl[i].first, 100, 250 + i * 60, 28, r, g, b);

        bool on = *cl[i].second;
        int sr = on ? 100 : 255, sg = on ? 255 : 100, sb = on ? 100 : 100;
        std::string st = on ? Localization::get_text("on") : Localization::get_text("off");
        DrawUtils::text(
            eng, st, 450, 250 + i * 60, 28, is_sel ? sr : r, is_sel ? sg : g, is_sel ? sb : b);
    }
}

void ExtrasState::draw_achievements(Engine& eng) {
    using namespace GameSettings;
    for (int i = 0; i < (int)achievements_list.size(); ++i) {
        auto& ach = achievements_list[i];
        int y = 220 + i * 80;
        bool un = false;
        for (auto& id : unlocked_achievements) {
            if (id == ach.id) {
                un = true;
                break;
            }
        }
        DrawUtils::text(eng,
                        un ? "\xe2\x98\x85" : "\xe2\x98\x86",
                        80,
                        y,
                        30,
                        un ? STAR_COLOR.r : 50,
                        un ? STAR_COLOR.g : 50,
                        un ? STAR_COLOR.b : 60);
        DrawUtils::text(eng, ach.name, 130, y, 24, un ? 255 : 60, un ? 255 : 60, un ? 255 : 70);
        DrawUtils::text(
            eng, ach.desc, 130, y + 30, 16, un ? 120 : 40, un ? 120 : 40, un ? 130 : 45);
    }
}

}  // namespace fnwf
