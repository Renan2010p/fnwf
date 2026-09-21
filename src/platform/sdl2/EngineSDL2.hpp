#pragma once

// EngineSDL2 — concrete SDL2 implementation of the Engine interface.
// This file lives in src/platform/sdl2/ and is the ONLY place SDL2 headers
// are pulled into the Engine hierarchy.

#include "engine/Engine.hpp"

#include <SDL.h>
#include <SDL_image.h>
#include <SDL_mixer.h>
#include <SDL_ttf.h>

#include <unordered_map>

namespace fnwf {

class EngineSDL2 final : public Engine
{
public:
    EngineSDL2() = default;
    ~EngineSDL2() override;

    // Lifecycle
    bool init(std::string_view title, std::uint32_t w, std::uint32_t h,
              bool fullscreen, bool vsync) override;
    void shutdown() override;

    // Events & timing
    std::vector<Event> poll_events() override;
    float ticks() const noexcept override;
    bool keeps_running() const noexcept override { return m_running; }
    void request_stop() noexcept override { m_running = false; }
    void present() override;

    // Window
    void set_logical_size(std::uint32_t w, std::uint32_t h) override;
    void set_fullscreen(bool on) override;
    void set_vsync(bool on) override;
    void set_resolution(std::uint32_t w, std::uint32_t h) override;
    std::vector<std::array<std::int32_t, 3>> get_display_modes() override;

    // Drawing
    void clear(std::uint8_t r, std::uint8_t g, std::uint8_t b, std::uint8_t a) override;
    void draw_rect(std::int32_t x, std::int32_t y, std::uint32_t w, std::uint32_t h,
                   std::uint8_t r, std::uint8_t g, std::uint8_t b, std::uint8_t a,
                   bool filled) override;
    void line(std::int32_t x1, std::int32_t y1, std::int32_t x2, std::int32_t y2,
              std::uint8_t r, std::uint8_t g, std::uint8_t b, std::uint8_t a) override;
    void circle(std::int32_t cx, std::int32_t cy, std::int32_t radius,
                std::uint8_t r, std::uint8_t g, std::uint8_t b, std::uint8_t a,
                bool filled) override;

    // Textures
    void draw_texture(const TextureHandle& tex, std::int32_t dx, std::int32_t dy,
                      std::uint32_t dw, std::uint32_t dh, std::int32_t sx, std::int32_t sy,
                      std::int32_t sw, std::int32_t sh,
                      std::optional<std::uint8_t> alpha) override;
    void draw_texture_rotated(const TextureHandle& tex, std::int32_t dx, std::int32_t dy,
                              std::uint32_t dw, std::uint32_t dh, float angle,
                              std::optional<std::uint8_t> alpha) override;

    // Text
    bool draw_text(std::string_view text, std::int32_t x, std::int32_t y,
                   std::uint32_t font_size, std::uint8_t r, std::uint8_t g, std::uint8_t b,
                   std::uint8_t a, bool center, std::int32_t font_idx) override;
    bool draw_text_rotated(std::string_view text, std::int32_t x, std::int32_t y,
                           std::uint32_t font_size, float angle,
                           std::uint8_t r, std::uint8_t g, std::uint8_t b,
                           std::uint8_t a, bool center, std::int32_t font_idx) override;

    // Resources
    std::optional<TextureHandle> load_texture(std::string_view path) override;
    std::optional<TextureHandle> create_target(std::uint32_t w, std::uint32_t h) override;
    std::optional<SoundHandle> load_sound(std::string_view path) override;
    std::int64_t load_font(std::string_view path, std::uint16_t size) override;
    std::optional<std::array<std::int32_t, 2>> font_text_size(std::string_view text,
                                                              std::uint32_t font_idx) override;
    std::pair<std::uint32_t, std::uint32_t> texture_size(std::uint32_t id) noexcept override;

    // Render targets
    void set_render_target(std::optional<TextureHandle> target) override;
    void reset_render_target() override;

    // Sound
    std::int32_t play_sound(const SoundHandle& snd, std::int32_t loops,
                            std::int32_t channel) override;
    void stop_channel(std::int32_t channel) override;
    void stop_all_sounds() override;

    // Input
    std::pair<std::int32_t, std::int32_t> mouse_pos() override;

    // Volume
    void set_master_volume(int vol) override;
    void set_sfx_volume(int vol) override;
    void set_music_volume(int vol) override;

    // Misc
    void update_discord(std::string_view details, std::string_view state) override;
    void on_vsync_change() override;

private:
    SDL_Texture* get_texture(std::uint32_t id) noexcept;

    // SDL2 smart-pointer deleters
    struct WindowDeleter  { void operator()(SDL_Window* w) const noexcept { SDL_DestroyWindow(w); } };
    struct RendererDeleter { void operator()(SDL_Renderer* r) const noexcept { SDL_DestroyRenderer(r); } };
    struct TextureDeleter  { void operator()(SDL_Texture* t) const noexcept { SDL_DestroyTexture(t); } };
    struct FontDeleter     { void operator()(TTF_Font* f) const noexcept { TTF_CloseFont(f); } };

    using Window   = std::shared_ptr<SDL_Window>;
    using Renderer = std::shared_ptr<SDL_Renderer>;
    using Tex      = std::shared_ptr<SDL_Texture>;
    using Font     = std::shared_ptr<TTF_Font>;

    Window   m_window{};
    Renderer m_renderer{};
    std::vector<Font> m_fonts{};
    std::unordered_map<std::uint32_t, Tex> m_textures{};
    std::unordered_map<std::uint32_t, std::shared_ptr<Mix_Chunk>> m_chunks{};
    std::unordered_map<std::uint64_t, Tex> m_text_cache{};
    std::optional<std::uint32_t> m_active_target{};
    std::uint32_t m_next_id{1};
    std::uint32_t m_logical_w{};
    std::uint32_t m_logical_h{};
    bool m_running{false};
    bool m_vsync{false};

    int m_master_vol{80};
    int m_sfx_vol{100};
    int m_music_vol{70};
};

}  // namespace fnwf
