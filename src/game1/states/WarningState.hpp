#pragma once
#include "core/GameState.hpp"
namespace fnwf {
class WarningState : public GameState {
public:
    WarningState(Engine& eng);
    void handle_event(const Event& ev) override;
    void update(double dt) override;
    void draw(Engine& eng) override;
    bool is_done() const override { return done; }
private:
    double timer{0.0}, alpha{0.0};
    int phase{0};
    bool done{false};
};
}
