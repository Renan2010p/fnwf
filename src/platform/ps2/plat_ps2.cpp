// plat_ps2.cpp — PS2 implementation of the Platform interface.

#include "core/Platform.hpp"

#ifdef __PS2__
#include <cstdio>
#include <sys/stat.h>
#include <string>

namespace fnwf {

class PS2Platform : public Platform {
public:
    std::string get_platform_name() const override { return "ps2"; }

    std::string get_data_path() const override {
        return "mc0:/FNWF/";
    }

    bool init() override {
        // Create memory card directory using POSIX mkdir
        mkdir("mc0:", 0777);  // ignore error if exists
        mkdir("mc0:/FNWF", 0777);
        return true;
    }

    void shutdown() override {}

    void show_message(const std::string& title, const std::string& message) override {
        (void)title;
        (void)message;
    }

    void open_url(const std::string&) override {}

    bool is_touch_device() const override { return false; }
    bool is_desktop() const override { return false; }
};

Platform* create_platform() { return new PS2Platform(); }
void destroy_platform(Platform* p) { delete p; }

}  // namespace fnwf

#else

namespace fnwf {

class StubPlatform : public Platform {
public:
    std::string get_platform_name() const override { return "stub"; }
    std::string get_data_path() const override { return "."; }
    bool init() override { return true; }
};

Platform* create_platform() { return new StubPlatform(); }
void destroy_platform(Platform* p) { delete p; }

}  // namespace fnwf
#endif
