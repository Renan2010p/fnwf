#pragma once

// EnginePS2 — concrete PS2 implementation of the Engine interface.
// Uses SDL 1.2 from ps2sdk-ports.
// Runs on the Emotion Engine (MIPS R5900) with 32MB RAM.

#include "engine/Engine.hpp"

#ifdef __PS2__
// PS2SDK: include only what we need — tamtypes.h 128-bit types break with -mgp32.
// libpad.h and sifrpc.h pull in their own type definitions.
#include <kernel.h>
// ps2sdk moved DelayThread out of kernel.h into its own header; older
// releases still have it in kernel.h — include only if present.
#if defined(__has_include)
#  if __has_include(<delaythread.h>)
#    include <delaythread.h>
#  endif
#endif
#include <sifrpc.h>
#include <loadfile.h>
#include <libpad.h>
#include <audsrv.h>
#include <SDL.h>
#include <SDL_ttf.h>
#include <SDL_mixer.h>
#include <SDL_image.h>
#else
#include <SDL.h>
#include <SDL_ttf.h>
#include <SDL_mixer.h>
#include <SDL_image.h>
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

    // Recomputes m_scale/m_off_x/m_off_y (logical size → screen, letterboxed).
    void update_viewport();

    // Reads the DualShock every frame (libpad directly — SDL's joystick
    // driver hangs loading IOP modules under PCSX2's HLE) and appends
    // virtual mouse/keyboard events — the game was built for mouse +
    // keyboard. sdl_mouse_* report whether SDL already delivered real mouse
    // input this frame (USB mouse) so nothing gets applied twice.
    void poll_pad(std::vector<Event>& out, bool sdl_mouse_motion,
                  bool sdl_mouse_button);

    // Runs padInit / SifLoadModule / padPortOpen in a background thread
    // with a 1 s timeout so the game never freezes on a hung IOP bind.
    // Only meaningful on PS2 (guarded at the definition site).
    static void boot_pad_thread(EnginePS2 *eng, int sem_id);

    // Where draws go: active render target, else the backbuffer, else the screen.
    SDL_Surface* draw_target() const {
        return m_target != nullptr ? m_target : (m_backbuf != nullptr ? m_backbuf : m_screen);
    }

    // Logical (game) → physical (screen) coordinate mapping.
    std::int32_t map_x(std::int32_t v) const {
        return m_off_x + static_cast<std::int32_t>(static_cast<float>(v) * m_scale);
    }
    std::int32_t map_y(std::int32_t v) const {
        return m_off_y + static_cast<std::int32_t>(static_cast<float>(v) * m_scale);
    }

    SDL_Surface* m_screen{nullptr};
    // Offscreen buffer in the engine's canonical pixel format. All screen-space
    // drawing targets it; present() blits it onto m_screen (which may be in a
    // different format chosen by SDL's PS2 video driver).
    SDL_Surface* m_backbuf{nullptr};
    // 1x1 surface used purely as an SDL_PixelFormat template for conversions.
    SDL_Surface* m_tpl_alpha{nullptr};
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
    float m_scale{1.0f};
    std::int32_t m_off_x{0};
    std::int32_t m_off_y{0};
    bool m_running{false};
    bool m_vsync{false};
    bool m_ttf_ok{false};
    bool m_audio_ok{false};

    // D-pad → arrow-key autorepeat state (index 0=up 1=down 2=left 3=right).
    bool m_dpad_held[4]{};
    int m_dpad_wait[4]{};

    // PS2 pad → virtual mouse/keyboard (see poll_pad(); libpad directly).
    bool m_pad_ok{false};
    alignas(64) std::uint8_t m_pad_buf[256]{};  // padPortOpen DMA buffer
    std::uint32_t m_pad_prev{0};  // PAD_* mask held last frame (edge detect)
    std::int32_t m_mouse_x{0};    // logical cursor backing mouse_pos()
    std::int32_t m_mouse_y{0};

#ifdef __PS2__
    // Boot-thread state: padInit / SifLoadModule hang on some HLE setups, so
    // we run them in a separate thread with a 1s timeout — the game always
    // boots (gray splash = no pad) instead of freezing forever.
    s32 m_boot_thread_id{-1};
    s32 m_boot_sem_id{-1};
#endif

    int m_master_vol{80};
    int m_sfx_vol{100};
    int m_music_vol{70};
};

}  // namespace fnwf
