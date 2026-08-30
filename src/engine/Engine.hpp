// Five Nights With Friends — engine (C++26, SDL2 + Lua).
// Style: braces on their own line (Allman), `auto foo() -> T` trailing returns,
// explicit Zig-flavoured allocator, smart pointers, `std::expected` results.
#pragma once

#include <SDL.h>
#include <SDL_ttf.h>
#include <SDL_image.h>
#include <SDL_mixer.h>
#include <lua.hpp>

#include <array>
#include <cstdint>
#include <expected>
#include <functional>
#include <memory>
#include <optional>
#include <span>
#include <string>
#include <string_view>
#include <unordered_map>
#include <vector>

#include "engine/Allocator.hpp"

namespace fnwf
{

// ---- SDL resources as smart pointers ------------------------------------
struct WindowDeleter
{
    auto operator()(SDL_Window* W) const noexcept -> void { SDL_DestroyWindow(W); }
};
struct RendererDeleter
{
    auto operator()(SDL_Renderer* R) const noexcept -> void { SDL_DestroyRenderer(R); }
};
struct TextureDeleter
{
    auto operator()(SDL_Texture* T) const noexcept -> void { SDL_DestroyTexture(T); }
};
struct SurfaceDeleter
{
    auto operator()(SDL_Surface* S) const noexcept -> void { SDL_FreeSurface(S); }
};
struct FontDeleter
{
    auto operator()(TTF_Font* F) const noexcept -> void { TTF_CloseFont(F); }
};
struct ChunkDeleter
{
    auto operator()(Mix_Chunk* C) const noexcept -> void { Mix_FreeChunk(C); }
};

using Window = std::shared_ptr<SDL_Window>;
using Renderer = std::shared_ptr<SDL_Renderer>;
using Tex = std::shared_ptr<SDL_Texture>;
using Font = std::shared_ptr<TTF_Font>;

// An event summarized for Lua (key = numeric SDL keycode, the game compares
// against numbers such as 13=Return, 32=Space, 27=Esc, 10737419xx=arrows).
struct Ev
{
    std::string type{};
    std::int32_t key{};
    std::string key_name{};
    std::string scan_name{};
    std::int32_t x{};
    std::int32_t y{};
};

struct TextureHandle
{
    std::uint32_t id{};
};

struct SoundHandle
{
    std::uint32_t id{};
};

void register_engine(lua_State* L);

class Engine
{
public:
    auto new_instance(std::string_view title, std::uint32_t w, std::uint32_t h, bool fullscreen, bool vsync) -> std::expected<bool, std::string>;
    void shutdown() noexcept;

    // frame lifecycle
    auto poll_events() -> std::vector<Ev>;
    auto ticks() const noexcept -> double;
    auto keeps_running() const noexcept -> bool { return m_running; }
    void request_stop() noexcept { m_running = false; }
    void present();

    void set_logical_size(std::uint32_t w, std::uint32_t h);
    void set_fullscreen(bool on);
    void set_vsync(bool on);
    void set_resolution(std::uint32_t w, std::uint32_t h);
    auto get_display_modes() -> std::vector<std::array<std::int32_t, 3>>;

    // primitives (render-target aware, like the Rust engine)
    void clear(std::uint8_t r, std::uint8_t g, std::uint8_t b, std::uint8_t a);
    void draw_rect(std::int32_t x, std::int32_t y, std::uint32_t w, std::uint32_t h, std::uint8_t r, std::uint8_t g, std::uint8_t b, std::uint8_t a, bool filled);
    void line(std::int32_t x1, std::int32_t y1, std::int32_t x2, std::int32_t y2, std::uint8_t r, std::uint8_t g, std::uint8_t b, std::uint8_t a);
    void circle(std::int32_t cx, std::int32_t cy, std::int32_t radius, std::uint8_t r, std::uint8_t g, std::uint8_t b, std::uint8_t a, bool filled);
    void draw_texture(const TextureHandle& tex, std::int32_t dx, std::int32_t dy, std::uint32_t dw, std::uint32_t dh,
                      std::optional<std::array<std::int32_t, 4>> src = std::nullopt,
                      std::optional<std::uint8_t> alpha = std::nullopt);
    auto draw_text(std::string_view text, std::int32_t x, std::int32_t y, SDL_Color color, std::uint8_t alpha, bool center, std::uint32_t font_idx) -> bool;

    auto load_texture(std::string_view path) -> std::optional<TextureHandle>;
    auto create_target(std::uint32_t w, std::uint32_t h) -> std::optional<TextureHandle>;
    auto load_sound(std::string_view path) -> std::optional<SoundHandle>;
    auto load_font(std::string_view path, std::uint16_t size) -> std::int64_t;
    auto font_text_size(std::string_view text, std::uint32_t font_idx) -> std::optional<std::array<std::int32_t, 2>>;
    auto texture_size(std::uint32_t id) noexcept -> std::pair<std::uint32_t, std::uint32_t>;

    void set_render_target(std::optional<TextureHandle> target);
    void reset_render_target();

    auto play_sound(const SoundHandle& snd, std::int32_t loops, std::int32_t channel) -> std::int32_t;
    void stop_channel(std::int32_t channel);
    void stop_all_sounds();
    auto mouse_pos() -> std::pair<std::int32_t, std::int32_t>;

    void update_discord(std::string_view details, std::string_view state);

    // scratch arena exposed to the binding (explicit allocator)
    Arena arena{1 << 20};

private:
    auto get_texture(std::uint32_t id) noexcept -> SDL_Texture*;

    Window m_window{};
    Renderer m_renderer{};
    std::vector<Font> m_fonts{};
    std::unordered_map<std::uint32_t, Tex> m_textures{};
    std::unordered_map<std::uint32_t, Mix_Chunk*> m_chunks{};
    std::unordered_map<std::uint64_t, Tex> m_text_cache{};
    std::optional<std::uint32_t> m_active_target{};
    std::uint32_t m_next_id{1};
    std::uint32_t m_logical_w{};
    std::uint32_t m_logical_h{};
    bool m_running{false};
};

} // namespace fnwf
