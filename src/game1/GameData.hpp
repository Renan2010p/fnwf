#pragma once

#include <string>
#include <unordered_map>
#include <vector>

namespace fnwf::GameSettings
{

inline auto night_ai_levels(int night) -> std::vector<int>
{
    static const std::vector<std::vector<int>> levels = {
        {3, 2, 0, 0}, {5, 4, 3, 0}, {7, 6, 6, 5}, {10, 9, 10, 8},
        {13, 12, 14, 12}, {16, 15, 18, 15}, {20, 20, 20, 20}
    };
    if (night < 1 || night > 7) return levels[0];
    return levels[night - 1];
}

inline auto camera_names() -> const std::unordered_map<std::string, std::string>&
{
    static const std::unordered_map<std::string, std::string> names = {
        {"1A", "Show Stage"}, {"1B", "Dining Area"}, {"1C", "Backstage"},
        {"5", "Pirate Cove"}, {"2A", "West Hall"}, {"2B", "West Hall Corner"},
        {"3", "Supply Closet"}, {"4A", "East Hall"}, {"4B", "East Hall Corner"},
        {"V", "Ventilation"}
    };
    return names;
}

inline auto cedro_path() -> const std::unordered_map<std::string, std::vector<std::string>>&
{
    static const std::unordered_map<std::string, std::vector<std::string>> path = {
        {"1A", {"1B"}}, {"1B", {"2A", "3", "1C"}}, {"1C", {"1B"}},
        {"2A", {"2B", "1B", "3"}}, {"3", {"2A"}}, {"2B", {"LEFT_DOOR"}},
        {"LEFT_DOOR", {"1B"}}
    };
    return path;
}

inline auto eser_path() -> const std::unordered_map<std::string, std::vector<std::string>>&
{
    static const std::unordered_map<std::string, std::vector<std::string>> path = {
        {"1A", {"1B"}}, {"1B", {"4A"}}, {"4A", {"4B", "1B"}},
        {"4B", {"RIGHT_DOOR"}}, {"RIGHT_DOOR", {"1B"}}
    };
    return path;
}

inline auto alice_path() -> const std::unordered_map<std::string, std::vector<std::string>>&
{
    static const std::unordered_map<std::string, std::vector<std::string>> path = {
        {"1A", {"1B"}}, {"1B", {"4A", "2A"}}, {"4A", {"V"}},
        {"2A", {"V"}}, {"V", {"OFFICE_VENT"}}, {"OFFICE_VENT", {"1B"}}
    };
    return path;
}

inline auto any_door_path() -> const std::unordered_map<std::string, std::vector<std::string>>&
{
    static const std::unordered_map<std::string, std::vector<std::string>> path = {
        {"1A", {"1B"}}, {"1B", {"2A", "4A", "3", "1C"}}, {"1C", {"1B"}},
        {"2A", {"2B", "1B", "3", "4A"}}, {"2B", {"LEFT_DOOR", "RIGHT_DOOR", "2A"}},
        {"3", {"2A", "1B"}}, {"4A", {"4B", "1B", "2A"}},
        {"4B", {"RIGHT_DOOR", "LEFT_DOOR", "4A"}},
        {"LEFT_DOOR", {"1B"}}, {"RIGHT_DOOR", {"1B"}}
    };
    return path;
}

} // namespace fnwf::GameSettings
