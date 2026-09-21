#include "platform/ps2/EnginePS2.hpp"
#include "core/DrawUtils.hpp"
#include "game1/GameSettings.hpp"

#include <algorithm>
#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <string>

namespace fnwf {

// ── Helpers ──────────────────────────────────────────────────────────────────

namespace {

SDL_Color make_color(std::uint8_t r, std::uint8_t g, std::uint8_t b, std::uint8_t a) {
    SDL_Color c;
    c.r = r; c.g = g; c.b = b;
    c.unused = a;
    return c;
}

SDL_Surface* create_surface(std::uint32_t w, std::uint32_t h) {
    return SDL_CreateRGBSurface(SDL_SWSURFACE, static_cast<int>(w), static_cast<int>(h),
                                32, 0x00FF0000, 0x0000FF00, 0x000000FF, 0xFF000000);
}

}  // namespace

// ── Lifecycle ────────────────────────────────────────────────────────────────

EnginePS2::~EnginePS2() {
    shutdown();
}

bool EnginePS2::init(std::string_view /*title*/, std::uint32_t w, std::uint32_t h,
                     bool /*fullscreen*/, bool vsync) {
#ifdef __PS2__
    SifInitRpc(0);
#endif

    if (SDL_Init(SDL_INIT_VIDEO | SDL_INIT_AUDIO | SDL_INIT_TIMER) != 0) {
        return false;
    }
    if (TTF_Init() != 0) {
        return false;
    }
    if (Mix_OpenAudio(44100, MIX_DEFAULT_FORMAT, 2, 1024) != 0) {
        return false;
    }
    Mix_AllocateChannels(32);

    m_physical_w = 640;
    m_physical_h = 448;

    m_screen = SDL_SetVideoMode(static_cast<int>(m_physical_w),
                                static_cast<int>(m_physical_h),
                                32,
                                SDL_SWSURFACE | SDL_HWSURFACE);
    if (m_screen == nullptr) {
        return false;
    }

    SDL_WM_SetCaption("Five Nights With Friends", nullptr);

    m_logical_w = w;
    m_logical_h = h;
    m_running = true;
    m_vsync = vsync;

    return true;
}

void EnginePS2::shutdown() {
    for (auto& [id, surf] : m_textures) {
        if (surf) SDL_FreeSurface(surf);
    }
    m_textures.clear();

    for (auto& [h, surf] : m_text_cache) {
        if (surf) SDL_FreeSurface(surf);
    }
    m_text_cache.clear();

    for (auto* font : m_fonts) {
        if (font) TTF_CloseFont(font);
    }
    m_fonts.clear();

    for (auto& [id, chunk] : m_chunks) {
        if (chunk) Mix_FreeChunk(chunk);
    }
    m_chunks.clear();

    Mix_CloseAudio();
    TTF_Quit();

    m_screen = nullptr;
    SDL_Quit();
}

// ── Events & timing ──────────────────────────────────────────────────────────

std::vector<Event> EnginePS2::poll_events() {
    std::vector<Event> events;
    SDL_Event e{};

    while (SDL_PollEvent(&e)) {
        Event ev;
        switch (e.type) {
            case SDL_QUIT:
                ev.type = EventType::Quit;
                break;
            case SDL_KEYDOWN:
            case SDL_KEYUP:
                ev.type = (e.type == SDL_KEYDOWN) ? EventType::KeyDown : EventType::KeyUp;
                ev.key = static_cast<std::int32_t>(e.key.keysym.sym);
                ev.key_name = e.key.keysym.sym ? SDL_GetKeyName(e.key.keysym.sym) : "";
                ev.scan_name = "";
                break;
            case SDL_MOUSEBUTTONDOWN:
            case SDL_MOUSEBUTTONUP:
                ev.type = (e.type == SDL_MOUSEBUTTONDOWN) ? EventType::MouseButtonDown
                                                          : EventType::MouseButtonUp;
                ev.x = e.button.x;
                ev.y = e.button.y;
                break;
            case SDL_MOUSEMOTION:
                ev.type = EventType::MouseMotion;
                ev.x = e.motion.x;
                ev.y = e.motion.y;
                break;
            default:
                continue;
        }
        events.push_back(std::move(ev));
    }
    return events;
}

float EnginePS2::ticks() const noexcept {
    return static_cast<float>(SDL_GetTicks());
}

void EnginePS2::present() {
    SDL_Flip(m_screen);
}

// ── Window ───────────────────────────────────────────────────────────────────

void EnginePS2::set_logical_size(std::uint32_t w, std::uint32_t h) {
    m_logical_w = w;
    m_logical_h = h;
}

void EnginePS2::set_fullscreen(bool /*on*/) {}

void EnginePS2::set_vsync(bool on) {
    m_vsync = on;
}

void EnginePS2::set_resolution(std::uint32_t /*w*/, std::uint32_t /*h*/) {}

std::vector<std::array<std::int32_t, 3>> EnginePS2::get_display_modes() {
    return {{640, 448, 60}, {640, 480, 60}};
}

// ── Drawing primitives ───────────────────────────────────────────────────────

void EnginePS2::clear(std::uint8_t r, std::uint8_t g, std::uint8_t b, std::uint8_t /*a*/) {
    SDL_Surface* target = m_target ? m_target : m_screen;
    SDL_FillRect(target, nullptr, SDL_MapRGB(target->format, r, g, b));
}

void EnginePS2::draw_rect(std::int32_t x, std::int32_t y, std::uint32_t w, std::uint32_t h,
                           std::uint8_t r, std::uint8_t g, std::uint8_t b, std::uint8_t a,
                           bool filled) {
    SDL_Surface* target = m_target ? m_target : m_screen;
    SDL_Rect rect{static_cast<Sint16>(x), static_cast<Sint16>(y),
                  static_cast<Uint16>(w), static_cast<Uint16>(h)};

    if (filled) {
        if (a < 255) {
            SDL_Surface* tmp = create_surface(w, h);
            if (tmp) {
                SDL_FillRect(tmp, nullptr, SDL_MapRGBA(tmp->format, r, g, b, a));
                SDL_BlitSurface(tmp, nullptr, target, &rect);
                SDL_FreeSurface(tmp);
            }
        } else {
            SDL_FillRect(target, &rect, SDL_MapRGB(target->format, r, g, b));
        }
    } else {
        Uint32 color = SDL_MapRGB(target->format, r, g, b);
        SDL_Rect top{rect.x, rect.y, rect.w, 1};
        SDL_Rect bot{rect.x, static_cast<Sint16>(rect.y + rect.h - 1), rect.w, 1};
        SDL_Rect lft{rect.x, rect.y, 1, rect.h};
        SDL_Rect rgt{static_cast<Sint16>(rect.x + rect.w - 1), rect.y, 1, rect.h};
        SDL_FillRect(target, &top, color);
        SDL_FillRect(target, &bot, color);
        SDL_FillRect(target, &lft, color);
        SDL_FillRect(target, &rgt, color);
    }
}

void EnginePS2::line(std::int32_t x1, std::int32_t y1, std::int32_t x2, std::int32_t y2,
                      std::uint8_t r, std::uint8_t g, std::uint8_t b, std::uint8_t /*a*/) {
    SDL_Surface* target = m_target ? m_target : m_screen;
    Uint32 color = SDL_MapRGB(target->format, r, g, b);

    int dx = std::abs(x2 - x1);
    int dy = std::abs(y2 - y1);
    int sx = (x1 < x2) ? 1 : -1;
    int sy = (y1 < y2) ? 1 : -1;
    int err = dx - dy;

    while (true) {
        SDL_Rect pt{static_cast<Sint16>(x1), static_cast<Sint16>(y1), 1, 1};
        SDL_FillRect(target, &pt, color);
        if (x1 == x2 && y1 == y2) break;
        int e2 = 2 * err;
        if (e2 > -dy) { err -= dy; x1 += sx; }
        if (e2 < dx)  { err += dx; y1 += sy; }
    }
}

void EnginePS2::circle(std::int32_t cx, std::int32_t cy, std::int32_t radius,
                        std::uint8_t r, std::uint8_t g, std::uint8_t b, std::uint8_t /*a*/,
                        bool filled) {
    if (radius <= 0) return;
    SDL_Surface* target = m_target ? m_target : m_screen;
    Uint32 color = SDL_MapRGB(target->format, r, g, b);

    auto r2 = static_cast<int>(radius) * radius;
    for (int dy = -radius; dy <= radius; ++dy) {
        int dy2 = dy * dy;
        int diff = r2 - dy2;
        if (diff < 0) continue;
        int half = static_cast<int>(std::sqrt(static_cast<float>(diff)));
        int w = half * 2 + 1;
        if (w > 0) {
            SDL_Rect rect{static_cast<Sint16>(cx - half), static_cast<Sint16>(cy + dy),
                          static_cast<Uint16>(w), 1};
            if (filled) {
                SDL_FillRect(target, &rect, color);
            } else {
                SDL_Rect left{static_cast<Sint16>(cx - half), static_cast<Sint16>(cy + dy), 1, 1};
                SDL_Rect rght{static_cast<Sint16>(cx + half), static_cast<Sint16>(cy + dy), 1, 1};
                SDL_FillRect(target, &left, color);
                SDL_FillRect(target, &rght, color);
            }
        }
    }
}

// ── Texture blitting with scaling ────────────────────────────────────────────

void EnginePS2::blit_scaled(SDL_Surface* src, std::int32_t dx, std::int32_t dy,
                            std::uint32_t dw, std::uint32_t dh,
                            std::int32_t sx, std::int32_t sy,
                            std::int32_t sw, std::int32_t sh,
                            std::uint8_t alpha) {
    if (!src) return;

    SDL_Surface* target = m_target ? m_target : m_screen;

    if (alpha < 255) {
        SDL_SetAlpha(src, SDL_SRCALPHA | SDL_RLEACCEL, alpha);
    } else {
        SDL_SetAlpha(src, 0, 0);
    }

    SDL_Rect src_rect;
    if (sx >= 0 && sy >= 0 && sw >= 0 && sh >= 0) {
        src_rect = {static_cast<Sint16>(sx), static_cast<Sint16>(sy),
                    static_cast<Uint16>(sw), static_cast<Uint16>(sh)};
    } else {
        src_rect = {0, 0, static_cast<Uint16>(src->w), static_cast<Uint16>(src->h)};
    }

    SDL_Rect dst_rect{static_cast<Sint16>(dx), static_cast<Sint16>(dy),
                      static_cast<Uint16>(dw), static_cast<Uint16>(dh)};

    SDL_BlitSurface(src, &src_rect, target, &dst_rect);

    if (alpha < 255) {
        SDL_SetAlpha(src, 0, 0);
    }
}

// ── Textures ─────────────────────────────────────────────────────────────────

void EnginePS2::draw_texture(const TextureHandle& tex, std::int32_t dx, std::int32_t dy,
                              std::uint32_t dw, std::uint32_t dh,
                              std::int32_t sx, std::int32_t sy,
                              std::int32_t sw, std::int32_t sh,
                              std::optional<std::uint8_t> alpha) {
    auto it = m_textures.find(tex.id);
    if (it == m_textures.end()) return;

    Uint8 a = alpha.value_or(255);
    blit_scaled(it->second, dx, dy, dw, dh, sx, sy, sw, sh, a);
}

void EnginePS2::draw_texture_rotated(const TextureHandle& tex,
                                      std::int32_t dx, std::int32_t dy,
                                      std::uint32_t dw, std::uint32_t dh, float /*angle*/,
                                      std::optional<std::uint8_t> alpha) {
    draw_texture(tex, dx, dy, dw, dh, -1, -1, -1, -1, alpha);
}

// ── Text ─────────────────────────────────────────────────────────────────────

bool EnginePS2::draw_text(std::string_view text, std::int32_t x, std::int32_t y,
                           std::uint32_t font_size, std::uint8_t r, std::uint8_t g, std::uint8_t b,
                           std::uint8_t a, bool center, std::int32_t font_idx) {
    if (text.empty()) return true;

    std::int64_t fidx = font_idx;
    if (fidx < 0) {
        fidx = load_font(GameSettings::asset_path("font/font", ".ttf"),
                         static_cast<std::uint16_t>(font_size));
        if (fidx < 0) return true;
    }
    if (static_cast<std::size_t>(fidx) >= m_fonts.size()) return true;

    std::uint64_t h = 0xcbf29ce484222325ULL;
    for (unsigned char c : text) {
        h ^= c;
        h *= 0x100000001b3ULL;
    }
    h ^= (std::uint64_t(fidx) << 32) | (std::uint64_t(r) << 16) | (std::uint64_t(g) << 8) |
         std::uint64_t(b);
    h ^= std::uint64_t(a) << 24;

    auto it = m_text_cache.find(h);
    SDL_Surface* surf = nullptr;
    if (it == m_text_cache.end()) {
        if (m_text_cache.size() > 512) {
            for (auto& [k, s] : m_text_cache) {
                if (s) SDL_FreeSurface(s);
            }
            m_text_cache.clear();
        }
        TTF_Font* font = m_fonts[fidx];
        surf = TTF_RenderUTF8_Blended(font, std::string(text).c_str(), make_color(r, g, b, a));
        if (!surf) return true;
        m_text_cache.emplace(h, surf);
    } else {
        surf = it->second;
    }

    int tw = surf->w;
    int th = surf->h;
    int px = center ? (x - tw / 2) : x;
    int py = center ? (y - th / 2) : y;

    blit_scaled(surf, px, py, tw, th, -1, -1, -1, -1, 255);
    return true;
}

bool EnginePS2::draw_text_rotated(std::string_view text, std::int32_t x, std::int32_t y,
                                   std::uint32_t font_size, float /*angle*/,
                                   std::uint8_t r, std::uint8_t g, std::uint8_t b,
                                   std::uint8_t a, bool center, std::int32_t font_idx) {
    return draw_text(text, x, y, font_size, r, g, b, a, center, font_idx);
}

// ── Resources ────────────────────────────────────────────────────────────────

std::optional<TextureHandle> EnginePS2::load_texture(std::string_view path) {
    // SDL 1.2 on PS2: only BMP is guaranteed. PNG needs SDL_image which may not be available.
    SDL_Surface* surf = SDL_LoadBMP(std::string(path).c_str());
    if (!surf) return std::nullopt;

    SDL_Surface* converted = SDL_ConvertSurface(surf, m_screen->format, SDL_SWSURFACE);
    SDL_FreeSurface(surf);
    if (!converted) return std::nullopt;

    const std::uint32_t id = m_next_id++;
    m_textures[id] = converted;
    return TextureHandle{id};
}

std::optional<TextureHandle> EnginePS2::create_target(std::uint32_t w, std::uint32_t h) {
    SDL_Surface* surf = create_surface(w, h);
    if (!surf) return std::nullopt;

    const std::uint32_t id = m_next_id++;
    m_textures[id] = surf;
    return TextureHandle{id};
}

std::optional<SoundHandle> EnginePS2::load_sound(std::string_view path) {
    Mix_Chunk* chunk = Mix_LoadWAV(std::string(path).c_str());
    if (!chunk) return std::nullopt;

    const std::uint32_t id = m_next_id++;
    m_chunks[id] = chunk;
    return SoundHandle{id};
}

std::int64_t EnginePS2::load_font(std::string_view path, std::uint16_t size) {
    TTF_Font* font = TTF_OpenFont(std::string(path).c_str(), size);
    if (!font) return -1;

    const std::int64_t idx = static_cast<std::int64_t>(m_fonts.size());
    m_fonts.push_back(font);
    return idx;
}

std::optional<std::array<std::int32_t, 2>> EnginePS2::font_text_size(std::string_view text,
                                                                      std::uint32_t font_idx) {
    if (font_idx >= m_fonts.size()) return std::nullopt;
    int w{}, h{};
    if (TTF_SizeUTF8(m_fonts[font_idx], std::string(text).c_str(), &w, &h) != 0) {
        return std::nullopt;
    }
    return std::array<std::int32_t, 2>{w, h};
}

std::pair<std::uint32_t, std::uint32_t> EnginePS2::texture_size(std::uint32_t id) noexcept {
    auto it = m_textures.find(id);
    if (it == m_textures.end()) return {0, 0};
    return {static_cast<std::uint32_t>(it->second->w),
            static_cast<std::uint32_t>(it->second->h)};
}

// ── Render targets ───────────────────────────────────────────────────────────

void EnginePS2::set_render_target(std::optional<TextureHandle> target) {
    if (target.has_value()) {
        auto it = m_textures.find(target->id);
        if (it != m_textures.end()) {
            m_target = it->second;
        }
    } else {
        m_target = nullptr;
    }
}

void EnginePS2::reset_render_target() {
    m_target = nullptr;
}

// ── Sound ────────────────────────────────────────────────────────────────────

std::int32_t EnginePS2::play_sound(const SoundHandle& snd, std::int32_t loops,
                                    std::int32_t channel) {
    auto it = m_chunks.find(snd.id);
    if (it != m_chunks.end() && it->second) {
        Mix_PlayChannel(channel, it->second, loops);
    }
    return channel;
}

void EnginePS2::stop_channel(std::int32_t channel) {
    Mix_HaltChannel(channel);
}

void EnginePS2::stop_all_sounds() {
    Mix_HaltChannel(-1);
}

// ── Input ────────────────────────────────────────────────────────────────────

std::pair<std::int32_t, std::int32_t> EnginePS2::mouse_pos() {
    return {static_cast<std::int32_t>(m_logical_w / 2),
            static_cast<std::int32_t>(m_logical_h / 2)};
}

// ── Volume ───────────────────────────────────────────────────────────────────

void EnginePS2::set_master_volume(int vol) {
    m_master_vol = vol;
    int music_eff = (m_master_vol * m_music_vol * MIX_MAX_VOLUME) / 10000;
    int sfx_eff   = (m_master_vol * m_sfx_vol   * MIX_MAX_VOLUME) / 10000;
    Mix_VolumeMusic(music_eff);
    for (int ch = 0; ch < 16; ++ch)
        Mix_Volume(ch, sfx_eff);
}

void EnginePS2::set_sfx_volume(int vol) {
    m_sfx_vol = vol;
    int eff = (m_master_vol * m_sfx_vol * MIX_MAX_VOLUME) / 10000;
    for (int ch = 0; ch < 16; ++ch)
        Mix_Volume(ch, eff);
}

void EnginePS2::set_music_volume(int vol) {
    m_music_vol = vol;
    int eff = (m_master_vol * m_music_vol * MIX_MAX_VOLUME) / 10000;
    Mix_VolumeMusic(eff);
}

// ── Misc ─────────────────────────────────────────────────────────────────────

void EnginePS2::update_discord(std::string_view, std::string_view) {}

// ── Factory ──────────────────────────────────────────────────────────────────

Engine* create_engine() {
    return new EnginePS2();
}

void destroy_engine(Engine* e) {
    delete e;
}

}  // namespace fnwf
