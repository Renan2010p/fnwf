#include "core/MobileUI.hpp"
#include "core/DrawUtils.hpp"
#include "game1/GameSettings.hpp"
#include <algorithm>
#include <cmath>

#ifdef __EMSCRIPTEN__
#include <emscripten.h>
#endif

namespace fnwf {

auto MobileUI::is_mobile() -> bool {
    return s_is_mobile;
}

auto MobileUI::set_mobile(bool v) -> void {
    s_is_mobile = v;
}

MobileUI::MobileUI() = default;

auto MobileUI::add_button(const std::string& id,
                          const std::string& label,
                          int x, int y, int w, int h,
                          int font_size,
                          int r, int g, int b,
                          int r_on, int g_on, int b_on) -> void {
    m_buttons.push_back({id, label, x, y, w, h, false, true, font_size, r, g, b, r_on, g_on, b_on});
}

auto MobileUI::set_active(const std::string& id, bool active) -> void {
    for (auto& btn : m_buttons) {
        if (btn.id == id) {
            btn.active = active;
            return;
        }
    }
}

auto MobileUI::set_visible(const std::string& id, bool visible) -> void {
    for (auto& btn : m_buttons) {
        if (btn.id == id) {
            btn.visible = visible;
            return;
        }
    }
}

auto MobileUI::clear() -> void {
    m_buttons.clear();
}

auto MobileUI::draw(Engine& eng) -> void {
    if (!s_is_mobile)
        return;

    for (auto& btn : m_buttons) {
        if (!btn.visible)
            continue;

        int alpha = btn.active ? 210 : 160;
        int bg_r = btn.active ? btn.r_on : btn.r;
        int bg_g = btn.active ? btn.g_on : btn.g;
        int bg_b = btn.active ? btn.b_on : btn.b;

        eng.draw_rect(btn.x, btn.y, btn.w, btn.h, bg_r, bg_g, bg_b, alpha);
        eng.draw_rect(btn.x, btn.y, btn.w, btn.h, 200, 200, 210, 90, false);

        DrawUtils::text(eng,
                        btn.label,
                        btn.x + btn.w / 2,
                        btn.y + btn.h / 2,
                        btn.font_size,
                        255, 255, 255, 230,
                        true);
    }
}

auto MobileUI::handle_touch(int tx, int ty) -> std::string {
    for (auto& btn : m_buttons) {
        if (!btn.visible)
            continue;
        if (tx >= btn.x && tx <= btn.x + btn.w && ty >= btn.y && ty <= btn.y + btn.h) {
            return btn.id;
        }
    }
    return {};
}

auto MobileUI::handle_touch_down(int tx, int ty) -> std::string {
    return handle_touch(tx, ty);
}

auto MobileUI::handle_touch_up(int tx, int ty) -> std::string {
    return handle_touch(tx, ty);
}

auto MobileUI::button_count() const -> std::size_t {
    return m_buttons.size();
}

}  // namespace fnwf
