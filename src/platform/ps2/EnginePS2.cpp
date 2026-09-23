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

}  // namespace

#ifdef __PS2__
namespace {

// Convert an SDL surface (canonical 32bpp RGBA) into a gsKit GSTEXTURE.
// Allocates aligned EE memory, copies pixels (swizzling RGBA↔GS byte order),
// allocates VRAM, and DMA-transfers the texture data. Returns true on success.
bool gsKit_upload_surface(GSGLOBAL *gsGlobal, GSTEXTURE *tex, SDL_Surface *surf) {
    if (surf == nullptr || gsGlobal == nullptr) return false;
    const int w = surf->w, h = surf->h;
    tex->Width = w;
    tex->Height = h;
    tex->PSM = GS_PSM_CT32;
    tex->ClutPSM = 0;
    tex->Clut = nullptr;
    tex->Filter = GS_FILTER_NEAREST;
    tex->ClutStorageMode = GS_CLUT_STOREMODE_NOLOAD;
    tex->Delayed = 0;
    // gsKit needs the texture base width as a power-of-2 in 64-pixel blocks.
    gsKit_setup_tbw(tex);
    // Allocate aligned EE memory for the pixel data (8-byte align minimum for DMA).
    const u32 size = gsKit_texture_size(tex->Width, tex->Height, tex->PSM);
    tex->Mem = reinterpret_cast<u32 *>(memalign(64, size));
    if (tex->Mem == nullptr) return false;
    // Copy pixels: SDL stores RGBA (R=0x00FF0000), GS CT32 expects RGBA too,
    // but we need to byte-swizzle for the GS DMA (GS uses big-endian pixel words).
    const bool locked = SDL_MUSTLOCK(surf) != 0;
    if (locked && SDL_LockSurface(surf) != 0) { free(tex->Mem); tex->Mem = nullptr; return false; }
    const int bpp = surf->format->BytesPerPixel;
    for (int y = 0; y < h; ++y) {
        const Uint8* srow = static_cast<const Uint8*>(surf->pixels) +
                            static_cast<std::size_t>(y) * surf->pitch;
        u32* drow = tex->Mem + y * tex->TBW;
        for (int x = 0; x < w; ++x) {
            Uint32 px = 0;
            switch (bpp) {
                case 1: px = *srow++; break;
                case 2: px = *reinterpret_cast<const Uint16*>(srow); srow += 2; break;
                case 3: px = static_cast<Uint32>(srow[0]) | (static_cast<Uint32>(srow[1]) << 8) |
                           (static_cast<Uint32>(srow[2]) << 16); srow += 3; break;
                default: px = *reinterpret_cast<const Uint32*>(srow); srow += 4; break;
            }
            // SDL canonical format: R=0x00FF0000, G=0x0000FF00, B=0x000000FF, A=0xFF000000
            // GS CT32 wants the same layout — but DMA transfers are 8-byte aligned
            // and the GS reads in a specific order. For CT32 the layout matches SDL's
            // canonical RGBA, so we can copy directly after byte-swapping each word
            // for the GS's big-endian DMA word order.
            const Uint8 r = (px & RMASK) >> 16;
            const Uint8 g = (px & GMASK) >> 8;
            const Uint8 b = (px & BMASK);
            const Uint8 a = (px & AMASK) >> 24;
            // GS CT32 pixel word (big-endian DMA): ABGR in the 32-bit word
            drow[x] = (static_cast<u32>(a) << 24) | (static_cast<u32>(r) << 16) |
                      (static_cast<u32>(g) << 8) | static_cast<u32>(b);
        }
    }
    if (locked) SDL_UnlockSurface(surf);
    // Allocate VRAM and upload via DMA.
    tex->Vram = gsKit_vram_alloc(gsGlobal, gsKit_texture_size(tex->Width, tex->Height, tex->PSM),
                                 GSKIT_ALLOC_USERBUFFER);
    if (tex->Vram == GSKIT_ALLOC_ERROR) { free(tex->Mem); tex->Mem = nullptr; return false; }
    gsKit_texture_upload(gsGlobal, tex);
    return true;
}

}  // namespace
#endif  // __PS2__

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

// ── Viewport (logical size → screen, letterboxed) ──────────────────────────

