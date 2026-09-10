#pragma once

#include "engine/Engine.hpp"
#include <string>
#include <unordered_map>

namespace fnwf {

class DrawUtils
{
public:
    static auto load_sprite(Engine& eng, const std::string& name) -> void;
    static auto get_sprite(const std::string& name) -> std::optional<TextureHandle>;
    static auto set_fonts(Engine& eng) -> void;
    static auto get_font_by_size(Engine& eng, std::uint32_t size) -> std::int64_t;
    static auto set_render_quality(const std::string& level) -> void;
    static auto get_render_quality() -> const std::string&;

    static auto text(Engine& eng,
                     const std::string& text,
                     std::int32_t x,
                     std::int32_t y,
                     std::uint32_t size = 24,
                     std::uint8_t r = 255,
                     std::uint8_t g = 255,
                     std::uint8_t b = 255,
                     std::uint8_t alpha = 255,
                     bool center = false,
                     std::int32_t font_idx = -1) -> void;

    static auto text_rotated(Engine& eng,
                             const std::string& text,
                             std::int32_t x,
                             std::int32_t y,
                             double angle,
                             std::uint32_t size = 24,
                             std::uint8_t r = 255,
                             std::uint8_t g = 255,
                             std::uint8_t b = 255,
                             std::uint8_t alpha = 255,
                             bool center = false) -> void;

    static auto static_noise(Engine& eng,
                             std::int32_t x,
                             std::int32_t y,
                             std::uint32_t w,
                             std::uint32_t h,
                             float intensity = 0.3f) -> void;
    static auto scanlines(Engine& eng,
                          std::int32_t x,
                          std::int32_t y,
                          std::uint32_t w,
                          std::uint32_t h,
                          std::uint8_t alpha = 30) -> void;
    static auto button_box(Engine& eng,
                           std::int32_t x,
                           std::int32_t y,
                           std::uint32_t w,
                           std::uint32_t h,
                           const std::string& label,
                           bool active,
                           std::uint8_t r_on,
                           std::uint8_t g_on,
                           std::uint8_t b_on,
                           std::uint8_t r_off = 60,
                           std::uint8_t g_off = 60,
                           std::uint8_t b_off = 65) -> void;
    static auto animatronic_sprite(Engine& eng,
                                   const std::string& name,
                                   std::int32_t x,
                                   std::int32_t y,
                                   std::uint32_t w,
                                   std::uint32_t h) -> void;
    static auto trapezoid(Engine& eng,
                          std::uint8_t r,
                          std::uint8_t g,
                          std::uint8_t b,
                          std::int32_t p1x,
                          std::int32_t p1y,
                          std::int32_t p2x,
                          std::int32_t p2y,
                          std::int32_t p3x,
                          std::int32_t p3y,
                          std::int32_t p4x,
                          std::int32_t p4y) -> void;
    static auto star(Engine& eng,
                     std::int32_t cx,
                     std::int32_t cy,
                     std::int32_t outer_r = 10,
                     std::uint8_t r = 255,
                     std::uint8_t g = 255,
                     std::uint8_t b = 100) -> void;
    static auto animatronic_face(Engine& eng,
                                 const std::string& name,
                                 std::int32_t x,
                                 std::int32_t y,
                                 std::uint32_t w,
                                 std::uint32_t h) -> void;
    static auto rounded_texture(Engine& eng,
                                const TextureHandle& tex,
                                std::int32_t x,
                                std::int32_t y,
                                std::uint32_t w,
                                std::uint32_t h,
                                std::int32_t radius = 14,
                                std::uint8_t bg_r = 4,
                                std::uint8_t bg_g = 5,
                                std::uint8_t bg_b = 9,
                                std::uint8_t alpha = 255) -> void;
    static auto apply_camera_effect(Engine& eng,
                                    float noise_intensity = 0.02f,
                                    std::uint8_t scanline_alpha = 30,
                                    std::uint32_t scanline_spacing = 4) -> void;
    static auto vignette(Engine& eng,
                         float intensity = 0.3f,
                         std::uint8_t r = 0,
                         std::uint8_t g = 0,
                         std::uint8_t b = 0) -> void;
    static void
    tone_overlay(Engine& eng, std::uint8_t r, std::uint8_t g, std::uint8_t b, std::uint8_t alpha);
    static auto vhs_osd(Engine& eng,
                        const std::string& text,
                        std::int32_t x,
                        std::int32_t y,
                        std::uint8_t r = 210,
                        std::uint8_t g = 255,
                        std::uint8_t b = 210,
                        std::uint32_t scale = 14) -> void;

    static auto clear_cache() -> void;

private:
    static inline std::unordered_map<std::string, TextureHandle> s_sprite_cache{};
    static inline std::unordered_map<std::uint32_t, std::int64_t> s_font_cache{};
    static inline std::int64_t s_main_font{-1};
    static inline std::string s_render_quality{"high"};
    static inline std::unordered_map<std::string, std::vector<std::int32_t>> s_scanline_cache{};
};

}  // namespace fnwf
