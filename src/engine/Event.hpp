#pragma once

#include <cstdint>
#include <string>

namespace fnwf
{

enum class EventType
{
    None,
    Quit,
    KeyDown,
    KeyUp,
    MouseButtonDown,
    MouseButtonUp,
    MouseMotion,
    MouseWheel
};

struct Event
{
    EventType type{EventType::None};
    std::int32_t key{};
    std::string key_name{};
    std::string scan_name{};
    std::int32_t x{};
    std::int32_t y{};
};

} // namespace fnwf
