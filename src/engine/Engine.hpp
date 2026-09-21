#pragma once

// Engine — pure abstract interface. No platform headers here.

#include <array>
#include <cstdint>
#include <memory>
#include <optional>
#include <string>
#include <string_view>
#include <utility>
#include <vector>

#include "engine/Event.hpp"

namespace fnwf {

// ── Opaque resource handles ─────────────────────────────────────────────────
struct TextureHandle
{
    std::uint32_t id{};
};
struct SoundHandle
{
    std::uint32_t id{};
};

// ── Abstract engine interface ────────────────────────────────────────────────
class Engine
{
public:
    virtual ~Engine() = default;

    // Lifecycle
    virtual bool init(std::string_view title,
                      std::uint32_t w,
                      std::uint32_t h,
                      bool fullscreen,
                      bool vsync) = 0;
    virtual void shutdown() = 0;

    // Events & timing
    virtual std::vector<Event> poll_events() = 0;
    virtual float ticks() const noexcept = 0;
    virtual bool keeps_running() const noexcept = 0;
    virtual void request_stop() noexcept = 0;
    virtual void present() = 0;

    // Window
    virtual void set_logical_size(std::uint32_t w, std::uint32_t h) = 0;
    virtual void set_fullscreen(bool on) = 0;
    virtual void set_vsync(bool on) = 0;
    virtual void set_resolution(std::uint32_t w, std::uint32_t h) = 0;
    virtual std::vector<std::array<std::int32_t, 3>> get_display_modes() = 0;

    // Drawing primitives
    virtual void clear(std::uint8_t r, std::uint8_t g, std::uint8_t b, std::uint8_t a = 255) = 0;
    virtual void draw_rect(std::int32_t x, std::int32_t y, std::uint32_t w, std::uint32_t h,
                           std::uint8_t r, std::uint8_t g, std::uint8_t b, std::uint8_t a = 255,
                           bool filled = true) = 0;
    virtual void line(std::int32_t x1, std::int32_t y1, std::int32_t x2, std::int32_t y2,
                      std::uint8_t r, std::uint8_t g, std::uint8_t b, std::uint8_t a = 255) = 0;
    virtual void circle(std::int32_t cx, std::int32_t cy, std::int32_t radius,
                        std::uint8_t r, std::uint8_t g, std::uint8_t b, std::uint8_t a = 255,
                        bool filled = true) = 0;

    // Textures
    virtual void draw_texture(const TextureHandle& tex,
                              std::int32_t dx, std::int32_t dy, std::uint32_t dw, std::uint32_t dh,
                              std::int32_t sx = -1, std::int32_t sy = -1,
                              std::int32_t sw = -1, std::int32_t sh = -1,
                              std::optional<std::uint8_t> alpha = std::nullopt) = 0;
    virtual void draw_texture_rotated(const TextureHandle& tex,
                                      std::int32_t dx, std::int32_t dy,
                                      std::uint32_t dw, std::uint32_t dh, float angle,
                                      std::optional<std::uint8_t> alpha = std::nullopt) = 0;

    // Text
    virtual bool draw_text(std::string_view text, std::int32_t x, std::int32_t y,
                           std::uint32_t font_size, std::uint8_t r, std::uint8_t g, std::uint8_t b,
                           std::uint8_t a = 255, bool center = false, std::int32_t font_idx = -1) = 0;
    virtual bool draw_text_rotated(std::string_view text, std::int32_t x, std::int32_t y,
                                   std::uint32_t font_size, float angle,
                                   std::uint8_t r, std::uint8_t g, std::uint8_t b,
                                   std::uint8_t a = 255, bool center = false,
                                   std::int32_t font_idx = -1) = 0;

    // Resources
    virtual std::optional<TextureHandle> load_texture(std::string_view path) = 0;
    virtual std::optional<TextureHandle> create_target(std::uint32_t w, std::uint32_t h) = 0;
    virtual std::optional<SoundHandle> load_sound(std::string_view path) = 0;
    virtual std::int64_t load_font(std::string_view path, std::uint16_t size) = 0;
    virtual std::optional<std::array<std::int32_t, 2>> font_text_size(std::string_view text,
                                                                      std::uint32_t font_idx) = 0;
    virtual std::pair<std::uint32_t, std::uint32_t> texture_size(std::uint32_t id) noexcept = 0;

    // Render targets
    virtual void set_render_target(std::optional<TextureHandle> target) = 0;
    virtual void reset_render_target() = 0;

    // Sound
    virtual std::int32_t play_sound(const SoundHandle& snd, std::int32_t loops,
                                    std::int32_t channel) = 0;
    virtual void stop_channel(std::int32_t channel) = 0;
    virtual void stop_all_sounds() = 0;

    // Input
    virtual std::pair<std::int32_t, std::int32_t> mouse_pos() = 0;

    // Volume (abstracted from Mix_Volume calls)
    virtual void set_master_volume(int vol) = 0;
    virtual void set_sfx_volume(int vol) = 0;
    virtual void set_music_volume(int vol) = 0;

    // Misc
    virtual void update_discord(std::string_view details, std::string_view state) = 0;

    // Notification for derived classes when VSW triggers texture cache invalidation
    virtual void on_vsync_change() {}
};

// ── Factory ──────────────────────────────────────────────────────────────────
Engine* create_engine();
void destroy_engine(Engine* e);

}  // namespace fnwf
