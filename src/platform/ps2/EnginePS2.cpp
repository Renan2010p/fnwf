#include "platform/ps2/EnginePS2.hpp"
#include "core/DrawUtils.hpp"
#include "game1/GameSettings.hpp"

#include <algorithm>
#include <cmath>
#include <cstddef>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <string>

// File device used for asset access. "host:" is the PCSX2 / ps2link host
// filesystem, which resolves relative paths against the ELF's directory
// (enable Settings > Emulation > Enable Host Filesystem in PCSX2).
// Override at build time for other media, e.g. -DFNWF_PS2_DEVICE='"mass:/"'.
#ifndef FNWF_PS2_DEVICE
#define FNWF_PS2_DEVICE "host:"
#endif

namespace fnwf {

// ── Helpers ──────────────────────────────────────────────────────────────────

namespace {

// Canonical pixel format used by every surface the engine creates:
//   32bpp, RGB in the low three bytes, optional alpha in the high byte.
// (Exactly the format SDL_ttf's blended renderer produces.)
constexpr Uint32 RMASK = 0x00FF0000u;
constexpr Uint32 GMASK = 0x0000FF00u;
constexpr Uint32 BMASK = 0x000000FFu;
constexpr Uint32 AMASK = 0xFF000000u;

SDL_Color make_color(std::uint8_t r, std::uint8_t g, std::uint8_t b, std::uint8_t a) {
    SDL_Color c;
    c.r = r; c.g = g; c.b = b;
    c.unused = a;
    return c;
}

SDL_Surface* make_surface(std::uint32_t w, std::uint32_t h, bool with_alpha) {
    return SDL_CreateRGBSurface(SDL_SWSURFACE, static_cast<int>(w), static_cast<int>(h),
                                32, RMASK, GMASK, BMASK, with_alpha ? AMASK : 0);
}

bool is_canonical32(const SDL_PixelFormat* f) {
    return f != nullptr && f->BitsPerPixel == 32 && f->Rmask == RMASK &&
           f->Gmask == GMASK && f->Bmask == BMASK;
}

// Prepend the PS2 file device to a path unless it already has one.
std::string platform_path(std::string_view p) {
    std::string s(p);
    if (s.find(':') != std::string::npos) return s;
    return std::string(FNWF_PS2_DEVICE) + s;
}

// Nearest-neighbour downscale into the canonical alpha format. Runs once at
// load time to cap texture size: the PS2 has 32MB RAM and mafia.png would
// otherwise occupy ~19MB at 32bpp (plus ~19MB more during conversion).
SDL_Surface* downscale_surface(SDL_Surface* src, int nw, int nh) {
    if (src == nullptr || nw < 1 || nh < 1) return nullptr;
    SDL_Surface* dst = make_surface(static_cast<std::uint32_t>(nw),
                                    static_cast<std::uint32_t>(nh), true);
    if (dst == nullptr) return nullptr;
    SDL_FillRect(dst, nullptr, 0);  // transparent black

    const bool src_has_alpha = src->format->Amask != 0;
    const int sbpp = src->format->BytesPerPixel;
    const std::int64_t inc_x = (static_cast<std::int64_t>(src->w) << 16) / nw;

    const bool lock_s = SDL_MUSTLOCK(src) != 0;
    const bool lock_d = SDL_MUSTLOCK(dst) != 0;
    if (lock_s && SDL_LockSurface(src) != 0) {
        SDL_FreeSurface(dst);
        return nullptr;
    }
    if (lock_d && SDL_LockSurface(dst) != 0) {
        if (lock_s) SDL_UnlockSurface(src);
        SDL_FreeSurface(dst);
        return nullptr;
    }

    for (int j = 0; j < nh; ++j) {
        const int v = static_cast<int>(static_cast<std::int64_t>(j) * src->h / nh);
        const Uint8* srow = static_cast<const Uint8*>(src->pixels) +
                            static_cast<std::size_t>(v) * src->pitch;
        Uint32* drow = reinterpret_cast<Uint32*>(
            static_cast<Uint8*>(dst->pixels) + static_cast<std::size_t>(j) * dst->pitch);
        std::int64_t u = 0;
        for (int i = 0; i < nw; ++i, u += inc_x) {
            const Uint8* sp = srow + static_cast<std::size_t>(u >> 16) * sbpp;
            Uint32 px = 0;
            switch (sbpp) {
                case 1: px = *sp; break;
                case 2: px = *reinterpret_cast<const Uint16*>(sp); break;
                case 3: px = static_cast<Uint32>(sp[0]) | (static_cast<Uint32>(sp[1]) << 8) |
                            (static_cast<Uint32>(sp[2]) << 16); break;
                default: px = *reinterpret_cast<const Uint32*>(sp); break;
            }
            Uint8 r = 0, g = 0, b = 0, a = 0;
            SDL_GetRGBA(px, src->format, &r, &g, &b, &a);
            if (!src_has_alpha) a = 255;   // SDL_GetRGBA reports 0 without Amask
            if (a == 0) continue;          // dst is already transparent black
            drow[i] = SDL_MapRGBA(dst->format, r, g, b, a);
        }
    }

    if (lock_s) SDL_UnlockSurface(src);
    if (lock_d) SDL_UnlockSurface(dst);
    return dst;
}

// Make every pixel fully opaque. Needed for sources without an alpha channel,
// whose alpha bytes may be left at 0 by format conversion.
void force_opaque_pixels(SDL_Surface* s) {
    if (s == nullptr || !is_canonical32(s->format) || s->format->Amask != AMASK) return;
    const bool locked = SDL_MUSTLOCK(s) != 0;
    if (locked && SDL_LockSurface(s) != 0) return;
    for (int y = 0; y < s->h; ++y) {
        Uint32* row = reinterpret_cast<Uint32*>(static_cast<Uint8*>(s->pixels) +
                                                static_cast<std::size_t>(y) * s->pitch);
        for (int x = 0; x < s->w; ++x) row[x] |= AMASK;
    }
    if (locked) SDL_UnlockSurface(s);
}

}  // namespace

// ── Viewport (logical size → screen, letterboxed) ────────────────────────────

void EnginePS2::update_viewport() {
    if (m_screen == nullptr || m_logical_w == 0 || m_logical_h == 0) {
        m_scale = 1.0f;
        m_off_x = 0;
        m_off_y = 0;
        return;
    }
    const float sx = static_cast<float>(m_screen->w) / static_cast<float>(m_logical_w);
    const float sy = static_cast<float>(m_screen->h) / static_cast<float>(m_logical_h);
    m_scale = std::min(sx, sy);
    m_off_x = static_cast<std::int32_t>(
        (static_cast<float>(m_screen->w) - static_cast<float>(m_logical_w) * m_scale) * 0.5f);
    m_off_y = static_cast<std::int32_t>(
        (static_cast<float>(m_screen->h) - static_cast<float>(m_logical_h) * m_scale) * 0.5f);
    if (m_off_x < 0) m_off_x = 0;
    if (m_off_y < 0) m_off_y = 0;
}

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

