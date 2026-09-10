#pragma once
#include "core/GameState.hpp"
#include <string>
#include <vector>

namespace fnwf {

class StoryState : public GameState
{
public:
    StoryState(int night, Engine& eng);
    auto handle_event(const Event& ev) -> void override;
    auto update(double dt) -> void override;
    auto draw(Engine& eng) -> void override;
    auto is_done() const -> bool override {
        return done;
    }

private:
    struct Message
    {
        std::string type{};
        std::string user{};
        std::string avatar{};
        std::array<int, 3> color{};
        std::string text{};
    };

    auto build_messages() -> void;
    auto update_scroll_target() -> void;
    auto wrap_text(const std::string& text, int max_width, int font_size)
        -> std::vector<std::string>;
    auto draw_discord_ui(Engine& eng) -> void;

    Engine& m_eng;
    int night{1};
    int current_msg{0};
    double msg_timer{0.0};
    bool done{false};
    int phase{0};
    int fade_alpha{255};
    TextureHandle cedro_avatar{};
    TextureHandle renan_avatar{};
    TextureHandle unknown_avatar{};
    std::vector<Message> messages{};
    double scroll_y{0.0};
    double target_scroll{0.0};
    int visible_messages{0};
    double timer{0.0};
};

}  // namespace fnwf
