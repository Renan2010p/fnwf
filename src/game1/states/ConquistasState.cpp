#include "game1/states/ConquistasState.hpp"
#include "core/DrawUtils.hpp"
#include "core/Localization.hpp"
#include "core/SoundManager.hpp"
#include "game1/GameSettings.hpp"

namespace fnwf {

ConquistasState::ConquistasState(const std::vector<std::string>& ach, Engine& eng)
    : m_eng(eng), unlocked_achievements(ach)
{
    achievements_list = {
        {"survive_n1", Localization::get_text("night_1_ach_title"), Localization::get_text("night_1_ach_desc")},
        {"survive_n5", Localization::get_text("night_5_ach_title"), Localization::get_text("night_5_ach_desc")},
        {"survive_n6", Localization::get_text("night_6_ach_title"), Localization::get_text("night_6_ach_desc")},
        {"survive_n7", Localization::get_text("night_7_ach_title"), Localization::get_text("night_7_ach_desc")}
    };
}

void ConquistasState::update(double dt) { timer += dt; }

void ConquistasState::handle_event(const Event& ev)
{
    if (ev.type == EventType::KeyDown)
    {
        int key = ev.key;
        if (key == 27 || key == 13 || key == 32)
        { done = true; m_result = "menu"; SoundManager::play_sound("select"); }
    }
}

void ConquistasState::draw(Engine& eng)
{
    using namespace GameSettings;
    eng.clear(10, 10, 15, 255);
    DrawUtils::static_noise(eng, 0, 0, SCREEN_WIDTH, SCREEN_HEIGHT, 0.01f);
    DrawUtils::text(eng, Localization::get_text("ach_title_screen"), 80, 60, 40, TITLE_COLOR.r, TITLE_COLOR.g, TITLE_COLOR.b);
    eng.draw_rect(80, 110, 600, 2, STAR_COLOR.r, STAR_COLOR.g, STAR_COLOR.b, 255);

    for (int i = 0; i < (int)achievements_list.size(); ++i)
    {
        auto& ach = achievements_list[i];
        int y = 180 + i * 100;
        bool unlocked = false;
        for (auto& id : unlocked_achievements) { if (id == ach.id) { unlocked = true; break; } }

        int cr = unlocked ? 255 : 60, cg = unlocked ? 255 : 60, cb = unlocked ? 255 : 70;
        int bg_r = unlocked ? 20 : 15, bg_g = unlocked ? 20 : 15, bg_b = unlocked ? 30 : 20;

        eng.draw_rect(80, y - 10, SCREEN_WIDTH - 160, 80, bg_r, bg_g, bg_b, 255);
        if (unlocked) eng.draw_rect(80, y - 10, SCREEN_WIDTH - 160, 80, 40, 40, 60, 255, false);

        DrawUtils::text(eng, unlocked ? "\xe2\x98\x85" : "\xe2\x98\x86", 100, y + 10, 40,
            unlocked ? STAR_COLOR.r : 40, unlocked ? STAR_COLOR.g : 40, unlocked ? STAR_COLOR.b : 50);
        DrawUtils::text(eng, ach.name, 160, y, 28, cr, cg, cb);
        DrawUtils::text(eng, ach.desc, 160, y + 35, 18, unlocked ? 120 : 40, unlocked ? 120 : 40, unlocked ? 130 : 45);
    }

    DrawUtils::text(eng, Localization::get_text("ach_help"), SCREEN_WIDTH / 2, SCREEN_HEIGHT - 60, 16, 180, 180, 180, 255, true);
    DrawUtils::scanlines(eng, 0, 0, SCREEN_WIDTH, SCREEN_HEIGHT, 10);
}

} // namespace fnwf
