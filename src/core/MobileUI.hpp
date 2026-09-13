#pragma once

#include "engine/Engine.hpp"
#include <functional>
#include <string>
#include <vector>

namespace fnwf {

struct TouchButton
{
    std::string id;
    std::string label;
    int x{}, y{}, w{}, h{};
    bool active{false};
    bool visible{true};
    int font_size{12};
    int r{80}, g{80}, b{90};
    int r_on{100}, g_on{180}, b_on{255};
};

class MobileUI
{
public:
    static auto is_mobile() -> bool;
    static auto set_mobile(bool v) -> void;

    MobileUI();

    auto add_button(const std::string& id,
                    const std::string& label,
                    int x, int y, int w, int h,
                    int font_size = 12,
                    int r = 80, int g = 80, int b = 90,
                    int r_on = 100, int g_on = 180, int b_on = 255) -> void;

    auto set_active(const std::string& id, bool active) -> void;
    auto set_visible(const std::string& id, bool visible) -> void;
    auto clear() -> void;

    auto draw(Engine& eng) -> void;
    auto handle_touch(int tx, int ty) -> std::string;
    auto handle_touch_down(int tx, int ty) -> std::string;
    auto handle_touch_up(int tx, int ty) -> std::string;

    auto button_count() const -> std::size_t;

private:
    std::vector<TouchButton> m_buttons{};
    static inline bool s_is_mobile{false};
};

}  // namespace fnwf
