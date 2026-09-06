#pragma once
#include "core/GameState.hpp"
#include "engine/Engine.hpp"

namespace fnwf {

class SixAMState : public GameState
{
public:
    SixAMState(int night, Engine& eng);
    void handle_event(const Event& ev) override;
    void update(double dt) override;
    void draw(Engine& eng) override;
    bool is_done() const override { return done; }
    auto get_night() const -> int { return night; }

private:
    Engine& m_eng;
    int night{1};
    double timer{0.0};
    bool done{false};
    int hour{5};
    bool show_six{false};
    bool played_chime{false};
};

}
