#include "core/Platform.hpp"
#include <SDL.h>
#include <filesystem>
#include <cstdio>

#ifdef _WIN32
#include <windows.h>
#endif

#ifdef __APPLE__
#include <TargetConditionals.h>
#endif

namespace fnwf {

class DesktopPlatform : public Platform {
public:
    std::string get_platform_name() const override {
#ifdef __EMSCRIPTEN__
        return "web";
#elif defined(_WIN32)
        return "windows";
#elif defined(__linux__)
        return "linux";
#elif defined(__APPLE__)
        return "macos";
#else
        return "unknown";
#endif
    }

    std::string get_data_path() const override {
        // SDL_GetPrefPath returns the user data directory
        char* path = SDL_GetPrefPath("fnwf-dev", "fnwf-classic");
        if (path) {
            std::string result(path);
            SDL_free(path);
            return result;
        }
        return ".";
    }

    bool init() override {
        // Ensure data directory exists
        std::string data_path = get_data_path();
        std::filesystem::create_directories(data_path);
        return true;
    }

    void show_message(const std::string& title, const std::string& message) override {
        SDL_ShowSimpleMessageBox(SDL_MESSAGEBOX_INFORMATION,
                                 title.c_str(), message.c_str(), nullptr);
    }

    void open_url(const std::string& url) override {
#ifdef _WIN32
        ShellExecuteA(nullptr, "open", url.c_str(), nullptr, nullptr, SW_SHOWNORMAL);
#elif defined(__APPLE__)
        std::string cmd = "open \"" + url + "\"";
        (void)std::system(cmd.c_str());
#else
        std::string cmd = "xdg-open \"" + url + "\"";
        (void)std::system(cmd.c_str());
#endif
    }

    bool is_touch_device() const override { return false; }
    bool is_desktop() const override { return true; }
};

#ifdef __EMSCRIPTEN__
class WebPlatform : public DesktopPlatform {
public:
    std::string get_platform_name() const override { return "web"; }
    bool is_touch_device() const override { return true; }
    bool is_desktop() const override { return false; }
};
#endif

#ifdef __ANDROID__
class AndroidPlatform : public DesktopPlatform {
public:
    std::string get_platform_name() const override { return "android"; }
    std::string get_data_path() const override {
        // Android uses SDL's file system
        char* path = SDL_GetPrefPath("fnwf-dev", "fnwf-classic");
        if (path) {
            std::string result(path);
            SDL_free(path);
            return result;
        }
        return "/data/data/com.fnwf/files/";
    }
    bool is_touch_device() const override { return true; }
    bool is_desktop() const override { return false; }
};
#endif

// Platform factory
Platform* create_platform() {
#ifdef __EMSCRIPTEN__
    return new WebPlatform();
#elif defined(__ANDROID__)
    return new AndroidPlatform();
#else
    return new DesktopPlatform();
#endif
}

void destroy_platform(Platform* p) {
    delete p;
}

}  // namespace fnwf
