// explicit linear arena allocator (zig-flavoured: allocations are first-class,
// no hidden global operator-new for engine scratch memory).
#pragma once

#include <cstddef>
#include <cstdint>
#include <memory>
#include <new>

namespace fnwf
{

// A bump/linear arena. Every allocation is explicit: call arena.alloc<T>(n).
// Ranges can be checkpointed/reset; on reset no destructors are run (POD only).
class Arena final
{
public:
    explicit Arena(std::size_t capacity) noexcept
        : m_capacity(capacity)
    {
        m_data = std::make_unique<std::byte[]>(capacity);
    }

    Arena(const Arena&) = delete;
    auto operator=(const Arena&) -> Arena& = delete;
    Arena(Arena&&) = default;
    auto operator=(Arena&&) -> Arena& = default;

    [[nodiscard]] auto alloc_bytes(std::size_t n, std::size_t align = alignof(std::max_align_t)) noexcept -> void*
    {
        const auto addr = reinterpret_cast<std::size_t>(m_data.get() + m_offset);
        const auto aligned = (addr + align - 1) & ~(align - 1);
        const auto delta = aligned - addr;
        if (m_offset + delta + n > m_capacity)
        {
            return nullptr; // arena full -- explicit failure, no abort
        }
        m_offset += delta + n;
        return m_data.get() + (m_offset - n);
    }

    template <typename T>
    [[nodiscard]] auto alloc(std::size_t n = 1) noexcept -> T*
    {
        return static_cast<T*>(alloc_bytes(n * sizeof(T), alignof(T)));
    }

    void checkpoint() noexcept { m_checkpoint = m_offset; }
    void rollback() noexcept { m_offset = m_checkpoint; }
    void clear() noexcept { m_offset = 0; }
    [[nodiscard]] auto capacity() const noexcept -> std::size_t { return m_capacity; }
    [[nodiscard]] auto used() const noexcept -> std::size_t { return m_offset; }

private:
    std::size_t m_capacity{};
    std::size_t m_offset{};
    std::size_t m_checkpoint{};
    std::unique_ptr<std::byte[]> m_data{};
};

}; // namespace fnwf
