// plat_ps2.cpp — PS2 implementation of the Platform interface.
// Handles memory card, IOP modules, and PS2-specific system calls.

#include "core/Platform.hpp"

#ifdef __PS2__
#include <tamtypes.h>
#include <sifrpc.h>
#include <fileXio.h>
#include <loadfile.h>
#include <string>
#include <cstring>

namespace fnwf {

class PS2Platform : public Platform {
public:
    std::string get_platform_name() const override {
        return "ps2";
    }

    std::string get_data_path() const override {
        // Memory card slot 0, directory /FNWF/
        return "mc0:/FNWF/";
    }

    bool init() override {
        // Initialize fileXio for file operations
        SifInitRpc(0);
        fileXioInit();
        return true;
    }

    void shutdown() override {
        fileXioExit();
    }

    void show_message(const std::string& title, const std::string& message) override {
        (void)title;
        (void)message;
    }

    void open_url(const std::string&) override {
        // PS2 has no web browser in homebrew context
    }

    bool is_touch_device() const override { return false; }
    bool is_desktop() const override { return false; }
};

Platform* create_platform() {
    return new PS2Platform();
}

void destroy_platform(Platform* p) {
    delete p;
}

}  // namespace fnwf

#else
// Desktop stub — allows compilation for testing
#include <cstdio>

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
