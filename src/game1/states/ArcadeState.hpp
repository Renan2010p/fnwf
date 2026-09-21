#pragma once
#include "core/GameState.hpp"
#include "systems/Animatronics.hpp"
#include "systems/CameraSystem.hpp"
#include "systems/Doors.hpp"
#include "systems/Jumpscare.hpp"
#include "systems/Office.hpp"
#include "systems/Power.hpp"
#include <string>

namespace fnwf {

class ArcadeState : public GameState
{
public:
    ArcadeState(Engine& eng);
    auto handle_event(const Event& ev) -> void override;
    auto update(float dt) -> void override;
    auto draw(Engine& eng) -> void override;
    auto is_done() const -> bool override;
    auto result() const -> const std::string& override {
        return m_result;
    }

    auto get_score() const -> int {
        return static_cast<int>(time_survived);
    }
    auto state_type() const -> fnwf::StateType override {
        return fnwf::StateType::Arcade;
    }

private:
    auto update_difficulty() -> void;
    auto update_power_out(float dt) -> void;
    auto draw_hud(Engine& eng) -> void;
    auto draw_power_out(Engine& eng) -> void;
    auto draw_fade(Engine& eng) -> void;

    Engine& m_eng;

    Office office;
    CameraSystem cameras;
    DoorSystem doors;
    PowerSystem power;
    AnimatronicManager animatronics;
    JumpscareSystem jumpscare;

    float time_survived{0.0f};
    float ramp_timer{0.0f};
    int difficulty_level{0};

    int fade_alpha{255};
    int fade_speed{300};
    bool fading_in{true};
    bool fading_out{false};
    std::string m_result{};
    bool ambient_started{false};

    bool mask_on{false};
    float oxygen{100.0f};
    float max_oxygen{100.0f};
    float oxygen_depletion_rate{5.5};
    float oxygen_recovery_rate{8.0f};

    bool is_blackout{false};
    float blackout_alpha{0.0f};
    float blackout_timer{0.0f};

    int power_out_phase{0};
    float power_out_timer{0.0f};
    float power_out_delay{0.0f};
    float fx_timer{0.0f};
    float danger_level{0.0f};

    bool _power_out_snd{false};

    float base_move_interval{5.0f};
    float base_power_drain{0.12};
};

}  // namespace fnwf
