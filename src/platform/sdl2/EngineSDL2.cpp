#include "platform/sdl2/EngineSDL2.hpp"
#include "core/DrawUtils.hpp"
#include "game1/GameSettings.hpp"

#include <algorithm>
#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <string>

namespace fnwf {

// ── Helpers ──────────────────────────────────────────────────────────────────

namespace {
auto rgba(std::uint8_t r, std::uint8_t g, std::uint8_t b, std::uint8_t a) noexcept -> SDL_Color {
    return SDL_Color{r, g, b, a};
}
}  // namespace

// ── Lifecycle ────────────────────────────────────────────────────────────────

EngineSDL2::~EngineSDL2() {
    shutdown();
}

bool EngineSDL2::init(std::string_view title, std::uint32_t w, std::uint32_t h,
                      bool fullscreen, bool vsync) {
    if (SDL_Init(SDL_INIT_VIDEO | SDL_INIT_AUDIO | SDL_INIT_TIMER) != 0) {
        return false;
    }
    if (TTF_Init() != 0) {
        return false;
    }
    if (!(IMG_Init(IMG_INIT_PNG) & IMG_INIT_PNG)) {
        return false;
    }
    if (Mix_OpenAudio(44100, MIX_DEFAULT_FORMAT, 2, 1024) != 0) {
        return false;
    }
    Mix_Init(MIX_INIT_OGG | MIX_INIT_MP3 | MIX_INIT_FLAC);
    Mix_AllocateChannels(32);

    SDL_Window* raw = SDL_CreateWindow(std::string(title).c_str(),
                                       SDL_WINDOWPOS_CENTERED,
                                       SDL_WINDOWPOS_CENTERED,
                                       static_cast<int>(w),
                                       static_cast<int>(h),
                                       SDL_WINDOW_SHOWN);
    if (raw == nullptr) {
        return false;
    }
    m_window = Window(raw, WindowDeleter{});
    if (fullscreen) {
        SDL_SetWindowFullscreen(m_window.get(), SDL_WINDOW_FULLSCREEN_DESKTOP);
    }

    const std::uint32_t flags = SDL_RENDERER_ACCELERATED | (vsync ? SDL_RENDERER_PRESENTVSYNC : 0);
    SDL_Renderer* r = SDL_CreateRenderer(m_window.get(), -1, flags);
    if (r == nullptr) {
        return false;
    }
    m_renderer = Renderer(r, RendererDeleter{});
    SDL_SetRenderDrawBlendMode(m_renderer.get(), SDL_BLENDMODE_BLEND);
    SDL_RenderSetLogicalSize(m_renderer.get(), static_cast<int>(w), static_cast<int>(h));

    m_logical_w = w;
    m_logical_h = h;
    m_running = true;
    m_vsync = vsync;
    return true;
}

void EngineSDL2::shutdown() noexcept {
    m_textures.clear();
    m_text_cache.clear();
    m_fonts.clear();
    m_chunks.clear();
    m_renderer.reset();
    m_window.reset();
    Mix_Quit();
    IMG_Quit();
    TTF_Quit();
    SDL_Quit();
}

// ── Events & timing ──────────────────────────────────────────────────────────

std::vector<Event> EngineSDL2::poll_events() {
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
                ev.scan_name = SDL_GetScancodeName(e.key.keysym.scancode)
                                   ? SDL_GetScancodeName(e.key.keysym.scancode)
                                   : "";
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
            case SDL_MOUSEWHEEL:
                ev.type = EventType::MouseWheel;
                ev.y = e.wheel.y;
                break;
            default:
                continue;
        }
        events.push_back(std::move(ev));
    }
    return events;
}

float EngineSDL2::ticks() const noexcept {
    return static_cast<float>(SDL_GetTicks64());
}

void EngineSDL2::present() {
    SDL_RenderPresent(m_renderer.get());
}

// ── Window ───────────────────────────────────────────────────────────────────

void EngineSDL2::set_logical_size(std::uint32_t w, std::uint32_t h) {
    SDL_RenderSetLogicalSize(m_renderer.get(), static_cast<int>(w), static_cast<int>(h));
}

void EngineSDL2::set_fullscreen(bool on) {
    SDL_SetWindowFullscreen(m_window.get(), on ? SDL_WINDOW_FULLSCREEN_DESKTOP : 0);
}

