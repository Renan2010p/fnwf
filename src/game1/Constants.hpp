#pragma once

#include <cstdint>

namespace fnwf::GameSettings {

#ifdef PS2
constexpr int SCREEN_WIDTH = 640;
constexpr int SCREEN_HEIGHT = 448;
constexpr int FPS = 60;
constexpr const char* ASSETS_DIR = "mass:assets";

constexpr double HOUR_DURATION = 60.0;
constexpr double MAX_POWER = 100.0;
constexpr double BASE_POWER_DRAIN = 0.12;
constexpr int OFFICE_WIDTH = 640;
#else
constexpr int SCREEN_WIDTH = 1280;
constexpr int SCREEN_HEIGHT = 720;
constexpr int FPS = 60;
constexpr const char* ASSETS_DIR = "assets";

constexpr double HOUR_DURATION = 60.0;
constexpr double MAX_POWER = 100.0;
constexpr double BASE_POWER_DRAIN = 0.12;
constexpr int OFFICE_WIDTH = 1280;
#endif
constexpr double PAN_SPEED = 8.0;
constexpr int PAN_MARGIN = 200;
constexpr double MOVE_INTERVAL = 5.0;

}  // namespace fnwf::GameSettings
