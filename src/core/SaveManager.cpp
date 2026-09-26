#include "core/SaveManager.hpp"
#include <cstdio>
#include <cstring>
#include <filesystem>
#include <fstream>
#include <optional>

namespace fnwf {

static constexpr const char* SAVE_FILE = "save.dat";
static constexpr const char* GAME_SNAPSHOT_FILE = "game_snapshot.dat";
static constexpr std::size_t MAX_STRING_LEN = 1024;
static constexpr std::size_t MAX_ACHIEVEMENTS = 256;

// Platform-specific save directory
auto SaveManager::save_dir() -> std::string {
#if defined(__PS2__)
    // PS2: save to memory stick or CD-ROM root
    return ".";
#elif defined(__EMSCRIPTEN__)
    // Web: use localStorage (handled by platform layer)
    return ".";
#else
    // Desktop: use user's home directory
    const char* home = std::getenv("HOME");
    if (home)
        return std::string(home) + "/.fnwf";
    return ".";
#endif
}

static auto ensure_save_dir() -> void {
#if !defined(__PS2__) && !defined(__EMSCRIPTEN__)
    auto dir = SaveManager::save_dir();
    std::error_code ec;
    std::filesystem::create_directories(dir, ec);
#endif
}

static auto save_path() -> std::string {
    auto dir = SaveManager::save_dir();
    return dir.empty() ? std::string(SAVE_FILE) : dir + "/" + SAVE_FILE;
}

static auto snapshot_path() -> std::string {
    auto dir = SaveManager::save_dir();
    return dir.empty() ? std::string(GAME_SNAPSHOT_FILE) : dir + "/" + GAME_SNAPSHOT_FILE;
}

// ── Legacy save/load ──────────────────────────────────────────────────────────

auto SaveManager::load_data() -> GameData {
    GameData data{};

    // Try modern save location first
    auto path = save_path();
    std::ifstream f(path, std::ios::binary);
    if (!f.is_open()) {
        // Fallback: legacy location (current directory)
        f.close();
        f.open(SAVE_FILE, std::ios::binary);
    }
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

auto SaveManager::save_progress(int completed_nights,
                                bool has_seen_story,
                                bool infinite_power,
                                bool fast_nights,
                                const std::vector<std::string>& achievements) -> void {
    ensure_save_dir();
    auto path = save_path();
    std::ofstream f(path, std::ios::binary);
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

// ── Game snapshot save/load ───────────────────────────────────────────────────

auto SaveManager::save_game(const GameSnapshot& snap) -> bool {
    ensure_save_dir();
    auto path = snapshot_path();

    std::ofstream f(path, std::ios::binary | std::ios::trunc);
    if (!f.is_open())
        return false;

    // Write header
    uint32_t magic = GameSnapshot::MAGIC;
    uint32_t version = GameSnapshot::VERSION;
    f.write(reinterpret_cast<const char*>(&magic), sizeof(magic));
    f.write(reinterpret_cast<const char*>(&version), sizeof(version));

    // Night info
    int night = snap.night;
    f.write(reinterpret_cast<const char*>(&night), sizeof(night));

    // Custom AI (if any)
    uint32_t ai_count = static_cast<uint32_t>(snap.custom_ai.size());
    f.write(reinterpret_cast<const char*>(&ai_count), sizeof(ai_count));
    for (int v : snap.custom_ai) {
        f.write(reinterpret_cast<const char*>(&v), sizeof(v));
    }

    // Time
    f.write(reinterpret_cast<const char*>(&snap.time_elapsed), sizeof(float));
    f.write(reinterpret_cast<const char*>(&snap.night_duration), sizeof(float));
    f.write(reinterpret_cast<const char*>(&snap.current_hour), sizeof(int));

    // Power
    f.write(reinterpret_cast<const char*>(&snap.power), sizeof(float));
    f.write(reinterpret_cast<const char*>(&snap.power_usage_level), sizeof(int));
    f.write(reinterpret_cast<const char*>(&snap.power_is_dead), sizeof(bool));
    f.write(reinterpret_cast<const char*>(&snap.power_dead_timer), sizeof(float));

    // Doors
    f.write(reinterpret_cast<const char*>(&snap.door_left_closed), sizeof(bool));
    f.write(reinterpret_cast<const char*>(&snap.door_right_closed), sizeof(bool));
    f.write(reinterpret_cast<const char*>(&snap.door_left_light), sizeof(bool));
    f.write(reinterpret_cast<const char*>(&snap.door_right_light), sizeof(bool));
    f.write(reinterpret_cast<const char*>(&snap.door_left_anim), sizeof(float));
    f.write(reinterpret_cast<const char*>(&snap.door_right_anim), sizeof(float));

    // Camera
    f.write(reinterpret_cast<const char*>(&snap.cam_open), sizeof(bool));
    uint32_t cam_len = static_cast<uint32_t>(snap.cam_current.size());
    f.write(reinterpret_cast<const char*>(&cam_len), sizeof(cam_len));
    f.write(snap.cam_current.data(), cam_len);
    f.write(reinterpret_cast<const char*>(&snap.cam_mask_open), sizeof(bool));

    // Office
    f.write(reinterpret_cast<const char*>(&snap.office_pan_x), sizeof(float));
    f.write(reinterpret_cast<const char*>(&snap.office_vent_light), sizeof(bool));

    // Mask/Oxygen
    f.write(reinterpret_cast<const char*>(&snap.mask_on), sizeof(bool));
    f.write(reinterpret_cast<const char*>(&snap.oxygen), sizeof(float));
    f.write(reinterpret_cast<const char*>(&snap.max_oxygen), sizeof(float));

    // Blackout
    f.write(reinterpret_cast<const char*>(&snap.is_blackout), sizeof(bool));
    f.write(reinterpret_cast<const char*>(&snap.blackout_alpha), sizeof(float));
    f.write(reinterpret_cast<const char*>(&snap.blackout_timer), sizeof(float));

    // Animatronics positions (fixed-length strings)
    auto write_pos = [&](const std::string& pos) {
        uint32_t len = static_cast<uint32_t>(pos.size());
        f.write(reinterpret_cast<const char*>(&len), sizeof(len));
        f.write(pos.data(), len);
    };
    write_pos(snap.cedro_pos);
    write_pos(snap.eser_pos);
    write_pos(snap.alice_pos);
    write_pos(snap.sonk_pos);
    f.write(reinterpret_cast<const char*>(&snap.sonk_stage), sizeof(int));

    // Sonk charging
    f.write(reinterpret_cast<const char*>(&snap.sonk_charging), sizeof(bool));
    f.write(reinterpret_cast<const char*>(&snap.sonk_charge_timer), sizeof(float));

    return f.good();
}

auto SaveManager::load_game() -> std::optional<GameSnapshot> {
    GameSnapshot snap;

    // Try modern save location first
    auto path = snapshot_path();
    std::ifstream f(path, std::ios::binary);
    if (!f.is_open()) {
        // Fallback: legacy location
        f.close();
        f.open(GAME_SNAPSHOT_FILE, std::ios::binary);
    }
    if (!f.is_open())
        return std::nullopt;

    // Read header
    uint32_t magic{}, version{};
    f.read(reinterpret_cast<char*>(&magic), sizeof(magic));
    f.read(reinterpret_cast<char*>(&version), sizeof(version));
    if (magic != GameSnapshot::MAGIC || version != GameSnapshot::VERSION)
        return std::nullopt;

    // Night info
    f.read(reinterpret_cast<char*>(&snap.night), sizeof(int));

    uint32_t ai_count{};
    f.read(reinterpret_cast<char*>(&ai_count), sizeof(ai_count));
    snap.custom_ai.clear();
    for (uint32_t i = 0; i < ai_count; ++i) {
        int v{};
        f.read(reinterpret_cast<char*>(&v), sizeof(v));
        if (!f.good()) return std::nullopt;
        snap.custom_ai.push_back(v);
    }

    // Time
    f.read(reinterpret_cast<char*>(&snap.time_elapsed), sizeof(float));
    f.read(reinterpret_cast<char*>(&snap.night_duration), sizeof(float));
    f.read(reinterpret_cast<char*>(&snap.current_hour), sizeof(int));

    // Power
    f.read(reinterpret_cast<char*>(&snap.power), sizeof(float));
    f.read(reinterpret_cast<char*>(&snap.power_usage_level), sizeof(int));
    f.read(reinterpret_cast<char*>(&snap.power_is_dead), sizeof(bool));
    f.read(reinterpret_cast<char*>(&snap.power_dead_timer), sizeof(float));

    // Doors
    f.read(reinterpret_cast<char*>(&snap.door_left_closed), sizeof(bool));
    f.read(reinterpret_cast<char*>(&snap.door_right_closed), sizeof(bool));
    f.read(reinterpret_cast<char*>(&snap.door_left_light), sizeof(bool));
    f.read(reinterpret_cast<char*>(&snap.door_right_light), sizeof(bool));
    f.read(reinterpret_cast<char*>(&snap.door_left_anim), sizeof(float));
    f.read(reinterpret_cast<char*>(&snap.door_right_anim), sizeof(float));

    // Camera
    f.read(reinterpret_cast<char*>(&snap.cam_open), sizeof(bool));
    uint32_t cam_len{};
    f.read(reinterpret_cast<char*>(&cam_len), sizeof(cam_len));
    snap.cam_current.assign(cam_len, '\0');
    f.read(&snap.cam_current[0], cam_len);
    if (!f.good()) return std::nullopt;
    f.read(reinterpret_cast<char*>(&snap.cam_mask_open), sizeof(bool));

    // Office
    f.read(reinterpret_cast<char*>(&snap.office_pan_x), sizeof(float));
    f.read(reinterpret_cast<char*>(&snap.office_vent_light), sizeof(bool));

    // Mask/Oxygen
    f.read(reinterpret_cast<char*>(&snap.mask_on), sizeof(bool));
    f.read(reinterpret_cast<char*>(&snap.oxygen), sizeof(float));
    f.read(reinterpret_cast<char*>(&snap.max_oxygen), sizeof(float));

    // Blackout
    f.read(reinterpret_cast<char*>(&snap.is_blackout), sizeof(bool));
    f.read(reinterpret_cast<char*>(&snap.blackout_alpha), sizeof(float));
    f.read(reinterpret_cast<char*>(&snap.blackout_timer), sizeof(float));

    // Animatronics positions
    auto read_pos = [&](std::string& out) {
        uint32_t len{};
        f.read(reinterpret_cast<char*>(&len), sizeof(len));
        if (!f.good() || len > 64) return;
        out.assign(len, '\0');
        f.read(&out[0], len);
    };
    read_pos(snap.cedro_pos);
    read_pos(snap.eser_pos);
    read_pos(snap.alice_pos);
    read_pos(snap.sonk_pos);
    f.read(reinterpret_cast<char*>(&snap.sonk_stage), sizeof(int));

    // Sonk charging
    f.read(reinterpret_cast<char*>(&snap.sonk_charging), sizeof(bool));
    f.read(reinterpret_cast<char*>(&snap.sonk_charge_timer), sizeof(float));

    if (!f.good())
        return std::nullopt;

    return snap;
}

auto SaveManager::has_saved_game() -> bool {
    auto path = snapshot_path();
    std::ifstream f(path, std::ios::binary);
    if (f.is_open())
        return true;
    f.open(GAME_SNAPSHOT_FILE, std::ios::binary);
    return f.is_open();
}

auto SaveManager::delete_saved_game() -> void {
    auto path = snapshot_path();
    std::remove(path.c_str());
    std::remove(GAME_SNAPSHOT_FILE);
}

}  // namespace fnwf
