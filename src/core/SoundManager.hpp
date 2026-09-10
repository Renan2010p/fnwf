#pragma once

#include <string>

namespace fnwf {

class Engine;

namespace SoundManager {
auto set_engine(Engine* eng) -> void;
auto play_sound(const std::string& name, int loops = 0, int channel = -1) -> void;
auto stop_channel(int channel) -> void;
auto stop_all_sounds() -> void;
auto play_menu_ambient() -> void;
auto stop_menu_ambient() -> void;
auto play_ambient_loop() -> void;
auto stop_ambient() -> void;
auto play_scary_stinger() -> void;
auto play_camera_switch() -> void;
auto play_door_sound() -> void;
auto play_light_sound() -> void;
auto play_jumpscare_sound() -> void;
auto play_footstep_random() -> void;
auto play_window_scare() -> void;
auto play_mask_breathing() -> void;
auto stop_mask_breathing() -> void;
auto set_master_volume(int vol) -> void;
auto set_sfx_volume(int vol) -> void;
auto set_music_volume(int vol) -> void;
}  // namespace SoundManager

}  // namespace fnwf