void EngineSDL2::set_vsync(bool on) {
    if (on == m_vsync)
        return;
    m_vsync = on;

    SDL_RenderSetLogicalSize(m_renderer.get(), 0, 0);
    m_renderer.reset();

    m_textures.clear();
    m_text_cache.clear();
    DrawUtils::clear_cache();

    const std::uint32_t flags = SDL_RENDERER_ACCELERATED | (on ? SDL_RENDERER_PRESENTVSYNC : 0);
    SDL_Renderer* r = SDL_CreateRenderer(m_window.get(), -1, flags);
    if (r == nullptr) {
        r = SDL_CreateRenderer(m_window.get(), -1, SDL_RENDERER_ACCELERATED);
    }
    if (r == nullptr) {
        return;
    }
    m_renderer = Renderer(r, RendererDeleter{});
    SDL_SetRenderDrawBlendMode(m_renderer.get(), SDL_BLENDMODE_BLEND);
    SDL_RenderSetLogicalSize(
        m_renderer.get(), static_cast<int>(m_logical_w), static_cast<int>(m_logical_h));
}

void EngineSDL2::set_resolution(std::uint32_t w, std::uint32_t h) {
    SDL_SetWindowSize(m_window.get(), static_cast<int>(w), static_cast<int>(h));
    SDL_RenderSetLogicalSize(m_renderer.get(), static_cast<int>(w), static_cast<int>(h));
}

std::vector<std::array<std::int32_t, 3>> EngineSDL2::get_display_modes() {
    std::vector<std::array<std::int32_t, 3>> modes;
    const int displays = SDL_GetNumVideoDisplays();
    for (int d = 0; d < displays; ++d) {
        const int count = SDL_GetNumDisplayModes(d);
        for (int i = 0; i < count; ++i) {
            SDL_DisplayMode dm{};
            if (SDL_GetDisplayMode(d, i, &dm) == 0) {
                modes.push_back({dm.w, dm.h, dm.refresh_rate});
            }
        }
    }
    return modes;
}

// ── Drawing primitives ───────────────────────────────────────────────────────

void EngineSDL2::clear(std::uint8_t r, std::uint8_t g, std::uint8_t b, std::uint8_t a) {
    SDL_SetRenderDrawColor(m_renderer.get(), r, g, b, a);
    SDL_RenderClear(m_renderer.get());
}

void EngineSDL2::draw_rect(std::int32_t x, std::int32_t y, std::uint32_t w, std::uint32_t h,
                           std::uint8_t r, std::uint8_t g, std::uint8_t b, std::uint8_t a,
                           bool filled) {
    SDL_SetRenderDrawColor(m_renderer.get(), r, g, b, a);
    const SDL_Rect rect{x, y, static_cast<int>(w), static_cast<int>(h)};
    if (filled) {
        SDL_RenderFillRect(m_renderer.get(), &rect);
    } else {
        SDL_RenderDrawRect(m_renderer.get(), &rect);
    }
}

void EngineSDL2::line(std::int32_t x1, std::int32_t y1, std::int32_t x2, std::int32_t y2,
                      std::uint8_t r, std::uint8_t g, std::uint8_t b, std::uint8_t a) {
    SDL_SetRenderDrawColor(m_renderer.get(), r, g, b, a);
    SDL_RenderDrawLine(m_renderer.get(), x1, y1, x2, y2);
}

void EngineSDL2::circle(std::int32_t cx, std::int32_t cy, std::int32_t radius,
                        std::uint8_t r, std::uint8_t g, std::uint8_t b, std::uint8_t a,
                        bool filled) {
    if (radius <= 0)
        return;
    SDL_SetRenderDrawColor(m_renderer.get(), r, g, b, a);
    const auto r2 = static_cast<std::int64_t>(radius) * radius;
    for (std::int32_t dy = -radius; dy <= radius; ++dy) {
        const auto dy2 = static_cast<std::int64_t>(dy) * dy;
        const auto diff = r2 - dy2;
        if (diff < 0)
            continue;
        const int half = static_cast<int>(std::sqrt(static_cast<float>(diff)));
        const int w = half * 2 + 1;
        if (w > 0) {
            const SDL_Rect rect{cx - half, cy + dy, w, 1};
            if (filled) {
                SDL_RenderFillRect(m_renderer.get(), &rect);
            } else {
                SDL_RenderDrawPoint(m_renderer.get(), cx, cy + dy);
            }
        }
    }
}