#ifdef __PS2__
// ── Boot thread: pad bring-up with bounded timeout ──────────────────────────
// padInit() (called inside libpad) does sceSifBindRpc() which can hang if
// the IOP has no pad server — on some PCSX2 HLE setups, without rom0 loaded
// first, that bind blocks forever. We run the whole pad bring-up (including
// SifLoadModule calls) in a separate thread so the main thread can timeout
// after 1 s and still boot: gray splash = no pad, but the game runs. The
// thread itself is color-coded:
//   orange = before SifLoadModule SIO2MAN · purple = before PADMAN ·
//   blue   = padPortOpen · white = pad ready · gray = NO pad detected.
void EnginePS2::boot_pad_thread(EnginePS2 *eng, int sem_id) {
    SDL_Surface *scr = eng->m_screen;
    auto splash = [scr](int r, int g, int b) {
        SDL_FillRect(scr, nullptr,
                     SDL_MapRGB(scr->format, Uint8(r), Uint8(g), Uint8(b)));
        SDL_Flip(scr);
    };

    // Load IOP modules first: without them the pad RPC server doesn't exist
    // and padInit's bind blocks forever. On PCSX2 HLE rom0: loads resolve
    // to HLE replacements — on real BIOS they come from the console ROM.
    splash(255, 128, 0);  // orange
    int r1 = SifLoadModule("rom0:SIO2MAN", 0, nullptr);
    (void)r1;
    splash(180, 0, 255);  // purple
    int r2 = SifLoadModule("rom0:PADMAN", 0, nullptr);
    (void)r2;

    padInit(0);
    eng->m_pad_ok = (padPortOpen(0, 0, eng->m_pad_buf) != 0);
    splash(0, 64, 255);   // blue: settling
    for (int i = 0; i < 100 && eng->m_pad_ok; ++i) {
        const int st = padGetState(0, 0);
        if (st == PAD_STATE_STABLE || st == PAD_STATE_FINDCTP1) break;
        if (st == PAD_STATE_DISCONN) { eng->m_pad_ok = false; break; }
        DelayThread(10000);  // 10 ms → ≤ 1 s total
    }
    if (eng->m_pad_ok) {
        const int st = padGetState(0, 0);
        eng->m_pad_ok = (st == PAD_STATE_STABLE || st == PAD_STATE_FINDCTP1);
    }
    if (eng->m_pad_ok) {
        // Dualshock main mode, locked: makes the analog sticks report.
        // Fails harmlessly on a digital pad — poll_pad() discards the
        // all-zero analog reading; D-pad still works.
        padSetMainMode(0, 0, PAD_MMODE_DUALSHOCK, PAD_MMODE_LOCK);
    }

    SignalSema(sem_id);
}
#endif  // __PS2__

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

    // Video first: the game must reach SDL_SetVideoMode even if the audio
    // stack (libsd + audsrv RPC on the IOP) fails or hangs. The old order
    // (audio before video) turned any sound failure into a silent black
    // screen, because main() reports init failures on stderr — invisible
    // under PCSX2.
    if (SDL_Init(SDL_INIT_VIDEO | SDL_INIT_TIMER) != 0) {
        return false;
    }

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

    // TEMP DIAGNOSTIC (black-screen triage, remove once resolved): green
    // splash proves video setup completed; it stays on screen if the game
    // never reaches the main loop.
    SDL_FillRect(m_screen, nullptr, SDL_MapRGB(m_screen->format, 0, 255, 0));
    SDL_Flip(m_screen);

    m_logical_w = w;
    m_logical_h = h;

    // All screen-space drawing happens on the backbuffer (canonical format);
    // present() scales nothing — coordinates are mapped at draw time instead.
    m_backbuf = make_surface(m_physical_w, m_physical_h, false);
    m_tpl_alpha = make_surface(1, 1, true);
    update_viewport();

    // TEMP DIAGNOSTIC: cyan splash = backbuffer + viewport ready.
    SDL_FillRect(m_screen, nullptr, SDL_MapRGB(m_screen->format, 0, 255, 255));
    SDL_Flip(m_screen);

    m_ttf_ok = (TTF_Init() == 0);

