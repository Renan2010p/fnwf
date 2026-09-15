#include "core/InputManager.hpp"
#include <SDL.h>
#include <unordered_map>
#include <vector>

namespace fnwf {

namespace {

Key sdl_key_to_fnwf(Uint32 sdl_key) {
    switch (sdl_key) {
        case SDLK_a: return Key::A;
        case SDLK_b: return Key::B;
        case SDLK_c: return Key::C;
        case SDLK_d: return Key::D;
        case SDLK_e: return Key::E;
        case SDLK_f: return Key::F;
        case SDLK_g: return Key::G;
        case SDLK_h: return Key::H;
        case SDLK_i: return Key::I;
        case SDLK_j: return Key::J;
        case SDLK_k: return Key::K;
        case SDLK_l: return Key::L;
        case SDLK_m: return Key::M;
        case SDLK_n: return Key::N;
        case SDLK_o: return Key::O;
        case SDLK_p: return Key::P;
        case SDLK_q: return Key::Q;
        case SDLK_r: return Key::R;
        case SDLK_s: return Key::S;
        case SDLK_t: return Key::T;
        case SDLK_u: return Key::U;
        case SDLK_v: return Key::V;
        case SDLK_w: return Key::W;
        case SDLK_x: return Key::X;
        case SDLK_y: return Key::Y;
        case SDLK_z: return Key::Z;
        case SDLK_0: return Key::Num0;
        case SDLK_1: return Key::Num1;
        case SDLK_2: return Key::Num2;
        case SDLK_3: return Key::Num3;
        case SDLK_4: return Key::Num4;
        case SDLK_5: return Key::Num5;
        case SDLK_6: return Key::Num6;
        case SDLK_7: return Key::Num7;
        case SDLK_8: return Key::Num8;
        case SDLK_9: return Key::Num9;
        case SDLK_F1: return Key::F1;
        case SDLK_F2: return Key::F2;
        case SDLK_F3: return Key::F3;
        case SDLK_F4: return Key::F4;
        case SDLK_F5: return Key::F5;
        case SDLK_F6: return Key::F6;
        case SDLK_F7: return Key::F7;
        case SDLK_F8: return Key::F8;
        case SDLK_F9: return Key::F9;
        case SDLK_F10: return Key::F10;
        case SDLK_F11: return Key::F11;
        case SDLK_F12: return Key::F12;
        case SDLK_ESCAPE: return Key::Escape;
        case SDLK_RETURN: return Key::Return;
        case SDLK_BACKSPACE: return Key::Backspace;
        case SDLK_TAB: return Key::Tab;
        case SDLK_SPACE: return Key::Space;
        case SDLK_LEFT: return Key::ArrowLeft;
        case SDLK_RIGHT: return Key::ArrowRight;
        case SDLK_UP: return Key::ArrowUp;
        case SDLK_DOWN: return Key::ArrowDown;
        case SDLK_LSHIFT: return Key::LShift;
        case SDLK_RSHIFT: return Key::RShift;
        case SDLK_LCTRL: return Key::LCtrl;
        case SDLK_RCTRL: return Key::RCtrl;
        case SDLK_LALT: return Key::LAlt;
        case SDLK_RALT: return Key::RAlt;
        case SDLK_DELETE: return Key::Delete;
        case SDLK_HOME: return Key::Home;
        case SDLK_END: return Key::End;
        case SDLK_INSERT: return Key::Insert;
        default: return Key::Unknown;
    }
}

Uint32 fnwf_key_to_sdl(Key key) {
    switch (key) {
        case Key::A: return SDLK_a;
        case Key::B: return SDLK_b;
        case Key::C: return SDLK_c;
        case Key::D: return SDLK_d;
        case Key::E: return SDLK_e;
        case Key::F: return SDLK_f;
        case Key::G: return SDLK_g;
        case Key::H: return SDLK_h;
        case Key::I: return SDLK_i;
        case Key::J: return SDLK_j;
        case Key::K: return SDLK_k;
        case Key::L: return SDLK_l;
        case Key::M: return SDLK_m;
        case Key::N: return SDLK_n;
        case Key::O: return SDLK_o;
        case Key::P: return SDLK_p;
        case Key::Q: return SDLK_q;
        case Key::R: return SDLK_r;
        case Key::S: return SDLK_s;
        case Key::T: return SDLK_t;
        case Key::U: return SDLK_u;
        case Key::V: return SDLK_v;
        case Key::W: return SDLK_w;
        case Key::X: return SDLK_x;
        case Key::Y: return SDLK_y;
        case Key::Z: return SDLK_z;
        case Key::Num0: return SDLK_0;
        case Key::Num1: return SDLK_1;
        case Key::Num2: return SDLK_2;
        case Key::Num3: return SDLK_3;
        case Key::Num4: return SDLK_4;
        case Key::Num5: return SDLK_5;
        case Key::Num6: return SDLK_6;
        case Key::Num7: return SDLK_7;
        case Key::Num8: return SDLK_8;
        case Key::Num9: return SDLK_9;
        case Key::F1: return SDLK_F1;
        case Key::F2: return SDLK_F2;
        case Key::F3: return SDLK_F3;
        case Key::F4: return SDLK_F4;
        case Key::F5: return SDLK_F5;
        case Key::F6: return SDLK_F6;
        case Key::F7: return SDLK_F7;
        case Key::F8: return SDLK_F8;
        case Key::F9: return SDLK_F9;
        case Key::F10: return SDLK_F10;
        case Key::F11: return SDLK_F11;
        case Key::F12: return SDLK_F12;
        case Key::Escape: return SDLK_ESCAPE;
        case Key::Return: return SDLK_RETURN;
        case Key::Backspace: return SDLK_BACKSPACE;
        case Key::Tab: return SDLK_TAB;
        case Key::Space: return SDLK_SPACE;
        case Key::ArrowLeft: return SDLK_LEFT;
        case Key::ArrowRight: return SDLK_RIGHT;
        case Key::ArrowUp: return SDLK_UP;
        case Key::ArrowDown: return SDLK_DOWN;
        case Key::LShift: return SDLK_LSHIFT;
        case Key::RShift: return SDLK_RSHIFT;
        case Key::LCtrl: return SDLK_LCTRL;
        case Key::RCtrl: return SDLK_RCTRL;
        case Key::LAlt: return SDLK_LALT;
        case Key::RAlt: return SDLK_RALT;
        case Key::Delete: return SDLK_DELETE;
        case Key::Home: return SDLK_HOME;
        case Key::End: return SDLK_END;
        case Key::Insert: return SDLK_INSERT;
        default: return 0;
    }
}

}  // namespace

class SDLInputManager : public InputManager {
    std::unordered_map<Uint32, bool> m_key_states;
    std::unordered_map<Uint32, bool> m_key_pressed;
    std::unordered_map<Uint32, bool> m_key_released;
    int m_mouse_x = 0, m_mouse_y = 0;
    std::unordered_map<Uint32, bool> m_mouse_buttons;
    std::vector<std::pair<int, int>> m_touches;

public:
    bool init() override { return true; }
    void shutdown() override {}

