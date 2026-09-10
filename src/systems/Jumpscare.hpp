#pragma once

#include "engine/Engine.hpp"
#include <string>

namespace fnwf {

class JumpscareSystem
{
public:
    JumpscareSystem();
    auto trigger(const std::string& animatronic_name) -> void;
    auto update(double dt) -> void;
    auto draw(Engine& eng) -> void;
    auto is_done() const -> bool {
        return done;
    }
    auto reset() -> void;

    bool active{false};
    std::string animatronic{};
    double timer{0.0};
    double duration{1.2};
    bool done{false};
};

}  // namespace fnwf
