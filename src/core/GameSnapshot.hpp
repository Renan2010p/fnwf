#pragma once

#include <string>
#include <vector>
#include <cstdint>

namespace fnwf {

// Snapshot of all in-game state for save/load
struct GameSnapshot
{
    // Night info
    int night{1};
    std::vector<int> custom_ai{};

    // Time
    float time_elapsed{0.0f};
    float night_duration{0.0f};
    int current_hour{12};

    // Power
    float power{100.0f};
    int power_usage_level{1};
    bool power_is_dead{false};
    float power_dead_timer{0.0f};

    // Doors
    bool door_left_closed{false};
    bool door_right_closed{false};
    bool door_left_light{false};
    bool door_right_light{false};
    float door_left_anim{0.0f};
    float door_right_anim{0.0f};

    // Camera
    bool cam_open{false};
    std::string cam_current{"1A"};
    bool cam_mask_open{false};

    // Office
    float office_pan_x{0.0f};
    bool office_vent_light{false};

    // Mask/Oxygen
    bool mask_on{false};
    float oxygen{100.0f};
    float max_oxygen{100.0f};

    // Blackout
    bool is_blackout{false};
    float blackout_alpha{0.0f};
    float blackout_timer{0.0f};

    // Animatronics positions
    std::string cedro_pos{"1A"};
    std::string eser_pos{"1A"};
    std::string alice_pos{"1A"};
    std::string sonk_pos{"5"};
    int sonk_stage{0};

    // Sonk specific
    bool sonk_charging{false};
    float sonk_charge_timer{0.0f};

    // Save magic + version (for validation)
    static constexpr uint32_t MAGIC = 0x464E5746;  // "FNWF"
    static constexpr uint32_t VERSION = 1;
};

}  // namespace fnwf
