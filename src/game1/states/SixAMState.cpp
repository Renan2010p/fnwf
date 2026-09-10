#include "game1/states/SixAMState.hpp"
#include "core/DrawUtils.hpp"
#include "core/Localization.hpp"
#include "core/SoundManager.hpp"
#include "game1/GameSettings.hpp"
#include <string>

namespace fnwf {

SixAMState::SixAMState(int night_, Engine& eng) : m_eng(eng), night(night_) {}

auto SixAMState::update(double dt) -> void {
    timer += dt;
    if (!show_six && timer > 2.0) {
        hour = 6;
        show_six = true;
    }
    if (show_six && !played_chime) {
        SoundManager::play_sound("noite_concluida");
        played_chime = true;
    }
    if (timer > 10.0)
        done = true;
}

auto SixAMState::handle_event(const Event& ev) -> void {
    if (timer > 2.0 && (ev.type == EventType::KeyDown || ev.type == EventType::MouseButtonDown))
        done = true;
}

auto SixAMState::draw(Engine& eng) -> void {
    using namespace GameSettings;
    eng.clear(0, 0, 0, 255);
    int cx = SCREEN_WIDTH / 2, cy = SCREEN_HEIGHT / 2;
    DrawUtils::text(eng, std::to_string(hour), cx - 40, cy - 20, 120, 255, 255, 255, 255, true);
    DrawUtils::text(eng, "AM", cx + 80, cy - 10, 50, 255, 255, 255, 255, true);

    if (timer > 8.0 && ((int)(timer * 2) % 2 == 1))
        DrawUtils::text(eng,
                        Localization::get_text("press_any_key"),
                        cx,
                        SCREEN_HEIGHT - 50,
                        16,
                        150,
                        150,
                        150,
                        255,
                        true);
}

}  // namespace fnwf
