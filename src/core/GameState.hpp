#pragma once

#include "engine/Engine.hpp"
#include "engine/Event.hpp"

#include <string>

namespace fnwf
{

enum class StateResult
{
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

class GameState
{
public:
    virtual ~GameState() = default;
    virtual void handle_event(const Event& ev) = 0;
    virtual void update(double dt) = 0;
    virtual void draw(Engine& eng) = 0;
    virtual bool is_done() const = 0;
    virtual auto get_result() const -> StateResult { return StateResult::None; }
    virtual auto result() const -> const std::string& { static const std::string empty; return empty; }
};

} // namespace fnwf
