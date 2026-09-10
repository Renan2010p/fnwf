#pragma once
#include "core/GameState.hpp"

namespace fnwf {

class NightTransitionState : public GameState
{
public:
    NightTransitionState(int night, Engine& eng);
    void handle_event(const Event& ev) override;
    void update(double dt) override;
    void draw(Engine& eng) override;
    bool is_done() const override {
        return done;
    }

private:
    struct Message
    {
        std::string user{};
        std::string avatar{};
        std::array<int, 3> color{};
        std::string text{};
    };

    void advance();
    void update_scroll();
    void draw_discord(Engine& eng);

    Engine& m_eng;
    int night{1};
    double timer{0.0};
    bool done{false};
    int phase{0};
    int fade_alpha{255};
    TextureHandle cedro_avatar{};
    TextureHandle renan_avatar{};
    std::vector<Message> messages{};
    int visible_messages{0};
    double scroll_y{0.0};
    double target_scroll{0.0};
};

}  // namespace fnwf