    std::vector<InputEvent> poll_events() override {
        std::vector<InputEvent> events;
        SDL_Event sdl_event;

        // Process previous frame's pressed/released states
        for (auto& [key, pressed] : m_key_pressed) {
            events.push_back({InputEvent::Type::KeyDown, sdl_key_to_fnwf(key)});
        }
        for (auto& [key, released] : m_key_released) {
            events.push_back({InputEvent::Type::KeyUp, sdl_key_to_fnwf(key)});
        }
        m_key_pressed.clear();
        m_key_released.clear();

        while (SDL_PollEvent(&sdl_event)) {
            InputEvent ev;
            switch (sdl_event.type) {
                case SDL_KEYDOWN:
                    ev.type = InputEvent::Type::KeyDown;
                    ev.key = sdl_key_to_fnwf(sdl_event.key.keysym.sym);
                    ev.shift = (sdl_event.key.keysym.mod & KMOD_SHIFT) != 0;
                    ev.ctrl = (sdl_event.key.keysym.mod & KMOD_CTRL) != 0;
                    ev.alt = (sdl_event.key.keysym.mod & KMOD_ALT) != 0;
                    m_key_pressed[sdl_event.key.keysym.sym] = true;
                    break;
                case SDL_KEYUP:
                    ev.type = InputEvent::Type::KeyUp;
                    ev.key = sdl_key_to_fnwf(sdl_event.key.keysym.sym);
                    m_key_released[sdl_event.key.keysym.sym] = true;
                    break;
                case SDL_MOUSEMOTION:
                    ev.type = InputEvent::Type::Motion;
                    ev.x = sdl_event.motion.x;
                    ev.y = sdl_event.motion.y;
                    m_mouse_x = ev.x;
                    m_mouse_y = ev.y;
                    break;
                case SDL_MOUSEBUTTONDOWN:
                    ev.type = InputEvent::Type::MouseButtonPress;
                    ev.x = sdl_event.button.x;
                    ev.y = sdl_event.button.y;
                    m_mouse_buttons[sdl_event.button.button] = true;
                    break;
                case SDL_MOUSEBUTTONUP:
                    ev.type = InputEvent::Type::MouseButtonRelease;
                    m_mouse_buttons[sdl_event.button.button] = false;
                    break;
                case SDL_FINGERMOTION:
                case SDL_FINGERDOWN:
                    ev.type = InputEvent::Type::TouchBegin;
                    ev.touch_id = sdl_event.tfinger.fingerId;
                    ev.x = static_cast<int>(sdl_event.tfinger.x * 1280);
                    ev.y = static_cast<int>(sdl_event.tfinger.y * 720);
                    m_touches.emplace_back(ev.x, ev.y);
                    break;
                case SDL_FINGERUP:
                    ev.type = InputEvent::Type::TouchEnd;
                    ev.touch_id = sdl_event.tfinger.fingerId;
                    break;
                case SDL_JOYBUTTONDOWN:
                    ev.type = InputEvent::Type::JoystickButton;
                    break;
                case SDL_JOYAXISMOTION:
                    ev.type = InputEvent::Type::JoystickAxis;
                    ev.axis_value = sdl_event.jaxis.value / 32767.0f;
                    break;
                case SDL_QUIT:
                    ev.type = InputEvent::Type::None;  // Handled separately
                    break;
                default:
                    break;
            }
            if (ev.type != InputEvent::Type::None) {
                events.push_back(ev);
            }
        }
        return events;
    }

