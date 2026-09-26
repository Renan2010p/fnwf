// EnginePS2 — SDL (timers/loading/text) + gsKit (all rendering on the GS).
//
// The game's Engine API is a 2D immediate-mode API; every primitive here maps
// to a gsKit primitive, every texture to a gsKit VRAM texture. There is no
// software framebuffer and no SDL video surface: the GS consumes the prims
// directly, which is what gets the PS2 off the EE-bound software rasteriser.

#include "platform/ps2/EnginePS2.hpp"
#include "game1/GameSettings.hpp"

#include <algorithm>
#include <cmath>
#include <cstddef>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <string>
#include <unistd.h>

#include <malloc.h>

// File device used for asset access. "host:" is the PCSX2 / ps2link host
// filesystem (enable Settings > Emulation > Enable Host Filesystem). Override
// at build time for other media, e.g. -DFNWF_PS2_DEVICE='"mass:/"'.
#ifndef FNWF_PS2_DEVICE
#define FNWF_PS2_DEVICE "host:/"
#endif

namespace fnwf {

// ── Small helpers ────────────────────────────────────────────────────────────

namespace {


// gsKit's vertex colours use 0x80 for 1.0 (so alpha 255 -> 0x80). Texture
// alpha is stored directly as 0..255 (0 transparent, 255 opaque); blending
// with PABE=0 uses it. col_rgbaq() is for solid prims, tex_rgbaq() scales a
// textured sprite's alpha by a global 0..255 value.
inline std::uint8_t vtx_alpha(std::uint8_t a8) {
    int v = (static_cast<int>(a8) * 128) / 255;
    if (v > 128) v = 128;
    return static_cast<std::uint8_t>(v);
}

inline u64 col_rgbaq(std::uint8_t r, std::uint8_t g, std::uint8_t b, std::uint8_t a8) {
    return GS_SETREG_RGBAQ(r, g, b, vtx_alpha(a8), 0x00);
}
inline u64 tex_rgbaq(std::uint8_t a8) {
    const std::uint8_t a = vtx_alpha(a8);
    return GS_SETREG_RGBAQ(0x80, 0x80, 0x80, a, 0x00);
}

// Prepends a file device to a path unless it already has one. Tries a few
// media (CD, USB, host) and the uppercase ISO9660 spelling.
std::string platform_path(std::string_view p) {
    std::string s(p);
    if (s.find(':') != std::string::npos) return s;

    static const char* s_paths[] = {
        "cdrom:/", "cdrom0:/", "usbmass:/fnwf/", "mass:/fnwf/", "host:/fnwf/", "host:/",
        nullptr};

    for (int i = 0; s_paths[i] != nullptr; ++i) {
        std::string test = std::string(s_paths[i]) + s;
        FILE* f = fopen(test.c_str(), "rb");
        if (f != nullptr) { fclose(f); return test; }
    }

    std::string upper = s;
    std::transform(upper.begin(), upper.end(), upper.begin(), ::toupper);
    for (int i = 0; s_paths[i] != nullptr; ++i) {
        std::string test = std::string(s_paths[i]) + upper;
        FILE* f = fopen(test.c_str(), "rb");
        if (f != nullptr) { fclose(f); return test; }
    }
    return std::string("cdrom:/") + s;
}

// Nearest-neighbour downscale of a 32bpp surface (PS2 RAM is only 32MB and
// VRAM even smaller, so 2405x1991 source art must be capped).
SDL_Surface* downscale_surface(SDL_Surface* src, int nw, int nh) {
    if (src == nullptr || nw < 1 || nh < 1) return nullptr;
    SDL_Surface* dst = SDL_CreateRGBSurface(SDL_SWSURFACE, nw, nh, 32,
                                            0x00FF0000u, 0x0000FF00u, 0x000000FFu, 0u);
    if (dst == nullptr) return nullptr;
    SDL_FillRect(dst, nullptr, 0);

    const int sbpp = src->format->BytesPerPixel;
    const std::int64_t inc_x = (static_cast<std::int64_t>(src->w) << 16) / nw;
    const bool lock_s = SDL_MUSTLOCK(src) != 0;
    const bool lock_d = SDL_MUSTLOCK(dst) != 0;
    if (lock_s && SDL_LockSurface(src) != 0) { SDL_FreeSurface(dst); return nullptr; }
    if (lock_d && SDL_LockSurface(dst) != 0) {
        if (lock_s) SDL_UnlockSurface(src);
        SDL_FreeSurface(dst);
        return nullptr;
    }

    for (int j = 0; j < nh; ++j) {
        const int v = static_cast<int>(static_cast<std::int64_t>(j) * src->h / nh);
        const Uint8* srow = static_cast<const Uint8*>(src->pixels) +
                            static_cast<std::size_t>(v) * src->pitch;
        Uint8* drow = static_cast<Uint8*>(dst->pixels) + static_cast<std::size_t>(j) * dst->pitch;
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
            if (src->format->Amask == 0) a = 255;
            Uint8* dp = drow + static_cast<std::size_t>(i) * 4;
            dp[0] = b; dp[1] = g; dp[2] = r;
            dp[3] = a;
        }
    }