    // All screen-space drawing happens on the backbuffer (canonical format);
    // present() scales nothing — coordinates are mapped at draw time instead.
    m_backbuf = make_surface(m_physical_w, m_physical_h, false);
    m_tpl_alpha = make_surface(1, 1, true);
    update_viewport();

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

    if (m_backbuf) {
        SDL_FreeSurface(m_backbuf);
        m_backbuf = nullptr;
    }
    if (m_tpl_alpha) {
        SDL_FreeSurface(m_tpl_alpha);
        m_tpl_alpha = nullptr;
    }

    Mix_CloseAudio();
    TTF_Quit();

    m_screen = nullptr;
    SDL_Quit();
}

// ── Events & timing ──────────────────────────────────────────────────────────

std::vector<Event> EnginePS2::poll_events() {
    std::vector<Event> events;
    SDL_Event e{};

    // SDL mouse events arrive in physical pixels; the game speaks logical ones.
    const float s = (m_scale > 0.0f) ? m_scale : 1.0f;
    auto to_lx = [this, s](std::int32_t v) {
        return static_cast<std::int32_t>((static_cast<float>(v - m_off_x)) / s);
    };
    auto to_ly = [this, s](std::int32_t v) {
        return static_cast<std::int32_t>((static_cast<float>(v - m_off_y)) / s);
    };

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
                ev.x = to_lx(e.button.x);
                ev.y = to_ly(e.button.y);
                break;
            case SDL_MOUSEMOTION:
                ev.type = EventType::MouseMotion;
                ev.x = to_lx(e.motion.x);
                ev.y = to_ly(e.motion.y);
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
    if (m_screen == nullptr) return;
    if (m_backbuf != nullptr) {
        // Formats may differ between the backbuffer and SDL's video surface —
        // SDL_BlitSurface converts (this is the classic SDL 1.2 cross-format blit).
        SDL_BlitSurface(m_backbuf, nullptr, m_screen, nullptr);
    }
    SDL_Flip(m_screen);
}

