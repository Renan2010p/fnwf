#pragma once

#include <cstdint>
#include <random>

namespace fnwf::Rng {

inline auto engine() -> std::mt19937& {
    static std::mt19937 eng{std::random_device{}()};
    return eng;
}

inline auto int_range(int min, int max) -> int {
    std::uniform_int_distribution<int> dist(min, max);
    return dist(engine());
}

inline auto float_range(float min, float max) -> float {
    std::uniform_real_distribution<float> dist(min, max);
    return dist(engine());
}

inline auto probability(float chance) -> bool {
    return float_range(0.0f, 1.0f) < chance;
}

}  // namespace fnwf::Rng
