#pragma once
#include "core/GameState.hpp"
namespace fnwf {
class WarningState : public GameState
{
public:
    WarningState(Engine& eng);
    auto handle_event(const Event& ev) -> void override;
    auto update(double dt) -> void override;
    auto draw(Engine& eng) -> void override;
    auto is_done() const -> bool override {
        return done;
    }

private:
    double timer{0.0}, alpha{0.0};
    int phase{0};
    bool done{false};
};
}  // namespace fnwf