    if (lock_s) SDL_UnlockSurface(src);
    if (lock_d) SDL_UnlockSurface(dst);
    return dst;
}

// Fills a gsKit CT32 texture from an SDL surface. gsKit wants bytes R,G,B,A
// with the alpha stored as-is (0 transparent, 255 opaque).
void fill_ct32(GSTEXTURE& t, SDL_Surface* s) {
    std::memset(&t, 0, sizeof(t));
    t.Width = static_cast<u32>(s->w);
    t.Height = static_cast<u32>(s->h);
    t.PSM = GS_PSM_CT32;
    t.Filter = GS_FILTER_NEAREST;
    const int bytes = s->w * s->h * 4;
    t.Mem = reinterpret_cast<u32*>(memalign(128, static_cast<std::size_t>(bytes)));
    if (t.Mem == nullptr) return;

    const bool has_alpha = s->format->Amask != 0;
    const bool locked = SDL_MUSTLOCK(s) != 0;
    if (locked) SDL_LockSurface(s);
    Uint8* dst = reinterpret_cast<Uint8*>(t.Mem);
    for (int y = 0; y < s->h; ++y) {
        const Uint8* row = static_cast<const Uint8*>(s->pixels) +
                           static_cast<std::size_t>(y) * s->pitch;
        for (int x = 0; x < s->w; ++x) {
            Uint32 px = 0;
            switch (s->format->BytesPerPixel) {
                case 1: px = row[x]; break;
                case 2: px = *reinterpret_cast<const Uint16*>(row + x * 2); break;
                case 3: px = static_cast<Uint32>(row[x * 3]) |
                            (static_cast<Uint32>(row[x * 3 + 1]) << 8) |
                            (static_cast<Uint32>(row[x * 3 + 2]) << 16); break;
                default: px = *reinterpret_cast<const Uint32*>(row + x * 4); break;
            }
            Uint8 r = 0, g = 0, b = 0, a = 0;
            SDL_GetRGBA(px, s->format, &r, &g, &b, &a);
            if (!has_alpha) a = 255;
            dst[0] = r; dst[1] = g; dst[2] = b; dst[3] = a;
            dst += 4;
        }
    }
    if (locked) SDL_UnlockSurface(s);
}

}  // namespace

// ── Boot thread: pad bring-up with bounded timeout ──────────────────────────

#ifdef __PS2__
void EnginePS2::boot_pad_thread(EnginePS2* eng, int sem_id) {
    SifLoadModule("rom0:SIO2MAN", 0, nullptr);
    SifLoadModule("rom0:PADMAN", 0, nullptr);
    padInit(0);
    eng->m_pad_ok = (padPortOpen(0, 0, eng->m_pad_buf) != 0);
    for (int i = 0; i < 100 && eng->m_pad_ok; ++i) {
        const int st = padGetState(0, 0);
        if (st == PAD_STATE_STABLE || st == PAD_STATE_FINDCTP1) break;
        if (st == PAD_STATE_DISCONN) { eng->m_pad_ok = false; break; }
        DelayThread(10000);
    }
    if (eng->m_pad_ok) {
        const int st = padGetState(0, 0);
        eng->m_pad_ok = (st == PAD_STATE_STABLE || st == PAD_STATE_FINDCTP1);
    }
    if (eng->m_pad_ok) padSetMainMode(0, 0, PAD_MMODE_DUALSHOCK, PAD_MMODE_LOCK);
    SignalSema(sem_id);
}
#endif

void EnginePS2::update_viewport() {
    const int sw = (m_gs != nullptr) ? m_gs->Width : 0;
    const int sh = (m_gs != nullptr) ? m_gs->Height : 0;
    if (sw <= 0 || sh <= 0 || m_logical_w == 0 || m_logical_h == 0) {
        m_scale = 1.0f;
        m_off_x = 0;
        m_off_y = 0;
        return;
    }
    const float sx = static_cast<float>(sw) / static_cast<float>(m_logical_w);
    const float sy = static_cast<float>(sh) / static_cast<float>(m_logical_h);
    m_scale = std::min(sx, sy);
    m_off_x = static_cast<std::int32_t>(
        (static_cast<float>(sw) - static_cast<float>(m_logical_w) * m_scale) * 0.5f);
    m_off_y = static_cast<std::int32_t>(
        (static_cast<float>(sh) - static_cast<float>(m_logical_h) * m_scale) * 0.5f);
    if (m_off_x < 0) m_off_x = 0;
    if (m_off_y < 0) m_off_y = 0;
}

// ── Lifecycle ────────────────────────────────────────────────────────────────

EnginePS2::~EnginePS2() { shutdown(); }

