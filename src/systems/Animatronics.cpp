#include "systems/Animatronics.hpp"
#include "core/Rng.hpp"
#include "core/SoundManager.hpp"
#include "game1/GameSettings.hpp"
#include <algorithm>

namespace fnwf {

// Animatronic
Animatronic::Animatronic(std::string n,
                         int ai,
                         std::string start,
                         const std::unordered_map<std::string, std::vector<std::string>>& paths)
    : name(std::move(n)), ai_level(ai), position(std::move(start)), path_map(&paths),
      active(ai > 0) {}

auto Animatronic::update(double dt,
                         const std::string* camera_looking_at,
                         bool left_door_closed,
                         bool right_door_closed,
                         bool mask_on) -> void {
    if (!active || attacking)
        return;
    just_left_office = false;
    move_timer += dt;

    if (!at_door.empty() || at_vent || in_office) {
        stare_timer += dt;
        double target_max = in_office ? 3.0 : max_stare;
        if (stare_timer >= target_max) {
            if (position == "OFFICE_VENT" || in_office) {
                if (!mask_on) {
                    attacking = true;
                } else {
                    auto& path = *path_map;
                    auto it = path.find("OFFICE_VENT");
                    position = (it != path.end() && !it->second.empty()) ? it->second[0] : "1A";
                    at_vent = false;
                    in_office = false;
                    just_left_office = true;
                    stare_timer = 0.0;
                }
            }
        }
    }

    if (move_timer >= move_interval) {
        move_timer = 0.0;
        try_move(camera_looking_at, left_door_closed, right_door_closed, mask_on);
    }
}

auto Animatronic::try_move(const std::string* /*camera_looking_at*/,
                           bool left_door_closed,
                           bool right_door_closed,
                           bool /*mask_on*/) -> void {
    int roll = Rng::int_range(1, 20);
    if (roll > ai_level)
        return;

    if (position == "LEFT_DOOR") {
        if (!left_door_closed) {
            attacking = true;
        } else {
            auto& path = *path_map;
            auto it = path.find("LEFT_DOOR");
            position = (it != path.end() && !it->second.empty()) ? it->second[0] : "1A";
            at_door.clear();
        }
        return;
    }
    if (position == "RIGHT_DOOR") {
        if (!right_door_closed) {
            attacking = true;
        } else {
            auto& path = *path_map;
            auto it = path.find("RIGHT_DOOR");
            position = (it != path.end() && !it->second.empty()) ? it->second[0] : "1A";
            at_door.clear();
        }
        return;
    }
    if (position == "OFFICE_VENT")
        return;

    auto& path = *path_map;
    auto it = path.find(position);
    if (it == path.end() || it->second.empty())
        return;

    auto& possible = it->second;
    auto next_pos = possible[Rng::int_range(0, static_cast<int>(possible.size()) - 1)];
    auto old_pos = position;
    position = next_pos;

    if (old_pos != next_pos) {
        if (name == "alice") {
            if (next_pos == "V" || next_pos == "OFFICE_VENT")
                SoundManager::play_sound("vent");
            else
                SoundManager::play_footstep_random();
        } else {
            SoundManager::play_footstep_random();
        }
    }

    if (next_pos == "LEFT_DOOR" || next_pos == "RIGHT_DOOR") {
        at_door = next_pos;
        at_vent = false;
    } else if (next_pos == "V") {
        at_vent = false;
    } else if (next_pos == "OFFICE_VENT") {
        at_vent = true;
        in_office = true;
        at_door.clear();
        stare_timer = 0.0;
    } else {
        at_door.clear();
        at_vent = false;
        in_office = false;
        stare_timer = 0.0;
    }
}

auto Animatronic::is_at_left_door() const -> bool {
    return position == "LEFT_DOOR";
}
auto Animatronic::is_at_right_door() const -> bool {
    return position == "RIGHT_DOOR";
}

// Sonk
SonkAnimatronic::SonkAnimatronic(int ai) : ai_level(ai), active(ai > 0) {}

auto SonkAnimatronic::update(double dt,
                             const std::string* camera_looking_at,
                             bool /*left_door_closed*/,
                             bool /*right_door_closed*/,
                             bool /*mask_on*/) -> void {
    if (!active || attacking)
        return;

    if (is_charging) {
        charge_timer += dt;
        if (charge_timer >= charge_duration) {
            is_charging = false;
            position = "LEFT_DOOR";
            at_door = "LEFT_DOOR";
            stare_timer = 0.0;
            SoundManager::play_sound("animatronic_door");
        }
        return;
    }

    move_timer += dt;

    if (position == "LEFT_DOOR") {
        stare_timer += dt;
        if (stare_timer >= 1.0) {
            position = "5";
            stage = 0;
            at_door.clear();
            stare_timer = 0.0;
        }
        return;
    }

    if (move_timer < move_interval)
        return;
    move_timer = 0.0;

    int effective_ai = ai_level;
    if (camera_looking_at && *camera_looking_at == "5") {
        effective_ai = std::max(0, effective_ai - 7);
    }

    int roll = Rng::int_range(1, 20);
    if (roll > effective_ai)
        return;

    if (stage < 3) {
        stage++;
    } else {
        is_charging = true;
        charge_timer = 0.0;
        SoundManager::play_sound("footstep");
    }
}

auto SonkAnimatronic::is_at_left_door() const -> bool {
    return position == "LEFT_DOOR";
}
auto SonkAnimatronic::is_at_right_door() const -> bool {
    return false;
}

// Manager
AnimatronicManager::AnimatronicManager(int night, const std::vector<int>* custom_ai)
    : cedro("cedro", 0, "1A", GameSettings::cedro_path()),
      eser("eser", 0, "1A", GameSettings::eser_path()),
      alice("alice", 0, "1A", GameSettings::alice_path()), sonk(0) {
    auto levels = custom_ai ? *custom_ai : GameSettings::night_ai_levels(night);

    bool is_secret = (night == 7);
    if (is_secret && custom_ai) {
        for (int i = 0; i < 4; ++i) {
            if ((*custom_ai)[i] < 40) {
                is_secret = false;
                break;
            }
        }
    }
    secret_mode = is_secret;

    auto move_int = secret_mode ? 1.6 : GameSettings::MOVE_INTERVAL;

    auto& cp = secret_mode ? GameSettings::any_door_path() : GameSettings::cedro_path();
    auto& ep = secret_mode ? GameSettings::any_door_path() : GameSettings::eser_path();

    cedro = Animatronic("cedro", levels[0], "1A", cp);
    eser = Animatronic("eser", levels[1], "1A", ep);
    alice = Animatronic("alice", levels[2], "1A", GameSettings::alice_path());

    cedro.move_interval = move_int;
    eser.move_interval = move_int;
    alice.move_interval = move_int;
    if (secret_mode) {
        cedro.max_stare = 2.3;
        eser.max_stare = 2.3;
        alice.max_stare = 2.3;
    }

    int sonk_ai = levels.size() > 3 ? levels[3] : 0;
    if (!custom_ai && night >= 3 && sonk_ai <= 0)
        sonk_ai = 5;

    sonk = SonkAnimatronic(sonk_ai);
    sonk.move_interval = secret_mode ? 1.25 : GameSettings::MOVE_INTERVAL;
    if (secret_mode)
        sonk.charge_duration = 0.65;
}

auto AnimatronicManager::update(double dt,
                                const std::string* camera_looking_at,
                                bool left_door_closed,
                                bool right_door_closed,
                                bool mask_on) -> void {
    cedro.update(dt, camera_looking_at, left_door_closed, right_door_closed, mask_on);
    eser.update(dt, camera_looking_at, left_door_closed, right_door_closed, mask_on);
    alice.update(dt, camera_looking_at, left_door_closed, right_door_closed, mask_on);
    sonk.update(dt, camera_looking_at, left_door_closed, right_door_closed, mask_on);
}

auto AnimatronicManager::get_positions() const -> std::unordered_map<std::string, std::string> {
    return {{"cedro", cedro.position},
            {"eser", eser.position},
            {"alice", alice.position},
            {"sonk", sonk.position}};
}

auto AnimatronicManager::get_attacker() const -> std::string {
    if (cedro.attacking)
        return "cedro";
    if (eser.attacking)
        return "eser";
    if (alice.attacking)
        return "alice";
    if (sonk.attacking)
        return "Sonk";
    return {};
}

auto AnimatronicManager::get_at_left_door() const -> std::string {
    if (cedro.is_at_left_door() && !cedro.attacking)
        return "cedro";
    if (eser.is_at_left_door() && !eser.attacking)
        return "eser";
    if (alice.is_at_left_door() && !alice.attacking)
        return "alice";
    if (sonk.is_at_left_door() && !sonk.attacking)
        return "Sonk";
    return {};
}

auto AnimatronicManager::get_at_right_door() const -> std::string {
    if (cedro.is_at_right_door() && !cedro.attacking)
        return "cedro";
    if (eser.is_at_right_door() && !eser.attacking)
        return "eser";
    if (alice.is_at_right_door() && !alice.attacking)
        return "alice";
    if (sonk.is_at_right_door() && !sonk.attacking)
        return "Sonk";
    return {};
}

auto AnimatronicManager::get_at_vent() const -> std::string {
    if (cedro.at_vent && !cedro.attacking)
        return "cedro";
    if (eser.at_vent && !eser.attacking)
        return "eser";
    if (alice.at_vent && !alice.attacking)
        return "alice";
    if (sonk.at_vent && !sonk.attacking)
        return "Sonk";
    return {};
}

auto AnimatronicManager::get_in_office() const -> std::string {
    if (cedro.in_office && !cedro.attacking)
        return "cedro";
    if (eser.in_office && !eser.attacking)
        return "eser";
    if (alice.in_office && !alice.attacking)
        return "alice";
    if (sonk.in_office && !sonk.attacking)
        return "Sonk";
    return {};
}

auto AnimatronicManager::check_alice_just_left() -> bool {
    return alice.just_left_office;
}
auto AnimatronicManager::get_foxy_stage() const -> int {
    return sonk.stage;
}
auto AnimatronicManager::is_secret_mode() const -> bool {
    return secret_mode;
}

}  // namespace fnwf
