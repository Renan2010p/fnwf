#pragma once

#include "engine/Engine.hpp"

namespace fnwf {

class PowerSystem
{
public:
    PowerSystem();
    auto update(double dt, int door_usage, bool camera_open) -> void;
    auto draw(Engine& eng) -> void;

    double power{100.0};
    int usage_level{1};
    bool is_dead{false};
    double dead_timer{0.0};
};

}  // namespace fnwf
