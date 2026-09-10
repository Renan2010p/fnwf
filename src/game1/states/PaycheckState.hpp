#pragma once
#include "core/GameState.hpp"

namespace fnwf {

class PaycheckState : public GameState
{
public:
    PaycheckState(Engine& eng);
    void handle_event(const Event& ev) override;
    void update(double dt) override;
    void draw(Engine& eng) override;
    bool is_done() const override {
        return done;
    }

private:
    Engine& m_eng;
    double timer{0.0};
    bool done{false};
    int fade_alpha{255};
    bool fading_in{true};
    bool fading_out{false};
    std::string name{"Renan Lucas"};
    std::string amount{"1.621,00"};
    std::string date{"15/02/2026"};
};

}  // namespace fnwf
