#pragma once

#include "core/GameSnapshot.hpp"
#include <optional>
#include <string>
#include <vector>

namespace fnwf {

struct GameData
{
    int completed_nights{0};
    bool has_seen_story{false};
    bool infinite_power{false};
    bool fast_nights{false};
    std::vector<std::string> achievements{};
};

class SaveManager
{
public:
    // Legacy save/load (completed nights, achievements)
    static auto load_data() -> GameData;
    static auto save_progress(int completed_nights,
                              bool has_seen_story,
                              bool infinite_power,
                              bool fast_nights,
                              const std::vector<std::string>& achievements) -> void;

    // In-game snapshot save/load (mid-office state)
    static auto save_game(const GameSnapshot& snap) -> bool;
    static auto load_game() -> std::optional<GameSnapshot>;

    // Has a snapshot been saved?
    static auto has_saved_game() -> bool;

    // Delete saved game
    static auto delete_saved_game() -> void;

    // Get the save directory (platform-specific)
    static auto save_dir() -> std::string;
};

}  // namespace fnwf
