#include "game1/states/LoadingState.hpp"
#include "core/DrawUtils.hpp"
#include "core/Localization.hpp"
#include "core/Rng.hpp"
#include "game1/GameSettings.hpp"
#include <algorithm>
#include <cmath>

namespace fnwf {

LoadingState::LoadingState(Engine& eng) : m_eng(eng) {
    int tip_idx = Rng::int_range(1, 12);
    tip = Localization::get_text("tip_" + std::to_string(tip_idx));
}

auto LoadingState::handle_event(const Event&) -> void {}

auto LoadingState::update(float dt) -> void {
    timer += dt;
    glitch_timer += dt;
    loader_angle += 360.0f * dt;

    if (timer < 0.4f)
        font_alpha = (int)((timer / 0.4f) * 255);
    else
        font_alpha = 255;

    // Real work: load one queued sprite per frame. Each call blocks for the
    // decode, then the next draw() shows the updated progress bar.
    if (loaded < preload.size()) {
        DrawUtils::load_sprite(m_eng, preload[loaded]);
        ++loaded;
    }

    // Finish once everything loaded (plus a short minimum so the screen is
    // visible). The 8s cap guarantees we never get stuck on a bad asset.
    const bool all_loaded = (loaded >= preload.size()) || timer >= 8.0f;
    if (all_loaded && timer >= duration) {
        done = true;
        if (next_factory)
            next_state = next_factory(m_eng);
    }
}

auto LoadingState::draw(Engine& eng) -> void {
    using namespace GameSettings;
    eng.clear(3, 3, 5, 255);
    DrawUtils::static_noise(eng, 0, 0, SCREEN_WIDTH, SCREEN_HEIGHT, 0.012f);

    int ox = Rng::probability(0.05f) ? Rng::int_range(-4, 4) : 0;
    DrawUtils::text(
        eng, tip, SCREEN_WIDTH / 2 + ox, SCREEN_HEIGHT / 2, 18, 160, 160, 170, font_alpha, true);

    int lx = SCREEN_WIDTH - 80, ly = SCREEN_HEIGHT - 80, radius = 20;
    for (int i = 0; i < 8; ++i) {
        float angle =
            std::fmod(loader_angle, 360.0f) * 3.14159 / 180.0f + i * 45.0f * 3.14159 / 180.0f;
        int ex = lx + (int)(std::cos(angle) * radius);
        int ey = ly + (int)(std::sin(angle) * radius);
        eng.line(lx, ly, ex, ey, 120, 120, 130, 255);
    }
    eng.circle(lx, ly, radius - 6, 0, 0, 0, 255, true);
    eng.circle(lx, ly, radius - 10, 150, 150, 160, 255, false);

    DrawUtils::text(
        eng, Localization::get_text("loading"), lx, ly + 35, 14, 100, 100, 110, 255, true);

    // Progress bar: filled by however much has actually loaded.
    if (!preload.empty()) {
        const float p = static_cast<float>(loaded) / static_cast<float>(preload.size());
        const int bw = 420, bh = 10;
        const int bx = SCREEN_WIDTH / 2 - bw / 2;
        const int by = SCREEN_HEIGHT - 60;
        eng.draw_rect(bx, by, bw, bh, 30, 30, 36, 220);
        eng.draw_rect(bx + 2, by + 2, static_cast<int>((bw - 4) * p), bh - 4, 150, 150, 160, 255);
        eng.draw_rect(bx, by, bw, bh, 90, 90, 100, 255, false);
        const std::string item = (loaded < preload.size()) ? preload[loaded] : "";
        if (!item.empty())
            DrawUtils::text(eng,
                            item,
                            SCREEN_WIDTH / 2,
                            by - 16,
                            12,
                            120,
                            120,
                            130,
                            std::min(255, font_alpha),
                            true);
    }
}

}  // namespace fnwf
