#include "core/SettingsManager.hpp"
#include <fstream>
#include <sstream>
#include <cstdlib>

namespace fnwf
{

static GameSettingsData s_settings{};
static bool s_loaded = false;

auto SettingsManager::instance() -> GameSettingsData&
{
    if (!s_loaded) { load(); s_loaded = true; }
    return s_settings;
}

void SettingsManager::load()
{
    std::ifstream f("config.dat", std::ios::binary);
    if (!f.is_open()) return;

    auto read_string = [&](std::string& s) {
        std::size_t len{};
        f.read(reinterpret_cast<char*>(&len), sizeof(std::size_t));
        s.resize(len);
        f.read(s.data(), len);
    };

    read_string(s_settings.language);
    f.read(reinterpret_cast<char*>(&s_settings.show_fps), sizeof(bool));
    f.read(reinterpret_cast<char*>(&s_settings.vsync), sizeof(bool));
    f.read(reinterpret_cast<char*>(&s_settings.resolution_w), sizeof(int));
    f.read(reinterpret_cast<char*>(&s_settings.resolution_h), sizeof(int));
    f.read(reinterpret_cast<char*>(&s_settings.fullscreen), sizeof(bool));
    read_string(s_settings.quality);
    f.read(reinterpret_cast<char*>(&s_settings.discord_rpc), sizeof(bool));
    if (f.peek() != EOF)
    {
        f.read(reinterpret_cast<char*>(&s_settings.master_volume), sizeof(int));
        f.read(reinterpret_cast<char*>(&s_settings.sfx_volume), sizeof(int));
        f.read(reinterpret_cast<char*>(&s_settings.music_volume), sizeof(int));
    }
}

void SettingsManager::save()
{
    std::ofstream f("config.dat", std::ios::binary);
    if (!f.is_open()) return;

    auto write_string = [&](const std::string& s) {
        std::size_t len = s.size();
        f.write(reinterpret_cast<const char*>(&len), sizeof(std::size_t));
        f.write(s.data(), len);
    };

    write_string(s_settings.language);
    f.write(reinterpret_cast<const char*>(&s_settings.show_fps), sizeof(bool));
    f.write(reinterpret_cast<const char*>(&s_settings.vsync), sizeof(bool));
    f.write(reinterpret_cast<const char*>(&s_settings.resolution_w), sizeof(int));
    f.write(reinterpret_cast<const char*>(&s_settings.resolution_h), sizeof(int));
    f.write(reinterpret_cast<const char*>(&s_settings.fullscreen), sizeof(bool));
    write_string(s_settings.quality);
    f.write(reinterpret_cast<const char*>(&s_settings.discord_rpc), sizeof(bool));
    f.write(reinterpret_cast<const char*>(&s_settings.master_volume), sizeof(int));
    f.write(reinterpret_cast<const char*>(&s_settings.sfx_volume), sizeof(int));
    f.write(reinterpret_cast<const char*>(&s_settings.music_volume), sizeof(int));
}

} // namespace fnwf
