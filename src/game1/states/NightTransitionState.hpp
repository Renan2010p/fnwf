#pragma once
#include "core/GameState.hpp"

namespace fnwf {

class NightTransitionState : public GameState
{
public:
    NightTransitionState(int night, Engine& eng);
    auto handle_event(const Event& ev) -> void override;
    auto update(double dt) -> void override;
    auto draw(Engine& eng) -> void override;
    auto is_done() const -> bool override {
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

    auto advance() -> void;
    auto update_scroll() -> void;
    auto draw_discord(Engine& eng) -> void;

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
