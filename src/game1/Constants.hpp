#pragma once

#include <cstdint>
#include <string>
#include <algorithm>

namespace fnwf::GameSettings {

#ifdef PS2
constexpr int SCREEN_WIDTH = 640;
constexpr int SCREEN_HEIGHT = 448;
constexpr int FPS = 60;
constexpr const char* ASSETS_DIR = "CDROM0:/ASSETS";

constexpr double HOUR_DURATION = 60.0;
constexpr double MAX_POWER = 100.0;
constexpr double BASE_POWER_DRAIN = 0.12;
constexpr int OFFICE_WIDTH = 640;

inline std::string asset_path(const std::string& sub, const std::string& ext) {
    std::string upper_sub = sub;
    std::string upper_ext = ext;
    std::transform(upper_sub.begin(), upper_sub.end(), upper_sub.begin(), ::toupper);
    std::transform(upper_ext.begin(), upper_ext.end(), upper_ext.begin(), ::toupper);
    return std::string(ASSETS_DIR) + "/" + upper_sub + upper_ext;
}

inline std::string asset_file(const std::string& name, const std::string& ext) {
    std::string upper_name = name;
    std::string upper_ext = ext;
    std::transform(upper_name.begin(), upper_name.end(), upper_name.begin(), ::toupper);
    std::transform(upper_ext.begin(), upper_ext.end(), upper_ext.begin(), ::toupper);
    return std::string(ASSETS_DIR) + "/" + upper_name + upper_ext;
}

inline std::string asset_full(const std::string& rel) {
    std::string upper = rel;
    std::transform(upper.begin(), upper.end(), upper.begin(), ::toupper);
    return std::string(ASSETS_DIR) + "/" + upper;
}
#else
constexpr int SCREEN_WIDTH = 1280;
constexpr int SCREEN_HEIGHT = 720;
constexpr int FPS = 60;
constexpr const char* ASSETS_DIR = "assets";

constexpr double HOUR_DURATION = 60.0;
constexpr double MAX_POWER = 100.0;
constexpr double BASE_POWER_DRAIN = 0.12;
constexpr int OFFICE_WIDTH = 1280;

inline std::string asset_path(const std::string& sub, const std::string& ext) {
    return std::string(ASSETS_DIR) + "/" + sub + ext;
}

inline std::string asset_file(const std::string& name, const std::string& ext) {
    return std::string(ASSETS_DIR) + "/" + name + ext;
}

inline std::string asset_full(const std::string& rel) {
    return std::string(ASSETS_DIR) + "/" + rel;
}
#endif
constexpr double PAN_SPEED = 8.0;
constexpr int PAN_MARGIN = 200;
constexpr double MOVE_INTERVAL = 5.0;

}  // namespace fnwf::GameSettings
