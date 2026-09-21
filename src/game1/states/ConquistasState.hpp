#pragma once
#include "core/GameState.hpp"
#include <string>
#include <vector>

namespace fnwf {

class ConquistasState : public GameState
{
public:
    ConquistasState(const std::vector<std::string>& achievements, Engine& eng);
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
        return fnwf::StateType::Conquistas;
    }

private:
    std::vector<std::string> unlocked_achievements{};
    bool done{false};
    std::string m_result{};
    float timer{0.0f};

    struct AchData
    {
        std::string id;
        std::string name;
        std::string desc;
    };
    std::vector<AchData> achievements_list{};
};

}  // namespace fnwf
