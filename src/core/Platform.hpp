#pragma once
#include <string>

namespace fnwf {

// Platform abstraction - minimal cross-platform interface
class Platform {
public:
    virtual ~Platform() = default;

    // Returns the platform name (e.g., "linux", "windows", "macos", "android", "web")
    virtual std::string get_platform_name() const = 0;

    // Get the app data directory path (for saves, config)
    virtual std::string get_data_path() const = 0;

    // Initialize platform-specific subsystems
    virtual bool init() { return true; }

    // Shutdown platform-specific subsystems
    virtual void shutdown() {}

    // Show a message box (platform-specific)
    virtual void show_message(const std::string& /*title*/, const std::string& /*message*/) {}

    // Open a URL in the default browser
    virtual void open_url(const std::string& /*url*/) {}

    // Check if running on mobile/touch device
    virtual bool is_touch_device() const { return false; }

    // Check if running on desktop
    virtual bool is_desktop() const { return true; }
};

// Factory function - implemented by platform-specific code
Platform* create_platform();
void destroy_platform(Platform* p);

}  // namespace fnwf
