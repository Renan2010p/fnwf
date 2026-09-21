#pragma once

#include "engine/Engine.hpp"
#include <string>
#include <unordered_map>

namespace fnwf {

class DoorSystem
{
public:
    DoorSystem();
    auto update(float dt) -> void;
    auto draw_buttons(Engine& eng, bool camera_open) -> void;
    auto handle_click(int mx, int my) -> std::string;
    auto get_power_usage() -> int;

    bool left_closed{false};
    bool right_closed{false};
    bool left_light{false};
    bool right_light{false};
    float left_anim{0.0f};
    float right_anim{0.0f};

private:
    float anim_speed{4.0f};
    std::unordered_map<std::string, std::array<int, 4>> button_rects{};
};

}  // namespace fnwf