// ── Textures ─────────────────────────────────────────────────────────────────

void EngineSDL2::draw_texture(const TextureHandle& tex,
                              std::int32_t dx, std::int32_t dy, std::uint32_t dw, std::uint32_t dh,
                              std::int32_t sx, std::int32_t sy, std::int32_t sw, std::int32_t sh,
                              std::optional<std::uint8_t> alpha) {
    auto it = m_textures.find(tex.id);
    if (it == m_textures.end()) {
        return;
    }
    SDL_Texture* t = it->second.get();
    if (alpha.has_value()) {
        SDL_SetTextureAlphaMod(t, *alpha);
    }

    SDL_Rect* sr_ptr = nullptr;
    SDL_Rect sr{};
    if (sx >= 0 && sy >= 0 && sw >= 0 && sh >= 0) {
        sr = SDL_Rect{sx, sy, sw, sh};
        sr_ptr = &sr;
    }
    const SDL_Rect dst{dx, dy, static_cast<int>(dw), static_cast<int>(dh)};
    SDL_RenderCopy(m_renderer.get(), t, sr_ptr, &dst);
    if (alpha.has_value()) {
        SDL_SetTextureAlphaMod(t, 255);
    }
}

void EngineSDL2::draw_texture_rotated(const TextureHandle& tex,
                                      std::int32_t dx, std::int32_t dy,
                                      std::uint32_t dw, std::uint32_t dh, float angle,
                                      std::optional<std::uint8_t> alpha) {
    auto it = m_textures.find(tex.id);
    if (it == m_textures.end()) {
        return;
    }
    SDL_Texture* t = it->second.get();
    if (alpha.has_value()) {
        SDL_SetTextureAlphaMod(t, *alpha);
    }

    const SDL_Rect dst{dx, dy, static_cast<int>(dw), static_cast<int>(dh)};
    SDL_RenderCopyEx(m_renderer.get(), t, nullptr, &dst, angle, nullptr, SDL_FLIP_NONE);
    if (alpha.has_value()) {
        SDL_SetTextureAlphaMod(t, 255);
    }
}

// ── Text ─────────────────────────────────────────────────────────────────────

bool EngineSDL2::draw_text(std::string_view text, std::int32_t x, std::int32_t y,
                           std::uint32_t font_size, std::uint8_t r, std::uint8_t g, std::uint8_t b,
                           std::uint8_t a, bool center, std::int32_t font_idx) {
    if (text.empty()) {
        return true;
    }

    std::int64_t fidx = font_idx;
    if (fidx < 0) {
        fidx = load_font(GameSettings::asset_path("font/font", ".ttf"),
                         static_cast<std::uint16_t>(font_size));
        if (fidx < 0) {
            return true;
        }
    }
    if (static_cast<std::size_t>(fidx) >= m_fonts.size()) {
        return true;
    }

    // FNV-1a cache key
    std::uint64_t h = 0xcbf29ce484222325ULL;
    for (unsigned char c : text) {
        h ^= c;
        h *= 0x100000001b3ULL;
    }
    h ^= (std::uint64_t(fidx) << 32) | (std::uint64_t(r) << 16) | (std::uint64_t(g) << 8) |
         std::uint64_t(b);
    h ^= std::uint64_t(a) << 24;

    auto it = m_text_cache.find(h);
    Tex tex;
    int tw{};
    int th{};
    if (it == m_text_cache.end()) {
        if (m_text_cache.size() > 2048) {
            m_text_cache.clear();
        }
        TTF_Font* font = m_fonts[fidx].get();
        SDL_Surface* surf =
            TTF_RenderUTF8_Blended(font, std::string(text).c_str(), rgba(r, g, b, a));
        if (surf == nullptr) {
            return true;
        }
        tw = surf->w;
        th = surf->h;
        SDL_Texture* raw = SDL_CreateTextureFromSurface(m_renderer.get(), surf);
        SDL_FreeSurface(surf);
        if (raw == nullptr) {
            return true;
        }
        SDL_SetTextureBlendMode(raw, SDL_BLENDMODE_BLEND);
        tex = Tex(raw, TextureDeleter{});
        m_text_cache.emplace(h, tex);
    } else {
        tex = it->second;
        SDL_QueryTexture(tex.get(), nullptr, nullptr, &tw, &th);
    }

    const int px = center ? (x - tw / 2) : x;
    const int py = center ? (y - th / 2) : y;
    const SDL_Rect dst{px, py, tw, th};
    SDL_RenderCopy(m_renderer.get(), tex.get(), nullptr, &dst);
    return true;
}

