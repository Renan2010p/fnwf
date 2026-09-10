#include "systems/CameraSystem.hpp"
#include "core/DrawUtils.hpp"
#include "core/SoundManager.hpp"
#include "game1/GameSettings.hpp"
#include <algorithm>
#include <cmath>
#include <cstdlib>

namespace fnwf {

CameraSystem::CameraSystem(Engine& eng) : m_eng(eng) {
    using namespace GameSettings;
    map_x = SCREEN_WIDTH - map_w - 20;
    map_y = SCREEN_HEIGHT - map_h - 60;

    monitor_tex = *m_eng.create_target(SCREEN_WIDTH, SCREEN_HEIGHT);
    map_tex = *m_eng.create_target(map_w, map_h);
    map_base_tex = *m_eng.create_target(map_w, map_h);
}

auto CameraSystem::ease_out_cubic(double v) const -> double {
    v = std::max(0.0, std::min(1.0, v));
    return 1.0 - std::pow(1.0 - v, 3.0);
}

auto CameraSystem::get_bottom_toggle_rects() const
    -> std::pair<std::array<int, 4>, std::array<int, 4>> {
    using namespace GameSettings;
    int btn_w = 300, btn_h = 28, gap = 16;
    int total_w = btn_w * 2 + gap;
    int start_x = SCREEN_WIDTH / 2 - total_w / 2;
    int btn_y = SCREEN_HEIGHT - btn_h - 4;
    auto btn1 = std::array<int, 4>{start_x, btn_y, btn_w, btn_h};
    auto btn2 = std::array<int, 4>{start_x + btn_w + gap, btn_y, btn_w, btn_h};
    return {btn1, btn2};
}

void CameraSystem::toggle() {
    if (is_mask_open || is_mask_animating)
        return;
    is_open = !is_open;
    is_animating = true;
    if (is_open)
        static_timer = static_duration;
}

void CameraSystem::toggle_mask() {
    if (is_open || is_animating || is_mask_animating)
        return;
    is_mask_open = !is_mask_open;
    is_mask_animating = true;
    if (is_mask_open) {
        SoundManager::play_sound("mask_on");
        SoundManager::play_mask_breathing();
    } else {
        SoundManager::play_sound("mask_off");
        SoundManager::stop_mask_breathing();
    }
}

void CameraSystem::force_remove_mask() {
    if (!is_mask_open && mask_anim_progress <= 0.0)
        return;
    if (is_mask_animating && !is_mask_open)
        return;
    is_mask_open = false;
    is_mask_animating = true;
}

void CameraSystem::switch_camera(const std::string& cam_id) {
    if (cam_id != current_cam) {
        auto& names = GameSettings::camera_names();
        if (names.find(cam_id) != names.end()) {
            current_cam = cam_id;
            static_timer = static_duration;
        }
    }
}

auto CameraSystem::is_fully_open() const -> bool {
    return is_open && anim_progress >= 0.99;
}
auto CameraSystem::is_visible() const -> bool {
    return anim_progress > 0.01;
}

auto CameraSystem::check_toggle_click(int mx, int my) -> bool {
    auto [mask_rect, monitor_rect] = get_bottom_toggle_rects();
    int rx = monitor_rect[0], ry = monitor_rect[1], rw = monitor_rect[2], rh = monitor_rect[3];
    if (mx >= rx && mx <= rx + rw && my >= ry && my <= ry + rh) {
        if (!is_animating && !is_mask_open && !is_mask_animating)
            toggle();
        return true;
    }
    return false;
}

auto CameraSystem::check_mask_toggle_click(int mx, int my) -> bool {
    auto [mask_rect, monitor_rect] = get_bottom_toggle_rects();
    int rx = mask_rect[0], ry = mask_rect[1], rw = mask_rect[2], rh = mask_rect[3];
    if (mx >= rx && mx <= rx + rw && my >= ry && my <= ry + rh) {
        if (!is_mask_animating && !is_open && !is_animating)
            toggle_mask();
        return true;
    }
    return false;
}

auto CameraSystem::check_mouse_trigger(int mouse_x, int mouse_y) -> bool {
    auto [mask_rect, monitor_rect] = get_bottom_toggle_rects();
    int mx_m = mask_rect[0], my_m = mask_rect[1], mw_m = mask_rect[2], mh_m = mask_rect[3];
    int mx_c = monitor_rect[0], my_c = monitor_rect[1], mw_c = monitor_rect[2];

    double gesture_h = std::max((double)(mh_m + 18), mouse_trigger_zone);
    bool in_mask = mouse_x >= mx_m && mouse_x <= mx_m + mw_m && mouse_y >= my_m - 14 &&
                   mouse_y <= my_m - 14 + gesture_h;
    bool in_cam = mouse_x >= mx_c && mouse_x <= mx_c + mw_c && mouse_y >= my_c - 14 &&
                  mouse_y <= my_c - 14 + gesture_h;

    if (in_cam && !mouse_in_cam_zone) {
        if (!is_animating && !is_mask_open && !is_mask_animating) {
            toggle();
            mouse_in_cam_zone = true;
            return true;
        }
    } else if (!in_cam)
        mouse_in_cam_zone = false;

    if (in_mask && !mouse_in_mask_zone) {
        if (!is_mask_animating && !is_open && !is_animating) {
            toggle_mask();
            mouse_in_mask_zone = true;
            return true;
        }
    } else if (!in_mask)
        mouse_in_mask_zone = false;

    return false;
}

auto CameraSystem::handle_click(int mx, int my) -> bool {
    if (!is_fully_open())
        return false;
    for (auto& [id, rect] : cam_buttons) {
        if (mx >= rect[0] && mx <= rect[0] + rect[2] && my >= rect[1] && my <= rect[1] + rect[3]) {
            switch_camera(id);
            return true;
        }
    }
    auto [mask_rect, monitor_rect] = get_bottom_toggle_rects();
    int tx = monitor_rect[0], ty = monitor_rect[1], tw = monitor_rect[2], th = monitor_rect[3];
    if (mx >= tx && mx <= tx + tw && my >= ty && my <= ty + th) {
        if (!is_animating && !is_mask_open && !is_mask_animating)
            toggle();
        return true;
    }
    return false;
}

void CameraSystem::update(double dt) {
    if (static_timer > 0)
        static_timer -= dt;

    double target = is_open ? 1.0 : 0.0;
    if (anim_progress != target) {
        is_animating = true;
        if (anim_progress < target)
            anim_progress = std::min(target, anim_progress + anim_speed * dt);
        else
            anim_progress = std::max(target, anim_progress - anim_speed * dt);
    } else
        is_animating = false;

    double mask_target = is_mask_open ? 1.0 : 0.0;
    if (mask_anim_progress != mask_target) {
        is_mask_animating = true;
        if (mask_anim_progress < mask_target)
            mask_anim_progress = std::min(mask_target, mask_anim_progress + mask_anim_speed * dt);
        else
            mask_anim_progress = std::max(mask_target, mask_anim_progress - mask_anim_speed * dt);
    } else
        is_mask_animating = false;
}

void CameraSystem::draw(Engine& eng,
                        const std::unordered_map<std::string, std::string>& anim_positions,
                        int foxy_stage) {
    auto [mask_rect, monitor_rect] = get_bottom_toggle_rects();

    if (!is_mask_open && !is_visible()) {
        double pulse = 0.5 + 0.5 * std::sin(m_eng.ticks() / 1000.0 * 5.0);
        int glow = (int)(80 + 70 * pulse);
        eng.draw_rect(mask_rect[0], mask_rect[1], mask_rect[2], mask_rect[3], 28, 22, 18, 230);
        eng.draw_rect(
            mask_rect[0], mask_rect[1], mask_rect[2], mask_rect[3], 220, glow, 60, 255, false);
        DrawUtils::text(eng,
                        "MASK",
                        mask_rect[0] + mask_rect[2] / 2,
                        mask_rect[1] + mask_rect[3] / 2,
                        12,
                        230,
                        160,
                        80,
                        255,
                        true);
    }

    if (!is_visible() && !is_mask_open) {
        double pulse = 0.5 + 0.5 * std::sin(m_eng.ticks() / 1000.0 * 4.0);
        int edge_g = (int)(160 + 60 * pulse);
        eng.draw_rect(
            monitor_rect[0], monitor_rect[1], monitor_rect[2], monitor_rect[3], 12, 18, 12, 220);
        eng.draw_rect(monitor_rect[0],
                      monitor_rect[1],
                      monitor_rect[2],
                      monitor_rect[3],
                      40,
                      edge_g,
                      90,
                      255,
                      false);
        DrawUtils::text(eng,
                        "MONITOR",
                        monitor_rect[0] + monitor_rect[2] / 2,
                        monitor_rect[1] + monitor_rect[3] / 2,
                        12,
                        120,
                        edge_g,
                        160,
                        255,
                        true);
    }

    if (mask_anim_progress > 0.01)
        draw_mask_overlay(eng);
    if (is_visible()) {
        if (is_fully_open())
            draw_monitor(eng, anim_positions, foxy_stage);
        else
            draw_monitor_animation(eng);
    }
}

void CameraSystem::draw_mask_overlay(Engine& eng) {
    using namespace GameSettings;
    double eased = ease_out_cubic(mask_anim_progress);
    int slide_offset = (int)((1.0 - eased) * -SCREEN_HEIGHT);

    int mask_r = 44, mask_g = 33, mask_b = 22, mask_a = 185;
    int y_top = slide_offset;
    int y_bottom = slide_offset + SCREEN_HEIGHT;
    int eye_w = 210, eye_h = 170, eye_gap = 90;
    int eye_y = slide_offset + SCREEN_HEIGHT / 2 - 88;
    int left_eye_x = SCREEN_WIDTH / 2 - eye_gap / 2 - eye_w;
    int right_eye_x = SCREEN_WIDTH / 2 + eye_gap / 2;

    eng.draw_rect(
        0, y_top, SCREEN_WIDTH, std::max(0, eye_y - y_top), mask_r, mask_g, mask_b, mask_a);
    eng.draw_rect(0,
                  eye_y + eye_h,
                  SCREEN_WIDTH,
                  std::max(0, y_bottom - (eye_y + eye_h)),
                  mask_r,
                  mask_g,
                  mask_b,
                  mask_a);
    eng.draw_rect(0, eye_y, std::max(0, left_eye_x), eye_h, mask_r, mask_g, mask_b, mask_a);
    int middle_x = left_eye_x + eye_w;
    int middle_w = right_eye_x - middle_x;
    eng.draw_rect(middle_x, eye_y, std::max(0, middle_w), eye_h, mask_r, mask_g, mask_b, mask_a);
    eng.draw_rect(right_eye_x + eye_w,
                  eye_y,
                  std::max(0, SCREEN_WIDTH - (right_eye_x + eye_w)),
                  eye_h,
                  mask_r,
                  mask_g,
                  mask_b,
                  mask_a);

    int nose_x = SCREEN_WIDTH / 2 - 34;
    int nose_y = eye_y + eye_h - 10;
    eng.draw_rect(nose_x, nose_y, 68, 120, 48, 36, 24, 210);

    eng.draw_rect(left_eye_x, eye_y, eye_w, eye_h, 100, 78, 50, 255, false);
    eng.draw_rect(right_eye_x, eye_y, eye_w, eye_h, 100, 78, 50, 255, false);
}

void CameraSystem::draw_monitor(Engine& eng,
                                const std::unordered_map<std::string, std::string>& anim_positions,
                                int foxy_stage) {
    using namespace GameSettings;
    double eased = ease_out_cubic(anim_progress);
    int slide_offset = (int)((1.0 - eased) * (SCREEN_HEIGHT - 40));

    eng.set_render_target(monitor_tex);
    eng.clear(5, 10, 5, 230);

    if (static_timer > 0) {
        DrawUtils::static_noise(eng, 0, 0, SCREEN_WIDTH, SCREEN_HEIGHT, 0.5f);
    } else {
        draw_camera_view(eng, anim_positions, foxy_stage);
        draw_map(eng, anim_positions);
        DrawUtils::text(
            eng, "CAM " + current_cam, 30, 30, 20, CAM_OUTLINE.r, CAM_OUTLINE.g, CAM_OUTLINE.b);
        DrawUtils::scanlines(eng, 0, 0, SCREEN_WIDTH, SCREEN_HEIGHT, 20);
        DrawUtils::static_noise(eng, 0, 0, SCREEN_WIDTH, SCREEN_HEIGHT, 0.02f);
        if ((int)(m_eng.ticks() / 1000.0) % 2 == 0) {
            eng.draw_rect(SCREEN_WIDTH - 50, 35, 12, 12, 200, 30, 30);
            DrawUtils::text(eng, "REC", SCREEN_WIDTH - 35, 28, 14, 200, 30, 30);
        }
    }

    eng.reset_render_target();
    eng.draw_texture(monitor_tex, 0, slide_offset, SCREEN_WIDTH, SCREEN_HEIGHT);

    int btn_w = 400;
    int btn_x = SCREEN_WIDTH / 2 - btn_w / 2;
    int close_btn_y = slide_offset + SCREEN_HEIGHT - 30;
    eng.draw_rect(btn_x, close_btn_y, btn_w, 30, 20, 25, 20);
    eng.draw_rect(btn_x, close_btn_y, btn_w, 30, 200, 60, 60, 255, false);
    DrawUtils::text(eng, "CLOSE", btn_x + btn_w / 2, close_btn_y + 15, 12, 200, 60, 60, 255, true);
}

void CameraSystem::draw_monitor_animation(Engine& eng) {
    using namespace GameSettings;
    double progress = ease_out_cubic(anim_progress);
    int slide_offset = (int)((1.0 - progress) * (SCREEN_HEIGHT - 40));

    eng.draw_rect(16, slide_offset, SCREEN_WIDTH - 32, SCREEN_HEIGHT, 42, 42, 48, 245);
    eng.draw_rect(16, slide_offset, SCREEN_WIDTH - 32, SCREEN_HEIGHT, 180, 180, 180, 255, false);

    int bar_alpha = (int)(120 + 100 * (1.0 - progress));
    for (int i = 0; i <= 5; ++i) {
        int y = slide_offset + 40 + i * 90 + (int)((1.0 - progress) * 24);
        eng.draw_rect(28, y, SCREEN_WIDTH - 56, 18, 20, 30, 20, bar_alpha);
    }
}

void CameraSystem::draw_camera_view(
    Engine& eng,
    const std::unordered_map<std::string, std::string>& anim_positions,
    int foxy_stage) {
    using namespace GameSettings;
    int cx = SCREEN_WIDTH / 2, cy = SCREEN_HEIGHT / 2 - 30;
    if (current_cam == "1A")
        draw_show_stage(eng, cx, cy, anim_positions);
    else if (current_cam == "1B")
        draw_dining_area(eng, cx, cy, anim_positions);
    else if (current_cam == "1C")
        draw_backstage(eng, cx, cy, anim_positions);
    else if (current_cam == "5")
        draw_sonk_cove(eng, cx, cy, foxy_stage);
    else if (current_cam == "2A" || current_cam == "4A")
        draw_hallway(eng, cx, cy, anim_positions, current_cam);
    else if (current_cam == "2B" || current_cam == "4B")
        draw_hall_corner(eng, cx, cy, anim_positions, current_cam);
    else if (current_cam == "3")
        draw_supply_closet(eng, cx, cy, anim_positions);
}

void CameraSystem::draw_show_stage(Engine& eng,
                                   int cx,
                                   int cy,
                                   const std::unordered_map<std::string, std::string>& ap) {
    eng.draw_rect(cx - 300, cy - 150, 600, 350, 40, 30, 35);
    auto it = ap.find("cedro");
    if (it != ap.end() && it->second == "1A")
        DrawUtils::animatronic_face(eng, "cedro", cx - 130, cy - 40, 100, 120);
    it = ap.find("eser");
    if (it != ap.end() && it->second == "1A")
        DrawUtils::animatronic_face(eng, "eser", cx + 30, cy - 40, 100, 120);
}

void CameraSystem::draw_dining_area(Engine& eng,
                                    int cx,
                                    int cy,
                                    const std::unordered_map<std::string, std::string>& ap) {
    eng.draw_rect(cx - 300, cy - 150, 600, 350, 30, 28, 32);
    for (auto& name : {"cedro", "eser"}) {
        auto it = ap.find(name);
        if (it != ap.end() && it->second == "1B") {
            DrawUtils::animatronic_face(eng, name, cx - 50, cy - 60, 100, 120);
            break;
        }
    }
}

void CameraSystem::draw_backstage(Engine& eng,
                                  int cx,
                                  int cy,
                                  const std::unordered_map<std::string, std::string>& ap) {
    eng.draw_rect(cx - 300, cy - 150, 600, 350, 25, 20, 28);
    auto it = ap.find("cedro");
    if (it != ap.end() && it->second == "1C")
        DrawUtils::animatronic_face(eng, "cedro", cx - 60, cy - 40, 120, 150);
}

void CameraSystem::draw_hallway(Engine& eng,
                                int cx,
                                int cy,
                                const std::unordered_map<std::string, std::string>& ap,
                                const std::string& cam_id) {
    eng.draw_rect(cx - 300, cy - 150, 600, 350, 35, 32, 38);
    for (auto& name : {"cedro", "eser"}) {
        auto it = ap.find(name);
        if (it != ap.end() && it->second == cam_id) {
            DrawUtils::animatronic_face(eng, name, cx - 50, cy - 50, 100, 130);
            break;
        }
    }
}

void CameraSystem::draw_hall_corner(Engine& eng,
                                    int cx,
                                    int cy,
                                    const std::unordered_map<std::string, std::string>& ap,
                                    const std::string& cam_id) {
    eng.draw_rect(cx - 300, cy - 150, 600, 350, 20, 18, 22);
    for (auto& name : {"cedro", "eser"}) {
        auto it = ap.find(name);
        if (it != ap.end() && it->second == cam_id) {
            DrawUtils::animatronic_face(eng, name, cx - 80, cy - 100, 160, 200);
            break;
        }
    }
}

void CameraSystem::draw_supply_closet(Engine& eng,
                                      int cx,
                                      int cy,
                                      const std::unordered_map<std::string, std::string>& ap) {
    eng.draw_rect(cx - 300, cy - 150, 600, 350, 28, 25, 30);
    auto it = ap.find("cedro");
    if (it != ap.end() && it->second == "3")
        DrawUtils::animatronic_face(eng, "cedro", cx - 60, cy - 40, 120, 150);
}

void CameraSystem::draw_sonk_cove(Engine& eng, int cx, int cy, int foxy_stage) {
    eng.draw_rect(cx - 300, cy - 150, 600, 350, 15, 12, 20);
    eng.draw_rect(cx - 280, cy - 130, 560, 310, 35, 30, 45, 120);

    std::string label = "EMPTY";
    if (foxy_stage == 1)
        label = "RUSTLING...";
    else if (foxy_stage == 2)
        label = "MOVING...";
    else if (foxy_stage >= 3)
        label = "GONE";

    DrawUtils::text(eng, "SONK COVE", cx - 240, cy - 120, 22, 170, 170, 190);
    DrawUtils::text(eng, label, cx - 240, cy - 86, 16, 120, 120, 140);

    if (foxy_stage <= 2) {
        int face_w = 220 + foxy_stage * 30;
        int face_h = 250 + foxy_stage * 20;
        int fx = cx + 40 - face_w / 2;
        int fy = cy + 10 - face_h / 2;
        int alpha = 145 + foxy_stage * 40;
        DrawUtils::animatronic_face(eng, "Sonk", fx, fy, face_w, face_h);
        eng.draw_rect(fx, fy, face_w, face_h, 0, 0, 0, std::max(0, 240 - alpha));
    }
}

void CameraSystem::draw_map(Engine& eng, const std::unordered_map<std::string, std::string>&) {
    using namespace GameSettings;

    auto cam_positions =
        std::unordered_map<std::string, std::pair<int, int>>{{"1A", {map_w / 2, 40}},
                                                             {"1B", {map_w / 2, 80}},
                                                             {"1C", {60, 100}},
                                                             {"5", {145, 105}},
                                                             {"2A", {90, 150}},
                                                             {"2B", {90, 210}},
                                                             {"3", {50, 160}},
                                                             {"4A", {map_w - 90, 150}},
                                                             {"4B", {map_w - 90, 210}}};

    auto connections = std::vector<std::pair<std::string, std::string>>{{"1A", "1B"},
                                                                        {"1B", "1C"},
                                                                        {"1C", "5"},
                                                                        {"1B", "2A"},
                                                                        {"2A", "2B"},
                                                                        {"2A", "3"},
                                                                        {"1B", "4A"},
                                                                        {"4A", "4B"}};

    if (map_base_dirty) {
        eng.set_render_target(map_base_tex);
        eng.clear(10, 20, 10, 180);
        eng.draw_rect(0, 0, map_w, map_h, CAM_OUTLINE.r, CAM_OUTLINE.g, CAM_OUTLINE.b, 255, false);
        for (auto& [a, b] : connections) {
            auto& p1 = cam_positions[a];
            auto& p2 = cam_positions[b];
            eng.line(p1.first, p1.second, p2.first, p2.second, 0, 255, 0, 255);
        }
        map_base_dirty = false;
    }

    eng.set_render_target(map_tex);
    eng.clear(0, 0, 0, 0);
    eng.draw_texture(map_base_tex, 0, 0, map_w, map_h);

    cam_buttons.clear();
    for (auto& [cam_id, pos] : cam_positions) {
        int btn_w = 36, btn_h = 22;
        int px = pos.first - btn_w / 2;
        int py = pos.second - btn_h / 2;
        cam_buttons[cam_id] = {map_x + px, map_y + py, btn_w, btn_h};

        bool is_active = (cam_id == current_cam);
        int bg_r = is_active ? 20 : 5, bg_g = is_active ? 80 : 20, bg_b = is_active ? 20 : 5;
        eng.draw_rect(
            pos.first - btn_w / 2, pos.second - btn_h / 2, btn_w, btn_h, bg_r, bg_g, bg_b);
        eng.draw_rect(
            pos.first - btn_w / 2, pos.second - btn_h / 2, btn_w, btn_h, 0, 255, 0, 255, false);
        DrawUtils::text(eng, cam_id, pos.first, pos.second, 11, 0, 255, 0, 255, true);
    }

    DrawUtils::text(eng, "YOU", map_w / 2, map_h - 30, 12, 0, 255, 0, 255, true);
    eng.line(map_w / 2, map_h - 45, map_w / 2, map_h - 55, 0, 255, 0, 255);

    eng.set_render_target(monitor_tex);
    eng.draw_texture(map_tex, map_x, map_y, map_w, map_h);
}

}  // namespace fnwf
