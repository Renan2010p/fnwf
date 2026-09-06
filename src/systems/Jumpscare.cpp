#include "systems/Jumpscare.hpp"
#include "core/DrawUtils.hpp"
#include "game1/GameSettings.hpp"
#include <algorithm>
#include <cstdlib>

namespace fnwf
{

JumpscareSystem::JumpscareSystem() = default;

void JumpscareSystem::trigger(const std::string& animatronic_name)
{
    if (active) return;
    active = true;
    animatronic = animatronic_name;
    timer = 0.0;
    done = false;
}

void JumpscareSystem::update(double dt)
{
    if (!active) return;
    timer += dt;
    if (timer >= duration) done = true;
}

void JumpscareSystem::draw(Engine& eng)
{
    if (!active) return;
    float prog = std::min(1.0f, static_cast<float>(timer / duration));
    eng.draw_rect(0, 0, GameSettings::SCREEN_WIDTH, GameSettings::SCREEN_HEIGHT, 0, 0, 0);

    int sx = (std::rand() % 41) - 20;
    int sy = (std::rand() % 41) - 20;
    sx = static_cast<int>(sx * (1.0f - prog * 0.5f));
    sy = static_cast<int>(sy * (1.0f - prog * 0.5f));

    if (prog < 0.1f)
    {
        eng.draw_rect(0, 0, GameSettings::SCREEN_WIDTH, GameSettings::SCREEN_HEIGHT,
                      255, 255, 255, static_cast<int>(255 * (1.0f - prog / 0.1f)));
    }

    auto fw = static_cast<int>(GameSettings::SCREEN_WIDTH * 0.6 * (1.0f + prog * 0.3f));
    auto fh = static_cast<int>(GameSettings::SCREEN_HEIGHT * 0.7 * (1.0f + prog * 0.3f));
    DrawUtils::animatronic_face(eng, animatronic,
        GameSettings::SCREEN_WIDTH / 2 - fw / 2 + sx,
        GameSettings::SCREEN_HEIGHT / 2 - fh / 2 + sy - 30, fw, fh);
    DrawUtils::static_noise(eng, 0, 0, GameSettings::SCREEN_WIDTH, GameSettings::SCREEN_HEIGHT, 0.1f + prog * 0.2f);

    auto red_a = static_cast<int>(80 * std::pow(std::sin(timer * 20.0), 2));
    eng.draw_rect(0, 0, GameSettings::SCREEN_WIDTH, GameSettings::SCREEN_HEIGHT, 200, 0, 0, red_a);
}

void JumpscareSystem::reset()
{
    active = false;
    animatronic.clear();
    timer = 0.0;
    done = false;
}

} // namespace fnwf
