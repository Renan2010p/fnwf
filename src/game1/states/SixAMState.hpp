#pragma once
#include "core/GameState.hpp"

namespace fnwf {

class SixAMState : public GameState
{
public:
    SixAMState(int night, Engine& eng);
    auto handle_event(const Event& ev) -> void override;
    auto update(double dt) -> void override;
    auto draw(Engine& eng) -> void override;
    auto is_done() const -> bool override {
        return done;
    }
    auto get_night() const -> int {
        return night;
    }

private:
    Engine& m_eng;
    int night{1};
    double timer{0.0};
    bool done{false};
    int hour{5};
    bool show_six{false};
    bool played_chime{false};
};

}  // namespace fnwf
