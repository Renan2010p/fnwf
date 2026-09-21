// plat_input_ps2.cpp — PS2 implementation of InputManager.
// Uses libpad for DualShock 2 controller input.

#include "core/InputManager.hpp"

#ifdef __PS2__
#include <tamtypes.h>
#include <libpad.h>
#include <sifrpc.h>
#include <cstring>
#include <unordered_map>
#include <vector>

namespace fnwf {

namespace {

Key ps2_button_to_key(unsigned short button) {
    switch (button) {
        case PAD_CROSS:     return Key::Space;
        case PAD_CIRCLE:    return Key::Return;
        case PAD_SQUARE:    return Key::A;
        case PAD_TRIANGLE:  return Key::S;
        case PAD_L1:        return Key::LShift;
        case PAD_R1:        return Key::RShift;
        case PAD_L2:        return Key::LAlt;
        case PAD_R2:        return Key::RAlt;
        case PAD_UP:        return Key::ArrowUp;
        case PAD_DOWN:      return Key::ArrowDown;
        case PAD_LEFT:      return Key::ArrowLeft;
        case PAD_RIGHT:     return Key::ArrowRight;
        case PAD_START:     return Key::Return;
        case PAD_SELECT:    return Key::Escape;
        default:            return Key::Unknown;
    }
}

}  // namespace

class PS2InputManager : public InputManager {
    std::unordered_map<unsigned short, bool> m_key_states{};
    std::unordered_map<unsigned short, bool> m_key_pressed{};
    std::unordered_map<unsigned short, bool> m_key_released{};
    int m_mouse_x = 0, m_mouse_y = 0;
    std::unordered_map<uint32_t, bool> m_mouse_buttons{};
    unsigned char m_pad_buf[256] __attribute__((aligned(64))) = {};
    unsigned short m_prev_buttons = 0;

public:
    bool init() override {
        SifInitRpc(0);
        padInit(0);
        padPortOpen(0, 1, m_pad_buf);
        return true;
    }

    void shutdown() override {
        padPortClose(0, 1);
    }

    std::vector<InputEvent> poll_events() override {
        std::vector<InputEvent> events;

        // Process previous frame's pressed/released
        for (auto& [key, pressed] : m_key_pressed) {
            events.push_back({InputEvent::Type::KeyDown, ps2_button_to_key(key)});
        }
        for (auto& [key, released] : m_key_released) {
            events.push_back({InputEvent::Type::KeyUp, ps2_button_to_key(key)});
        }
        m_key_pressed.clear();
        m_key_released.clear();

        // Read PS2 controller
        int state = padGetState(0, 1);
        if (state == PAD_STATE_STABLE) {
            struct padButtonStatus pad_data;
            if (padRead(0, 1, &pad_data)) {
                unsigned short buttons = pad_data.btns;
                unsigned short changed = buttons ^ m_prev_buttons;

                for (unsigned short mask = 0x8000; mask; mask >>= 1) {
                    if (changed & mask) {
                        if (buttons & mask) {
                            m_key_pressed[mask] = true;
                            m_key_states[mask] = true;
                        } else {
                            m_key_released[mask] = true;
                            m_key_states[mask] = false;
                        }
                    }
                }

                // Map analog stick to mouse position
                int8_t joy_x = static_cast<int8_t>(pad_data.ljoy_h - 128);
                int8_t joy_y = static_cast<int8_t>(pad_data.ljoy_v - 128);
                if (joy_x > 20 || joy_x < -20 || joy_y > 20 || joy_y < -20) {
                    m_mouse_x += joy_x / 8;
                    m_mouse_y += joy_y / 8;
                    if (m_mouse_x < 0) m_mouse_x = 0;
                    if (m_mouse_y < 0) m_mouse_y = 0;
                    if (m_mouse_x > 1280) m_mouse_x = 1280;
                    if (m_mouse_y > 720) m_mouse_y = 720;
                    events.push_back({InputEvent::Type::Motion, Key::Unknown,
                                     m_mouse_x, m_mouse_y});
                }

                m_prev_buttons = buttons;
            }
        }

        return events;
    }

    bool is_key_down(Key key) const override {
        for (auto& [mask, pressed] : m_key_states) {
            if (ps2_button_to_key(mask) == key && pressed) return true;
        }
        return false;
    }

    bool is_key_pressed(Key key) const override {
        for (auto& [mask, pressed] : m_key_pressed) {
            if (ps2_button_to_key(mask) == key && pressed) return true;
        }
        return false;
    }

    bool is_key_released(Key key) const override {
        for (auto& [mask, released] : m_key_released) {
            if (ps2_button_to_key(mask) == key && released) return true;
        }
        return false;
    }

    int get_mouse_x() const override { return m_mouse_x; }
    int get_mouse_y() const override { return m_mouse_y; }

    bool is_mouse_button_down(uint8_t button) const override {
        auto it = m_mouse_buttons.find(button);
        return it != m_mouse_buttons.end() && it->second;
    }

    std::vector<std::pair<int, int>> get_touch_positions() const override {
        return {};
    }

    bool is_gamepad_connected(int /*index*/ = 0) const override {
        int state = padGetState(0, 1);
        return (state == PAD_STATE_STABLE);
    }

    float get_gamepad_axis(int /*index*/, int axis) const override {
        struct padButtonStatus pad_data;
        if (padRead(0, 1, const_cast<struct padButtonStatus*>(&pad_data))) {
            if (axis == 0) return (pad_data.ljoy_h - 128) / 127.0f;
            if (axis == 1) return (pad_data.ljoy_v - 128) / 127.0f;
        }
        return 0.0f;
    }

    bool is_gamepad_button_pressed(int /*index*/, int /*button*/) const override {
        return false;
    }

    bool is_action_pressed(const std::vector<Key>& actions) const override {
        for (auto key : actions) {
            if (is_key_pressed(key)) return true;
        }
        return false;
    }
};

InputManager* create_input_manager() {
    return new PS2InputManager();
}

void destroy_input_manager(InputManager* im) {
    delete im;
}

}  // namespace fnwf

#else
// Desktop stub

#include <cstdio>

namespace fnwf {

class StubInputManager : public InputManager {
public:
    bool init() override { return true; }
    void shutdown() override {}
    std::vector<InputEvent> poll_events() override { return {}; }
    bool is_key_down(Key) const override { return false; }
    bool is_key_pressed(Key) const override { return false; }
    bool is_key_released(Key) const override { return false; }
    int get_mouse_x() const override { return 0; }
    int get_mouse_y() const override { return 0; }
    bool is_mouse_button_down(uint8_t) const override { return false; }
    std::vector<std::pair<int, int>> get_touch_positions() const override { return {}; }
    bool is_gamepad_connected(int = 0) const override { return false; }
    float get_gamepad_axis(int, int) const override { return 0.0f; }
    bool is_gamepad_button_pressed(int, int) const override { return false; }
    bool is_action_pressed(const std::vector<Key>&) const override { return false; }
};

InputManager* create_input_manager() { return new StubInputManager(); }
void destroy_input_manager(InputManager* im) { delete im; }

}  // namespace fnwf
#endif
