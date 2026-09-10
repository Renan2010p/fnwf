#include "core/StateMachine.hpp"
#include "core/GameState.hpp"

namespace fnwf {

void StateMachine::switch_state(const std::string& name, StateFactory factory) {
    m_current_name = name;
    m_current = factory(m_eng);
}

void StateMachine::switch_state_raw(std::unique_ptr<GameState> state) {
    m_current = std::move(state);
}

void StateMachine::update(double dt) {
    if (m_current) {
        m_current->update(dt);
    }
}

void StateMachine::draw() {
    if (m_current) {
        m_current->draw(m_eng);
    }
}

void StateMachine::handle_event(const Event& ev) {
    if (m_current) {
        m_current->handle_event(ev);
    }
}

}  // namespace fnwf
