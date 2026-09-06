#pragma once

#include "engine/Engine.hpp"
#include "game1/GameSettings.hpp"
#include <vector>
#include <cmath>

namespace fnwf
{

struct ProjectionSlice
{
    int sx{};
    double theta{};
    int target_h{};
    int src_w{};
};

class Office
{
public:
    Office(Engine& eng);
    void update(int mouse_x, double dt);
    void draw(Engine& eng, double left_door_anim, double right_door_anim,
              bool left_light, bool right_light,
              const std::string& anim_at_left, const std::string& anim_at_right,
              const std::string& anim_at_vent, const std::string& anim_in_office);

    bool vent_light{false};

private:
    auto shade(const Color& c, double factor) -> Color;
    auto project_depth(double nx, double z, double height = 0.0) -> std::tuple<int, int, double>;
    void precalculate_projection();
    void build_static_layer();
    void draw_ceiling(Engine& eng);
    void draw_floor(Engine& eng);
    void draw_back_wall_base(Engine& eng);
    void draw_back_wall_dynamic(Engine& eng, double t);
    void draw_depth_structure(Engine& eng);
    void draw_side_walls(Engine& eng);
    void draw_hallways_base(Engine& eng);
    void draw_hallways_dynamic(Engine& eng, bool left_light, bool right_light,
                               const std::string& anim_left, const std::string& anim_right);
    void draw_vent_base(Engine& eng);
    void draw_vent_dynamic(Engine& eng, const std::string& anim_vent);
    void draw_doors(Engine& eng, double left_anim, double right_anim);
    void draw_single_door(Engine& eng, int x, int y, int w, int v_h);
    void draw_office_elements(Engine& eng);
    void draw_fan(Engine& eng, double t);
    void draw_wall_dressing(Engine& eng);
    void draw_in_office(Engine& eng, const std::string& anim_name);
    void draw_ambient(Engine& eng);

    Engine& m_eng;
    double pan_x{0.0};
    double target_pan{0.0};
    TextureHandle office_tex;
    TextureHandle office_static_tex;

    int vp_x{}, vp_y{};
    int bw_left{}, bw_right{}, bw_top{}, bw_bottom{};
    int hall_w{100};
    int hall_depth{250};

    std::vector<ProjectionSlice> projection_data{};
};

} // namespace fnwf
