#pragma once

#include "engine/Engine.hpp"
#include <string>

namespace fnwf {

class JumpscareSystem
{
public:
    JumpscareSystem();
    void trigger(const std::string& animatronic_name);
    void update(double dt);
    void draw(Engine& eng);
    auto is_done() const -> bool {
        return done;
    }
    void reset();

    bool active{false};
    std::string animatronic{};
    double timer{0.0};
    double duration{1.2};
    bool done{false};
};

}  // namespace fnwf
