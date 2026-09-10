#pragma once

#include "engine/Engine.hpp"
#include <functional>
#include <memory>
#include <string>

namespace fnwf {

class GameState;

class StateMachine
{
public:
    using StateFactory = std::function<std::unique_ptr<GameState>(Engine&)>;

    explicit StateMachine(Engine& eng) : m_eng(eng) {}

    void switch_state(const std::string& name, StateFactory factory);
    void switch_state_raw(std::unique_ptr<GameState> state);
    void update(double dt);
    void draw();
    void handle_event(const Event& ev);
    auto current_name() const -> const std::string& {
        return m_current_name;
    }
    auto current() -> GameState* {
        return m_current.get();
    }

private:
    Engine& m_eng;
    std::unique_ptr<GameState> m_current{};
    std::string m_current_name{};
};

}  // namespace fnwf