// ── Window ───────────────────────────────────────────────────────────────────

void EnginePS2::set_logical_size(std::uint32_t w, std::uint32_t h) {
    m_logical_w = w;
    m_logical_h = h;
    update_viewport();
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
    SDL_Surface* target = draw_target();
    if (target == nullptr) return;
    SDL_FillRect(target, nullptr, SDL_MapRGB(target->format, r, g, b));
}

void EnginePS2::draw_rect(std::int32_t x, std::int32_t y, std::uint32_t w, std::uint32_t h,
                           std::uint8_t r, std::uint8_t g, std::uint8_t b, std::uint8_t a,
                           bool filled) {
    SDL_Surface* target = draw_target();
    if (target == nullptr) return;

    Sint16 rx = static_cast<Sint16>(x);
    Sint16 ry = static_cast<Sint16>(y);
    Uint16 rw = static_cast<Uint16>(w);
    Uint16 rh = static_cast<Uint16>(h);

    if (m_target == nullptr) {
        // Logical → physical mapping (render targets are logical-sized).
        const std::int32_t x0 = map_x(x);
        const std::int32_t y0 = map_y(y);
        const std::int32_t x1 = map_x(x + static_cast<std::int32_t>(w));
        const std::int32_t y1 = map_y(y + static_cast<std::int32_t>(h));
        rx = static_cast<Sint16>(x0);
        ry = static_cast<Sint16>(y0);
        rw = static_cast<Uint16>(std::max<std::int32_t>(1, x1 - x0));
        rh = static_cast<Uint16>(std::max<std::int32_t>(1, y1 - y0));
    }

    SDL_Rect rect{rx, ry, rw, rh};

    if (filled) {
        if (a < 255) {
            SDL_Surface* tmp = make_surface(rw, rh, true);
            if (tmp) {
                // Enable per-pixel alpha so MapRGBA's alpha actually applies.
                SDL_SetAlpha(tmp, SDL_SRCALPHA, 255);
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
    SDL_Surface* target = draw_target();
    if (target == nullptr) return;

    if (m_target == nullptr) {
        x1 = map_x(x1); y1 = map_y(y1);
        x2 = map_x(x2); y2 = map_y(y2);
    }

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
    SDL_Surface* target = draw_target();
    if (target == nullptr) return;

    if (m_target == nullptr) {
        cx = map_x(cx);
        cy = map_y(cy);
        radius = std::max(1, static_cast<std::int32_t>(static_cast<float>(radius) * m_scale));
    }

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
//
// SDL 1.2's SDL_BlitSurface does NOT scale (dst w/h are outputs only), so the
// scaled case is implemented manually: nearest-neighbour sampling with
// straight-alpha blending on the canonical 32bpp format.

void EnginePS2::blit_scaled(SDL_Surface* src, std::int32_t dx, std::int32_t dy,
                            std::uint32_t dw, std::uint32_t dh,
                            std::int32_t sx, std::int32_t sy,
                            std::int32_t sw, std::int32_t sh,
                            std::uint8_t alpha) {
    if (src == nullptr || dw == 0 || dh == 0) return;
    SDL_Surface* dst = draw_target();
    if (dst == nullptr) return;

    // Source sub-rectangle, clamped to the surface.
    std::int32_t su = 0, sv = 0, swd = src->w, sht = src->h;
    if (sx >= 0 && sy >= 0 && sw > 0 && sh > 0) {
        su = sx;
        sv = sy;
        swd = sw;
        sht = sh;
        if (su >= src->w || sv >= src->h) return;
        if (su + swd > src->w) swd = src->w - su;
        if (sv + sht > src->h) sht = src->h - sv;
    }
    if (swd <= 0 || sht <= 0) return;

    // Destination rectangle; map logical → physical when drawing to the screen.
    std::int32_t x0 = dx;
    std::int32_t y0 = dy;
    std::int32_t w0 = static_cast<std::int32_t>(dw);
    std::int32_t h0 = static_cast<std::int32_t>(dh);
    if (m_target == nullptr) {
        x0 = map_x(dx);
        y0 = map_y(dy);
        w0 = map_x(dx + static_cast<std::int32_t>(dw)) - x0;
        h0 = map_y(dy + static_cast<std::int32_t>(dh)) - y0;
        if (w0 < 1) w0 = 1;
        if (h0 < 1) h0 = 1;
    }

    // Fast path: 1:1 — SDL's own blitter already handles cross-format blits
    // and per-pixel alpha. (Global alpha < 255 must go through our loop:
    // SDL 1.2 ignores SDL_SetAlpha's value on per-pixel-alpha surfaces.)
    if (alpha == 255 && w0 == swd && h0 == sht) {
        SDL_Rect s{static_cast<Sint16>(su), static_cast<Sint16>(sv),
                   static_cast<Uint16>(swd), static_cast<Uint16>(sht)};
        SDL_Rect d{static_cast<Sint16>(x0), static_cast<Sint16>(y0), 0, 0};
        SDL_BlitSurface(src, &s, dst, &d);
        return;
    }

    // Degraded path: unexpected format — draw unscaled rather than drop the draw.
    if (!is_canonical32(src->format) || !is_canonical32(dst->format)) {
        if (alpha < 255) SDL_SetAlpha(src, SDL_SRCALPHA, alpha);
        SDL_Rect s{static_cast<Sint16>(su), static_cast<Sint16>(sv),
                   static_cast<Uint16>(swd), static_cast<Uint16>(sht)};
        SDL_Rect d{static_cast<Sint16>(x0), static_cast<Sint16>(y0), 0, 0};
        SDL_BlitSurface(src, &s, dst, &d);
        if (alpha < 255) SDL_SetAlpha(src, SDL_SRCALPHA, 255);
        return;
    }

    // Clip against the destination; the sample start shifts accordingly.
    const std::int32_t ix0 = std::max<std::int32_t>(0, x0);
    const std::int32_t iy0 = std::max<std::int32_t>(0, y0);
    const std::int32_t ix1 = std::min<std::int32_t>(dst->w, x0 + w0);
    const std::int32_t iy1 = std::min<std::int32_t>(dst->h, y0 + h0);
    if (ix0 >= ix1 || iy0 >= iy1) return;

    const std::int64_t inc_x = (static_cast<std::int64_t>(swd) << 16) / w0;
    const std::int64_t inc_y = (static_cast<std::int64_t>(sht) << 16) / h0;
    const std::int64_t u0 = (static_cast<std::int64_t>(ix0 - x0) *
                             (static_cast<std::int64_t>(swd) << 16)) / w0;
    std::int64_t v_acc = (static_cast<std::int64_t>(iy0 - y0) *
                          (static_cast<std::int64_t>(sht) << 16)) / h0;

    const bool lock_s = SDL_MUSTLOCK(src) != 0;
    const bool lock_d = SDL_MUSTLOCK(dst) != 0;
    if (lock_s && SDL_LockSurface(src) != 0) return;
    if (lock_d && SDL_LockSurface(dst) != 0) {
        if (lock_s) SDL_UnlockSurface(src);
        return;
    }

    const Uint32 sam = src->format->Amask;
    const unsigned sash = src->format->Ashift;
    const Uint32 dam = dst->format->Amask;
    const unsigned dash = dst->format->Ashift;

    for (std::int32_t y = iy0; y < iy1; ++y, v_acc += inc_y) {
        const std::int32_t v = sv + static_cast<std::int32_t>(v_acc >> 16);
        const Uint32* srow = reinterpret_cast<const Uint32*>(
            static_cast<const Uint8*>(src->pixels) + static_cast<std::size_t>(v) * src->pitch);
        Uint32* drow = reinterpret_cast<Uint32*>(
            static_cast<Uint8*>(dst->pixels) + static_cast<std::size_t>(y) * dst->pitch);
        std::int64_t u = u0;
        for (std::int32_t x = ix0; x < ix1; ++x, u += inc_x) {
            Uint32 pix = srow[static_cast<std::size_t>(u >> 16)];
            Uint32 pa = 255;
            if (sam != 0) pa = (pix & sam) >> sash;
            if (alpha != 255) pa = (pa * alpha) / 255;
            if (pa == 0) continue;
            if (pa >= 255) {
                drow[x] = pix;
                continue;
            }
            const Uint32 d = drow[x];
            const Uint32 inv = 255 - pa;
            const Uint32 nr = ((((pix >> 16) & 0xFFu) * pa) + (((d >> 16) & 0xFFu) * inv)) / 255;
            const Uint32 ng = ((((pix >> 8) & 0xFFu) * pa) + (((d >> 8) & 0xFFu) * inv)) / 255;
            const Uint32 nb = (((pix & 0xFFu) * pa) + ((d & 0xFFu) * inv)) / 255;
            Uint32 out = (nr << 16) | (ng << 8) | nb;
            if (dam != 0) {
                const Uint32 da = (d & dam) >> dash;
                out |= ((pa + (da * (255 - pa)) / 255) << dash) & dam;
            }
            drow[x] = out;
        }
    }

    if (lock_s) SDL_UnlockSurface(src);
    if (lock_d) SDL_UnlockSurface(dst);
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
        // SDL_ttf already renders in the canonical alpha format; convert only
        // if that ever changes, and make sure per-pixel alpha is enabled.
        if (!(is_canonical32(surf->format) && surf->format->Amask == AMASK) &&
            m_tpl_alpha != nullptr) {
            SDL_Surface* cv = SDL_ConvertSurface(surf, m_tpl_alpha->format, SDL_SWSURFACE);
            SDL_FreeSurface(surf);
            surf = cv;
            if (!surf) return true;
        }
        if (surf->format->Amask != 0) SDL_SetAlpha(surf, SDL_SRCALPHA, 255);
        m_text_cache.emplace(h, surf);
    } else {
        surf = it->second;
    }

    int tw = surf->w;
    int th = surf->h;
    int px = center ? (x - tw / 2) : x;
    int py = center ? (y - th / 2) : y;

    // Global alpha is applied during the blit (SDL_ttf ignores color alpha).
    blit_scaled(surf, px, py, static_cast<std::uint32_t>(tw),
                static_cast<std::uint32_t>(th), -1, -1, -1, -1, a);
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
    const std::string p = platform_path(path);

    // SDL_image reads PNG (our assets are all .png); BMP is the fallback.
    SDL_Surface* surf = IMG_Load(p.c_str());
    if (surf == nullptr) surf = SDL_LoadBMP(p.c_str());
    if (surf == nullptr) return std::nullopt;

    // Sources without an alpha channel must end up fully opaque.
    const bool force_opaque = (surf->format->Amask == 0);

    SDL_Surface* converted = nullptr;

    // PS2 has 32MB RAM — cap texture dimensions before converting. mafia.png
    // is 2405x1991: ~19MB decoded plus ~19MB more if converted at full size.
    constexpr int MAX_DIM = 768;
    if (surf->w > MAX_DIM || surf->h > MAX_DIM) {
        const float f = std::min(static_cast<float>(MAX_DIM) / static_cast<float>(surf->w),
                                 static_cast<float>(MAX_DIM) / static_cast<float>(surf->h));
        const int nw = std::max(1, static_cast<int>(static_cast<float>(surf->w) * f));
        const int nh = std::max(1, static_cast<int>(static_cast<float>(surf->h) * f));
        converted = downscale_surface(surf, nw, nh);
        SDL_FreeSurface(surf);
        if (converted == nullptr) return std::nullopt;
    } else if (is_canonical32(surf->format) && surf->format->Amask == AMASK) {
        converted = surf;  // already canonical
    } else if (m_tpl_alpha != nullptr) {
        converted = SDL_ConvertSurface(surf, m_tpl_alpha->format, SDL_SWSURFACE);
        SDL_FreeSurface(surf);
        if (converted == nullptr) return std::nullopt;
    } else {
        SDL_FreeSurface(surf);
        return std::nullopt;
    }

    if (force_opaque) force_opaque_pixels(converted);
    if (converted->format->Amask != 0) SDL_SetAlpha(converted, SDL_SRCALPHA, 255);

    const std::uint32_t id = m_next_id++;
    m_textures[id] = converted;
    return TextureHandle{id};
}

std::optional<TextureHandle> EnginePS2::create_target(std::uint32_t w, std::uint32_t h) {
    // Render targets are opaque canonical surfaces in logical coordinates.
    SDL_Surface* surf = make_surface(w, h, false);
    if (!surf) return std::nullopt;

    const std::uint32_t id = m_next_id++;
    m_textures[id] = surf;
    return TextureHandle{id};
}

std::optional<SoundHandle> EnginePS2::load_sound(std::string_view path) {
    Mix_Chunk* chunk = Mix_LoadWAV(platform_path(path).c_str());
    if (!chunk) return std::nullopt;

    const std::uint32_t id = m_next_id++;
    m_chunks[id] = chunk;
    return SoundHandle{id};
}

std::int64_t EnginePS2::load_font(std::string_view path, std::uint16_t size) {
    TTF_Font* font = TTF_OpenFont(platform_path(path).c_str(), size);
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
