#pragma once
#include "core/GameState.hpp"
namespace fnwf {
class WarningState : public GameState
{
public:
    WarningState(Engine& eng);
    auto handle_event(const Event& ev) -> void override;
    auto update(float dt) -> void override;
    auto draw(Engine& eng) -> void override;
    auto is_done() const -> bool override {
        return done;
    }
    auto state_type() const -> fnwf::StateType override {
        return fnwf::StateType::Warning;
    }

private:
    float timer{0.0f}, alpha{0.0f};
    int phase{0};
    bool done{false};
};
}  // namespace fnwf
