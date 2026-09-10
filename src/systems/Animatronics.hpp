#pragma once

#include <string>
#include <unordered_map>
#include <vector>

namespace fnwf {

class Animatronic
{
public:
    Animatronic(std::string name,
                int ai_level,
                std::string start_pos,
                const std::unordered_map<std::string, std::vector<std::string>>& path_map);

    auto update(double dt,
                const std::string* camera_looking_at,
                bool left_door_closed,
                bool right_door_closed,
                bool mask_on) -> void;
    auto is_at_left_door() const -> bool;
    auto is_at_right_door() const -> bool;

    std::string name;
    int ai_level;
    std::string position;
    const std::unordered_map<std::string, std::vector<std::string>>* path_map;
    double move_timer{0.0};
    bool active{false};
    std::string at_door{};
    bool at_vent{false};
    bool attacking{false};
    bool in_office{false};
    bool just_left_office{false};
    double stare_timer{0.0};
    double max_stare{4.0};
    double move_interval{5.0};

private:
    auto try_move(const std::string* camera_looking_at,
                  bool left_door_closed,
                  bool right_door_closed,
                  bool mask_on) -> void;
};

class SonkAnimatronic
{
public:
    SonkAnimatronic(int ai_level);

    auto update(double dt,
                const std::string* camera_looking_at,
                bool left_door_closed,
                bool right_door_closed,
                bool mask_on) -> void;
    auto is_at_left_door() const -> bool;
    auto is_at_right_door() const -> bool;

    std::string name{"Sonk"};
    int ai_level{0};
    bool active{false};
    std::string position{"5"};
    int stage{0};
    double move_timer{0.0};
    std::string at_door{};
    bool at_vent{false};
    bool in_office{false};
    bool attacking{false};
    double stare_timer{0.0};
    bool is_charging{false};
    double charge_timer{0.0};
    double charge_duration{1.1};
    double move_interval{5.0};
};

class AnimatronicManager
{
public:
    AnimatronicManager(int night, const std::vector<int>* custom_ai = nullptr);

    auto update(double dt,
                const std::string* camera_looking_at,
                bool left_door_closed,
                bool right_door_closed,
                bool mask_on) -> void;

    auto get_positions() const -> std::unordered_map<std::string, std::string>;
    auto get_attacker() const -> std::string;
    auto get_at_left_door() const -> std::string;
    auto get_at_right_door() const -> std::string;
    auto get_at_vent() const -> std::string;
    auto get_in_office() const -> std::string;
    auto check_alice_just_left() -> bool;
    auto get_foxy_stage() const -> int;
    auto is_secret_mode() const -> bool;

    Animatronic cedro;
    Animatronic eser;
    Animatronic alice;
    SonkAnimatronic sonk;
    bool secret_mode{false};
};

}  // namespace fnwf
