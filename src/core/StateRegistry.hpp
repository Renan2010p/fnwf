#pragma once

#include "core/GameState.hpp"
#include "engine/Engine.hpp"

#include <functional>
#include <memory>
#include <string>
#include <unordered_map>

namespace fnwf {

class StateRegistry
{
public:
    using Factory = std::function<std::unique_ptr<GameState>(Engine&)>;

    void register_state(const std::string& name, Factory factory);
    auto create(const std::string& name, Engine& eng) -> std::unique_ptr<GameState>;
    auto has_state(const std::string& name) const -> bool;

private:
    std::unordered_map<std::string, Factory> m_factories;
};

}  // namespace fnwf