#ifdef __PS2__
    // ── gsKit hardware renderer init ────────────────────────────────────────
    // All drawing (clear, rects, textured sprites) runs on the GS GPU via
    // the persistent draw queue, then we flip with vsync limiting to 60 fps.
    // SDL stays for video init, input polling, audio, and asset loading only.
    dmaKit_init(D_CTRL_RELE_OFF, D_CTRL_MFD_OFF, D_CTRL_STS_UNSPEC,
                D_CTRL_STD_OFF, D_CTRL_RCYC_8, 1 << DMA_CHANNEL_GIF);
    dmaKit_chan_init(DMA_CHANNEL_GIF);

    m_gsGlobal = gsKit_init_global();
    m_gsGlobal->Mode = GS_MODE_NTSC;
    m_gsGlobal->Interlace = GS_INTERLACED;
    m_gsGlobal->Field = GS_FIELD;
    m_gsGlobal->Width = static_cast<u32>(m_physical_w);
    m_gsGlobal->Height = static_cast<u32>(m_physical_h);
    m_gsGlobal->DoubleBuffering = GS_SETTING_ON;
    m_gsGlobal->ZBuffering = GS_SETTING_OFF;
    m_gsGlobal->PrimAlphaEnable = GS_SETTING_ON;
    gsKit_init_screen(m_gsGlobal);
    gsKit_mode_switch(m_gsGlobal, GS_PERSISTENT);
    gsKit_clear(m_gsGlobal, GS_SETREG_RGBAQ(0, 0, 0, 0, 0));
    // Upload the blank backbuffer surface so present() has a display target.
    gsKit_upload_surface(m_gsGlobal, &m_gsBackbuf, m_backbuf);
#endif

    // Audio is DISABLED on PS2 for now: the green splash froze on PCSX2
    // (log silent right after video init), i.e. the libsd/audsrv IOP RPC
    // chain inside SDL_Init(SDL_INIT_AUDIO)/Mix_OpenAudio never returns.
    // Every Mix call tolerates a closed device (Mix_LoadWAV/Mix_CloseAudio
    // check audio_opened), so the game runs silent until audio gets its own
    // debugging pass. Re-enable with -DFNWF_PS2_ENABLE_AUDIO.
#ifdef FNWF_PS2_ENABLE_AUDIO
    SDL_Init(SDL_INIT_AUDIO);  // registers the driver; the device opens below
    if (Mix_OpenAudio(44100, MIX_DEFAULT_FORMAT, 2, 1024) == 0) {
        Mix_AllocateChannels(32);
        m_audio_ok = true;
    }
#endif

    // PS2 pad bring-up in a BOOT THREAD with a 1 s timeout.
    // padInit() (called inside libpad) does sceSifBindRpc() which can hang
    // if the IOP has no pad server — on some PCSX2 HLE setups, without
    // rom0:SIO2MAN/PADMAN loaded first, that bind blocks forever. We run
    // the whole pad bring-up (including SifLoadModule calls) in a separate
    // thread so the main thread can timeout after 1 s and still boot: gray
    // splash = no pad, but the game runs. The thread itself is color-coded:
    //   orange = before SifLoadModule SIO2MAN · purple = before PADMAN ·
    //   blue   = padPortOpen · white = pad ready · gray = NO pad detected.
#ifdef __PS2__
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
            alignas(16) uint8_t th_stack[4096];
            th.func           = reinterpret_cast<void *>(boot_pad_thread);
            th.stack          = th_stack;
            th.stack_size     = sizeof(th_stack);
            th.gp_reg         = &_gp;
            th.initial_priority = 0x70;  // same as ps2sdk's poweroff thread
            th.attr           = 0;
            th.option         = 0;
            const s32 tid = CreateThread(&th);
            m_boot_thread_id = tid;
            if (tid >= 0) {
                StartThread(tid, this);
                // Wait up to 1 s for the pad thread (100 × 10 ms).
                for (int i = 0; i < 100 && !m_pad_ok; ++i) {
                    DelayThread(10000);
                }
                TerminateThread(tid);
                DeleteThread(tid);
                m_boot_thread_id = -1;
            }
        }
        if (m_boot_sem_id >= 0) { DeleteSema(m_boot_sem_id); m_boot_sem_id = -1; }
    }
#endif

    m_running = true;
    m_vsync = vsync;

    // TEMP DIAGNOSTIC: splash = init() completed. White = pad ready;
    // gray = no pad detected (controls will not respond). A hang while
    // loading fonts/saves/building states in main() leaves it on screen.
    SDL_FillRect(m_screen, nullptr,
                 m_pad_ok ? SDL_MapRGB(m_screen->format, 255, 255, 255)
                          : SDL_MapRGB(m_screen->format, 96, 96, 96));
    SDL_Flip(m_screen);

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

