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
    void handle_event(const Event& ev) override;
    void update(double dt) override;
    void draw(Engine& eng) override;
    bool is_done() const override;
    auto result() const -> const std::string& override {
        return m_result;
    }

    int get_score() const {
        return static_cast<int>(time_survived);
    }

private:
    void update_difficulty();
    void update_power_out(double dt);
    void draw_hud(Engine& eng);
    void draw_power_out(Engine& eng);
    void draw_fade(Engine& eng);

    Engine& m_eng;

    Office office;
    CameraSystem cameras;
    DoorSystem doors;
    PowerSystem power;
    AnimatronicManager animatronics;
    JumpscareSystem jumpscare;

    double time_survived{0.0};
    double ramp_timer{0.0};
    int difficulty_level{0};

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

    bool _power_out_snd{false};

    double base_move_interval{5.0};
    double base_power_drain{0.12};
};

}  // namespace fnwf
