#pragma once
#include "core/GameState.hpp"
#include "engine/Engine.hpp"
#include <vector>
#include <string>

namespace fnwf {

class CustomNightState : public GameState
{
public:
    CustomNightState(Engine& eng);
    void handle_event(const Event& ev) override;
    void update(double dt) override;
    void draw(Engine& eng) override;
    bool is_done() const override { return done; }
    auto result() const -> const std::string& override { return m_result; }
    auto get_ai_levels() const -> const std::vector<int>& { return ai_levels; }

private:
    void rebuild_layout();
    void apply_preset(int index);
    void cycle_preset(int direction);
    auto get_ai_cap() const -> int;
    void unlock_secret_mode();

    Engine& m_eng;
    double timer{0.0};
    int selected{1};
    bool done{false};
    std::string m_result{};
    std::vector<int> ai_levels{0, 0, 0, 0};

    struct AnimData { std::string name; std::string sprite; int size_w; int size_h; };
    std::vector<AnimData> animatronics{};
    std::unordered_map<std::string, TextureHandle> sprites{};

    struct Preset { std::string name; std::vector<int> levels; bool has_levels; };
    std::vector<Preset> presets{};
    int current_preset{1};

    std::string secret_code_buffer{};
    bool secret_code_pending{false};
    bool secret_mode_unlocked{false};

    std::vector<std::array<int,4>> card_rects{};
    std::vector<std::array<int,4>> up_rects{};
    std::vector<std::array<int,4>> down_rects{};
    std::array<int,4> preset_prev{};
    std::array<int,4> preset_next{};
    std::array<int,4> preset_label{};
    std::array<int,4> ready_rect{};
    std::vector<double> card_scales{};
    std::vector<double> card_glows{};
};

}