bool EnginePS2::init(std::string_view /*title*/, std::uint32_t w, std::uint32_t h,
                     bool /*fullscreen*/, bool /*vsync*/) {
    SifInitRpc(0);

    // SDL is only used for its timer, image decoding and TTF rasterisation;
    // no video subsystem, so the GS belongs to gsKit alone.
    if (SDL_Init(SDL_INIT_TIMER) != 0) return false;

    m_gs = gsKit_init_global();
    if (m_gs == nullptr) return false;

    dmaKit_init(D_CTRL_RELE_OFF, D_CTRL_MFD_OFF, D_CTRL_STS_UNSPEC, D_CTRL_STD_OFF,
                D_CTRL_RCYC_8, 1 << DMA_CHANNEL_GIF);
    dmaKit_chan_init(DMA_CHANNEL_GIF);

    m_gs->PSM = GS_PSM_CT24;         // full colour (CT16 clips / bands)
    m_gs->ZBuffering = GS_SETTING_OFF;
    m_gs->DoubleBuffering = GS_SETTING_ON;
    m_gs->PrimAAEnable = 0;
    m_gs->PrimAlphaEnable = GS_SETTING_ON;  // ABE + TCC for alpha textures
    m_gs->Test->ZTE = 0;
    gsKit_init_screen(m_gs);
    gsKit_set_test(m_gs, GS_ZTEST_OFF);
    gsKit_set_primalpha(m_gs, GS_SETREG_ALPHA(0, 1, 0, 1, 0), 1);
    gsKit_TexManager_init(m_gs);

    m_logical_w = w;
    m_logical_h = h;
    update_viewport();

    m_ttf_ok = (TTF_Init() == 0);

    // Audio stays off: the libsd/audsrv IOP RPC chain can hang on some HLE
    // setups. Enable with -DFNWF_PS2_ENABLE_AUDIO.
#ifdef FNWF_PS2_ENABLE_AUDIO
    SDL_Init(SDL_INIT_AUDIO);
    if (Mix_OpenAudio(44100, MIX_DEFAULT_FORMAT, 2, 1024) == 0) {
        Mix_AllocateChannels(32);
        m_audio_ok = true;
    }
#endif

    // Pad bring-up in a thread with a 1s timeout so a hung IOP bind can't
    // freeze the boot.
    {
        ee_sema_t sem{};
        sem.count = 0;
        sem.max_count = 1;
        sem.init_count = 0;
        sem.wait_threads = 0;
        const s32 sem_id = CreateSema(&sem);
        m_boot_sem_id = sem_id;
        if (sem_id >= 0) {
            ee_thread_t th{};
            alignas(16) static uint8_t th_stack[4096];
            th.func = reinterpret_cast<void*>(boot_pad_thread);
            th.stack = th_stack;
            th.stack_size = sizeof(th_stack);
            th.gp_reg = &_gp;
            th.initial_priority = 0x70;
            th.attr = 0;
            th.option = 0;
            const s32 tid = CreateThread(&th);
            m_boot_thread_id = tid;
            if (tid >= 0) {
                StartThread(tid, this);
                for (int i = 0; i < 100 && !m_pad_ok; ++i) DelayThread(10000);
                TerminateThread(tid);
                DeleteThread(tid);
                m_boot_thread_id = -1;
            }
        }
        if (m_boot_sem_id >= 0) { DeleteSema(m_boot_sem_id); m_boot_sem_id = -1; }
    }

    m_mouse_x = static_cast<std::int32_t>(m_logical_w) / 2;
    m_mouse_y = static_cast<std::int32_t>(m_logical_h) / 2;
    m_running = true;
    return true;
}

void EnginePS2::free_tex(GsTex& t) {
    if (!t.valid) return;
    if (m_gs != nullptr) gsKit_TexManager_free(m_gs, &t.tex);
    if (t.tex.Mem != nullptr) {
        free(t.tex.Mem);
        t.tex.Mem = nullptr;
    }
    t.valid = false;
}

void EnginePS2::shutdown() {
    for (auto& [id, t] : m_textures) free_tex(t);
    m_textures.clear();
    for (auto& [k, t] : m_text_cache) free_tex(t);
    m_text_cache.clear();

    for (auto* font : m_fonts)
        if (font) TTF_CloseFont(font);
    m_fonts.clear();

    for (auto& [id, chunk] : m_chunks)
        if (chunk) Mix_FreeChunk(chunk);
    m_chunks.clear();

#ifdef __PS2__
    if (m_boot_thread_id >= 0) {
        TerminateThread(m_boot_thread_id);
        DeleteThread(m_boot_thread_id);
        m_boot_thread_id = -1;
    }
    if (m_boot_sem_id >= 0) DeleteSema(m_boot_sem_id);
#endif

    Mix_CloseAudio();
    TTF_Quit();

    if (m_gs != nullptr) {
        gsKit_deinit_global(m_gs);
        m_gs = nullptr;
    }
    SDL_Quit();
}

// ── Events & timing ──────────────────────────────────────────────────────────

std::vector<Event> EnginePS2::poll_events() {
    std::vector<Event> events;
    SDL_Event e{};
    bool sdl_mouse_motion = false;
    bool sdl_mouse_button = false;

    // SDL mouse events (USB mouse, when present) arrive in GS pixels; the game
    // speaks logical ones.
    const float s = (m_scale > 0.0f) ? m_scale : 1.0f;
    auto to_lx = [this, s](std::int32_t v) {
        const std::int32_t mx = m_logical_w ? static_cast<std::int32_t>(m_logical_w) - 1 : 0;
        const std::int32_t lx = static_cast<std::int32_t>(
            static_cast<float>(v - m_off_x - m_user_dx) / s);
        return std::min<std::int32_t>(std::max<std::int32_t>(lx, 0), mx);
    };
    auto to_ly = [this, s](std::int32_t v) {
        const std::int32_t my = m_logical_h ? static_cast<std::int32_t>(m_logical_h) - 1 : 0;
        const std::int32_t ly = static_cast<std::int32_t>(
            static_cast<float>(v - m_off_y - m_user_dy) / s);
        return std::min<std::int32_t>(std::max<std::int32_t>(ly, 0), my);
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
                m_mouse_x = to_lx(e.button.x);
                m_mouse_y = to_ly(e.button.y);
                ev.x = m_mouse_x;
                ev.y = m_mouse_y;
                sdl_mouse_button = true;
                break;
            case SDL_MOUSEMOTION:
                ev.type = EventType::MouseMotion;
                m_mouse_x = to_lx(e.motion.x);
                m_mouse_y = to_ly(e.motion.y);
                ev.x = m_mouse_x;
                ev.y = m_mouse_y;
                sdl_mouse_motion = true;
                break;
            default:
                continue;
        }
        events.push_back(std::move(ev));
    }

    poll_pad(events, sdl_mouse_motion, sdl_mouse_button);
    return events;
}

