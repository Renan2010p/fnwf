#pragma once
#include "core/GameState.hpp"
#include "engine/Engine.hpp"
#include <string>
#include <vector>
#include <functional>

namespace fnwf {

class LoadingState : public GameState
{
public:
    using StateFactory = std::function<std::unique_ptr<GameState>(Engine&)>;

    LoadingState(Engine& eng);
    void set_factory(StateFactory f) { next_factory = std::move(f); }
    void handle_event(const Event& ev) override;
    void update(double dt) override;
    void draw(Engine& eng) override;
    bool is_done() const override { return done; }
    auto get_next_state() -> std::unique_ptr<GameState> { return std::move(next_state); }

private:
    Engine& m_eng;
    StateFactory next_factory{};
    double timer{0.0};
    double duration{4.0};
    std::string tip{};
    bool done{false};
    std::unique_ptr<GameState> next_state{};
    int font_alpha{0};
    double glitch_timer{0.0};
    double loader_angle{0.0};

    static const std::vector<std::string> TIPS;
};

}
