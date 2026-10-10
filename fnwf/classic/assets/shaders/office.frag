#version 330 core
// Game-provided office shader (fragment). Edit freely — this lives in the game
// package, not in the engine. `u_params` = pan, source_width, screen_w, screen_h.
in vec2 v_screen;
uniform sampler2D u_tex;
uniform vec4 u_params;
out vec4 o_color;

const float PI = 3.14159265;

void main() {
    float pan = u_params.x;
    float srcw = u_params.y;
    float sw = u_params.z;
    float sh = u_params.w;

    float focal = (sw * 0.5) / tan(radians(100.0) * 0.5);
    float ppr = srcw / PI;
    float center = PI * 0.5 + pan * radians(45.0);

    float theta = atan(((v_screen.x - 0.5) * sw) / focal);
    float u = (center + theta) * ppr / srcw;
    float th = sh / cos(theta);
    float y0 = (sh - th) * 0.5;
    float sy = v_screen.y * sh;

    if (sy < y0 || sy > y0 + th) { o_color = vec4(0.0); return; }
    o_color = texture(u_tex, vec2(clamp(u, 0.0, 1.0), 1.0 - (sy - y0) / th));
}
