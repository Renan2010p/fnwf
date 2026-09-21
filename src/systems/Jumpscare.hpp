#pragma once

#include "engine/Engine.hpp"
#include <string>

namespace fnwf {

class JumpscareSystem
{
public:
    JumpscareSystem();
    auto trigger(const std::string& animatronic_name) -> void;
    auto update(float dt) -> void;
    auto draw(Engine& eng) -> void;
    auto is_done() const -> bool {
        return done;
    }
    auto reset() -> void;

    bool active{false};
    std::string animatronic{};
    float timer{0.0f};
    float duration{1.2};
    bool done{false};
};

}  // namespace fnwf