void EnginePS2::poll_pad(std::vector<Event>& out, bool sdl_mouse_motion,
                         bool sdl_mouse_button) {
    if (!m_pad_ok) return;

    struct padButtonStatus pbs;
    if (padRead(0, 0, &pbs) == 0) return;
    const std::uint32_t pressed = (~static_cast<std::uint32_t>(pbs.btns)) & 0xFFFFu;

    // D-pad → arrow keys (menu navigation), with keyboard autorepeat.
    {
        static constexpr std::int32_t kArrowCode[4] = {1073741906, 1073741905, 1073741904,
                                                       1073741903};
        static constexpr std::uint32_t kDirBtn[4] = {PAD_UP, PAD_DOWN, PAD_LEFT, PAD_RIGHT};
        constexpr int kRepeatFirst = 15;
        constexpr int kRepeatRate = 6;
        for (int d = 0; d < 4; ++d) {
            const bool active = (pressed & kDirBtn[d]) != 0;
            bool send = false;
            if (active) {
                if (!m_dpad_held[d]) {
                    m_dpad_held[d] = true;
                    m_dpad_wait[d] = kRepeatFirst;
                    send = true;
                } else if (--m_dpad_wait[d] <= 0) {
                    m_dpad_wait[d] = kRepeatRate;
                    send = true;
                }
            } else if (m_dpad_held[d]) {
                m_dpad_held[d] = false;
                send = true;
            }
            if (send) {
                Event ev;
                ev.type = m_dpad_held[d] ? EventType::KeyDown : EventType::KeyUp;
                ev.key = kArrowCode[d];
                ev.scan_name = "";
                out.push_back(std::move(ev));
            }
        }
    }

    // Left stick → virtual cursor.
    int dx = 0, dy = 0;
    constexpr int kAxisMax = 128;
    constexpr int kDeadzone = 6;
    constexpr float kStickSpeed = 22.0f;
    int ax = 0, ay = 0;
    if (!(pbs.ljoy_h == 0 && pbs.ljoy_v == 0 && pbs.rjoy_h == 0 && pbs.rjoy_v == 0)) {
        ax = static_cast<int>(pbs.ljoy_h) - 128;
        ay = static_cast<int>(pbs.ljoy_v) - 128;
    }
    if (ax > kDeadzone || ax < -kDeadzone)
        dx += static_cast<int>(static_cast<float>(ax) * kStickSpeed / kAxisMax);
    if (ay > kDeadzone || ay < -kDeadzone)
        dy += static_cast<int>(static_cast<float>(ay) * kStickSpeed / kAxisMax);

    if ((dx != 0 || dy != 0) && !sdl_mouse_motion) {
        const std::int32_t max_x = m_logical_w ? static_cast<std::int32_t>(m_logical_w) - 1 : 0;
        const std::int32_t max_y = m_logical_h ? static_cast<std::int32_t>(m_logical_h) - 1 : 0;
        m_mouse_x = std::min<std::int32_t>(std::max<std::int32_t>(m_mouse_x + dx, 0), max_x);
        m_mouse_y = std::min<std::int32_t>(std::max<std::int32_t>(m_mouse_y + dy, 0), max_y);
        Event ev;
        ev.type = EventType::MouseMotion;
        ev.x = m_mouse_x;
        ev.y = m_mouse_y;
        out.push_back(std::move(ev));
    }

    const std::uint32_t rose = pressed & ~m_pad_prev;
    const std::uint32_t fell = m_pad_prev & ~pressed;
    m_pad_prev = pressed;

    if (!sdl_mouse_button) {
        if (rose & PAD_TRIANGLE) {
            Event ev;
            ev.type = EventType::MouseButtonDown;
            ev.x = m_mouse_x;
            ev.y = m_mouse_y;
            out.push_back(std::move(ev));
        }
        if (fell & PAD_TRIANGLE) {
            Event ev;
            ev.type = EventType::MouseButtonUp;
            ev.x = m_mouse_x;
            ev.y = m_mouse_y;
            out.push_back(std::move(ev));
        }
    }

    auto key_edges = [&out, rose, fell](std::uint32_t bit, std::int32_t code) {
        const char* name = SDL_GetKeyName(static_cast<SDLKey>(code));
        if (rose & bit) {
            Event ev;
            ev.type = EventType::KeyDown;
            ev.key = code;
            ev.key_name = name ? name : "";
            ev.scan_name = "";
            out.push_back(std::move(ev));
        }
        if (fell & bit) {
            Event ev;
            ev.type = EventType::KeyUp;
            ev.key = code;
            ev.key_name = name ? name : "";
            ev.scan_name = "";
            out.push_back(std::move(ev));
        }
    };
    key_edges(PAD_SQUARE, 32);    // Space
    key_edges(PAD_CROSS, 13);     // Enter
    key_edges(PAD_CIRCLE, 27);    // Escape
    key_edges(PAD_SELECT, 9);     // Tab
    key_edges(PAD_START, 13);     // Enter
    key_edges(PAD_L1, 'q');
    key_edges(PAD_R1, 'e');
    key_edges(PAD_L2, 'a');
    key_edges(PAD_R2, 'd');
    key_edges(PAD_L3, 'l');
}

