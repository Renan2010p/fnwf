#pragma once
#include "core/GameState.hpp"
#include <functional>
#include <string>
#include <vector>

namespace fnwf {

class LoadingState : public GameState
{
public:
    using StateFactory = std::function<std::unique_ptr<GameState>(Engine&)>;

    LoadingState(Engine& eng);
    auto set_factory(StateFactory f) -> void {
        next_factory = std::move(f);
    }
    auto handle_event(const Event& ev) -> void override;
    auto update(float dt) -> void override;
    auto draw(Engine& eng) -> void override;
    auto is_done() const -> bool override {
        return done;
    }
    auto get_next_state() -> std::unique_ptr<GameState> {
        return std::move(next_state);
    }
    auto state_type() const -> fnwf::StateType override {
        return fnwf::StateType::Loading;
    }

private:
    Engine& m_eng;
    StateFactory next_factory{};
    float timer{0.0f};
    float duration{4.0f};
    std::string tip{};
    bool done{false};
    std::unique_ptr<GameState> next_state{};
    int font_alpha{0};
    float glitch_timer{0.0f};
    float loader_angle{0.0f};

    static const std::vector<std::string> TIPS;
};

}  // namespace fnwf
