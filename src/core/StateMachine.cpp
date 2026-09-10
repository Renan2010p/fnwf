#include "core/StateMachine.hpp"
#include "core/GameState.hpp"

namespace fnwf {

auto StateMachine::switch_state(const std::string& name, StateFactory factory) -> void {
    m_current_name = name;
    m_current = factory(m_eng);
}

auto StateMachine::switch_state_raw(std::unique_ptr<GameState> state) -> void {
    m_current = std::move(state);
}

auto StateMachine::update(double dt) -> void {
    if (m_current) {
        m_current->update(dt);
    }
}

auto StateMachine::draw() -> void {
    if (m_current) {
        m_current->draw(m_eng);
    }
}

auto StateMachine::handle_event(const Event& ev) -> void {
    if (m_current) {
        m_current->handle_event(ev);
    }
}

}  // namespace fnwf