float EnginePS2::ticks() const noexcept { return static_cast<float>(SDL_GetTicks()); }

void EnginePS2::present() {
    if (m_gs == nullptr) return;

    // No on-screen cursor: the cross/+ sprite was intrusive, so the game
    // presents clean. (△ still clicks at the virtual cursor position.)

    gsKit_queue_exec(m_gs);
    gsKit_sync_flip(m_gs);
    gsKit_TexManager_nextFrame(m_gs);
}

// ── Window ───────────────────────────────────────────────────────────────────

void EnginePS2::set_logical_size(std::uint32_t w, std::uint32_t h) {
    m_logical_w = w;
    m_logical_h = h;
    m_mouse_x = static_cast<std::int32_t>(w) / 2;
    m_mouse_y = static_cast<std::int32_t>(h) / 2;
    update_viewport();
}
void EnginePS2::set_fullscreen(bool /*on*/) {}
void EnginePS2::set_vsync(bool on) { m_vsync = on; }
void EnginePS2::set_resolution(std::uint32_t /*w*/, std::uint32_t /*h*/) {}
std::vector<std::array<std::int32_t, 3>> EnginePS2::get_display_modes() {
    return {{640, 448, 60}, {640, 480, 60}};
}

// ── Drawing primitives ───────────────────────────────────────────────────────

void EnginePS2::clear(std::uint8_t r, std::uint8_t g, std::uint8_t b, std::uint8_t /*a*/) {
    if (m_gs == nullptr) return;
    // gsKit_clear's sprite respects ABE, so use an opaque vertex alpha.
    gsKit_clear(m_gs, GS_SETREG_RGBAQ(r, g, b, 0x80, 0x00));
}

void EnginePS2::draw_rect(std::int32_t x, std::int32_t y, std::uint32_t w, std::uint32_t h,
                          std::uint8_t r, std::uint8_t g, std::uint8_t b, std::uint8_t a,
                          bool filled) {
    if (m_gs == nullptr || w == 0 || h == 0) return;
    const std::int32_t x0 = map_x(x);
    const std::int32_t y0 = map_y(y);
    const std::int32_t x1 = map_x(x + static_cast<std::int32_t>(w));
    const std::int32_t y1 = map_y(y + static_cast<std::int32_t>(h));
    const std::int32_t rw = std::max<std::int32_t>(1, x1 - x0);
    const std::int32_t rh = std::max<std::int32_t>(1, y1 - y0);
    const u64 col = col_rgbaq(r, g, b, a);

    gsKit_set_primalpha(m_gs, GS_SETREG_ALPHA(0, 1, 0, 1, 0), 0);
    if (filled) {
        gsKit_prim_sprite(m_gs, static_cast<float>(x0), static_cast<float>(y0),
                          static_cast<float>(x0 + rw), static_cast<float>(y0 + rh), 1, col);
    } else {
        gsKit_prim_sprite(m_gs, x0, y0, x0 + rw, y0 + 1, 1, col);
        gsKit_prim_sprite(m_gs, x0, y0 + rh - 1, x0 + rw, y0 + rh, 1, col);
        gsKit_prim_sprite(m_gs, x0, y0, x0 + 1, y0 + rh, 1, col);
        gsKit_prim_sprite(m_gs, x0 + rw - 1, y0, x0 + rw, y0 + rh, 1, col);
    }
}

void EnginePS2::line(std::int32_t x1, std::int32_t y1, std::int32_t x2, std::int32_t y2,
                     std::uint8_t r, std::uint8_t g, std::uint8_t b, std::uint8_t a) {
    if (m_gs == nullptr) return;
    gsKit_set_primalpha(m_gs, GS_SETREG_ALPHA(0, 1, 0, 1, 0), 0);
    gsKit_prim_line_3d(m_gs, static_cast<float>(map_x(x1)), static_cast<float>(map_y(y1)), 1,
                       static_cast<float>(map_x(x2)), static_cast<float>(map_y(y2)), 1,
                       col_rgbaq(r, g, b, a));
}

