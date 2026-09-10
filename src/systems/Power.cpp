#include "systems/Power.hpp"
#include "core/DrawUtils.hpp"
#include "core/Localization.hpp"
#include "game1/GameSettings.hpp"
#include <algorithm>
#include <cstdio>

namespace fnwf {

PowerSystem::PowerSystem() = default;

auto PowerSystem::update(double dt, int door_usage, bool camera_open) -> void {
    if (is_dead) {
        dead_timer += dt;
        return;
    }
    usage_level = std::min(5, 1 + door_usage + (camera_open ? 1 : 0));
    static const double drain_muls[] = {1.0, 1.55, 2.35, 3.4, 4.8};
    double mul = drain_muls[std::max(0, std::min(4, usage_level - 1))];
    power -= GameSettings::BASE_POWER_DRAIN * mul * dt;
    if (power <= 0.0) {
        power = 0.0;
        is_dead = true;
        dead_timer = 0.0;
    }
}

auto PowerSystem::draw(Engine& eng) -> void {
    auto x = 24;
    auto y = GameSettings::SCREEN_HEIGHT - 78;
    int pct = std::max(0, static_cast<int>(power));

    char buf[128];
    std::snprintf(buf, sizeof(buf), Localization::get_text("power_left").c_str(), pct);
    DrawUtils::text(eng, buf, x, y, 18, 255, 255, 255);

    auto uy = y + 28;
    DrawUtils::text(eng, Localization::get_text("usage"), x, uy, 16, 200, 200, 200);
    for (int i = 0; i < 5; ++i) {
        auto ux = x + 78 + i * 16;
        auto c = (i < usage_level) ? GameSettings::MONITOR_GREEN : Color{40, 40, 45};
        eng.draw_rect(ux, uy + 4, 10, 16, c.r, c.g, c.b);
        eng.draw_rect(ux, uy + 4, 10, 16, 75, 75, 80, 255, false);
    }
}

}  // namespace fnwf
