#pragma once

#include <cstdint>

namespace fnwf::GameSettings {

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

constexpr double PAN_SPEED = 8.0;
constexpr int PAN_MARGIN = 200;
constexpr double MOVE_INTERVAL = 5.0;

}  // namespace fnwf::GameSettings