void EnginePS2::circle(std::int32_t cx, std::int32_t cy, std::int32_t radius,
                       std::uint8_t r, std::uint8_t g, std::uint8_t b, std::uint8_t a,
                       bool filled) {
    if (m_gs == nullptr || radius <= 0) return;
    const std::int32_t px = map_x(cx);
    const std::int32_t py = map_y(cy);
    const std::int32_t rr =
        std::max<std::int32_t>(1, static_cast<std::int32_t>(static_cast<float>(radius) * m_scale));
    const u64 col = col_rgbaq(r, g, b, a);
    constexpr int kSeg = 40;
    gsKit_set_primalpha(m_gs, GS_SETREG_ALPHA(0, 1, 0, 1, 0), 0);

    if (filled) {
        // gsKit's triangle fan takes x,y,z per vertex (3 floats), not pairs.
        alignas(16) float fan[(kSeg + 2) * 3];
        fan[0] = static_cast<float>(px);
        fan[1] = static_cast<float>(py);
        fan[2] = 1.0f;
        for (int i = 0; i <= kSeg; ++i) {
            const float t = (static_cast<float>(i) / kSeg) * 6.2831853f;
            fan[(i + 1) * 3] = static_cast<float>(px) + std::cos(t) * rr;
            fan[(i + 1) * 3 + 1] = static_cast<float>(py) + std::sin(t) * rr;
            fan[(i + 1) * 3 + 2] = 1.0f;
        }
        gsKit_prim_triangle_fan_3d(m_gs, fan, kSeg + 2, col);
    } else {
        for (int i = 0; i < kSeg; ++i) {
            const float t0 = (static_cast<float>(i) / kSeg) * 6.2831853f;
            const float t1 = (static_cast<float>(i + 1) / kSeg) * 6.2831853f;
            gsKit_prim_line_3d(m_gs, px + std::cos(t0) * rr, py + std::sin(t0) * rr, 1,
                               px + std::cos(t1) * rr, py + std::sin(t1) * rr, 1, col);
        }
    }
}

// ── Textures ─────────────────────────────────────────────────────────────────

EnginePS2::GsTex* EnginePS2::find_tex(std::uint32_t id) {
    auto it = m_textures.find(id);
    return (it == m_textures.end() || !it->second.valid) ? nullptr : &it->second;
}

EnginePS2::GsTex& EnginePS2::make_tex_from_surface(SDL_Surface* surf) {
    const std::uint32_t id = m_next_id++;
    GsTex& t = m_textures[id];
    t.valid = true;
    fill_ct32(t.tex, surf);
    return t;
}

void EnginePS2::blit_tex(GsTex& t, std::int32_t dx, std::int32_t dy, std::uint32_t dw,
                         std::uint32_t dh, std::int32_t sx, std::int32_t sy, std::int32_t sw,
                         std::int32_t sh, std::uint8_t alpha) {
    if (!t.valid || t.tex.Mem == nullptr || dw == 0 || dh == 0) return;
    const std::int32_t tw = static_cast<std::int32_t>(t.tex.Width);
    const std::int32_t thh = static_cast<std::int32_t>(t.tex.Height);
    if (sx < 0 || sy < 0 || sw <= 0 || sh <= 0) { sx = 0; sy = 0; sw = tw; sh = thh; }
    if (sx >= tw || sy >= thh) return;
    if (sx + sw > tw) sw = tw - sx;
    if (sy + sh > thh) sh = thh - sy;
    if (sw <= 0 || sh <= 0) return;

    const float x0 = static_cast<float>(map_x(dx));
    const float y0 = static_cast<float>(map_y(dy));
    const float x1 = static_cast<float>(map_x(dx + static_cast<std::int32_t>(dw)));
    const float y1 = static_cast<float>(map_y(dy + static_cast<std::int32_t>(dh)));

    gsKit_TexManager_bind(m_gs, &t.tex);
    gsKit_set_primalpha(m_gs, GS_SETREG_ALPHA(0, 1, 0, 1, 0), 0);
    gsKit_prim_sprite_texture(m_gs, &t.tex, x0, y0, static_cast<float>(sx),
                              static_cast<float>(sy), x1, y1,
                              static_cast<float>(sx + sw), static_cast<float>(sy + sh), 1,
                              tex_rgbaq(alpha));
}

void EnginePS2::quad_tex(GsTex& t, float x0, float y0, float x1, float y1, float x2, float y2,
                         float x3, float y3, std::uint8_t alpha) {
    if (!t.valid || t.tex.Mem == nullptr) return;
    gsKit_TexManager_bind(m_gs, &t.tex);
    gsKit_set_primalpha(m_gs, GS_SETREG_ALPHA(0, 1, 0, 1, 0), 0);
    gsKit_prim_quad_texture(m_gs, &t.tex, x0, y0, 0.0f, 0.0f, x1, y1, 0.0f,
                            static_cast<float>(t.tex.Height), x2, y2,
                            static_cast<float>(t.tex.Width), static_cast<float>(t.tex.Height),
                            x3, y3, static_cast<float>(t.tex.Width), 0.0f, 1, tex_rgbaq(alpha));
}

void EnginePS2::draw_texture(const TextureHandle& tex, std::int32_t dx, std::int32_t dy,
                             std::uint32_t dw, std::uint32_t dh, std::int32_t sx,
                             std::int32_t sy, std::int32_t sw, std::int32_t sh,
                             std::optional<std::uint8_t> alpha) {
    GsTex* t = find_tex(tex.id);
    if (t == nullptr) return;
    blit_tex(*t, dx, dy, dw, dh, sx, sy, sw, sh, alpha.value_or(255));
}

