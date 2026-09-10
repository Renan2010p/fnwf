#pragma once

#include <string>

namespace fnwf {

class Engine;

namespace SoundManager {
void set_engine(Engine* eng);
void play_sound(const std::string& name, int loops = 0, int channel = -1);
void stop_channel(int channel);
void stop_all_sounds();
void play_menu_ambient();
void stop_menu_ambient();
void play_ambient_loop();
void stop_ambient();
void play_scary_stinger();
void play_camera_switch();
void play_door_sound();
void play_light_sound();
void play_jumpscare_sound();
void play_footstep_random();
void play_window_scare();
void play_mask_breathing();
void stop_mask_breathing();
void set_master_volume(int vol);
void set_sfx_volume(int vol);
void set_music_volume(int vol);
}  // namespace SoundManager

}  // namespace fnwf
