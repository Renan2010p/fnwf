#include "systems/Office.hpp"
#include "core/DrawUtils.hpp"
#include "game1/GameSettings.hpp"
#include <algorithm>
#include <cmath>
#include <ctime>

namespace fnwf {

static constexpr double PI = 3.14159265358979323846;

Office::Office(Engine& eng) : m_eng(eng) {
    office_tex = *eng.create_target(GameSettings::OFFICE_WIDTH, GameSettings::SCREEN_HEIGHT);
    office_static_tex = *eng.create_target(GameSettings::OFFICE_WIDTH, GameSettings::SCREEN_HEIGHT);

    vp_x = GameSettings::OFFICE_WIDTH / 2;
    vp_y = GameSettings::SCREEN_HEIGHT / 2 - 30;
    bw_left = vp_x - 240;
    bw_right = vp_x + 240;
    bw_top = 80;
    bw_bottom = GameSettings::SCREEN_HEIGHT - 120;

    precalculate_projection();
    build_static_layer();
}

Color Office::shade(const Color& c, double factor) {
    return {static_cast<std::uint8_t>(std::max(0, std::min(255, static_cast<int>(c.r * factor)))),
            static_cast<std::uint8_t>(std::max(0, std::min(255, static_cast<int>(c.g * factor)))),
            static_cast<std::uint8_t>(std::max(0, std::min(255, static_cast<int>(c.b * factor))))};
}

auto Office::project_depth(double nx, double z, double height) -> std::tuple<int, int, double> {
    double zc = std::max(0.0, std::min(1.0, z));
    double scale = 0.40 + zc * 1.45;
    double world_half = 320;
    int sx = static_cast<int>(vp_x + (nx * world_half * scale));
    double floor_y =
        bw_bottom + static_cast<int>((GameSettings::SCREEN_HEIGHT - bw_bottom) * std::pow(zc, 1.2));
    int sy = static_cast<int>(floor_y - height * scale);
    return {sx, sy, scale};
}

void Office::precalculate_projection() {
    auto screen_w = GameSettings::SCREEN_WIDTH;
    auto screen_h = GameSettings::SCREEN_HEIGHT;
    double fov = PI * 100.0 / 180.0;
    double focal_length = (screen_w / 2.0) / std::tan(fov / 2.0);
    int slice_w = 16;
    double pixels_per_radian = GameSettings::OFFICE_WIDTH / PI;

    for (int sx = 0; sx < screen_w; sx += slice_w) {
        double theta = std::atan((sx + slice_w / 2.0 - screen_w / 2.0) / focal_length);
        double scale_y = 1.0 / std::cos(theta);
        double src_w_d =
            slice_w * (pixels_per_radian * std::pow(std::cos(theta), 2) / focal_length);
        projection_data.push_back({sx,
                                   theta,
                                   static_cast<int>(screen_h * scale_y),
                                   std::max(1, static_cast<int>(src_w_d))});
    }
}

void Office::build_static_layer() {
    m_eng.set_render_target(office_static_tex);
    m_eng.clear(5, 5, 8);
    draw_ceiling(m_eng);
    draw_floor(m_eng);
    draw_back_wall_base(m_eng);
    draw_depth_structure(m_eng);
    draw_hallways_base(m_eng);
    draw_vent_base(m_eng);
    draw_side_walls(m_eng);
    draw_wall_dressing(m_eng);
    draw_office_elements(m_eng);
    draw_ambient(m_eng);
    m_eng.reset_render_target();
}

void Office::update(int mouse_x, double dt) {
    double norm = static_cast<double>(mouse_x) / GameSettings::SCREEN_WIDTH;
    target_pan = (norm - 0.5) * 2.0;
    pan_x += (target_pan - pan_x) * 4.0 * dt;
}

void Office::draw(Engine& eng,
                  double left_door_anim,
                  double right_door_anim,
                  bool left_light,
                  bool right_light,
                  const std::string& anim_at_left,
                  const std::string& anim_at_right,
                  const std::string& anim_at_vent,
                  const std::string& anim_in_office) {
    double t = static_cast<double>(clock()) / CLOCKS_PER_SEC;
    eng.set_render_target(office_tex);
    eng.draw_texture(
        office_static_tex, 0, 0, GameSettings::OFFICE_WIDTH, GameSettings::SCREEN_HEIGHT);

    draw_back_wall_dynamic(eng, t);
    draw_hallways_dynamic(eng, left_light, right_light, anim_at_left, anim_at_right);
    draw_vent_dynamic(eng, anim_at_vent);
    draw_doors(eng, left_door_anim, right_door_anim);
    draw_fan(eng, t);
    draw_in_office(eng, anim_in_office);

    eng.reset_render_target();

    auto screen_h = GameSettings::SCREEN_HEIGHT;
    auto office_w = GameSettings::OFFICE_WIDTH;
    double pixels_per_radian = office_w / PI;
    double max_pan_angle = PI / 4.0;
    double center_angle = PI / 2.0 + pan_x * max_pan_angle;

    for (auto& data : projection_data) {
        double target_angle = center_angle + data.theta;
        double source_x = target_angle * pixels_per_radian;
        int src_w = data.src_w;
        int target_h = data.target_h;
        int src_x = static_cast<int>(std::floor(source_x - src_w / 2.0));

        if (src_x + src_w > 0 && src_x < office_w) {
            int final_src_x = std::max(0, src_x);
            int final_src_w = std::min(office_w - final_src_x, src_w - (final_src_x - src_x));
            if (final_src_w > 0) {
                eng.draw_texture(office_tex,
                                 data.sx,
                                 static_cast<int>((screen_h - target_h) / 2),
                                 17,
                                 target_h,
                                 final_src_x,
                                 0,
                                 final_src_w,
                                 screen_h);
            }
        }
    }
}

void Office::draw_ceiling(Engine& eng) {
    DrawUtils::trapezoid(eng,
                         22,
                         20,
                         25,
                         0,
                         0,
                         GameSettings::OFFICE_WIDTH,
                         0,
                         bw_right + hall_depth,
                         bw_top,
                         bw_left - hall_depth,
                         bw_top);
    for (int i = 1; i < 10; ++i) {
        double prog = i / 10.0;
        int y = static_cast<int>(prog * bw_top);
        int lx = static_cast<int>((bw_left - hall_depth) * prog);
        int rx = static_cast<int>(GameSettings::OFFICE_WIDTH -
                                  (GameSettings::OFFICE_WIDTH - bw_right - hall_depth) * prog);
        auto shade = static_cast<int>(std::max(0.0, 30.0 - prog * 20));
        eng.line(lx, y, rx, y, shade, shade, shade + 3);
    }
    for (int i = 0; i <= 5; ++i) {
        double frac = (i + 1) / 7.0;
        int top_x = static_cast<int>(GameSettings::OFFICE_WIDTH * frac);
        int bot_x = static_cast<int>((bw_left - hall_depth) +
                                     frac * (bw_right + hall_depth - bw_left + hall_depth));
        eng.line(top_x, 0, bot_x, bw_top, 18, 18, 22);
    }
}

void Office::draw_floor(Engine& eng) {
    int floor_left_far = bw_left - hall_depth;
    int floor_right_far = bw_right + hall_depth;
    DrawUtils::trapezoid(eng,
                         GameSettings::FLOOR_COLOR.r,
                         GameSettings::FLOOR_COLOR.g,
                         GameSettings::FLOOR_COLOR.b,
                         floor_left_far,
                         bw_bottom,
                         floor_right_far,
                         bw_bottom,
                         GameSettings::OFFICE_WIDTH + 100,
                         GameSettings::SCREEN_HEIGHT,
                         -100,
                         GameSettings::SCREEN_HEIGHT);

    int rows = 4, cols = 8;
    for (int r = 0; r < rows; ++r) {
        double py0 = r / (double)rows;
        double py1 = (r + 1) / (double)rows;
        int y0 = static_cast<int>(bw_bottom + py0 * (GameSettings::SCREEN_HEIGHT - bw_bottom));
        int y1 = static_cast<int>(bw_bottom + py1 * (GameSettings::SCREEN_HEIGHT - bw_bottom));
        int lx0 = static_cast<int>(floor_left_far + (-100 - floor_left_far) * py0);
        int rx0 = static_cast<int>(floor_right_far +
                                   (GameSettings::OFFICE_WIDTH + 100 - floor_right_far) * py0);
        int lx1 = static_cast<int>(floor_left_far + (-100 - floor_left_far) * py1);
        int rx1 = static_cast<int>(floor_right_far +
                                   (GameSettings::OFFICE_WIDTH + 100 - floor_right_far) * py1);
        for (int c = 0; c < cols; ++c) {
            int px0 = lx0 + static_cast<int>(c / (double)cols * (rx0 - lx0));
            int px1 = lx0 + static_cast<int>((c + 1) / (double)cols * (rx0 - lx0));
            int px0b = lx1 + static_cast<int>(c / (double)cols * (rx1 - lx1));
            int px1b = lx1 + static_cast<int>((c + 1) / (double)cols * (rx1 - lx1));
            auto& color =
                ((r + c) % 2 == 0) ? GameSettings::FLOOR_TILE_1 : GameSettings::FLOOR_TILE_2;
            double fade = std::max(0.3, 1.0 - (1.0 - py0) * 0.6);
            DrawUtils::trapezoid(eng,
                                 static_cast<int>(color.r * fade),
                                 static_cast<int>(color.g * fade),
                                 static_cast<int>(color.b * fade),
                                 px0,
                                 y0,
                                 px1,
                                 y0,
                                 px1b,
                                 y1,
                                 px0b,
                                 y1);
        }
    }
}

void Office::draw_back_wall_base(Engine& eng) {
    eng.draw_rect(bw_left,
                  bw_top,
                  bw_right - bw_left,
                  bw_bottom - bw_top,
                  GameSettings::WALL_COLOR.r,
                  GameSettings::WALL_COLOR.g,
                  GameSettings::WALL_COLOR.b);
    eng.draw_rect(bw_left + 10, bw_top + 16, bw_right - bw_left - 20, 22, 34, 32, 40, 190);
    for (int i = 0; i <= 6; ++i) {
        int yy = bw_top + 14 + i * 4;
        eng.line(bw_left + 16, yy, bw_right - 16, yy, 52, 48, 58, 70);
    }
    eng.draw_rect(bw_left, bw_bottom - 20, bw_right - bw_left, 20, 35, 30, 38);
    eng.line(bw_left, bw_bottom - 20, bw_right, bw_bottom - 20, 50, 45, 55);

    int p1x = vp_x - 64, p1y = bw_top + 36;
    eng.draw_rect(p1x, p1y, 128, 128, 40, 36, 46);
    eng.draw_rect(p1x + 2, p1y + 2, 124, 124, 22, 22, 24);
    eng.draw_rect(p1x + 8, p1y + 10, 112, 108, 14, 14, 18);
    eng.draw_rect(p1x,
                  p1y,
                  128,
                  128,
                  GameSettings::WALL_ACCENT.r,
                  GameSettings::WALL_ACCENT.g,
                  GameSettings::WALL_ACCENT.b,
                  255,
                  false);
    DrawUtils::text(eng, "MAFIA", p1x + 64, p1y + 52, 24, 255, 255, 100, 255, true);
    DrawUtils::text(eng, "NIGHT SHIFT", p1x + 64, p1y + 82, 11, 160, 150, 72, 220, true);
    for (int i = 0; i <= 5; ++i)
        eng.line(p1x + 10, p1y + 96 + i * 3, p1x + 118, p1y + 90 + i * 3, 45, 42, 50, 120);

    int flyer_x = bw_left + 42, flyer_y = bw_top + 70;
    eng.draw_rect(flyer_x, flyer_y, 84, 104, 64, 58, 62);
    eng.draw_rect(flyer_x + 5, flyer_y + 8, 74, 88, 38, 34, 40);
    DrawUtils::text(eng, "RULES", flyer_x + 42, flyer_y + 26, 12, 188, 182, 168, 245, true);
    for (int i = 0; i <= 5; ++i)
        eng.line(flyer_x + 12,
                 flyer_y + 40 + i * 9,
                 flyer_x + 70,
                 flyer_y + 40 + i * 9,
                 74,
                 70,
                 64,
                 180);

    int clock_x = vp_x + 120, clock_y = bw_top + 30;
    eng.circle(clock_x, clock_y, 18, 50, 48, 55);
    eng.circle(clock_x,
               clock_y,
               18,
               GameSettings::WALL_ACCENT.r,
               GameSettings::WALL_ACCENT.g,
               GameSettings::WALL_ACCENT.b,
               255,
               false);

    for (int i = 0; i <= 7; ++i) {
        int gx = bw_left + 40 + i * 58;
        eng.line(gx, bw_top + 44, gx + 8, bw_bottom - 26, 30, 26, 33, 90);
    }
    eng.line(vp_x, bw_top, vp_x, bw_bottom, 60, 55, 65, 120);
}

void Office::draw_back_wall_dynamic(Engine& eng, double t) {
    int clock_x = vp_x + 120, clock_y = bw_top + 30;
    eng.line(clock_x,
             clock_y,
             clock_x + static_cast<int>(std::cos(t) * 10),
             clock_y + static_cast<int>(std::sin(t) * 10),
             140,
             130,
             120);
    double pulse = 0.45 + 0.55 * std::sin(t * 2.8);
    auto lamp_a = static_cast<int>(26 + pulse * 38);
    eng.draw_rect(vp_x - 120, bw_top + 6, 240, 16, 220, 210, 165, lamp_a);
}

void Office::draw_depth_structure(Engine& eng) {
    double depths[] = {0.12, 0.24, 0.36, 0.50, 0.66, 0.82};
    for (double z : depths) {
        auto [lx, y, s] = project_depth(-1.0, z);
        auto [rx, ry, rs] = project_depth(1.0, z);
        auto shade_val = static_cast<int>(70 - z * 28);
        eng.line(lx, y, rx, y, shade_val, shade_val, shade_val + 4, 120);
    }

    double side_depths[] = {0.18, 0.42, 0.70};
    for (int side : {-1, 1}) {
        for (double z : side_depths) {
            auto [x0, y0, s0] = project_depth(0.82 * side, z, 0);
            auto [x1, y1, s1] = project_depth(0.82 * side, z, 150);
            int w = std::max(8, static_cast<int>(16 * s0));
            auto col = shade({48, 45, 52}, 1.05 - z * 0.35);
            eng.draw_rect(x0 - w / 2, y1, w, std::max(8, y0 - y1), col.r, col.g, col.b, 150);
        }
    }
}

void Office::draw_side_walls(Engine& eng) {
    DrawUtils::trapezoid(eng,
                         38,
                         35,
                         42,
                         bw_left - hall_depth,
                         0,
                         bw_left,
                         bw_top,
                         bw_left,
                         bw_bottom,
                         bw_left - hall_depth,
                         GameSettings::SCREEN_HEIGHT);
    DrawUtils::trapezoid(eng,
                         38,
                         35,
                         42,
                         bw_right,
                         bw_top,
                         bw_right + hall_depth,
                         0,
                         bw_right + hall_depth,
                         GameSettings::SCREEN_HEIGHT,
                         bw_right,
                         bw_bottom);
}

void Office::draw_hallways_base(Engine& eng) {
    int ht = bw_top + 15, hb = bw_bottom - 15;
    int lx = bw_left - hall_depth - hall_w;
    int lw = hall_w + 10;
    int lh = hb - ht;
    eng.draw_rect(lx, ht, lw, lh, 8, 8, 10);
    eng.draw_rect(lx,
                  ht,
                  lw,
                  lh,
                  GameSettings::DOOR_FRAME_COLOR.r,
                  GameSettings::DOOR_FRAME_COLOR.g,
                  GameSettings::DOOR_FRAME_COLOR.b,
                  255,
                  false);
    for (int i = 0; i <= 8; ++i) {
        int y = ht + i * (lh / 9);
        auto c = (i % 2 == 0) ? std::array<int, 3>{168, 138, 42} : std::array<int, 3>{35, 30, 28};
        eng.line(lx + lw - 10, y, lx + lw, y, c[0], c[1], c[2], 210);
    }

    int rx = bw_right + hall_depth - 10;
    int rw = hall_w + 10;
    eng.draw_rect(rx, ht, rw, lh, 8, 8, 10);
    eng.draw_rect(rx,
                  ht,
                  rw,
                  lh,
                  GameSettings::DOOR_FRAME_COLOR.r,
                  GameSettings::DOOR_FRAME_COLOR.g,
                  GameSettings::DOOR_FRAME_COLOR.b,
                  255,
                  false);
    for (int i = 0; i <= 8; ++i) {
        int y = ht + i * (lh / 9);
        auto c = (i % 2 == 0) ? std::array<int, 3>{168, 138, 42} : std::array<int, 3>{35, 30, 28};
        eng.line(rx, y, rx + 10, y, c[0], c[1], c[2], 210);
    }
}

void Office::draw_hallways_dynamic(Engine& eng,
                                   bool left_light,
                                   bool right_light,
                                   const std::string& anim_left,
                                   const std::string& anim_right) {
    int ht = bw_top + 15, hb = bw_bottom - 15;
    int lx = bw_left - hall_depth - hall_w;
    int lw = hall_w + 10;
    int lh = hb - ht;
    int rx = bw_right + hall_depth - 10;
    int rw = hall_w + 10;

    if (left_light) {
        eng.draw_rect(lx,
                      ht,
                      lw,
                      lh,
                      GameSettings::HALL_LIGHT.r,
                      GameSettings::HALL_LIGHT.g,
                      GameSettings::HALL_LIGHT.b,
                      70);
        eng.draw_rect(lx + 6, ht + 8, lw - 12, lh - 16, 226, 214, 170, 24);
        if (!anim_left.empty())
            DrawUtils::animatronic_face(eng, anim_left, lx + 10, ht + 20, lw - 20, 160);
    }
    if (right_light) {
        eng.draw_rect(rx,
                      ht,
                      rw,
                      lh,
                      GameSettings::HALL_LIGHT.r,
                      GameSettings::HALL_LIGHT.g,
                      GameSettings::HALL_LIGHT.b,
                      70);
        eng.draw_rect(rx + 6, ht + 8, rw - 12, lh - 16, 226, 214, 170, 24);
        if (!anim_right.empty())
            DrawUtils::animatronic_face(eng, anim_right, rx + 10, ht + 20, rw - 20, 160);
    }
}

void Office::draw_vent_base(Engine& eng) {
    int vx = vp_x - 60, vy = bw_bottom - 110, vw = 120, vh = 80;
    eng.draw_rect(vx, vy, vw, vh, 5, 5, 7);
    eng.draw_rect(vx, vy, vw, vh, 40, 40, 45, 255, false);
    for (int i = 1; i <= 3; ++i) {
        int by = vy + i * (vh / 4);
        eng.line(vx, by, vx + vw, by, 35, 35, 40);
    }
}

void Office::draw_vent_dynamic(Engine& eng, const std::string& anim_vent) {
    int vx = vp_x - 60, vy = bw_bottom - 110, vw = 120, vh = 80;
    if (vent_light) {
        eng.draw_rect(vx, vy, vw, vh, 200, 200, 220, 90);
        if (!anim_vent.empty())
            DrawUtils::animatronic_face(eng, anim_vent, vx + 20, vy + 10, vw - 40, vh - 20);
    } else if (!anim_vent.empty()) {
        eng.circle(vx + 45, vy + 30, 4, 255, 200, 220);
        eng.circle(vx + 75, vy + 30, 4, 255, 200, 220);
    }
}

void Office::draw_doors(Engine& eng, double left_anim_val, double right_anim_val) {
    int ht = bw_top + 15, hb = bw_bottom - 15;
    int door_h = hb - ht;
    if (left_anim_val > 0.01)
        draw_single_door(eng,
                         bw_left - hall_depth - hall_w,
                         ht,
                         hall_w + 10,
                         static_cast<int>(door_h * left_anim_val));
    if (right_anim_val > 0.01)
        draw_single_door(eng,
                         bw_right + hall_depth - 10,
                         ht,
                         hall_w + 10,
                         static_cast<int>(door_h * right_anim_val));
}

void Office::draw_single_door(Engine& eng, int x, int y, int w, int v_h) {
    eng.draw_rect(x,
                  y,
                  w,
                  v_h,
                  GameSettings::DOOR_COLOR.r,
                  GameSettings::DOOR_COLOR.g,
                  GameSettings::DOOR_COLOR.b);
    for (int i = 0; i < v_h; i += 14)
        eng.line(x, y + i, x + w, y + i, 85, 80, 78);
    int sh = 12;
    for (int i = 0; i <= w + sh; i += sh)
        eng.line(x + i, y, x + i - sh, y + std::min(sh, v_h), 200, 180, 40);
    if (v_h > 80) {
        eng.draw_rect(x + w / 2 - 18, y + 35, 36, 28, 15, 25, 15);
        eng.draw_rect(x + w / 2 - 18, y + 35, 36, 28, 95, 90, 85, 255, false);
    }
    eng.draw_rect(x, y, w, v_h, 95, 90, 85, 255, false);
}

void Office::draw_office_elements(Engine& eng) {
    auto [bl_x, bl_y, bl_s] = project_depth(-0.70, 0.58, 0);
    auto [br_x, br_y, br_s] = project_depth(0.70, 0.58, 0);
    auto [fl_x, fl_y, fl_s] = project_depth(-1.00, 0.92, 0);
    auto [fr_x, fr_y, fr_s] = project_depth(1.00, 0.92, 0);
    DrawUtils::trapezoid(eng,
                         GameSettings::DESK_TOP.r,
                         GameSettings::DESK_TOP.g,
                         GameSettings::DESK_TOP.b,
                         bl_x,
                         bl_y,
                         br_x,
                         br_y,
                         fr_x,
                         fr_y,
                         fl_x,
                         fl_y);
    auto col_desk = shade(GameSettings::DESK_COLOR, 0.85);
    DrawUtils::trapezoid(eng,
                         col_desk.r,
                         col_desk.g,
                         col_desk.b,
                         fl_x,
                         fl_y,
                         fr_x,
                         fr_y,
                         fr_x,
                         fr_y + 46,
                         fl_x,
                         fl_y + 46);
    eng.line(fl_x, fl_y, fr_x, fr_y, 120, 104, 86);
    eng.draw_rect(fl_x + 30, fl_y + 8, 120, 18, 72, 64, 60);
    eng.draw_rect(fr_x - 170, fr_y + 12, 145, 16, 74, 66, 62);
    for (int i = 0; i <= 4; ++i)
        eng.line(fl_x + 36 + i * 7, fl_y + 11, fl_x + 130 + i * 7, fl_y + 11, 96, 90, 84, 160);

    auto [mx, my, ms] = project_depth(0.42, 0.64, 66);
    int mw = std::max(42, static_cast<int>(85 * ms));
    int mh = std::max(28, static_cast<int>(56 * ms));
    eng.draw_rect(mx - mw / 2, my - mh / 2, mw, mh, 18, 20, 24);
    eng.draw_rect(mx - mw / 2, my - mh / 2, mw, mh, 65, 70, 78, 255, false);
    eng.draw_rect(mx - 4, my + mh / 2, 8, static_cast<int>(15 * ms), 45, 45, 48);
    eng.draw_rect(mx - static_cast<int>(24 * ms),
                  my + mh / 2 + static_cast<int>(15 * ms),
                  static_cast<int>(48 * ms),
                  static_cast<int>(5 * ms),
                  55,
                  55,
                  60);

    auto [cx, cy, cs] = project_depth(-0.34, 0.70, 32);
    int cw = std::max(8, static_cast<int>(14 * cs));
    int ch = std::max(12, static_cast<int>(28 * cs));
    eng.draw_rect(cx - cw / 2, cy - ch, cw, ch, 180, 25, 25);
    eng.draw_rect(cx - cw / 2 - 1, cy - ch - 3, cw + 2, 5, 210, 45, 45);

    auto [mug_x, mug_y, mug_s] = project_depth(0.08, 0.73, 28);
    int mug_w = std::max(10, static_cast<int>(18 * mug_s));
    int mug_h = std::max(8, static_cast<int>(12 * mug_s));
    eng.draw_rect(mug_x - mug_w / 2, mug_y - mug_h, mug_w, mug_h, 120, 115, 102);
    eng.draw_rect(
        mug_x + mug_w / 2 - 1, mug_y - mug_h + 2, 5, mug_h - 4, 120, 115, 102, 255, false);
}

void Office::draw_fan(Engine& eng, double t) {
    auto [fx, fy, fs] = project_depth(-0.46, 0.66, 34);
    int cx = fx, cy = fy;
    auto hub_r = std::max(3, static_cast<int>(5 * fs));
    auto ring_r = std::max(12, static_cast<int>(24 * fs));
    eng.draw_rect(cx - 10, cy + 2, 20, 22, 55, 55, 60);
    eng.draw_rect(cx - 16, cy + 22, 32, 6, 65, 65, 70);
    eng.circle(cx, cy - 5, ring_r, 70, 24, 24);
    eng.circle(cx, cy - 5, std::max(8, ring_r - 2), 48, 48, 52);
    double ft = t * 12.0;
    for (int i = 0; i < 4; ++i) {
        double angle = ft + i * (PI / 2);
        int ex = cx + static_cast<int>(std::cos(angle) * (ring_r - 5));
        int ey = cy - 5 + static_cast<int>(std::sin(angle) * (ring_r - 5));
        eng.line(cx, cy - 5, ex, ey, 110, 110, 115);
    }
    eng.circle(cx, cy - 5, hub_r, 80, 80, 85);
}

void Office::draw_wall_dressing(Engine& eng) {
    for (int side : {-1, 1}) {
        int base_x = (side < 0) ? (bw_left - hall_depth + 22) : (bw_right + hall_depth - 130);
        eng.draw_rect(base_x, bw_top + 44, 108, 30, 26, 24, 30);
        eng.draw_rect(base_x + 3, bw_top + 47, 102, 24, 56, 18, 18);
        DrawUtils::text(eng, "DOOR CTRL", base_x + 54, bw_top + 59, 11, 220, 214, 194, 240, true);
    }
    for (int i = 0; i <= 3; ++i) {
        int x0 = vp_x - 150 + i * 92;
        int y0 = bw_bottom - 56 - i * 4;
        eng.line(x0, y0, x0 + 78, y0 - 8, 26, 24, 30, 180);
    }
}

void Office::draw_in_office(Engine& eng, const std::string& anim_name) {
    if (anim_name.empty())
        return;
    int w = 400, h = 500;
    int x = vp_x - w / 2;
    int y = bw_bottom - h + 80;
    int ct = static_cast<int>(static_cast<double>(clock()) / CLOCKS_PER_SEC * 7);
    if (ct % 3 != 0)
        DrawUtils::animatronic_sprite(eng, anim_name, x, y, w, h);
}

void Office::draw_ambient(Engine& eng) {
    eng.draw_rect(0, 0, GameSettings::OFFICE_WIDTH, GameSettings::SCREEN_HEIGHT, 0, 0, 0, 24);
    eng.draw_rect(0, 0, GameSettings::OFFICE_WIDTH, 120, 0, 0, 0, 40);
    eng.draw_rect(0, GameSettings::SCREEN_HEIGHT - 90, GameSettings::OFFICE_WIDTH, 90, 0, 0, 0, 32);
    for (int i = 0; i <= 6; ++i) {
        int y = static_cast<int>(i * (GameSettings::SCREEN_HEIGHT / 7.0));
        int a = 20 - i * 2;
        if (a > 0)
            eng.draw_rect(0,
                          y,
                          GameSettings::OFFICE_WIDTH,
                          static_cast<int>(GameSettings::SCREEN_HEIGHT / 7.0),
                          0,
                          0,
                          0,
                          a);
    }
}

}  // namespace fnwf
