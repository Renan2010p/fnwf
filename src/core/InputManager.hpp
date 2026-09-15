#pragma once
#include <cstdint>
#include <string>
#include <functional>
#include <unordered_map>

namespace fnwf {

// Abstract key codes that work across platforms
enum class Key : uint32_t {
    Unknown = 0,
    // Alphabet (1-26)
    A = 0x00000001, B, C, D, E, F, G, H, I, J, K, L, M,
    N, O, P, Q, R, S, T, U, V, W, X, Y, Z,
    // Numbers (0x100-0x109) — no conflict with A-Z
    Num0 = 0x00000100, Num1, Num2, Num3, Num4, Num5, Num6, Num7, Num8, Num9,
    // Function keys (0x200-0x20B)
    F1 = 0x00000200, F2, F3, F4, F5, F6, F7, F8, F9, F10, F11, F12,
    // Navigation (0x300-0x304)
    Escape = 0x00000300, Return = 0x00000301, Backspace = 0x00000302, Tab = 0x00000303, Space = 0x00000304,
    ArrowLeft = 0x00000305, ArrowRight = 0x00000306, ArrowUp = 0x00000307, ArrowDown = 0x00000308,
    // modifiers (0x400-0x405)
    LShift = 0x00000400, RShift = 0x00000401, LCtrl = 0x00000402, RCtrl = 0x00000403, LAlt = 0x00000404, RAlt = 0x00000405,
    // Misc (0x500-0x503)
    Delete = 0x00000500, Home = 0x00000501, End = 0x00000502, Insert = 0x00000503,
    // Mouse buttons (0x600-0x602)
    MouseButtonLeft = 0x00000600, MouseButtonRight = 0x00000601, MouseButtonMiddle = 0x00000602,
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