void EnginePS2::draw_texture_rotated(const TextureHandle& tex, std::int32_t dx, std::int32_t dy,
                                     std::uint32_t dw, std::uint32_t dh, float angle,
                                     std::optional<std::uint8_t> alpha) {
    GsTex* t = find_tex(tex.id);
    if (t == nullptr) return;
    const float cx = static_cast<float>(map_x(dx)) +
                     static_cast<float>(map_x(dx + static_cast<std::int32_t>(dw)) - map_x(dx)) * 0.5f;
    const float cy = static_cast<float>(map_y(dy)) +
                     static_cast<float>(map_y(dy + static_cast<std::int32_t>(dh)) - map_y(dy)) * 0.5f;
    const float hw = static_cast<float>(dw) * m_scale * 0.5f;
    const float hh = static_cast<float>(dh) * m_scale * 0.5f;
    const float rad = angle * 3.14159265f / 180.0f;
    const float c = std::cos(rad), s = std::sin(rad);
    auto rot = [&](float px, float py, float& ox, float& oy) {
        ox = cx + px * c - py * s;
        oy = cy + px * s + py * c;
    };
    float ax, ay, bx, by, ccx, cyy, ddx, ddy;
    rot(-hw, -hh, ax, ay);
    rot(hw, -hh, bx, by);
    rot(hw, hh, ccx, cyy);
    rot(-hw, hh, ddx, ddy);
    // quad_tex order: (u0,v0) top-left, (u1,v1) bottom-left, (u2,v2) bottom-right,
    // (u3,v3) top-right — rotating corners accordingly.
    quad_tex(*t, ax, ay, ddx, ddy, ccx, cyy, bx, by, alpha.value_or(255));
}

// ── Text ─────────────────────────────────────────────────────────────────────

bool EnginePS2::draw_text(std::string_view text, std::int32_t x, std::int32_t y,
                          std::uint32_t font_size, std::uint8_t r, std::uint8_t g,
                          std::uint8_t b, std::uint8_t a, bool center, std::int32_t font_idx) {
    if (text.empty() || m_gs == nullptr) return true;

    std::int64_t fidx = font_idx;
    if (fidx < 0) {
        fidx = load_font(GameSettings::asset_path("font/font", ".ttf"),
                         static_cast<std::uint16_t>(font_size));
        if (fidx < 0) return true;
    }
    if (static_cast<std::size_t>(fidx) >= m_fonts.size()) return true;

    std::uint64_t h = 0xcbf29ce484222325ULL;
    for (unsigned char c : text) { h ^= c; h *= 0x100000001b3ULL; }
    h ^= (static_cast<std::uint64_t>(fidx) << 32) | (static_cast<std::uint64_t>(r) << 16) |
         (static_cast<std::uint64_t>(g) << 8) | static_cast<std::uint64_t>(b);

    auto it = m_text_cache.find(h);
    if (it == m_text_cache.end()) {
        if (m_text_cache.size() > 400) {
            for (auto& [k, s] : m_text_cache) free_tex(s);
            m_text_cache.clear();
        }
        TTF_Font* font = m_fonts[fidx];
        SDL_Color col{r, g, b, 255};
        SDL_Surface* surf = TTF_RenderUTF8_Blended(font, std::string(text).c_str(), col);
        if (surf == nullptr) return true;
        GsTex& t = m_text_cache[h];
        t.valid = true;
        fill_ct32(t.tex, surf);
        SDL_FreeSurface(surf);
        it = m_text_cache.find(h);
    }

    GsTex& t = it->second;
    if (!t.valid) return true;
    const std::int32_t tw = static_cast<std::int32_t>(t.tex.Width);
    const std::int32_t th = static_cast<std::int32_t>(t.tex.Height);
    const std::int32_t px = center ? (x - tw / 2) : x;
    const std::int32_t py = center ? (y - th / 2) : y;
    blit_tex(t, px, py, static_cast<std::uint32_t>(tw), static_cast<std::uint32_t>(th), 0, 0,
             tw, th, a);
    return true;
}

bool EnginePS2::draw_text_rotated(std::string_view text, std::int32_t x, std::int32_t y,
                                  std::uint32_t font_size, float /*angle*/, std::uint8_t r,
                                  std::uint8_t g, std::uint8_t b, std::uint8_t a, bool center,
                                  std::int32_t font_idx) {
    return draw_text(text, x, y, font_size, r, g, b, a, center, font_idx);
}

// ── Resources ────────────────────────────────────────────────────────────────

