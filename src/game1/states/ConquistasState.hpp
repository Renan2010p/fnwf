#pragma once
#include "core/GameState.hpp"
#include "engine/Engine.hpp"
#include <vector>
#include <string>

namespace fnwf {

class ConquistasState : public GameState
{
public:
    ConquistasState(const std::vector<std::string>& achievements, Engine& eng);
    void handle_event(const Event& ev) override;
    void update(double dt) override;
    void draw(Engine& eng) override;
    bool is_done() const override { return done; }
    auto result() const -> const std::string& override { return m_result; }

private:
    Engine& m_eng;
    std::vector<std::string> unlocked_achievements{};
    bool done{false};
    std::string m_result{};
    double timer{0.0};

    struct AchData { std::string id; std::string name; std::string desc; };
    std::vector<AchData> achievements_list{};
};

}
