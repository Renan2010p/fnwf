#pragma once
#include "core/GameState.hpp"
#include <string>
#include <vector>
namespace fnwf {
struct MenuItem
{
    std::string label;
    std::string action;
};
class MenuState : public GameState
{
public:
    MenuState(int completed_nights, bool has_seen_story, Engine& eng);
    void handle_event(const Event& ev) override;
    void update(double dt) override;
    void draw(Engine& eng) override;
    bool is_done() const override {
        return done;
    }
    auto result() const -> const std::string& override {
        return m_result;
    }

private:
    void build_options();
    auto handle_action(const std::string& action) -> std::string;
    Engine& m_eng;
    int m_completed_nights;
    bool m_has_seen_story;
    int selected{1};
    bool done{false};
    std::string m_result{};
    std::string menu_page{"main"};
    std::vector<MenuItem> options{};
    double timer{0.0};
    double highlight_y{300};
    double highlight_target_y{300};
    TextureHandle cedro_sprite{};
    TextureHandle eser_sprite{};
    TextureHandle alice_sprite{};
    TextureHandle sonk_sprite{};
    TextureHandle mafia_logo{};
    std::vector<TextureHandle> menu_animatronics{};
    int current_anim_idx{0};
};
}  // namespace fnwf
