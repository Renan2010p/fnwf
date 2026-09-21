#pragma once

#include "engine/Engine.hpp"

namespace fnwf {

class PowerSystem
{
public:
    PowerSystem();
    auto update(float dt, int door_usage, bool camera_open) -> void;
    auto draw(Engine& eng) -> void;

    float power{100.0f};
    int usage_level{1};
    bool is_dead{false};
    float dead_timer{0.0f};
};

}  // namespace fnwf
