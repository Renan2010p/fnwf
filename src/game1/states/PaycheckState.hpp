#pragma once
#include "core/GameState.hpp"

namespace fnwf {

class PaycheckState : public GameState
{
public:
    PaycheckState(Engine& eng);
    auto handle_event(const Event& ev) -> void override;
    auto update(float dt) -> void override;
    auto draw(Engine& eng) -> void override;
    auto is_done() const -> bool override {
        return done;
    }
    auto state_type() const -> fnwf::StateType override {
        return fnwf::StateType::Paycheck;
    }

private:
    Engine& m_eng;
    float timer{0.0f};
    bool done{false};
    int fade_alpha{255};
    bool fading_in{true};
    bool fading_out{false};
    std::string name{"Renan Lucas"};
    std::string amount{"1.621,00"};
    std::string date{"15/02/2026"};
};

}  // namespace fnwf