#ifdef __PS2__
    if (m_boot_thread_id >= 0) {
        TerminateThread(m_boot_thread_id);
        DeleteThread(m_boot_thread_id);
        m_boot_thread_id = -1;
    }
    if (m_boot_sem_id >= 0) DeleteSema(m_boot_sem_id);
    // Free EE-side texture memory. gsKit manages GS VRAM internally;
    // the VRAM pool is freed when the application exits.
    for (auto& [id, tex] : m_gsTextures) {
        if (tex.Mem != nullptr) { free(tex.Mem); tex.Mem = nullptr; }
    }
    m_gsTextures.clear();
    if (m_gsGlobal != nullptr) {
        if (m_gsBackbuf.Mem != nullptr) { free(m_gsBackbuf.Mem); m_gsBackbuf.Mem = nullptr; }
        m_gsGlobal = nullptr;
    }
#endif

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
    // NOTE: explicit std::int32_t on every min/max below — on the ps2-elf
    // target int32_t is `long`, so deducing std::max(v, 0) conflicts
    // ('long int' vs 'int') and fails to compile (host x86 can't catch it).
    auto clamp_x = [this](std::int32_t v) {
        const std::int32_t mx =
            m_logical_w ? static_cast<std::int32_t>(m_logical_w) - 1 : 0;
        return std::min<std::int32_t>(std::max<std::int32_t>(v, 0), mx);
    };
    auto clamp_y = [this](std::int32_t v) {
        const std::int32_t my =
            m_logical_h ? static_cast<std::int32_t>(m_logical_h) - 1 : 0;
        return std::min<std::int32_t>(std::max<std::int32_t>(v, 0), my);
    };

    // Set when SDL delivered real mouse input this frame (USB mouse, or the
    // port's own pad→mouse emulation if it got enabled); poll_pad() then
    // skips its own synthesis so input is never applied twice.
    bool sdl_mouse_motion = false;
    bool sdl_mouse_button = false;

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
                m_mouse_x = clamp_x(to_lx(e.button.x));
                m_mouse_y = clamp_y(to_ly(e.button.y));
                ev.x = m_mouse_x;
                ev.y = m_mouse_y;
                sdl_mouse_button = true;
                break;
            case SDL_MOUSEMOTION:
                ev.type = EventType::MouseMotion;
                m_mouse_x = clamp_x(to_lx(e.motion.x));
                m_mouse_y = clamp_y(to_ly(e.motion.y));
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

