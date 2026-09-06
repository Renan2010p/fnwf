#pragma once
#include "core/GameState.hpp"
#include "engine/Engine.hpp"

namespace fnwf {

class GameOverState : public GameState
{
public:
    GameOverState(bool is_win, int night, Engine& eng);
    void handle_event(const Event& ev) override;
    void update(double dt) override;
    void draw(Engine& eng) override;
    bool is_done() const override;
    auto result() const -> const std::string& override { return m_result; }
    auto get_is_win() const -> bool { return is_win; }
    auto get_night() const -> int { return night; }

private:
    void draw_game_over(Engine& eng);
    void draw_win(Engine& eng);

    Engine& m_eng;
    bool is_win{false};
    int night{1};
    double timer{0.0};
    int text_alpha{0};
    bool show_text{false};
    std::string m_result{};
};

}
