#pragma once

// EnginePS2 — concrete PS2 implementation of the Engine interface.
// Uses SDL 1.2 from ps2sdk-ports.
// Runs on the Emotion Engine (MIPS R5900) with 32MB RAM.

#include "engine/Engine.hpp"

#ifdef __PS2__
// PS2SDK: include only what we need — tamtypes.h 128-bit types break with -mgp32.
// libpad.h and sifrpc.h pull in their own type definitions.
#include <kernel.h>
#include <sifrpc.h>
#include <loadfile.h>
#include <libpad.h>
#include <audsrv.h>
#include <SDL.h>
#include <SDL_ttf.h>
#include <SDL_mixer.h>
#else
#include <SDL.h>
#include <SDL_ttf.h>
#include <SDL_mixer.h>
#endif

#include <unordered_map>
#include <vector>
#include <string>

namespace fnwf {

class EnginePS2 final : public Engine
{
public:
    EnginePS2() = default;
    ~EnginePS2() override;

    bool init(std::string_view title, std::uint32_t w, std::uint32_t h,
              bool fullscreen, bool vsync) override;
    void shutdown() override;

    std::vector<Event> poll_events() override;
    float ticks() const noexcept override;
    bool keeps_running() const noexcept override { return m_running; }
    void request_stop() noexcept override { m_running = false; }
    void present() override;

    void set_logical_size(std::uint32_t w, std::uint32_t h) override;
    void set_fullscreen(bool on) override;
    void set_vsync(bool on) override;
    void set_resolution(std::uint32_t w, std::uint32_t h) override;
    std::vector<std::array<std::int32_t, 3>> get_display_modes() override;

    void clear(std::uint8_t r, std::uint8_t g, std::uint8_t b, std::uint8_t a) override;
    void draw_rect(std::int32_t x, std::int32_t y, std::uint32_t w, std::uint32_t h,
                   std::uint8_t r, std::uint8_t g, std::uint8_t b, std::uint8_t a,
                   bool filled) override;
    void line(std::int32_t x1, std::int32_t y1, std::int32_t x2, std::int32_t y2,
              std::uint8_t r, std::uint8_t g, std::uint8_t b, std::uint8_t a) override;
    void circle(std::int32_t cx, std::int32_t cy, std::int32_t radius,
                std::uint8_t r, std::uint8_t g, std::uint8_t b, std::uint8_t a,
                bool filled) override;

    void draw_texture(const TextureHandle& tex, std::int32_t dx, std::int32_t dy,
                      std::uint32_t dw, std::uint32_t dh, std::int32_t sx, std::int32_t sy,
                      std::int32_t sw, std::int32_t sh,
                      std::optional<std::uint8_t> alpha) override;
    void draw_texture_rotated(const TextureHandle& tex, std::int32_t dx, std::int32_t dy,
                              std::uint32_t dw, std::uint32_t dh, float angle,
                              std::optional<std::uint8_t> alpha) override;

    bool draw_text(std::string_view text, std::int32_t x, std::int32_t y,
                   std::uint32_t font_size, std::uint8_t r, std::uint8_t g, std::uint8_t b,
                   std::uint8_t a, bool center, std::int32_t font_idx) override;
    bool draw_text_rotated(std::string_view text, std::int32_t x, std::int32_t y,
                           std::uint32_t font_size, float angle,
                           std::uint8_t r, std::uint8_t g, std::uint8_t b,
                           std::uint8_t a, bool center, std::int32_t font_idx) override;

    std::optional<TextureHandle> load_texture(std::string_view path) override;
    std::optional<TextureHandle> create_target(std::uint32_t w, std::uint32_t h) override;
    std::optional<SoundHandle> load_sound(std::string_view path) override;
    std::int64_t load_font(std::string_view path, std::uint16_t size) override;
    std::optional<std::array<std::int32_t, 2>> font_text_size(std::string_view text,
                                                              std::uint32_t font_idx) override;
    std::pair<std::uint32_t, std::uint32_t> texture_size(std::uint32_t id) noexcept override;

    void set_render_target(std::optional<TextureHandle> target) override;
    void reset_render_target() override;

    std::int32_t play_sound(const SoundHandle& snd, std::int32_t loops,
                            std::int32_t channel) override;
    void stop_channel(std::int32_t channel) override;
    void stop_all_sounds() override;

    std::pair<std::int32_t, std::int32_t> mouse_pos() override;

    void set_master_volume(int vol) override;
    void set_sfx_volume(int vol) override;
    void set_music_volume(int vol) override;

    void update_discord(std::string_view details, std::string_view state) override;

private:
    void blit_scaled(SDL_Surface* src, std::int32_t dx, std::int32_t dy,
                     std::uint32_t dw, std::uint32_t dh,
                     std::int32_t sx, std::int32_t sy,
                     std::int32_t sw, std::int32_t sh,
                     std::uint8_t alpha);

    SDL_Surface* m_screen{nullptr};
    SDL_Surface* m_target{nullptr};
    std::unordered_map<std::uint32_t, SDL_Surface*> m_textures{};
    std::unordered_map<std::uint32_t, Mix_Chunk*> m_chunks{};
    std::vector<TTF_Font*> m_fonts{};
    std::unordered_map<std::uint64_t, SDL_Surface*> m_text_cache{};
    std::uint32_t m_next_id{1};
    std::uint32_t m_logical_w{};
    std::uint32_t m_logical_h{};
    std::uint32_t m_physical_w{};
    std::uint32_t m_physical_h{};
    bool m_running{false};
    bool m_vsync{false};

    int m_master_vol{80};
    int m_sfx_vol{100};
    int m_music_vol{70};
};

}  // namespace fnwf
