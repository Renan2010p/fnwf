#pragma once
#include "core/GameState.hpp"

namespace fnwf {

class NewspaperState : public GameState
{
public:
    NewspaperState(Engine& eng);
    auto handle_event(const Event& ev) -> void override;
    auto update(float dt) -> void override;
    auto draw(Engine& eng) -> void override;
    auto is_done() const -> bool override {
        return done;
    }
    auto state_type() const -> fnwf::StateType override {
        return fnwf::StateType::Newspaper;
    }

private:
    float timer{0.0f};
    bool done{false};
    int fade_alpha{255};
    bool fading_in{true};
    bool fading_out{false};
};

}  // namespace fnwf
