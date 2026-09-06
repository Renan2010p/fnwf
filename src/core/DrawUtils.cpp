#include "core/DrawUtils.hpp"
#include "game1/GameSettings.hpp"
#include <cmath>
#include <cstdlib>
#include <sstream>
#include <algorithm>

namespace fnwf
{

void DrawUtils::load_sprite(Engine& eng, const std::string& name)
{
    if (s_sprite_cache.count(name)) return;
    std::string path = std::string(GameSettings::ASSETS_DIR) + "/" + name + ".png";
    auto tex = eng.load_texture(path);
    if (tex) { s_sprite_cache[name] = *tex; }
}

auto DrawUtils::get_sprite(const std::string& name) -> std::optional<TextureHandle>
{
    auto it = s_sprite_cache.find(name);
    if (it != s_sprite_cache.end()) { return it->second; }
    return std::nullopt;
}

void DrawUtils::set_fonts(Engine& eng)
{
    s_main_font = eng.load_font(std::string(GameSettings::ASSETS_DIR) + "/font/font.ttf", 16);
    if (s_main_font == -1) s_main_font = 0;
    s_font_cache[16] = s_main_font;
}

auto DrawUtils::get_font_by_size(Engine& eng, std::uint32_t size) -> std::int64_t
{
    auto it = s_font_cache.find(size);
    if (it != s_font_cache.end()) { return it->second; }
    auto idx = eng.load_font(std::string(GameSettings::ASSETS_DIR) + "/font/font.ttf", size);
    if (idx == -1) return s_main_font;
    s_font_cache[size] = idx;
    return idx;
}

void DrawUtils::set_render_quality(const std::string& level)
{
    s_render_quality = (level == "high") ? "high" : "low";
}

auto DrawUtils::get_render_quality() -> const std::string&
{
    return s_render_quality;
}

void DrawUtils::text(Engine& eng, const std::string& text, std::int32_t x, std::int32_t y,
                     std::uint32_t size, std::uint8_t r, std::uint8_t g, std::uint8_t b,
                     std::uint8_t alpha, bool center, std::int32_t font_idx)
{
    auto f_idx = font_idx >= 0 ? font_idx : get_font_by_size(eng, size);
    eng.draw_text(text, x, y, size, r, g, b, alpha, center, f_idx);
}

void DrawUtils::text_rotated(Engine& eng, const std::string& text, std::int32_t x, std::int32_t y,
                             double angle, std::uint32_t size,
                             std::uint8_t r, std::uint8_t g, std::uint8_t b,
                             std::uint8_t alpha, bool center)
{
    auto f_idx = get_font_by_size(eng, size);
    eng.draw_text_rotated(text, x, y, size, angle, r, g, b, alpha, center, f_idx);
}

void DrawUtils::static_noise(Engine& eng, std::int32_t x, std::int32_t y, std::uint32_t w, std::uint32_t h, float intensity)
{
    float ci = intensity;
    if (s_render_quality == "low") { ci *= 0.55f; }
    if ((std::rand() / (float)RAND_MAX) < ci)
    {
        eng.draw_rect(x, y, w, h, 100, 100, 100, 20);
    }
}

void DrawUtils::scanlines(Engine& eng, std::int32_t x, std::int32_t y, std::uint32_t w, std::uint32_t h, std::uint8_t alpha)
{
    std::uint8_t a = alpha;
    std::int32_t step = 4;
    if (s_render_quality == "low") { a = static_cast<std::uint8_t>(a * 0.6); step = 6; }
    else if (alpha < 20) { step = 5; }

    std::string key = std::to_string(x) + "_" + std::to_string(y) + "_" + std::to_string(h) + "_" + std::to_string(step);
    auto it = s_scanline_cache.find(key);
    if (it == s_scanline_cache.end())
    {
        std::vector<std::int32_t> rows;
        for (std::int32_t py = y; py <= static_cast<std::int32_t>(y + h); py += step)
        {
            rows.push_back(py);
        }
        s_scanline_cache[key] = rows;
        it = s_scanline_cache.find(key);
    }
    for (auto py : it->second)
    {
        eng.draw_rect(x, py, w, 1, 0, 0, 0, a);
    }
}

void DrawUtils::button_box(Engine& eng, std::int32_t x, std::int32_t y, std::uint32_t w, std::uint32_t h,
                           const std::string& label, bool active,
                           std::uint8_t r_on, std::uint8_t g_on, std::uint8_t b_on,
                           std::uint8_t r_off, std::uint8_t g_off, std::uint8_t b_off)
{
    auto r = active ? r_on : r_off;
    auto g = active ? g_on : g_off;
    auto b = active ? b_on : b_off;
    eng.draw_rect(x, y, w, h, r, g, b);
    eng.draw_rect(x, y, w, h, 255, 255, 255, 255, false);
    text(eng, label, x + w / 2, y + h / 2, 14, 255, 255, 255, 255, true);
}

void DrawUtils::animatronic_sprite(Engine& eng, const std::string& name,
                                   std::int32_t x, std::int32_t y, std::uint32_t w, std::uint32_t h)
{
    auto tex = get_sprite(name);
    if (tex)
    {
        eng.draw_texture(*tex, x, y, w, h);
    }
    else
    {
        eng.draw_rect(x, y, w, h, 100, 100, 100);
        std::string upper = name;
        std::transform(upper.begin(), upper.end(), upper.begin(), ::toupper);
        text(eng, upper, x + w / 2, y + h / 2, 14, 255, 255, 255, 255, true);
    }
}

void DrawUtils::trapezoid(Engine& eng, std::uint8_t r, std::uint8_t g, std::uint8_t b,
                          std::int32_t p1x, std::int32_t p1y, std::int32_t p2x, std::int32_t p2y,
                          std::int32_t p3x, std::int32_t p3y, std::int32_t p4x, std::int32_t p4y)
{
    std::int32_t y_min = std::min(p1y, p2y);
    std::int32_t y_max = std::max(p3y, p4y);
    if (y_max == y_min) return;

    for (std::int32_t py = y_min; py <= y_max; ++py)
    {
        float prog = static_cast<float>(py - y_min) / static_cast<float>(y_max - y_min);
        float x_left = static_cast<float>(p1x) + (static_cast<float>(p4x) - static_cast<float>(p1x)) * prog;
        float x_right = static_cast<float>(p2x) + (static_cast<float>(p3x) - static_cast<float>(p2x)) * prog;
        auto xl = static_cast<std::int32_t>(std::floor(x_left));
        auto xr = static_cast<std::int32_t>(std::floor(x_right));
        if (xr > xl)
        {
            eng.line(xl, py, xr, py, r, g, b);
        }
    }
}

void DrawUtils::star(Engine& eng, std::int32_t cx, std::int32_t cy, std::int32_t outer_r,
                     std::uint8_t r, std::uint8_t g, std::uint8_t b)
{
    auto size = outer_r;
    eng.draw_rect(cx - size / 4, cy - size / 2, size / 2, size, r, g, b);
    eng.draw_rect(cx - size / 2, cy - size / 4, size, size / 2, r, g, b);
}

void DrawUtils::animatronic_face(Engine& eng, const std::string& name,
                                 std::int32_t x, std::int32_t y, std::uint32_t w, std::uint32_t h)
{
    auto tex = get_sprite(name);
    if (tex)
    {
        eng.draw_texture(*tex, x, y, w, h);
    }
}

void DrawUtils::rounded_texture(Engine& eng, const TextureHandle& tex,
                                std::int32_t x, std::int32_t y, std::uint32_t w, std::uint32_t h,
                                std::int32_t radius,
                                std::uint8_t bg_r, std::uint8_t bg_g, std::uint8_t bg_b,
                                std::uint8_t alpha)
{
    radius = std::max(1, radius);
    eng.draw_texture(tex, x, y, w, h, -1, -1, -1, -1, alpha);

    for (std::int32_t i = 0; i <= radius; ++i)
    {
        auto off = static_cast<std::int32_t>(std::floor(radius - std::sqrt(radius * radius - (radius - i) * (radius - i))));
        if (off > 0)
        {
            eng.draw_rect(x, y + i, off, 1, bg_r, bg_g, bg_b, 255);
            eng.draw_rect(x + w - off, y + i, off, 1, bg_r, bg_g, bg_b, 255);
            eng.draw_rect(x, y + h - i - 1, off, 1, bg_r, bg_g, bg_b, 255);
            eng.draw_rect(x + w - off, y + h - i - 1, off, 1, bg_r, bg_g, bg_b, 255);
        }
    }
}

void DrawUtils::apply_camera_effect(Engine& eng, float noise_intensity,
                                    std::uint8_t scanline_alpha, std::uint32_t /*scanline_spacing*/)
{
    scanlines(eng, 0, 0, GameSettings::SCREEN_WIDTH, GameSettings::SCREEN_HEIGHT, scanline_alpha);
    static_noise(eng, 0, 0, GameSettings::SCREEN_WIDTH, GameSettings::SCREEN_HEIGHT, noise_intensity);
}

void DrawUtils::vignette(Engine& eng, float intensity, std::uint8_t r, std::uint8_t g, std::uint8_t b)
{
    intensity = std::max(0.0f, std::min(1.0f, intensity));
    auto layers = (s_render_quality == "high") ? 22 : 10;
    auto max_a = static_cast<std::uint8_t>(150 * intensity);
    auto w = GameSettings::SCREEN_WIDTH;
    auto h = GameSettings::SCREEN_HEIGHT;

    for (int i = 1; i <= layers; ++i)
    {
        float t = static_cast<float>(i) / static_cast<float>(layers);
        auto inset = static_cast<std::int32_t>(std::floor(t * 64));
        auto a = static_cast<std::uint8_t>((1.0f - t) * max_a);
        eng.draw_rect(inset, inset, w - inset * 2, h - inset * 2, r, g, b, a, false);
    }
}

void DrawUtils::tone_overlay(Engine& eng, std::uint8_t r, std::uint8_t g, std::uint8_t b, std::uint8_t alpha)
{
    if (alpha <= 0) return;
    eng.draw_rect(0, 0, GameSettings::SCREEN_WIDTH, GameSettings::SCREEN_HEIGHT, r, g, b, alpha);
}

void DrawUtils::vhs_osd(Engine& eng, const std::string& text, std::int32_t x, std::int32_t y,
                        std::uint8_t r, std::uint8_t g, std::uint8_t b, std::uint32_t scale)
{
    DrawUtils::text(eng, text, x + 1, y + 1, scale, 0, 0, 0, 255, false);
    DrawUtils::text(eng, text, x, y, scale, r, g, b, 255, false);
}

} // namespace fnwf
