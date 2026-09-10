#include "game1/states/PaycheckState.hpp"
#include "core/DrawUtils.hpp"
#include "core/Localization.hpp"
#include "core/SoundManager.hpp"
#include "game1/GameSettings.hpp"

namespace fnwf {

PaycheckState::PaycheckState(Engine& eng) : m_eng(eng) {}

auto PaycheckState::update(double dt) -> void {
    timer += dt;
    if (fading_in) {
        fade_alpha = std::max(0, fade_alpha - (int)(150 * dt));
        if (fade_alpha <= 0)
            fading_in = false;
    }
    if (fading_out) {
        fade_alpha = std::min(255, fade_alpha + (int)(150 * dt));
        if (fade_alpha >= 255)
            done = true;
    }
}

auto PaycheckState::handle_event(const Event& ev) -> void {
    if ((ev.type == EventType::KeyDown || ev.type == EventType::MouseButtonDown) && !fading_in &&
        !fading_out) {
        fading_out = true;
        SoundManager::play_sound("select");
    }
}

auto PaycheckState::draw(Engine& eng) -> void {
    using namespace GameSettings;
    eng.clear(20, 20, 25, 255);
    DrawUtils::static_noise(eng, 0, 0, SCREEN_WIDTH, SCREEN_HEIGHT, 0.01f);

    int cw = 700, ch = 350;
    int cx = (SCREEN_WIDTH - cw) / 2, cy = (SCREEN_HEIGHT - ch) / 2;
    eng.draw_rect(cx, cy, cw, ch, 245, 245, 230, 255);
    eng.draw_rect(cx, cy, cw, ch, 50, 50, 50, 255, false);

    DrawUtils::text(eng, Localization::get_text("company_name"), cx + 30, cy + 30, 24, 40, 40, 50);
    DrawUtils::text(eng, Localization::get_text("pay_services"), cx + 30, cy + 65, 14, 60, 60, 70);

    eng.draw_rect(cx + cw - 220, cy + 30, 190, 40, 255, 255, 255, 255);
    eng.draw_rect(cx + cw - 220, cy + 30, 190, 40, 0, 0, 0, 255, false);

    std::string prefix = Localization::get_text("currency_br");
    DrawUtils::text(eng, prefix + " " + amount, cx + cw - 210, cy + 38, 22, 0, 0, 0);

    DrawUtils::text(eng, Localization::get_text("pay_to"), cx + 30, cy + 130, 16, 60, 60, 70);
    DrawUtils::text(eng, name, cx + 50, cy + 160, 38, 20, 20, 30);
    eng.line(cx + 50, cy + 205, cx + cw - 50, cy + 205, 100, 100, 110, 255);

    DrawUtils::text(
        eng, Localization::get_text("pay_date") + " " + date, cx + 30, cy + 250, 16, 60, 60, 70);
    DrawUtils::text(
        eng, Localization::get_text("pay_signed"), cx + cw - 250, cy + 250, 14, 60, 60, 70);
    DrawUtils::text(eng, "Cedro (Big Boss)", cx + cw - 250, cy + 280, 22, 30, 30, 40);
    eng.line(cx + cw - 260, cy + 275, cx + cw - 30, cy + 275, 0, 0, 0, 255);

    DrawUtils::text(eng,
                    Localization::get_text("pay_congrats_5"),
                    SCREEN_WIDTH / 2,
                    cy + ch + 50,
                    20,
                    255,
                    255,
                    255,
                    255,
                    true);
    DrawUtils::text(eng,
                    Localization::get_text("click_continue"),
                    SCREEN_WIDTH / 2,
                    SCREEN_HEIGHT - 40,
                    14,
                    180,
                    180,
                    180,
                    255,
                    true);

    if (fade_alpha > 0)
        eng.draw_rect(0, 0, SCREEN_WIDTH, SCREEN_HEIGHT, 0, 0, 0, fade_alpha);
}

}  // namespace fnwf
