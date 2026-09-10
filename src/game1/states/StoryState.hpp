#pragma once
#include "core/GameState.hpp"
#include <string>
#include <vector>

namespace fnwf {

class StoryState : public GameState
{
public:
    StoryState(int night, Engine& eng);
    void handle_event(const Event& ev) override;
    void update(double dt) override;
    void draw(Engine& eng) override;
    bool is_done() const override {
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

    void build_messages();
    void update_scroll_target();
    auto wrap_text(const std::string& text, int max_width, int font_size)
        -> std::vector<std::string>;
    void draw_discord_ui(Engine& eng);

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
