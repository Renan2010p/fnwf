#include "core/SaveManager.hpp"
#include <fstream>

namespace fnwf {

static constexpr const char* SAVE_FILE = "save.dat";
static constexpr std::size_t MAX_STRING_LEN = 1024;
static constexpr std::size_t MAX_ACHIEVEMENTS = 256;

auto SaveManager::load_data() -> GameData {
    GameData data{};
    std::ifstream f(SAVE_FILE, std::ios::binary);
    if (!f.is_open())
        return data;

    f.read(reinterpret_cast<char*>(&data.completed_nights), sizeof(int));
    f.read(reinterpret_cast<char*>(&data.has_seen_story), sizeof(bool));
    f.read(reinterpret_cast<char*>(&data.infinite_power), sizeof(bool));
    f.read(reinterpret_cast<char*>(&data.fast_nights), sizeof(bool));

    std::size_t count{};
    f.read(reinterpret_cast<char*>(&count), sizeof(std::size_t));
    if (!f.good() || count > MAX_ACHIEVEMENTS) {
        return data;
    }

    for (std::size_t i = 0; i < count; ++i) {
        std::size_t len{};
        f.read(reinterpret_cast<char*>(&len), sizeof(std::size_t));
        if (!f.good() || len > MAX_STRING_LEN) {
            break;
        }
        std::string s(len, '\0');
        f.read(s.data(), len);
        if (!f.good()) {
            break;
        }
        data.achievements.push_back(std::move(s));
    }
    return data;
}

void SaveManager::save_progress(int completed_nights,
                                bool has_seen_story,
                                bool infinite_power,
                                bool fast_nights,
                                const std::vector<std::string>& achievements) {
    std::ofstream f(SAVE_FILE, std::ios::binary);
    if (!f.is_open())
        return;

    f.write(reinterpret_cast<const char*>(&completed_nights), sizeof(int));
    f.write(reinterpret_cast<const char*>(&has_seen_story), sizeof(bool));
    f.write(reinterpret_cast<const char*>(&infinite_power), sizeof(bool));
    f.write(reinterpret_cast<const char*>(&fast_nights), sizeof(bool));

    const std::size_t count = achievements.size();
    f.write(reinterpret_cast<const char*>(&count), sizeof(std::size_t));
    for (const auto& s : achievements) {
        const std::size_t len = s.size();
        f.write(reinterpret_cast<const char*>(&len), sizeof(std::size_t));
        f.write(s.data(), len);
    }
}

}  // namespace fnwf
