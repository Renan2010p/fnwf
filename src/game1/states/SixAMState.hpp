#pragma once
#include "core/GameState.hpp"

namespace fnwf {

class SixAMState : public GameState
{
public:
    SixAMState(int night, Engine& eng);
    auto handle_event(const Event& ev) -> void override;
    auto update(float dt) -> void override;
    auto draw(Engine& eng) -> void override;
    auto is_done() const -> bool override {
        return done;
    }
    auto get_night() const -> int {
        return night;
    }
    auto state_type() const -> fnwf::StateType override {
        return fnwf::StateType::SixAM;
    }

private:
    Engine& m_eng;
    int night{1};
    float timer{0.0f};
    bool done{false};
    int hour{5};
    bool show_six{false};
    bool played_chime{false};
};

}  // namespace fnwf
