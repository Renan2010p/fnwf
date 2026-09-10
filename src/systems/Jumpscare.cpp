#include "systems/Jumpscare.hpp"
#include "core/DrawUtils.hpp"
#include "core/Rng.hpp"
#include "game1/GameSettings.hpp"
#include <algorithm>

namespace fnwf {

JumpscareSystem::JumpscareSystem() = default;

auto JumpscareSystem::trigger(const std::string& animatronic_name) -> void {
    if (active)
        return;
    active = true;
    animatronic = animatronic_name;
    timer = 0.0;
    done = false;
}

auto JumpscareSystem::update(double dt) -> void {
    if (!active)
        return;
    timer += dt;
    if (timer >= duration)
        done = true;
}

auto JumpscareSystem::draw(Engine& eng) -> void {
    if (!active)
        return;
    float prog = std::min(1.0f, static_cast<float>(timer / duration));
    eng.draw_rect(0, 0, GameSettings::SCREEN_WIDTH, GameSettings::SCREEN_HEIGHT, 0, 0, 0);

    int sx = Rng::int_range(-20, 20);
    int sy = Rng::int_range(-20, 20);
    sx = static_cast<int>(sx * (1.0f - prog * 0.5f));
    sy = static_cast<int>(sy * (1.0f - prog * 0.5f));

    if (prog < 0.1f) {
        eng.draw_rect(0,
                      0,
                      GameSettings::SCREEN_WIDTH,
                      GameSettings::SCREEN_HEIGHT,
                      255,
                      255,
                      255,
                      static_cast<int>(255 * (1.0f - prog / 0.1f)));
    }

    auto fw = static_cast<int>(GameSettings::SCREEN_WIDTH * 0.6 * (1.0f + prog * 0.3f));
    auto fh = static_cast<int>(GameSettings::SCREEN_HEIGHT * 0.7 * (1.0f + prog * 0.3f));
    DrawUtils::animatronic_face(eng,
                                animatronic,
                                GameSettings::SCREEN_WIDTH / 2 - fw / 2 + sx,
                                GameSettings::SCREEN_HEIGHT / 2 - fh / 2 + sy - 30,
                                fw,
                                fh);
    DrawUtils::static_noise(
        eng, 0, 0, GameSettings::SCREEN_WIDTH, GameSettings::SCREEN_HEIGHT, 0.1f + prog * 0.2f);

    auto red_a = static_cast<int>(80 * std::pow(std::sin(timer * 20.0), 2));
    eng.draw_rect(0, 0, GameSettings::SCREEN_WIDTH, GameSettings::SCREEN_HEIGHT, 200, 0, 0, red_a);
}

auto JumpscareSystem::reset() -> void {
    active = false;
    animatronic.clear();
    timer = 0.0;
    done = false;
}

}  // namespace fnwf
