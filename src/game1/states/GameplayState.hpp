#pragma once
#include "core/GameState.hpp"
#include "systems/Animatronics.hpp"
#include "systems/CameraSystem.hpp"
#include "systems/Doors.hpp"
#include "systems/Jumpscare.hpp"
#include "systems/Office.hpp"
#include "systems/Power.hpp"
#include <string>
#include <unordered_map>
#include <vector>

namespace fnwf {

class GameplayState : public GameState
{
public:
    GameplayState(Engine& eng, int night, const std::vector<int>* custom_ai = nullptr);
    auto handle_event(const Event& ev) -> void override;
    auto update(double dt) -> void override;
    auto draw(Engine& eng) -> void override;
    auto is_done() const -> bool override;
    auto result() const -> const std::string& override {
        return m_result;
    }

private:
    auto update_power_out(double dt) -> void;
    auto draw_hud(Engine& eng) -> void;
    auto draw_power_out(Engine& eng) -> void;
    auto draw_fade(Engine& eng) -> void;

    Engine& m_eng;
    int night{1};
    std::vector<int> custom_ai_data{};
    const std::vector<int>* custom_ai{nullptr};

    Office office;
    CameraSystem cameras;
    DoorSystem doors;
    PowerSystem power;
    AnimatronicManager animatronics;
    JumpscareSystem jumpscare;

    double time_elapsed{0.0};
    double night_duration{0.0};
    int current_hour{0};
    int prev_hour{0};

    int fade_alpha{255};
    int fade_speed{300};
    bool fading_in{true};
    bool fading_out{false};
    std::string m_result{};
    bool ambient_started{false};

    bool mask_on{false};
    double oxygen{100.0};
    double max_oxygen{100.0};
    double oxygen_depletion_rate{5.5};
    double oxygen_recovery_rate{8.0};

    bool is_blackout{false};
    double blackout_alpha{0.0};
    double blackout_timer{0.0};

    int power_out_phase{0};
    double power_out_timer{0.0};
    double power_out_delay{0.0};
    double fx_timer{0.0};
    double danger_level{0.0};

    bool _win_triggered{false};
    bool _power_out_snd{false};
    bool secret_mode{false};
};

}  // namespace fnwf
