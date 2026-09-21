#pragma once

#include "engine/Engine.hpp"

#include <string>

namespace fnwf {

enum class StateResult {
    None,
    Win,
    Jumpscare,
    Menu,
    Back,
    Start,
    Continue,
    Night6,
    Night7,
    Extras,
    Conquistas,
    Quit,
    Options,
    Next
};

// Type identifier for each state — replaces dynamic_cast
enum class StateType {
    None,
    Warning,
    Menu,
    Options,
    Gameplay,
    Loading,
    Story,
    NightTransition,
    SixAM,
    Paycheck,
    Newspaper,
    GameOver,
    CustomNight,
    Extras,
    Conquistas,
    Arcade,
};

class GameState
{
public:
    virtual ~GameState() = default;
    virtual auto handle_event(const Event& ev) -> void = 0;
    virtual auto update(float dt) -> void = 0;
    virtual auto draw(Engine& eng) -> void = 0;
    virtual auto is_done() const -> bool = 0;
    virtual auto get_result() const -> StateResult {
        return StateResult::None;
    }
    virtual auto result() const -> const std::string& {
        static const std::string empty;
        return empty;
    }
    virtual auto state_type() const -> StateType {
        return StateType::None;
    }
};

}  // namespace fnwf
