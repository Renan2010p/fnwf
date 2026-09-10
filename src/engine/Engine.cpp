#include "engine/Engine.hpp"
#include "core/DrawUtils.hpp"

#include <algorithm>
#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <string>

namespace fnwf {

namespace {
auto rgba(std::uint8_t r, std::uint8_t g, std::uint8_t b, std::uint8_t a) noexcept -> SDL_Color {
    return SDL_Color{r, g, b, a};
}
}  // namespace

auto Engine::new_instance(std::string_view title,
                          std::uint32_t w,
                          std::uint32_t h,
                          bool fullscreen,
                          bool vsync) -> std::expected<bool, std::string> {
    if (SDL_Init(SDL_INIT_VIDEO | SDL_INIT_AUDIO | SDL_INIT_TIMER) != 0) {
        return std::unexpected(SDL_GetError());
    }
    if (TTF_Init() != 0) {
        return std::unexpected(TTF_GetError());
    }
    if (!(IMG_Init(IMG_INIT_PNG) & IMG_INIT_PNG)) {
        return std::unexpected(IMG_GetError());
    }
    if (Mix_OpenAudio(44100, MIX_DEFAULT_FORMAT, 2, 1024) != 0) {
        return std::unexpected(Mix_GetError());
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
        return std::unexpected(SDL_GetError());
    }
    m_window = std::shared_ptr<SDL_Window>(raw, WindowDeleter{});
    if (fullscreen) {
        SDL_SetWindowFullscreen(m_window.get(), SDL_WINDOW_FULLSCREEN_DESKTOP);
    }

    const std::uint32_t flags = SDL_RENDERER_ACCELERATED | (vsync ? SDL_RENDERER_PRESENTVSYNC : 0);
    SDL_Renderer* r = SDL_CreateRenderer(m_window.get(), -1, flags);
    if (r == nullptr) {
        return std::unexpected(SDL_GetError());
    }
    m_renderer = std::shared_ptr<SDL_Renderer>(r, RendererDeleter{});
    SDL_SetRenderDrawBlendMode(m_renderer.get(), SDL_BLENDMODE_BLEND);
    SDL_RenderSetLogicalSize(m_renderer.get(), static_cast<int>(w), static_cast<int>(h));

    m_logical_w = w;
    m_logical_h = h;
    m_running = true;
    m_vsync = vsync;
    return true;
}

auto Engine::shutdown() noexcept -> void {
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

auto Engine::poll_events() -> std::vector<Event> {
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

auto Engine::ticks() const noexcept -> double {
    return static_cast<double>(SDL_GetTicks64());
}

auto Engine::present() -> void {
    SDL_RenderPresent(m_renderer.get());
}

auto Engine::set_logical_size(std::uint32_t w, std::uint32_t h) -> void {
    SDL_RenderSetLogicalSize(m_renderer.get(), static_cast<int>(w), static_cast<int>(h));
}

auto Engine::set_fullscreen(bool on) -> void {
    SDL_SetWindowFullscreen(m_window.get(), on ? SDL_WINDOW_FULLSCREEN_DESKTOP : 0);
}

auto Engine::set_vsync(bool on) -> void {
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
    m_renderer = std::shared_ptr<SDL_Renderer>(r, RendererDeleter{});
    SDL_SetRenderDrawBlendMode(m_renderer.get(), SDL_BLENDMODE_BLEND);
    SDL_RenderSetLogicalSize(
        m_renderer.get(), static_cast<int>(m_logical_w), static_cast<int>(m_logical_h));
}

auto Engine::set_resolution(std::uint32_t w, std::uint32_t h) -> void {
    SDL_SetWindowSize(m_window.get(), static_cast<int>(w), static_cast<int>(h));
    SDL_RenderSetLogicalSize(m_renderer.get(), static_cast<int>(w), static_cast<int>(h));
}

auto Engine::get_display_modes() -> std::vector<std::array<std::int32_t, 3>> {
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

auto Engine::clear(std::uint8_t r, std::uint8_t g, std::uint8_t b, std::uint8_t a) -> void {
    SDL_SetRenderDrawColor(m_renderer.get(), r, g, b, a);
    SDL_RenderClear(m_renderer.get());
}

auto Engine::draw_rect(std::int32_t x,
                       std::int32_t y,
                       std::uint32_t w,
                       std::uint32_t h,
                       std::uint8_t r,
                       std::uint8_t g,
                       std::uint8_t b,
                       std::uint8_t a,
                       bool filled) -> void {
    SDL_SetRenderDrawColor(m_renderer.get(), r, g, b, a);
    const SDL_Rect rect{x, y, static_cast<int>(w), static_cast<int>(h)};
    if (filled) {
        SDL_RenderFillRect(m_renderer.get(), &rect);
    } else {
        SDL_RenderDrawRect(m_renderer.get(), &rect);
    }
}

auto Engine::line(std::int32_t x1,
                  std::int32_t y1,
                  std::int32_t x2,
                  std::int32_t y2,
                  std::uint8_t r,
                  std::uint8_t g,
                  std::uint8_t b,
                  std::uint8_t a) -> void {
    SDL_SetRenderDrawColor(m_renderer.get(), r, g, b, a);
    SDL_RenderDrawLine(m_renderer.get(), x1, y1, x2, y2);
}

auto Engine::circle(std::int32_t cx,
                    std::int32_t cy,
                    std::int32_t radius,
                    std::uint8_t r,
                    std::uint8_t g,
                    std::uint8_t b,
                    std::uint8_t a,
                    bool filled) -> void {
    if (radius <= 0)
        return;
    SDL_SetRenderDrawColor(m_renderer.get(), r, g, b, a);
    const auto r2 = static_cast<std::int64_t>(radius) * radius;
    for (std::int32_t dy = -radius; dy <= radius; ++dy) {
        const auto dy2 = static_cast<std::int64_t>(dy) * dy;
        const auto diff = r2 - dy2;
        if (diff < 0)
            continue;
        const int half = static_cast<int>(std::sqrt(static_cast<double>(diff)));
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

auto Engine::draw_texture(const TextureHandle& tex,
                          std::int32_t dx,
                          std::int32_t dy,
                          std::uint32_t dw,
                          std::uint32_t dh,
                          std::int32_t sx,
                          std::int32_t sy,
                          std::int32_t sw,
                          std::int32_t sh,
                          std::optional<std::uint8_t> alpha) -> void {
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

auto Engine::draw_texture_rotated(const TextureHandle& tex,
                                  std::int32_t dx,
                                  std::int32_t dy,
                                  std::uint32_t dw,
                                  std::uint32_t dh,
                                  double angle,
                                  std::optional<std::uint8_t> alpha) -> void {
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

auto Engine::draw_text(std::string_view text,
                       std::int32_t x,
                       std::int32_t y,
                       std::uint32_t font_size,
                       std::uint8_t r,
                       std::uint8_t g,
                       std::uint8_t b,
                       std::uint8_t a,
                       bool center,
                       std::int32_t font_idx) -> bool {
    if (text.empty()) {
        return true;
    }

    // Find or create font for this size
    std::int64_t fidx = font_idx;
    if (fidx < 0) {
        fidx = load_font("assets/font/font.ttf", static_cast<std::uint16_t>(font_size));
        if (fidx < 0) {
            return true;
        }
    }
    if (static_cast<std::size_t>(fidx) >= m_fonts.size()) {
        return true;
    }

    // cache key: text + size + color
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

auto Engine::draw_text_rotated(std::string_view text,
                               std::int32_t x,
                               std::int32_t y,
                               std::uint32_t font_size,
                               double angle,
                               std::uint8_t r,
                               std::uint8_t g,
                               std::uint8_t b,
                               std::uint8_t a,
                               bool center,
                               std::int32_t font_idx) -> bool {
    if (text.empty()) {
        return true;
    }

    std::int64_t fidx = font_idx;
    if (fidx < 0) {
        fidx = load_font("assets/font/font.ttf", static_cast<std::uint16_t>(font_size));
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

auto Engine::load_texture(std::string_view path) -> std::optional<TextureHandle> {
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
    m_textures[id] = std::shared_ptr<SDL_Texture>(raw, TextureDeleter{});
    return TextureHandle{id};
}

auto Engine::create_target(std::uint32_t w, std::uint32_t h) -> std::optional<TextureHandle> {
    SDL_Texture* raw = SDL_CreateTexture(m_renderer.get(),
                                         SDL_PIXELFORMAT_RGBA8888,
                                         SDL_TEXTUREACCESS_TARGET,
                                         static_cast<int>(w),
                                         static_cast<int>(h));
    if (raw == nullptr) {
        return std::nullopt;
    }
    const std::uint32_t id = m_next_id++;
    m_textures[id] = std::shared_ptr<SDL_Texture>(raw, TextureDeleter{});
    return TextureHandle{id};
}

auto Engine::load_sound(std::string_view path) -> std::optional<SoundHandle> {
    Mix_Chunk* raw = Mix_LoadWAV(std::string(path).c_str());
    if (raw == nullptr) {
        return std::nullopt;
    }
    const std::uint32_t id = m_next_id++;
    m_chunks[id] = std::shared_ptr<Mix_Chunk>(raw, [](Mix_Chunk* c) { Mix_FreeChunk(c); });
    return SoundHandle{id};
}

auto Engine::load_font(std::string_view path, std::uint16_t size) -> std::int64_t {
    TTF_Font* raw = TTF_OpenFont(std::string(path).c_str(), size);
    if (raw == nullptr) {
        return -1;
    }
    const std::int64_t idx = static_cast<std::int64_t>(m_fonts.size());
    m_fonts.push_back(std::shared_ptr<TTF_Font>(raw, FontDeleter{}));
    return idx;
}

auto Engine::font_text_size(std::string_view text, std::uint32_t font_idx)
    -> std::optional<std::array<std::int32_t, 2>> {
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

auto Engine::texture_size(std::uint32_t id) noexcept -> std::pair<std::uint32_t, std::uint32_t> {
    auto it = m_textures.find(id);
    if (it == m_textures.end()) {
        return {0, 0};
    }
    int w{};
    int h{};
    SDL_QueryTexture(it->second.get(), nullptr, nullptr, &w, &h);
    return {static_cast<std::uint32_t>(w), static_cast<std::uint32_t>(h)};
}

auto Engine::set_render_target(std::optional<TextureHandle> target) -> void {
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

auto Engine::reset_render_target() -> void {
    set_render_target(std::nullopt);
}

auto Engine::play_sound(const SoundHandle& snd, std::int32_t loops, std::int32_t channel)
    -> std::int32_t {
    auto it = m_chunks.find(snd.id);
    if (it != m_chunks.end() && it->second) {
        Mix_PlayChannel(channel, it->second.get(), loops);
    }
    return channel;
}

auto Engine::stop_channel(std::int32_t channel) -> void {
    Mix_HaltChannel(channel);
}

auto Engine::stop_all_sounds() -> void {
    Mix_HaltChannel(-1);
}

auto Engine::mouse_pos() -> std::pair<std::int32_t, std::int32_t> {
    int x{};
    int y{};
    SDL_GetMouseState(&x, &y);
    return {x, y};
}

auto Engine::update_discord(std::string_view details, std::string_view state) -> void {
    (void)details;
    (void)state;
}

auto Engine::get_texture(std::uint32_t id) noexcept -> SDL_Texture* {
    auto it = m_textures.find(id);
    return (it == m_textures.end()) ? nullptr : it->second.get();
}

}  // namespace fnwf