    bool is_key_down(Key key) const override {
        auto it = m_key_states.find(fnwf_key_to_sdl(key));
        return it != m_key_states.end() && it->second;
    }

    bool is_key_pressed(Key key) const override {
        auto it = m_key_pressed.find(fnwf_key_to_sdl(key));
        return it != m_key_pressed.end() && it->second;
    }

    bool is_key_released(Key key) const override {
        auto it = m_key_released.find(fnwf_key_to_sdl(key));
        return it != m_key_released.end() && it->second;
    }

    int get_mouse_x() const override { return m_mouse_x; }
    int get_mouse_y() const override { return m_mouse_y; }

    bool is_mouse_button_down(uint8_t button) const override {
        auto it = m_mouse_buttons.find(button);
        return it != m_mouse_buttons.end() && it->second;
    }

    std::vector<std::pair<int, int>> get_touch_positions() const override {
        return m_touches;
    }

    bool is_gamepad_connected(int index = 0) const override {
#ifdef SDL_JOYSTICK
        return SDL_JoystickIsConnected(index);
#else
        return false;
#endif
    }

    float get_gamepad_axis(int index, int axis) const override {
#ifdef SDL_JOYSTICK
        auto* joy = SDL_JoystickOpen(index);
        if (!joy) return 0.0f;
        float value = static_cast<float>(SDL_JoystickGetAxis(joy, axis)) / 32767.0f;
        SDL_JoystickClose(joy);
        return value;
#else
        return 0.0f;
#endif
    }

    bool is_gamepad_button_pressed(int index, int button) const override {
#ifdef SDL_JOYSTICK
        auto* joy = SDL_JoystickOpen(index);
        if (!joy) return false;
        bool pressed = SDL_JoystickGetButton(joy, button);
        SDL_JoystickClose(joy);
        return pressed;
#else
        return false;
#endif
    }

    bool is_action_pressed(const std::vector<Key>& actions) const override {
        for (auto key : actions) {
            if (is_key_pressed(key)) return true;
        }
        return false;
    }
};

InputManager* create_input_manager() {
    return new SDLInputManager();
}

void destroy_input_manager(InputManager* im) {
    delete im;
}

}  // namespace fnwf