// The game is a mouse + keyboard title; on PS2 the DualShock stands in for
// both. The pad is read through libpad every frame (NOT SDL's joystick
// driver — that path SifLoadModule()s rom0 modules and freezes under
// PCSX2's HLE) and translated into the same events a real mouse/keyboard
// would produce:
//
//   D-pad ................. arrow keys — console-style menu navigation
//                           (MenuState moves the highlight on up/down)
//   Left stick ............ move the virtual cursor (office pan, camera
//                           hover, △-click targets)
//   ✕ (Cross) ............. Enter   (confirm the highlighted entry)
//   ○ (Circle) ............ Escape  (back / leave the night)
//   ◻ (Square) ............ Space   (advance dialogs / mask in-game)
//   △ (Triangle) .......... left click at the cursor (on-screen buttons:
//                           doors, camera select, menu entries by position)
//   START ................. Enter   (confirm)
//   SELECT ................ Tab     (monitor toggle)
//   L1 / R1 ............... q / e   (left / right door)
//   L2 / R2 ............... a / d   (left / right light)
//   L3 .................... l       (vent light)
void EnginePS2::poll_pad(std::vector<Event>& out, bool sdl_mouse_motion,
                         bool sdl_mouse_button) {
#ifndef __PS2__
    (void)out;
    (void)sdl_mouse_motion;
    (void)sdl_mouse_button;
#else
    if (!m_pad_ok) return;

    // Fresh sample, or nothing new this frame (padRead returns 0 when the
    // pad hasn't been serviced since the last read).
    struct padButtonStatus pbs;
    if (padRead(0, 0, &pbs) == 0) return;

    // btns is active-low: flip it so a set bit means "pressed" — the same
    // trick the SDL ps2 driver uses.
    const std::uint32_t pressed =
        (~static_cast<std::uint32_t>(pbs.btns)) & 0xFFFFu;

    // ── D-pad → arrow keys (menu navigation) ───────────────────────────
    // SDL2 keycode values, which is what the game states check
    // (MenuState: 1073741906 = up, 1073741905 = down). Held directions
    // repeat like a keyboard autorepeat. Most states ignore arrows —
    // StoryState explicitly returns on keys other than 13/32, and
    // GameplayState matches letters only.
    {
        static constexpr std::int32_t kArrowCode[4] = {1073741906, 1073741905,
                                                       1073741904, 1073741903};
        static constexpr std::uint32_t kDirBtn[4] = {PAD_UP, PAD_DOWN,
                                                     PAD_LEFT, PAD_RIGHT};
        constexpr int kRepeatFirst = 15;  // frames until the first repeat
        constexpr int kRepeatRate = 6;    // frames between repeats

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

    // ── Left stick → virtual cursor ────────────────────────────────────
    int dx = 0, dy = 0;

    // Raw stick values are 0..255 centered on 128 (libpad's scale — not the
    // SDL driver's ×16256). An all-zero reading means a digital pad or
    // analog not active: treat it as centered so a dead stick can't drift
    // the cursor. The deadzone swallows resting drift.
    constexpr int kAxisMax = 128;   // raw units from center at full deflection
    constexpr int kDeadzone = 6;     // raw units
    constexpr float kStickSpeed = 22.0f;
    int ax = 0, ay = 0;
    if (!(pbs.ljoy_h == 0 && pbs.ljoy_v == 0 && pbs.rjoy_h == 0 &&
          pbs.rjoy_v == 0)) {
        ax = static_cast<int>(pbs.ljoy_h) - 128;
        ay = static_cast<int>(pbs.ljoy_v) - 128;
    }
    if (ax > kDeadzone || ax < -kDeadzone)
        dx += static_cast<int>(static_cast<float>(ax) * kStickSpeed /
                               static_cast<float>(kAxisMax));
    if (ay > kDeadzone || ay < -kDeadzone)
        dy += static_cast<int>(static_cast<float>(ay) * kStickSpeed /
                               static_cast<float>(kAxisMax));

    if ((dx != 0 || dy != 0) && !sdl_mouse_motion) {
        const std::int32_t max_x =
            m_logical_w ? static_cast<std::int32_t>(m_logical_w) - 1 : 0;
        const std::int32_t max_y =
            m_logical_h ? static_cast<std::int32_t>(m_logical_h) - 1 : 0;
        m_mouse_x = std::min<std::int32_t>(
            std::max<std::int32_t>(m_mouse_x + dx, 0), max_x);
        m_mouse_y = std::min<std::int32_t>(
            std::max<std::int32_t>(m_mouse_y + dy, 0), max_y);

        Event ev;
        ev.type = EventType::MouseMotion;
        ev.x = m_mouse_x;
        ev.y = m_mouse_y;
        out.push_back(std::move(ev));
    }

    // ── Buttons (edge-triggered on the PAD_* mask) ─────────────────────
    const std::uint32_t rose = pressed & ~m_pad_prev;
    const std::uint32_t fell = m_pad_prev & ~pressed;
    m_pad_prev = pressed;

    // Triangle → left click at the cursor, suppressed if SDL already
    // delivered a real button event this frame (USB mouse). Cross is
    // Enter, NOT a click: menus must confirm the *highlighted* entry, and
    // a synthetic click would activate whatever option the cursor happens
    // to sit on instead.
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

    key_edges(PAD_SQUARE, 32);    // Square → Space
    key_edges(PAD_CROSS, 13);     // Cross → Enter (confirm)
    key_edges(PAD_CIRCLE, 27);    // Circle → Escape (back)
    key_edges(PAD_SELECT, 9);     // Select → Tab (monitor)
    key_edges(PAD_START, 13);     // Start → Enter
    key_edges(PAD_L1, 'q');       // L1 → left door
    key_edges(PAD_R1, 'e');       // R1 → right door
    key_edges(PAD_L2, 'a');       // L2 → left light
    key_edges(PAD_R2, 'd');       // R2 → right light
    key_edges(PAD_L3, 'l');       // L3 → vent light
#endif
}

float EnginePS2::ticks() const noexcept {
    return static_cast<float>(SDL_GetTicks());
}

void EnginePS2::present() {
#ifdef __PS2__
    if (m_gsGlobal == nullptr) {
        // gsKit not initialized — fall back to SDL (should not happen).
        if (m_screen != nullptr) SDL_Flip(m_screen);
        return;
    }
    // Reset the persistent draw queue each frame, then execute all queued
    // draws and flip with vsync limiting to 60 fps.
    gsKit_queue_reset(m_gsGlobal->Os_Queue);
    gsKit_queue_exec(m_gsGlobal);
    gsKit_sync_flip(m_gsGlobal);
#else
    if (m_screen == nullptr) return;
    if (m_backbuf != nullptr) {
        SDL_BlitSurface(m_backbuf, nullptr, m_screen, nullptr);
    }
    SDL_Flip(m_screen);
#endif
}

// ── Window ───────────────────────────────────────────────────────────────────

void EnginePS2::set_logical_size(std::uint32_t w, std::uint32_t h) {
    m_logical_w = w;
    m_logical_h = h;
    // Virtual cursor starts centered (mouse_pos() used to be this stub value).
    m_mouse_x = static_cast<std::int32_t>(w) / 2;
    m_mouse_y = static_cast<std::int32_t>(h) / 2;
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
#ifdef __PS2__
    if (m_gsGlobal != nullptr) {
        gsKit_clear(m_gsGlobal, GS_SETREG_RGBAQ(r, g, b, 0, 0));
    } else {
        SDL_Surface* target = draw_target();
        if (target != nullptr)
            SDL_FillRect(target, nullptr, SDL_MapRGB(target->format, r, g, b));
    }
#else
    SDL_Surface* target = draw_target();
    if (target == nullptr) return;
    SDL_FillRect(target, nullptr, SDL_MapRGB(target->format, r, g, b));
#endif
}

void EnginePS2::draw_rect(std::int32_t x, std::int32_t y, std::uint32_t w, std::uint32_t h,
                           std::uint8_t r, std::uint8_t g, std::uint8_t b, std::uint8_t a,
                           bool filled) {
#ifdef __PS2__
    if (m_gsGlobal == nullptr) return;
    std::int32_t x0 = map_x(x);
    std::int32_t y0 = map_y(y);
    std::int32_t x1 = map_x(static_cast<std::int32_t>(x) + static_cast<std::int32_t>(w));
    std::int32_t y1 = map_y(static_cast<std::int32_t>(y) + static_cast<std::int32_t>(h));
    x1 = std::max<std::int32_t>(x1, x0 + 1);
    y1 = std::max<std::int32_t>(y1, y0 + 1);
    const u64 color = GS_SETREG_RGBAQ(r, g, b, a, 0);
    if (filled) {
        gsKit_prim_quad(m_gsGlobal,
            static_cast<float>(x0), static_cast<float>(y0),
            static_cast<float>(x0), static_cast<float>(y1),
            static_cast<float>(x1), static_cast<float>(y0),
            static_cast<float>(x1), static_cast<float>(y1),
            0.f, color);
    } else {
        // Outline: four edges as thin quads.
        const u64 oc = GS_SETREG_RGBAQ(r, g, b, 255, 0);
        gsKit_prim_quad(m_gsGlobal,
            static_cast<float>(x0), static_cast<float>(y0),
            static_cast<float>(x0), static_cast<float>(y0 + 1),
            static_cast<float>(x1), static_cast<float>(y0),
            static_cast<float>(x1), static_cast<float>(y0 + 1),
            0.f, oc);
        gsKit_prim_quad(m_gsGlobal,
            static_cast<float>(x0), static_cast<float>(y1 - 1),
            static_cast<float>(x0), static_cast<float>(y1),
            static_cast<float>(x1), static_cast<float>(y1 - 1),
            static_cast<float>(x1), static_cast<float>(y1),
            0.f, oc);
        gsKit_prim_quad(m_gsGlobal,
            static_cast<float>(x0), static_cast<float>(y0),
            static_cast<float>(x0), static_cast<float>(y1),
            static_cast<float>(x0 + 1), static_cast<float>(y0),
            static_cast<float>(x0 + 1), static_cast<float>(y1),
            0.f, oc);
        gsKit_prim_quad(m_gsGlobal,
            static_cast<float>(x1 - 1), static_cast<float>(y0),
            static_cast<float>(x1 - 1), static_cast<float>(y1),
            static_cast<float>(x1), static_cast<float>(y0),
            static_cast<float>(x1), static_cast<float>(y1),
            0.f, oc);
    }
#else
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
#endif
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
        radius = std::max<std::int32_t>(1, static_cast<std::int32_t>(static_cast<float>(radius) * m_scale));
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
#ifdef __PS2__
    if (m_gsGlobal == nullptr) return;
    auto it = m_gsTextures.find(tex.id);
    if (it == m_gsTextures.end()) return;
    const GSTEXTURE& gstex = it->second;

    // Map logical → physical coordinates.
    std::int32_t x0 = map_x(dx);
    std::int32_t y0 = map_y(dy);
    std::int32_t x1 = map_x(static_cast<std::int32_t>(dx) + static_cast<std::int32_t>(dw));
    std::int32_t y1 = map_y(static_cast<std::int32_t>(dy) + static_cast<std::int32_t>(dh));
    x1 = std::max<std::int32_t>(x1, x0 + 1);
    y1 = std::max<std::int32_t>(y1, y0 + 1);

    // Source UV: which part of the texture to sample. (-1,-1,-1,-1) means whole texture.
    float u0 = 0.f, v0 = 0.f, u1 = 1.f, v1 = 1.f;
    if (sx >= 0 && sw > 0) {
        u0 = static_cast<float>(sx) / static_cast<float>(gstex.Width);
        u1 = u0 + static_cast<float>(sw) / static_cast<float>(gstex.Width);
    }
    if (sy >= 0 && sh > 0) {
        v0 = static_cast<float>(sy) / static_cast<float>(gstex.Height);
        v1 = v0 + static_cast<float>(sh) / static_cast<float>(gstex.Height);
    }
    u0 = std::max(0.f, std::min(1.f, u0));
    v0 = std::max(0.f, std::min(1.f, v0));
    u1 = std::max(0.f, std::min(1.f, u1));
    v1 = std::max(0.f, std::min(1.f, v1));

    const Uint8 a = alpha.value_or(255);
    gs_rgbaq color{};
    color.color.components.r = a;
    color.color.components.g = a;
    color.color.components.b = a;
    color.color.components.a = a;
    color.color.q = 0.f;
    // Build one quad vertex (top-left corner). gsKit sprite = 1 quad = 1 GSPRIMUVPOINTFLAT.
    GSPRIMUVPOINTFLAT vert{};
    vert.xyz2.xyz.x = static_cast<u16>(x0);
    vert.xyz2.xyz.y = static_cast<u16>(y0);
    vert.xyz2.xyz.z = 0;
    // UV in gsKit is in 1/16-pixel units, max 1024*16.
    vert.uv.coord.u = static_cast<u16>(
        std::min<int>(static_cast<int>(u0 * static_cast<float>(gstex.Width) * 16.0f), 16383));
    vert.uv.coord.v = static_cast<u16>(
        std::min<int>(static_cast<int>(v0 * static_cast<float>(gstex.Height) * 16.0f), 16383));
    gskit_prim_list_sprite_texture_uv_flat_color(m_gsGlobal, &gstex, color, 1, &vert);
#else
    auto it = m_textures.find(tex.id);
    if (it == m_textures.end()) return;

    Uint8 a = alpha.value_or(255);
    blit_scaled(it->second, dx, dy, dw, dh, sx, sy, sw, sh, a);
#endif
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

#ifdef __PS2__
    // Also upload to GS VRAM for hardware-accelerated rendering.
    GSTEXTURE gstex{};
    if (gsKit_upload_surface(m_gsGlobal, &gstex, converted)) {
        m_gsTextures[id] = gstex;
    } else {
        // GS upload failed — fall back to software rendering (texture will
        // still work via SDL_BlitSurface in draw_texture).
        if (gstex.Mem != nullptr) { free(gstex.Mem); gstex.Mem = nullptr; }
    }
#endif

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
    // With audio disabled (see init), fail fast instead of re-opening the
    // file on every play attempt — SoundManager only caches successful loads.
    if (!m_audio_ok) return std::nullopt;
    Mix_Chunk* chunk = Mix_LoadWAV(platform_path(path).c_str());
    if (!chunk) return std::nullopt;

    const std::uint32_t id = m_next_id++;
    m_chunks[id] = chunk;
    return SoundHandle{id};
}

std::int64_t EnginePS2::load_font(std::string_view path, std::uint16_t size) {
    if (!m_ttf_ok) return -1;
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
    // Logical cursor: updated by SDL mouse events in poll_events() and by the
    // pad's virtual cursor in poll_pad(). (Was a center-screen stub — office
    // panning and the camera hover trigger read this every frame.)
    return {m_mouse_x, m_mouse_y};
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