bool EngineSDL2::draw_text_rotated(std::string_view text, std::int32_t x, std::int32_t y,
                                   std::uint32_t font_size, float angle,
                                   std::uint8_t r, std::uint8_t g, std::uint8_t b,
                                   std::uint8_t a, bool center, std::int32_t font_idx) {
    if (text.empty()) {
        return true;
    }

    std::int64_t fidx = font_idx;
    if (fidx < 0) {
        fidx = load_font(GameSettings::asset_path("font/font", ".ttf"),
                         static_cast<std::uint16_t>(font_size));
        if (fidx < 0) {
            return true;
        }
    }
    if (static_cast<std::size_t>(fidx) >= m_fonts.size()) {
        return true;
    }

    TTF_Font* font = m_fonts[fidx].get();
    SDL_Surface* surf = TTF_RenderUTF8_Blended(font, std::string(text).c_str(), rgba(r, g, b, a));
    if (surf == nullptr) {
        return true;
    }
    int tw = surf->w;
    int th = surf->h;
    SDL_Texture* raw = SDL_CreateTextureFromSurface(m_renderer.get(), surf);
    SDL_FreeSurface(surf);
    if (raw == nullptr) {
        return true;
    }
    SDL_SetTextureBlendMode(raw, SDL_BLENDMODE_BLEND);

    const int px = center ? (x - tw / 2) : x;
    const int py = center ? (y - th / 2) : y;
    const SDL_Rect dst{px, py, tw, th};
    SDL_RenderCopyEx(m_renderer.get(), raw, nullptr, &dst, angle, nullptr, SDL_FLIP_NONE);
    SDL_DestroyTexture(raw);
    return true;
}

// ── Resources ────────────────────────────────────────────────────────────────

std::optional<TextureHandle> EngineSDL2::load_texture(std::string_view path) {
    SDL_Surface* surf = IMG_Load(std::string(path).c_str());
    if (surf == nullptr) {
        return std::nullopt;
    }
    SDL_Texture* raw = SDL_CreateTextureFromSurface(m_renderer.get(), surf);
    SDL_FreeSurface(surf);
    if (raw == nullptr) {
        return std::nullopt;
    }
    SDL_SetTextureBlendMode(raw, SDL_BLENDMODE_BLEND);
    const std::uint32_t id = m_next_id++;
    m_textures[id] = Tex(raw, TextureDeleter{});
    return TextureHandle{id};
}

std::optional<TextureHandle> EngineSDL2::create_target(std::uint32_t w, std::uint32_t h) {
    SDL_Texture* raw = SDL_CreateTexture(m_renderer.get(),
                                         SDL_PIXELFORMAT_RGBA8888,
                                         SDL_TEXTUREACCESS_TARGET,
                                         static_cast<int>(w),
                                         static_cast<int>(h));
    if (raw == nullptr) {
        return std::nullopt;
    }
    const std::uint32_t id = m_next_id++;
    m_textures[id] = Tex(raw, TextureDeleter{});
    return TextureHandle{id};
}

std::optional<SoundHandle> EngineSDL2::load_sound(std::string_view path) {
    Mix_Chunk* raw = Mix_LoadWAV(std::string(path).c_str());
    if (raw == nullptr) {
        return std::nullopt;
    }
    const std::uint32_t id = m_next_id++;
    m_chunks[id] = std::shared_ptr<Mix_Chunk>(raw, [](Mix_Chunk* c) { Mix_FreeChunk(c); });
    return SoundHandle{id};
}

std::int64_t EngineSDL2::load_font(std::string_view path, std::uint16_t size) {
    TTF_Font* raw = TTF_OpenFont(std::string(path).c_str(), size);
    if (raw == nullptr) {
        return -1;
    }
    const std::int64_t idx = static_cast<std::int64_t>(m_fonts.size());
    m_fonts.push_back(Font(raw, FontDeleter{}));
    return idx;
}

