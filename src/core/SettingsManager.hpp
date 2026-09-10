#pragma once

#include <fstream>
#include <string>

namespace fnwf {

struct GameSettingsData
{
    std::string language{"en"};
    bool show_fps{false};
    bool vsync{true};
    int resolution_w{1280};
    int resolution_h{720};
    bool fullscreen{false};
    std::string quality{"high"};
    bool discord_rpc{true};
    int master_volume{80};
    int sfx_volume{100};
    int music_volume{70};
};

class SettingsManager
{
public:
    static auto instance() -> GameSettingsData&;
    static auto load() -> void;
    static auto save() -> void;

private:
    static auto read_bounded_string(std::ifstream& f) -> std::string;
};

}  // namespace fnwf
