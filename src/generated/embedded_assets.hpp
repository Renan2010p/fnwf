#pragma once
#include <string>
#include <cstdint>

namespace embedded {
struct Asset { const std::uint8_t* data; std::uint32_t size; };
Asset get_asset(const std::string& name);
}
