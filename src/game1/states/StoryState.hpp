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
    auto update(float dt) -> void override;
    auto draw(Engine& eng) -> void override;
    auto is_done() const -> bool override {
        return done;
    }
    auto state_type() const -> fnwf::StateType override {
        return fnwf::StateType::Story;
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
    float msg_timer{0.0f};
    bool done{false};
    int phase{0};
    int fade_alpha{255};
    TextureHandle cedro_avatar{};
    TextureHandle renan_avatar{};
    TextureHandle unknown_avatar{};
    std::vector<Message> messages{};
    float scroll_y{0.0f};
    float target_scroll{0.0f};
    int visible_messages{0};
    float timer{0.0f};
};

}  // namespace fnwf
