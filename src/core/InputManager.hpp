#pragma once
#include <cstdint>
#include <string>
#include <functional>
#include <unordered_map>

namespace fnwf {

// Abstract key codes that work across platforms
enum class Key : uint32_t {
    Unknown = 0,
    // Alphabet
    A = 0x00000001, B, C, D, E, F, G, H, I, J, K, L, M,
    N, O, P, Q, R, S, T, U, V, W, X, Y, Z,
    // Numbers
    Num0 = 0x00000010, Num1, Num2, Num3, Num4, Num5, Num6, Num7, Num8, Num9,
    // Function keys
    F1 = 0x00000100, F2, F3, F4, F5, F6, F7, F8, F9, F10, F11, F12,
    // Navigation
    Escape = 0x00001000, Return, Backspace, Tab, Space,
    ArrowLeft = 0x00002000, ArrowRight, ArrowUp, ArrowDown,
    // modifiers
    LShift = 0x00004000, RShift, LCtrl, RCtrl, LAlt, RAlt,
    // Misc
    Delete = 0x00008000, Home, End, Insert,
    // Mouse buttons
    MouseButtonLeft = 0x00010000, MouseButtonRight, MouseButtonMiddle,
};

// Unified event structure
struct InputEvent {
    enum class Type : uint8_t {
        None,
        KeyDown,
        KeyUp,
        MouseButtonPress,
        MouseButtonRelease,
        Motion,     // Mouse movement
        TouchBegin, // Touch started
        TouchMove,  // Touch moved
        TouchEnd,   // Touch ended
        JoystickButton,
        JoystickAxis,
    };

    Type type = Type::None;
    Key key = Key::Unknown;
    int32_t x = 0, y = 0;  // Screen coords
    int32_t touch_id = 0;
    float axis_value = 0.0f;  // For joysticks
    bool shift = false, ctrl = false, alt = false;
};

class InputManager {
public:
    virtual ~InputManager() = default;

    // Initialize input system
    virtual bool init() = 0;
    virtual void shutdown() = 0;

    // Poll all pending input events
    virtual std::vector<InputEvent> poll_events() = 0;

    // Query current key state
    virtual bool is_key_down(Key key) const = 0;
    virtual bool is_key_pressed(Key key) const = 0;   // Just pressed this frame
    virtual bool is_key_released(Key key) const = 0;   // Just released this frame

    // Query mouse state
    virtual int get_mouse_x() const = 0;
    virtual int get_mouse_y() const = 0;
    virtual bool is_mouse_button_down(uint8_t button) const = 0;

    // Query touch state (for mobile)
    virtual std::vector<std::pair<int, int>> get_touch_positions() const = 0;

    // Query gamepad state
    virtual bool is_gamepad_connected(int index = 0) const = 0;
    virtual float get_gamepad_axis(int index, int axis) const = 0;
    virtual bool is_gamepad_button_pressed(int index, int button) const = 0;

    // Helper: check if any action key is pressed
    virtual bool is_action_pressed(const std::vector<Key>& actions) const = 0;
};

InputManager* create_input_manager();
void destroy_input_manager(InputManager* im);

}  // namespace fnwf
