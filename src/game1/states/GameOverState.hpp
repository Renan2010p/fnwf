#pragma once
#include "core/GameState.hpp"

namespace fnwf {

class GameOverState : public GameState
{
public:
    GameOverState(bool is_win, int night, Engine& eng);
    auto handle_event(const Event& ev) -> void override;
    auto update(float dt) -> void override;
    auto draw(Engine& eng) -> void override;
    auto is_done() const -> bool override;
    auto result() const -> const std::string& override {
        return m_result;
    }
    auto get_is_win() const -> bool {
        return is_win;
    }
    auto get_night() const -> int {
        return night;
    }
    auto state_type() const -> fnwf::StateType override {
        return fnwf::StateType::GameOver;
    }

private:
    auto draw_game_over(Engine& eng) -> void;
    auto draw_win(Engine& eng) -> void;

    bool is_win{false};
    int night{1};
    float timer{0.0f};
    int text_alpha{0};
    bool show_text{false};
    std::string m_result{};
};

}  // namespace fnwf
