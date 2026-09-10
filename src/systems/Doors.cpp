#include "systems/Doors.hpp"
#include "core/DrawUtils.hpp"
#include "core/Localization.hpp"
#include "game1/GameSettings.hpp"
#include <algorithm>
#include <string>

namespace fnwf {

DoorSystem::DoorSystem() = default;

void DoorSystem::update(double dt) {
    double tl = left_closed ? 1.0 : 0.0;
    if (left_anim < tl)
        left_anim = std::min(tl, left_anim + anim_speed * dt);
    else if (left_anim > tl)
        left_anim = std::max(tl, left_anim - anim_speed * dt);

    double tr = right_closed ? 1.0 : 0.0;
    if (right_anim < tr)
        right_anim = std::min(tr, right_anim + anim_speed * dt);
    else if (right_anim > tr)
        right_anim = std::max(tr, right_anim - anim_speed * dt);
}

void DoorSystem::draw_buttons(Engine& eng, bool camera_open) {
    if (camera_open)
        return;
    button_rects.clear();
    auto panel_w = 96;
    auto panel_h = 106;
    auto bw = 78;
    auto bh = 34;
    auto gap = 8;
    auto panel_y = static_cast<int>(GameSettings::SCREEN_HEIGHT * 0.50) - panel_h / 2;

    // Left panel
    auto lx = 14;
    eng.draw_rect(lx, panel_y, panel_w, panel_h, 12, 12, 16, 210);
    eng.draw_rect(lx, panel_y, panel_w, panel_h, 60, 60, 70, 255, false);
    DrawUtils::text(eng,
                    Localization::get_text("door_left"),
                    lx + panel_w / 2,
                    panel_y - 12,
                    11,
                    80,
                    80,
                    90,
                    255,
                    true);
    auto l_btn_x = lx + 9;
    auto l_btn_y = panel_y + 10;
    auto l_label =
        left_closed ? Localization::get_text("door_open") : Localization::get_text("door_close");
    DrawUtils::button_box(
        eng, l_btn_x, l_btn_y, bw, bh, l_label, left_closed, 200, 40, 40, 60, 60, 65);
    button_rects["left_door"] = {l_btn_x, l_btn_y, static_cast<int>(bw), static_cast<int>(bh)};
    DrawUtils::button_box(eng,
                          l_btn_x,
                          l_btn_y + bh + gap,
                          bw,
                          bh,
                          Localization::get_text("light"),
                          left_light,
                          30,
                          180,
                          60,
                          60,
                          60,
                          65);
    button_rects["left_light"] = {
        l_btn_x, l_btn_y + bh + gap, static_cast<int>(bw), static_cast<int>(bh)};

    // Right panel
    auto rx = GameSettings::SCREEN_WIDTH - panel_w - 14;
    eng.draw_rect(rx, panel_y, panel_w, panel_h, 12, 12, 16, 210);
    eng.draw_rect(rx, panel_y, panel_w, panel_h, 60, 60, 70, 255, false);
    DrawUtils::text(eng,
                    Localization::get_text("door_right"),
                    rx + panel_w / 2,
                    panel_y - 12,
                    11,
                    80,
                    80,
                    90,
                    255,
                    true);
    auto r_btn_x = rx + 9;
    auto r_btn_y = panel_y + 10;
    auto r_label =
        right_closed ? Localization::get_text("door_open") : Localization::get_text("door_close");
    DrawUtils::button_box(
        eng, r_btn_x, r_btn_y, bw, bh, r_label, right_closed, 200, 40, 40, 60, 60, 65);
    button_rects["right_door"] = {r_btn_x, r_btn_y, static_cast<int>(bw), static_cast<int>(bh)};
    DrawUtils::button_box(eng,
                          r_btn_x,
                          r_btn_y + bh + gap,
                          bw,
                          bh,
                          Localization::get_text("light"),
                          right_light,
                          30,
                          180,
                          60,
                          60,
                          60,
                          65);
    button_rects["right_light"] = {
        r_btn_x, r_btn_y + bh + gap, static_cast<int>(bw), static_cast<int>(bh)};
}

auto DoorSystem::handle_click(int mx, int my) -> std::string {
    for (auto& [name, rect] : button_rects) {
        if (mx >= rect[0] && mx <= rect[0] + rect[2] && my >= rect[1] && my <= rect[1] + rect[3]) {
            if (name.find("door") != std::string::npos) {
                if (name.find("left") != std::string::npos)
                    left_closed = !left_closed;
                else
                    right_closed = !right_closed;
                return "door";
            }
            if (name.find("light") != std::string::npos) {
                if (name.find("left") != std::string::npos) {
                    left_light = !left_light;
                    if (left_light)
                        right_light = false;
                } else {
                    right_light = !right_light;
                    if (right_light)
                        left_light = false;
                }
                return "light";
            }
        }
    }
    return {};
}

auto DoorSystem::get_power_usage() -> int {
    int usage = 0;
    if (left_closed)
        usage++;
    if (right_closed)
        usage++;
    if (left_light)
        usage++;
    if (right_light)
        usage++;
    return usage;
}

}  // namespace fnwf
