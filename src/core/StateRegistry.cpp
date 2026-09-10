#include "core/StateRegistry.hpp"

namespace fnwf {

void StateRegistry::register_state(const std::string& name, Factory factory) {
    m_factories[name] = std::move(factory);
}

auto StateRegistry::create(const std::string& name, Engine& eng) -> std::unique_ptr<GameState> {
    auto it = m_factories.find(name);
    if (it != m_factories.end()) {
        return it->second(eng);
    }
    return nullptr;
}

auto StateRegistry::has_state(const std::string& name) const -> bool {
    return m_factories.count(name) > 0;
}

}  // namespace fnwf