std::optional<std::array<std::int32_t, 2>> EngineSDL2::font_text_size(std::string_view text,
                                                                      std::uint32_t font_idx) {
    if (font_idx >= m_fonts.size()) {
        return std::nullopt;
    }
    int w{};
    int h{};
    if (TTF_SizeUTF8(m_fonts[font_idx].get(), std::string(text).c_str(), &w, &h) != 0) {
        return std::nullopt;
    }
    return std::array<std::int32_t, 2>{w, h};
}

std::pair<std::uint32_t, std::uint32_t> EngineSDL2::texture_size(std::uint32_t id) noexcept {
    auto it = m_textures.find(id);
    if (it == m_textures.end()) {
        return {0, 0};
    }
    int w{};
    int h{};
    SDL_QueryTexture(it->second.get(), nullptr, nullptr, &w, &h);
    return {static_cast<std::uint32_t>(w), static_cast<std::uint32_t>(h)};
}

// ── Render targets ───────────────────────────────────────────────────────────

void EngineSDL2::set_render_target(std::optional<TextureHandle> target) {
    if (target.has_value()) {
        auto it = m_textures.find(target->id);
        if (it != m_textures.end()) {
            m_active_target = target->id;
            SDL_SetRenderTarget(m_renderer.get(), it->second.get());
        }
    } else {
        m_active_target = std::nullopt;
        SDL_SetRenderTarget(m_renderer.get(), nullptr);
        SDL_RenderSetLogicalSize(
            m_renderer.get(), static_cast<int>(m_logical_w), static_cast<int>(m_logical_h));
    }
}

void EngineSDL2::reset_render_target() {
    set_render_target(std::nullopt);
}

// ── Sound ────────────────────────────────────────────────────────────────────

std::int32_t EngineSDL2::play_sound(const SoundHandle& snd, std::int32_t loops,
                                    std::int32_t channel) {
    auto it = m_chunks.find(snd.id);
    if (it != m_chunks.end() && it->second) {
        Mix_PlayChannel(channel, it->second.get(), loops);
    }
    return channel;
}

void EngineSDL2::stop_channel(std::int32_t channel) {
    Mix_HaltChannel(channel);
}

void EngineSDL2::stop_all_sounds() {
    Mix_HaltChannel(-1);
}

// ── Input ────────────────────────────────────────────────────────────────────

std::pair<std::int32_t, std::int32_t> EngineSDL2::mouse_pos() {
    int x{};
    int y{};
    SDL_GetMouseState(&x, &y);
    return {x, y};
}

// ── Volume ───────────────────────────────────────────────────────────────────

void EngineSDL2::set_master_volume(int vol) {
    m_master_vol = vol;
    int music_eff = (m_master_vol * m_music_vol * MIX_MAX_VOLUME) / 10000;
    int sfx_eff   = (m_master_vol * m_sfx_vol   * MIX_MAX_VOLUME) / 10000;
    Mix_VolumeMusic(music_eff);
    for (int ch = 0; ch < 16; ++ch)
        Mix_Volume(ch, sfx_eff);
}

void EngineSDL2::set_sfx_volume(int vol) {
    m_sfx_vol = vol;
    int eff = (m_master_vol * m_sfx_vol * MIX_MAX_VOLUME) / 10000;
    for (int ch = 0; ch < 16; ++ch)
        Mix_Volume(ch, eff);
}

void EngineSDL2::set_music_volume(int vol) {
    m_music_vol = vol;
    int eff = (m_master_vol * m_music_vol * MIX_MAX_VOLUME) / 10000;
    Mix_VolumeMusic(eff);
}

// ── Misc ─────────────────────────────────────────────────────────────────────

void EngineSDL2::update_discord(std::string_view, std::string_view) {
    // no-op for now
}

void EngineSDL2::on_vsync_change() {
    DrawUtils::clear_cache();
}

SDL_Texture* EngineSDL2::get_texture(std::uint32_t id) noexcept {
    auto it = m_textures.find(id);
    return (it == m_textures.end()) ? nullptr : it->second.get();
}

// ── Factory ──────────────────────────────────────────────────────────────────

Engine* create_engine() {
    return new EngineSDL2();
}

void destroy_engine(Engine* e) {
    delete e;
}

}  // namespace fnwf
