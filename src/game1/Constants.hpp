#pragma once

#include <cstdint>

namespace fnwf::GameSettings
{

constexpr std::int32_t SCREEN_WIDTH = 1280;
constexpr std::int32_t SCREEN_HEIGHT = 720;
constexpr std::int32_t FPS = 60;
constexpr const char* ASSETS_DIR = "assets";

constexpr double HOUR_DURATION = 60.0;
constexpr double MAX_POWER = 100.0;
constexpr double BASE_POWER_DRAIN = 0.12;
constexpr std::int32_t OFFICE_WIDTH = 1280;
constexpr double PAN_SPEED = 8.0;
constexpr std::int32_t PAN_MARGIN = 200;
constexpr double MOVE_INTERVAL = 5.0;

} // namespace fnwf::GameSettings
