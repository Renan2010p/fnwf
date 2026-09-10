#include "game1/states/GameOverState.hpp"
#include "core/DrawUtils.hpp"
#include "core/Localization.hpp"
#include "game1/GameSettings.hpp"
#include <algorithm>
#include <cmath>
#include <string>

namespace fnwf {

GameOverState::GameOverState(bool is_win_, int night_, Engine& eng)
    : m_eng(eng), is_win(is_win_), night(night_) {}

auto GameOverState::is_done() const -> bool {
    return timer > 3.0;
}

auto GameOverState::update(double dt) -> void {
    timer += dt;
    if (timer > 0.5) {
        show_text = true;
        text_alpha = std::min(255, text_alpha + (int)(200 * dt));
    }
}

auto GameOverState::handle_event(const Event& ev) -> void {
    if (timer < 2.0)
        return;
    if (ev.type == EventType::KeyDown || ev.type == EventType::MouseButtonDown)
        m_result = is_win ? "next" : "menu";
}

auto GameOverState::draw(Engine& eng) -> void {
    if (is_win)
        draw_win(eng);
    else
        draw_game_over(eng);
}

auto GameOverState::draw_game_over(Engine& eng) -> void {
    using namespace GameSettings;
    eng.clear(5, 0, 0, 255);
    DrawUtils::static_noise(eng, 0, 0, SCREEN_WIDTH, SCREEN_HEIGHT, 0.08f);
    if (!show_text)
        return;

    int pw = 500, ph = 350;
    int px = SCREEN_WIDTH / 2 - pw / 2, py = SCREEN_HEIGHT / 2 - ph / 2 - 30;
    eng.draw_rect(px, py, pw, ph, 180, 170, 150, text_alpha);

    if (text_alpha > 100) {
        DrawUtils::text(eng,
                        Localization::get_text("news_title"),
                        SCREEN_WIDTH / 2,
                        py + 20,
                        18,
                        40,
                        40,
                        40,
                        255,
                        true);
        eng.line(px + 20, py + 45, px + pw - 20, py + 45, 40, 40, 40, 255);
        DrawUtils::text(eng,
                        Localization::get_text("news_headline_1"),
                        SCREEN_WIDTH / 2,
                        py + 70,
                        32,
                        30,
                        30,
                        30,
                        255,
                        true);
        DrawUtils::text(eng,
                        Localization::get_text("news_headline_2"),
                        SCREEN_WIDTH / 2,
                        py + 110,
                        38,
                        150,
                        20,
                        20,
                        255,
                        true);

        std::string nl = Localization::get_text("night") + " " + std::to_string(night);
        auto lines = std::vector<std::string>{Localization::get_text("news_body_1"),
                                              Localization::get_text("news_body_2"),
                                              Localization::get_text("news_body_3"),
                                              "",
                                              Localization::get_text("news_body_4") + " " + nl,
                                              Localization::get_text("news_body_5")};
        for (int i = 0; i < (int)lines.size(); ++i)
            DrawUtils::text(
                eng, lines[i], SCREEN_WIDTH / 2, py + 165 + i * 22, 13, 50, 50, 50, 255, true);
    }

    DrawUtils::scanlines(eng, 0, 0, SCREEN_WIDTH, SCREEN_HEIGHT, 15);
    if (timer > 3.0 && ((int)(timer * 2) % 2 == 1))
        DrawUtils::text(eng,
                        Localization::get_text("press_any_key"),
                        SCREEN_WIDTH / 2,
                        SCREEN_HEIGHT - 50,
                        16,
                        100,
                        100,
                        100,
                        255,
                        true);
}

auto GameOverState::draw_win(Engine& eng) -> void {
    using namespace GameSettings;
    eng.clear(0, 0, 0, 255);
    if (!show_text)
        return;

    DrawUtils::text(eng,
                    Localization::get_text("gameover_win"),
                    SCREEN_WIDTH / 2,
                    SCREEN_HEIGHT / 2 - 40,
                    80,
                    255,
                    255,
                    255,
                    255,
                    true);

    if (timer > 1.5) {
        int a = std::min(100, (int)((timer - 1.5) * 80));
        eng.draw_rect(0, 0, SCREEN_WIDTH, SCREEN_HEIGHT, 255, 255, 200, a);
    }

    if (timer > 2.0) {
        std::string nl = Localization::get_text("night") + " " + std::to_string(night);
        DrawUtils::text(eng,
                        Localization::get_text("night_complete") + " " + nl,
                        SCREEN_WIDTH / 2,
                        SCREEN_HEIGHT / 2 + 50,
                        24,
                        200,
                        200,
                        200,
                        255,
                        true);
        for (int i = 0; i < std::min(night, 7); ++i)
            DrawUtils::star(eng,
                            SCREEN_WIDTH / 2 - 75 + i * 25,
                            SCREEN_HEIGHT / 2 + 100,
                            10,
                            STAR_COLOR.r,
                            STAR_COLOR.g,
                            STAR_COLOR.b);
    }

    if (timer > 3.5 && ((int)(timer * 2) % 2 == 1))
        DrawUtils::text(eng,
                        Localization::get_text("press_any_key_continue"),
                        SCREEN_WIDTH / 2,
                        SCREEN_HEIGHT - 50,
                        16,
                        100,
                        100,
                        100,
                        255,
                        true);
}

}  // namespace fnwf
