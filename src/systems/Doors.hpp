#pragma once

#include "engine/Engine.hpp"
#include <string>
#include <unordered_map>

namespace fnwf {

class DoorSystem
{
public:
    DoorSystem();
    void update(double dt);
    void draw_buttons(Engine& eng, bool camera_open);
    auto handle_click(int mx, int my) -> std::string;
    auto get_power_usage() -> int;

    bool left_closed{false};
    bool right_closed{false};
    bool left_light{false};
    bool right_light{false};
    double left_anim{0.0};
    double right_anim{0.0};

private:
    double anim_speed{4.0};
    std::unordered_map<std::string, std::array<int, 4>> button_rects{};
};

}  // namespace fnwf
