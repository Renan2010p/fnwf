#include "core/SoundManager.hpp"
#include "core/Rng.hpp"
#include "core/SettingsManager.hpp"
#include "engine/Engine.hpp"
#include "game1/GameSettings.hpp"
#include <unordered_map>

namespace fnwf {

static Engine* s_eng = nullptr;
static std::unordered_map<std::string, SoundHandle> s_cache{};
static int s_menu_channel = -1;
static int s_breathing_channel = -1;

static const std::unordered_map<std::string, std::string> s_filename_map = {
    {"door_open", "portas.ogg"},
    {"door_close", "portas.ogg"},
    {"door", "portas.ogg"},
    {"light", "trocar_camera.ogg"},
    {"footstep", "passos.ogg"},
    {"footsteps_1", "passos.ogg"},
    {"footsteps_2", "passos.ogg"},
    {"footsteps_3", "passos.ogg"},
    {"footsteps_4", "passos.ogg"},
    {"breathing", "usando_a_mascara.ogg"},
    {"mask_on", "colocar_mascara.ogg"},
    {"mask_off", "retirar_mascara.ogg"},
    {"blip", "trocar_camera.ogg"},
    {"select", "trocar_camera.ogg"},
    {"notification", "trocar_camera.ogg"},
    {"camera", "trocar_camera.ogg"},
    {"clock", "trocar_camera.ogg"},
    {"win", "noite_concluida.ogg"},
    {"noite_concluida", "noite_concluida.ogg"},
    {"vent", "ventilacao.ogg"},
    {"window_scare", "animatronic_na_porta.ogg"},
    {"animatronic_door", "animatronic_na_porta.ogg"},
    {"jumpscare", "animatronic_na_porta.ogg"},
    {"stinger", "animatronic_na_porta.ogg"},
    {"power_out", "animatronic_na_porta.ogg"},
};

auto SoundManager::set_engine(Engine* eng) -> void {
    s_eng = eng;
}

auto SoundManager::play_sound(const std::string& name, int loops, int channel) -> void {
    if (!s_eng)
        return;
    auto it = s_cache.find(name);
    if (it == s_cache.end()) {
        auto fname_it = s_filename_map.find(name);
        std::string fname = (fname_it != s_filename_map.end()) ? fname_it->second : name + ".ogg";
        std::string path = GameSettings::asset_full("audio/" + fname);
        auto snd = s_eng->load_sound(path);
        if (!snd)
            return;
        s_cache[name] = *snd;
        it = s_cache.find(name);
    }
    s_eng->play_sound(it->second, loops, channel);
}

auto SoundManager::stop_channel(int channel) -> void {
    if (s_eng)
        s_eng->stop_channel(channel);
}
auto SoundManager::stop_all_sounds() -> void {
    if (s_eng)
        s_eng->stop_all_sounds();
}

auto SoundManager::play_menu_ambient() -> void {
    s_menu_channel = 0;
    play_sound("menu_ambient", -1, 0);
}

auto SoundManager::stop_menu_ambient() -> void {
    if (s_menu_channel != -1)
        stop_channel(s_menu_channel);
}
auto SoundManager::play_ambient_loop() -> void {
    play_sound("ambient", -1, 1);
}
auto SoundManager::stop_ambient() -> void {
    stop_channel(1);
}
auto SoundManager::play_scary_stinger() -> void {
    play_sound("stinger", 0, -1);
}
auto SoundManager::play_camera_switch() -> void {
    play_sound("blip", 0, -1);
}
auto SoundManager::play_door_sound() -> void {
    play_sound("door");
}
auto SoundManager::play_light_sound() -> void {
    play_sound("light");
}
auto SoundManager::play_jumpscare_sound() -> void {
    play_sound("jumpscare");
}
auto SoundManager::play_window_scare() -> void {
    play_sound("window_scare");
}

auto SoundManager::play_footstep_random() -> void {
    int idx = Rng::int_range(1, 4);
    play_sound("footsteps_" + std::to_string(idx), 0, -1);
}

auto SoundManager::play_mask_breathing() -> void {
    if (s_breathing_channel == -1) {
        s_breathing_channel = 5;
        play_sound("breathing", -1, 5);
    }
}

auto SoundManager::stop_mask_breathing() -> void {
    if (s_breathing_channel != -1) {
        stop_channel(s_breathing_channel);
        s_breathing_channel = -1;
    }
}

auto SoundManager::set_master_volume(int vol) -> void {
    if (s_eng)
        s_eng->set_master_volume(vol);
}

auto SoundManager::set_sfx_volume(int vol) -> void {
    if (s_eng)
        s_eng->set_sfx_volume(vol);
}

auto SoundManager::set_music_volume(int vol) -> void {
    if (s_eng)
        s_eng->set_music_volume(vol);
}

}  // namespace fnwf
