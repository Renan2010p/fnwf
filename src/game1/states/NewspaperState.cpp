#include "game1/states/NewspaperState.hpp"
#include "core/DrawUtils.hpp"
#include "core/Localization.hpp"
#include "core/SoundManager.hpp"
#include "game1/GameSettings.hpp"

namespace fnwf {

NewspaperState::NewspaperState(Engine& eng) : m_eng(eng) {}

void NewspaperState::update(double dt) {
    timer += dt;
    if (fading_in) {
        fade_alpha = std::max(0, fade_alpha - (int)(100 * dt));
        if (fade_alpha <= 0)
            fading_in = false;
    }
    if (fading_out) {
        fade_alpha = std::min(255, fade_alpha + (int)(150 * dt));
        if (fade_alpha >= 255)
            done = true;
    }
}

void NewspaperState::handle_event(const Event& ev) {
    if ((ev.type == EventType::KeyDown || ev.type == EventType::MouseButtonDown) && !fading_in &&
        !fading_out && timer > 3.0) {
        fading_out = true;
        SoundManager::play_sound("select");
    }
}

void NewspaperState::draw(Engine& eng) {
    using namespace GameSettings;
    eng.clear(10, 10, 15, 255);
    DrawUtils::static_noise(eng, 0, 0, SCREEN_WIDTH, SCREEN_HEIGHT, 0.015f);

    int pw = 600, ph = 450;
    int px = (SCREEN_WIDTH - pw) / 2, py = (SCREEN_HEIGHT - ph) / 2;
    eng.draw_rect(px, py, pw, ph, 160, 155, 140, 255);
    eng.draw_rect(px, py, pw, ph, 30, 30, 30, 255, false);

    DrawUtils::text(
        eng, Localization::get_text("newspaper_name"), px + 30, py + 20, 20, 40, 40, 40);
    eng.line(px + 20, py + 45, px + pw - 20, py + 45, 40, 40, 40, 255);
    DrawUtils::text(eng,
                    Localization::get_text("newspaper_h1"),
                    px + pw / 2,
                    py + 80,
                    34,
                    20,
                    20,
                    20,
                    255,
                    true);
    DrawUtils::text(eng,
                    Localization::get_text("newspaper_h2"),
                    px + pw / 2,
                    py + 120,
                    16,
                    50,
                    50,
                    50,
                    255,
                    true);

    auto txt = std::vector<std::string>{Localization::get_text("newspaper_p1"),
                                        Localization::get_text("newspaper_p2"),
                                        Localization::get_text("newspaper_p3"),
                                        Localization::get_text("newspaper_p4"),
                                        "",
                                        Localization::get_text("newspaper_p5"),
                                        Localization::get_text("newspaper_p6"),
                                        "",
                                        Localization::get_text("newspaper_p7")};

    for (int i = 0; i < (int)txt.size(); ++i)
        DrawUtils::text(eng, txt[i], px + pw / 2, py + 170 + i * 22, 14, 30, 30, 30, 255, true);

    if (timer > 3.0 && ((int)(timer * 2) % 2 == 1))
        DrawUtils::text(eng,
                        Localization::get_text("click_continue"),
                        SCREEN_WIDTH / 2,
                        SCREEN_HEIGHT - 50,
                        16,
                        255,
                        255,
                        255,
                        255,
                        true);

    if (fade_alpha > 0)
        eng.draw_rect(0, 0, SCREEN_WIDTH, SCREEN_HEIGHT, 0, 0, 0, fade_alpha);
}

}  // namespace fnwf