std::optional<TextureHandle> EnginePS2::load_texture(std::string_view path) {
    const std::string p = platform_path(path);
    SDL_Surface* surf = IMG_Load(p.c_str());
    if (surf == nullptr) surf = SDL_LoadBMP(p.c_str());
    if (surf == nullptr) {
        std::fprintf(stderr, "ERROR: texture load failed: %s\n", p.c_str());
        return std::nullopt;
    }

    // Cap source art for RAM/VRAM. 512 keeps the biggest sprites sharp enough
    // on a 640x448 framebuffer while five textures still fit in 4MB of VRAM.
    constexpr int MAX_DIM = 256;
    if (surf->w > MAX_DIM || surf->h > MAX_DIM) {
        const float f = std::min(static_cast<float>(MAX_DIM) / static_cast<float>(surf->w),
                                 static_cast<float>(MAX_DIM) / static_cast<float>(surf->h));
        const int nw = std::max(1, static_cast<int>(static_cast<float>(surf->w) * f));
        const int nh = std::max(1, static_cast<int>(static_cast<float>(surf->h) * f));
        SDL_Surface* small = downscale_surface(surf, nw, nh);
        SDL_FreeSurface(surf);
        if (small == nullptr) return std::nullopt;
        GsTex& t = make_tex_from_surface(small);
        SDL_FreeSurface(small);
        return TextureHandle{t.valid ? (m_next_id - 1) : 0};
    }

    GsTex& t = make_tex_from_surface(surf);
    SDL_FreeSurface(surf);
    return TextureHandle{t.valid ? (m_next_id - 1) : 0};
}

std::optional<TextureHandle> EnginePS2::create_target(std::uint32_t /*w*/, std::uint32_t /*h*/) {
    // The GS has no cheap render-to-texture for full-screen targets; the game
    // draws such effects straight to the screen (supports_offscreen_targets()).
    return std::nullopt;
}

std::optional<SoundHandle> EnginePS2::load_sound(std::string_view path) {
    if (!m_audio_ok) return std::nullopt;
    Mix_Chunk* chunk = Mix_LoadWAV(platform_path(path).c_str());
    if (chunk == nullptr) return std::nullopt;
    const std::uint32_t id = m_next_id++;
    m_chunks[id] = chunk;
    return SoundHandle{id};
}

std::int64_t EnginePS2::load_font(std::string_view path, std::uint16_t size) {
    if (!m_ttf_ok) return -1;
    const std::string p = platform_path(path);
    TTF_Font* font = TTF_OpenFont(p.c_str(), size);
    if (font == nullptr) {
        std::string upper = p;
        std::transform(upper.begin(), upper.end(), upper.begin(), ::toupper);
        font = TTF_OpenFont(upper.c_str(), size);
    }
    if (font == nullptr) return -1;
    const std::int64_t idx = static_cast<std::int64_t>(m_fonts.size());
    m_fonts.push_back(font);
    return idx;
}

std::optional<std::array<std::int32_t, 2>> EnginePS2::font_text_size(std::string_view text,
                                                                     std::uint32_t font_idx) {
    if (font_idx >= m_fonts.size()) return std::nullopt;
    int w{}, h{};
    if (TTF_SizeUTF8(m_fonts[font_idx], std::string(text).c_str(), &w, &h) != 0)
        return std::nullopt;
    return std::array<std::int32_t, 2>{w, h};
}

std::pair<std::uint32_t, std::uint32_t> EnginePS2::texture_size(std::uint32_t id) noexcept {
    auto it = m_textures.find(id);
    if (it == m_textures.end() || !it->second.valid) return {0, 0};
    return {it->second.tex.Width, it->second.tex.Height};
}

// ── Render targets (unsupported) ─────────────────────────────────────────────

void EnginePS2::set_render_target(std::optional<TextureHandle> /*target*/) {}
void EnginePS2::reset_render_target() {}

// ── Sound ────────────────────────────────────────────────────────────────────

std::int32_t EnginePS2::play_sound(const SoundHandle& snd, std::int32_t loops,
                                   std::int32_t channel) {
    auto it = m_chunks.find(snd.id);
    if (it != m_chunks.end() && it->second != nullptr) Mix_PlayChannel(channel, it->second, loops);
    return channel;
}
void EnginePS2::stop_channel(std::int32_t channel) { Mix_HaltChannel(channel); }
void EnginePS2::stop_all_sounds() { Mix_HaltChannel(-1); }

// ── Input ────────────────────────────────────────────────────────────────────

std::pair<std::int32_t, std::int32_t> EnginePS2::mouse_pos() { return {m_mouse_x, m_mouse_y}; }

// ── Volume ───────────────────────────────────────────────────────────────────

void EnginePS2::set_master_volume(int vol) {
    m_master_vol = vol;
    const int music_eff = (m_master_vol * m_music_vol * MIX_MAX_VOLUME) / 10000;
    const int sfx_eff = (m_master_vol * m_sfx_vol * MIX_MAX_VOLUME) / 10000;
    Mix_VolumeMusic(music_eff);
    for (int ch = 0; ch < 16; ++ch) Mix_Volume(ch, sfx_eff);
}
void EnginePS2::set_sfx_volume(int vol) {
    m_sfx_vol = vol;
    const int eff = (m_master_vol * m_sfx_vol * MIX_MAX_VOLUME) / 10000;
    for (int ch = 0; ch < 16; ++ch) Mix_Volume(ch, eff);
}
void EnginePS2::set_music_volume(int vol) {
    m_music_vol = vol;
    const int eff = (m_master_vol * m_music_vol * MIX_MAX_VOLUME) / 10000;
    Mix_VolumeMusic(eff);
}

// ── Misc ─────────────────────────────────────────────────────────────────────

void EnginePS2::update_discord(std::string_view, std::string_view) {}

// ── Factory ──────────────────────────────────────────────────────────────────

Engine* create_engine() { return new EnginePS2(); }
void destroy_engine(Engine* e) { delete e; }

}  // namespace fnwf
