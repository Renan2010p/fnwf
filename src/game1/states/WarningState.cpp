#include "game1/states/WarningState.hpp"
#include "core/DrawUtils.hpp"
#include "core/Localization.hpp"
#include "game1/GameSettings.hpp"
namespace fnwf {
WarningState::WarningState(Engine& eng) {
    (void)eng;
}
auto WarningState::handle_event(const Event& ev) -> void {
    if (ev.type == EventType::KeyDown || ev.type == EventType::MouseButtonDown) {
        if (phase < 2) {
            phase = 2;
            alpha = 255.0;
        }
    }
}
auto WarningState::update(double dt) -> void {
    timer += dt;
    if (phase == 0) {
        alpha += 600 * dt;
        if (alpha >= 255) {
            alpha = 255;
            phase = 1;
            timer = 0;
        }
    } else if (phase == 1) {
        if (timer >= 1.0)
            phase = 2;
    } else if (phase == 2) {
        alpha -= 600 * dt;
        if (alpha <= 0) {
            alpha = 0;
            done = true;
        }
    }
}
auto WarningState::draw(Engine& eng) -> void {
    eng.clear(0, 0, 0);
    auto cx = GameSettings::SCREEN_WIDTH / 2, cy = GameSettings::SCREEN_HEIGHT / 2;
    auto a = static_cast<int>(alpha);
    DrawUtils::text(
        eng, Localization::get_text("warning_title"), cx, cy - 80, 40, 200, 50, 50, a, true);
    DrawUtils::text(
        eng, Localization::get_text("warning_line1"), cx, cy - 20, 24, 255, 255, 255, a, true);
    DrawUtils::text(
        eng, Localization::get_text("warning_line2"), cx, cy + 10, 24, 255, 255, 255, a, true);
    DrawUtils::text(
        eng, Localization::get_text("warning_line3"), cx, cy + 40, 24, 255, 255, 255, a, true);
    DrawUtils::text(
        eng, Localization::get_text("warning_line4"), cx, cy + 70, 24, 255, 255, 255, a, true);
}
}  // namespace fnwf
