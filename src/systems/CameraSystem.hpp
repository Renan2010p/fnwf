#pragma once

#include "engine/Engine.hpp"
#include <string>
#include <unordered_map>
#include <vector>

namespace fnwf {

class CameraSystem
{
public:
    CameraSystem(Engine& eng);

    void update(double dt);
    void draw(Engine& eng,
              const std::unordered_map<std::string, std::string>& anim_positions,
              int foxy_stage);
    void toggle();
    void toggle_mask();
    void force_remove_mask();
    void switch_camera(const std::string& cam_id);
    auto is_fully_open() const -> bool;
    auto is_visible() const -> bool;
    auto check_toggle_click(int mx, int my) -> bool;
    auto check_mask_toggle_click(int mx, int my) -> bool;
    auto check_mouse_trigger(int mouse_x, int mouse_y) -> bool;
    auto handle_click(int mx, int my) -> bool;

    bool is_open{false};
    std::string current_cam{"1A"};
    bool is_mask_open{false};
    bool is_mask_animating{false};
    bool is_animating{false};

private:
    auto ease_out_cubic(double v) const -> double;
    auto get_bottom_toggle_rects() const -> std::pair<std::array<int, 4>, std::array<int, 4>>;

    void draw_mask_overlay(Engine& eng);
    void draw_monitor(Engine& eng,
                      const std::unordered_map<std::string, std::string>& anim_positions,
                      int foxy_stage);
    void draw_monitor_animation(Engine& eng);
    void draw_camera_view(Engine& eng,
                          const std::unordered_map<std::string, std::string>& anim_positions,
                          int foxy_stage);
    void draw_show_stage(Engine& eng,
                         int cx,
                         int cy,
                         const std::unordered_map<std::string, std::string>& anim_positions);
    void draw_dining_area(Engine& eng,
                          int cx,
                          int cy,
                          const std::unordered_map<std::string, std::string>& anim_positions);
    void draw_backstage(Engine& eng,
                        int cx,
                        int cy,
                        const std::unordered_map<std::string, std::string>& anim_positions);
    void draw_hallway(Engine& eng,
                      int cx,
                      int cy,
                      const std::unordered_map<std::string, std::string>& anim_positions,
                      const std::string& cam_id);
    void draw_hall_corner(Engine& eng,
                          int cx,
                          int cy,
                          const std::unordered_map<std::string, std::string>& anim_positions,
                          const std::string& cam_id);
    void draw_supply_closet(Engine& eng,
                            int cx,
                            int cy,
                            const std::unordered_map<std::string, std::string>& anim_positions);
    void draw_sonk_cove(Engine& eng, int cx, int cy, int foxy_stage);
    void draw_map(Engine& eng, const std::unordered_map<std::string, std::string>& anim_positions);

    Engine& m_eng;
    double static_timer{0.0};
    double static_duration{0.4};
    double anim_progress{0.0};
    double anim_speed{5.0};
    double mask_anim_progress{0.0};
    double mask_anim_speed{4.0};
    double mouse_trigger_zone{60.0};
    bool mouse_in_cam_zone{false};
    bool mouse_in_mask_zone{false};

    int map_w{260};
    int map_h{300};
    int map_x{};
    int map_y{};

    TextureHandle monitor_tex{};
    TextureHandle map_tex{};
    TextureHandle map_base_tex{};
    bool map_base_dirty{true};

    std::unordered_map<std::string, std::array<int, 4>> cam_buttons{};
};

}  // namespace fnwf
