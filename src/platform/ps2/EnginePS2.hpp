#pragma once

// EnginePS2 — concrete PS2 implementation of the Engine interface.
//
// Hybrid backend: SDL is used only for timers, image loading (SDL_image) and
// text rasterisation (SDL_ttf); the DualShock is read through libpad. Every
// pixel that reaches the TV is drawn by gsKit on the GS (Graphics Synthesizer)
// — no SDL video, no software framebuffer blits.

#include "engine/Engine.hpp"

#ifdef __PS2__
// PS2SDK: include only what we need — tamtypes.h 128-bit types break with
// -mgp32 (a compat header shadows it for the toolchain).
#include <kernel.h>
#if defined(__has_include)
#  if __has_include(<delaythread.h>)
#    include <delaythread.h>
#  endif
#endif
#include <sifrpc.h>
#include <loadfile.h>
#include <libpad.h>
#include <audsrv.h>
#include <gsKit.h>
#include <dmaKit.h>
#else
#error "EnginePS2 is only built for the PS2 target"
#endif

#include <SDL.h>
#include <SDL_ttf.h>
#include <SDL_mixer.h>
#include <SDL_image.h>

#include <cstdint>
#include <string>
#include <unordered_map>
#include <vector>

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

    // The GS has no cheap per-slice cos(theta) warp, and only 4MB of VRAM, so
    // the office is drawn flat and effects go straight to the screen.
    bool supports_cylindrical_office() const override { return false; }
    bool supports_offscreen_targets() const override { return false; }
    void set_draw_offset(std::int32_t dx, std::int32_t dy) override {
        m_user_dx = dx;
        m_user_dy = dy;
    }

private:
    // A texture living in gsKit's VRAM pool. Mem is the CPU copy kept for
    // (re)uploads by the texture manager; Vram is owned by the manager.
    struct GsTex
    {
        GSTEXTURE tex{};
        bool valid{false};
    };

    GsTex* find_tex(std::uint32_t id);
    void free_tex(GsTex& t);

    // Converts a canonical SDL surface (32bpp) into a gsKit CT32 texture
    // (bytes R,G,B,A with gsKit's alpha convention) and registers it.
    GsTex& make_tex_from_surface(SDL_Surface* surf);

    // Common textured-sprite draw: maps logical coords and blends.
    void blit_tex(GsTex& t, std::int32_t dx, std::int32_t dy, std::uint32_t dw,
                  std::uint32_t dh, std::int32_t sx, std::int32_t sy, std::int32_t sw,
                  std::int32_t sh, std::uint8_t alpha);
    void quad_tex(GsTex& t, float x0, float y0, float x1, float y1, float x2, float y2,
                  float x3, float y3, std::uint8_t alpha);

    // Recomputes m_scale/m_off_x/m_off_y (logical size → GS screen, letterboxed).
    void update_viewport();

    // sdl_mouse_* report whether SDL already delivered real mouse input this
    // frame (USB mouse) so nothing gets applied twice.
    void poll_pad(std::vector<Event>& out, bool sdl_mouse_motion, bool sdl_mouse_button);

    static void boot_pad_thread(EnginePS2* eng, int sem_id);

    // Logical (game) → physical (GS) coordinate mapping.
    std::int32_t map_x(std::int32_t v) const {
        return m_off_x + m_user_dx +
               static_cast<std::int32_t>(static_cast<float>(v) * m_scale);
    }
    std::int32_t map_y(std::int32_t v) const {
        return m_off_y + m_user_dy +
               static_cast<std::int32_t>(static_cast<float>(v) * m_scale);
    }

    GSGLOBAL* m_gs{nullptr};
    std::unordered_map<std::uint32_t, GsTex> m_textures{};
    std::unordered_map<std::uint64_t, GsTex> m_text_cache{};
    std::vector<TTF_Font*> m_fonts{};
    std::unordered_map<std::uint32_t, Mix_Chunk*> m_chunks{};
    std::uint32_t m_next_id{1};
    std::uint32_t m_logical_w{};
    std::uint32_t m_logical_h{};
    float m_scale{1.0f};
    std::int32_t m_off_x{0};
    std::int32_t m_off_y{0};
    std::int32_t m_user_dx{0};
    std::int32_t m_user_dy{0};
    bool m_running{false};
    bool m_vsync{false};
    bool m_ttf_ok{false};
    bool m_audio_ok{false};

    // D-pad → arrow-key autorepeat state (index 0=up 1=down 2=left 3=right).
    bool m_dpad_held[4]{};
    int m_dpad_wait[4]{};

    // PS2 pad → virtual mouse/keyboard (see poll_pad(); libpad directly).
    bool m_pad_ok{false};
    alignas(64) std::uint8_t m_pad_buf[256]{};
    std::uint32_t m_pad_prev{0};
    std::int32_t m_mouse_x{0};
    std::int32_t m_mouse_y{0};

    // Boot-thread state: padInit / SifLoadModule hang on some HLE setups.
    s32 m_boot_thread_id{-1};
    s32 m_boot_sem_id{-1};

    int m_master_vol{80};
    int m_sfx_vol{100};
    int m_music_vol{70};
};

}  // namespace fnwf
