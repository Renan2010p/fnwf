#pragma once
#include "core/GameState.hpp"
#include <string>
#include <unordered_map>
#include <vector>

namespace fnwf {

class ExtrasState : public GameState
{
public:
    ExtrasState(int completed_nights,
                bool infinite_power,
                bool fast_nights,
                const std::vector<std::string>& achievements,
                Engine& eng);
    auto handle_event(const Event& ev) -> void override;
    auto update(double dt) -> void override;
    auto draw(Engine& eng) -> void override;
    auto is_done() const -> bool override {
        return done;
    }
    auto result() const -> const std::string& override {
        return m_result;
    }
    auto get_cheats() const -> std::pair<bool, bool> {
        return {infinite_power, fast_nights};
    }

private:
    auto draw_animatronics(Engine& eng) -> void;
    auto draw_credits(Engine& eng) -> void;
    auto draw_cheats(Engine& eng) -> void;
    auto draw_achievements(Engine& eng) -> void;

    Engine& m_eng;
    double timer{0.0};
    bool done{false};
    std::string m_result{};
    int category{1};
    int anim_idx{1};
    int selected{1};

    std::vector<std::string> categories{};
    struct AnimData
    {
        std::string name;
        std::string sprite;
        std::string desc;
    };
    std::vector<AnimData> animatronics{};
    std::unordered_map<std::string, TextureHandle> sprites{};

    struct AchData
    {
        std::string id;
        std::string name;
        std::string desc;
    };
    std::vector<AchData> achievements_list{};
    bool infinite_power{false};
    bool fast_nights{false};
    std::vector<std::string> unlocked_achievements{};
};

}  // namespace fnwf
