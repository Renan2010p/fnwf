#include "game1/states/LoadingState.hpp"
#include "core/DrawUtils.hpp"
#include "core/Localization.hpp"
#include "core/Rng.hpp"
#include "game1/GameSettings.hpp"
#include <cmath>

namespace fnwf {

LoadingState::LoadingState(Engine& eng) : m_eng(eng) {
    int tip_idx = Rng::int_range(1, 12);
    tip = Localization::get_text("tip_" + std::to_string(tip_idx));
}

void LoadingState::handle_event(const Event&) {}

void LoadingState::update(double dt) {
    timer += dt;
    glitch_timer += dt;
    loader_angle += 360.0 * dt;

    if (timer < 0.5)
        font_alpha = (int)((timer / 0.5) * 255);
    else if (duration - timer < 0.5)
        font_alpha = (int)(((duration - timer) / 0.5) * 255);
    else
        font_alpha = 255;

    if (timer >= duration) {
        done = true;
        if (next_factory)
            next_state = next_factory(m_eng);
    }
}

void LoadingState::draw(Engine& eng) {
    using namespace GameSettings;
    eng.clear(3, 3, 5, 255);
    DrawUtils::static_noise(eng, 0, 0, SCREEN_WIDTH, SCREEN_HEIGHT, 0.012f);

    int ox = Rng::probability(0.05f) ? Rng::int_range(-4, 4) : 0;
    DrawUtils::text(
        eng, tip, SCREEN_WIDTH / 2 + ox, SCREEN_HEIGHT / 2, 18, 160, 160, 170, font_alpha, true);

    int lx = SCREEN_WIDTH - 80, ly = SCREEN_HEIGHT - 80, radius = 20;
    for (int i = 0; i < 8; ++i) {
        double angle =
            std::fmod(loader_angle, 360.0) * 3.14159 / 180.0 + i * 45.0 * 3.14159 / 180.0;
        int ex = lx + (int)(std::cos(angle) * radius);
        int ey = ly + (int)(std::sin(angle) * radius);
        eng.line(lx, ly, ex, ey, 120, 120, 130, 255);
    }
    eng.circle(lx, ly, radius - 6, 0, 0, 0, 255, true);
    eng.circle(lx, ly, radius - 10, 150, 150, 160, 255, false);

    DrawUtils::text(
        eng, Localization::get_text("loading"), lx, ly + 35, 14, 100, 100, 110, 255, true);
}

}  // namespace fnwf
