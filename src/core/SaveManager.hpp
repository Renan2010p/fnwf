#pragma once

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
    static auto load_data() -> GameData;
    static auto save_progress(int completed_nights,
                              bool has_seen_story,
                              bool infinite_power,
                              bool fast_nights,
                              const std::vector<std::string>& achievements) -> void;
};

}  // namespace fnwf
