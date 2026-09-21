#pragma once
#include "core/GameState.hpp"
#include <string>
#include <vector>

namespace fnwf {

struct OptionItem
{
    std::string id;
    std::string label;
    enum Type { Toggle, Bool, Slider, Action } type;
    std::vector<std::string> values{};
    int current{0};
    bool value{false};
    int slider_value{0};
    int slider_max{100};
    std::string action{};
};

class OptionsState : public GameState
{
public:
    OptionsState(Engine& eng);
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
        return fnwf::StateType::Options;
    }

private:
    auto rebuild_options() -> void;
    auto apply_settings() -> void;
    auto handle_click(int mx, int my) -> void;

    Engine& m_eng;
    float timer{0.0f};
    int selected{1};
    bool done{false};
    std::string m_result{};
    std::vector<OptionItem> options{};
    int max_options{0};

    std::vector<std::pair<int, int>> resolutions{};
    int current_res_idx{0};
    bool is_fullscreen{false};
    bool show_fps{false};
    bool vsync{true};
    std::string lang{"en"};
    bool discord_rpc{true};
    int master_volume{80};
    int sfx_volume{100};
    int music_volume{70};

    float bg_scroll{0.0f};
    float highlight_y{150.0f};
    float highlight_target_y{150.0f};
    float scroll_offset{0.0f};
    float scroll_target{0.0f};
    std::vector<float> item_glows{};
};

}  // namespace fnwf
