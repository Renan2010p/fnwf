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
    auto handle_event(const Event& ev) -> void override;
    auto update(float dt) -> void override;
    auto draw(Engine& eng) -> void override;
    auto is_done() const -> bool override {
        return done;
    }
    auto result() const -> const std::string& override {
        return m_result;
    }
    auto state_type() const -> fnwf::StateType override {
        return fnwf::StateType::Menu;
    }

private:
    auto build_options() -> void;
    auto handle_action(const std::string& action) -> std::string;
    int m_completed_nights;
    bool m_has_seen_story;
    int selected{1};
    bool done{false};
    std::string m_result{};
    std::string menu_page{"main"};
    std::vector<MenuItem> options{};
    float timer{0.0f};
    float highlight_y{300};
    float highlight_target_y{300};
    TextureHandle cedro_sprite{};
    TextureHandle eser_sprite{};
    TextureHandle alice_sprite{};
    TextureHandle sonk_sprite{};
    TextureHandle mafia_logo{};
    std::vector<TextureHandle> menu_animatronics{};
    int current_anim_idx{0};
};
}  // namespace fnwf
