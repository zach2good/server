/*
===========================================================================

  Copyright (c) 2026 LandSandBoat Dev Teams

  This program is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with this program.  If not, see http://www.gnu.org/licenses/

===========================================================================
*/

#pragma once

//
// Breadcrumbs: a flight recorder for "what was this thread doing just before it crashed".
//
//   XI_BREADCRUMB("CZoneEntities::ZoneServer: Mob: {} ({})", PMob->getName(), PMob->id);
//
// Writing one is meant to be close to free, because some are written per entity per tick:
//   - every thread writes into its own fixed ring of fixed-size slots: no lock, no shared atomic,
//     no allocation;
//   - nothing is formatted at write time. A slot stores a pointer to the (literal) format string,
//     the call site, a decode-and-format function for the argument types, and the arguments as raw
//     bytes: arithmetic/enum/trivially-copyable values as-is, strings copied in (truncated to fit);
//   - the format string is still checked against the arguments at compile time.
//
// Formatting happens only when the rings are read (crash tombstone, the `backtrace` console
// command) -- see snapshot(), which never takes a lock, so it is safe to call from a crash handler
// that interrupted a write. A slot being rewritten while it is read is detected and skipped.
//
// Every log line (ShowInfo, ShowError, ...) is also copied into a separate, smaller per-thread "event"
// ring with larger slots (XI_BREADCRUMB_EVENT), so a busy tick of breadcrumbs cannot evict the
// warnings and errors you want after a crash.
//
// Rings are created on a thread's first write and are never freed, so a crash dump can still read a
// ring whose thread has exited.
//

#include <array>
#include <atomic>
#include <chrono>
#include <cstddef>
#include <cstdint>
#include <cstring>
#include <iterator>
#include <string>
#include <string_view>
#include <tuple>
#include <type_traits>
#include <vector>

#include <fmt/format.h>

#if defined(_MSC_VER)
#include <intrin.h>
#elif defined(__x86_64__) || defined(__i386__)
#include <x86intrin.h>
#endif

namespace breadcrumbs
{

// Kept small on purpose: the zone tick writes a breadcrumb per entity, and a ring that fits in L1
// (2 KiB / 8 KiB here) stays there instead of streaming tens of KiB through the cache every tick.
// A crash report wants the last few things each thread did, not a long history.

// Breadcrumb rings: small slots.
inline constexpr std::size_t kSlotBytes = 128;
inline constexpr std::size_t kRingSlots = 16; // per thread

// Event rings (copies of log lines): larger slots, so messages are rarely cut.
inline constexpr std::size_t kEventSlotBytes = 512;
inline constexpr std::size_t kEventRingSlots = 16; // per thread

// Where a breadcrumb was written. One static instance per call site (see XI_BREADCRUMB).
struct Site
{
    const char* file;
    int         line;
};

// Decodes a slot's argument bytes and appends the formatted message to `out`.
using RenderFn = void (*)(fmt::string_view format, const std::byte* args, std::string& out);

// Cheap, monotonic-enough timestamp used to merge rings into one timeline. The CPU cycle counter
// where there is one (a few ns), steady_clock otherwise. Only ever compared with itself.
[[nodiscard]] inline auto now() noexcept -> std::uint64_t
{
#if defined(_MSC_VER) && (defined(_M_X64) || defined(_M_IX86))
    return __rdtsc();
#elif defined(_MSC_VER) && defined(_M_ARM64)
    return static_cast<std::uint64_t>(_ReadStatusReg(ARM64_CNTVCT));
#elif defined(__x86_64__) || defined(__i386__)
    return __rdtsc();
#elif defined(__aarch64__)
    std::uint64_t value = 0;
    asm volatile("mrs %0, cntvct_el0" : "=r"(value));
    return value;
#else
    return static_cast<std::uint64_t>(std::chrono::steady_clock::now().time_since_epoch().count());
#endif
}

// The fields before `args` take this many bytes on 64-bit; the rest of a slot holds arguments.
inline constexpr std::size_t kSlotHeaderBytes = 48;

template <std::size_t SlotBytes>
struct BasicSlot
{
    static constexpr std::size_t kArgBytes = SlotBytes - kSlotHeaderBytes;

    // Odd while the owning thread is writing the slot; bumped twice per write (seqlock).
    std::atomic<std::uint32_t> version{ 0 };
    std::uint16_t              argBytes{ 0 };
    bool                       truncated{ false };
    const Site*                site{ nullptr };
    fmt::string_view           format;
    RenderFn                   render{ nullptr };
    std::uint64_t              stamp{ 0 };
    std::byte                  args[kArgBytes]{};
};

template <std::size_t SlotBytes, std::size_t SlotCount>
struct BasicRing
{
    static_assert((SlotCount & (SlotCount - 1)) == 0, "ring slot counts must be powers of two");
    static_assert(sizeof(BasicSlot<SlotBytes>) == SlotBytes, "slot layout changed: keep kSlotHeaderBytes in sync");

    using Slot = BasicSlot<SlotBytes>;

    static constexpr std::size_t kSlots = SlotCount;

    std::array<Slot, SlotCount> slots{};
    std::atomic<std::uint64_t>  head{ 0 };       // total writes; only the owning thread stores
    BasicRing*                  next{ nullptr }; // registry link, set before the ring is published
};

using Ring      = BasicRing<kSlotBytes, kRingSlots>;
using EventRing = BasicRing<kEventSlotBytes, kEventRingSlots>;

inline constexpr std::size_t kArgBytes = Ring::Slot::kArgBytes;

// One decoded breadcrumb, oldest first in snapshot().
struct Entry
{
    std::uint64_t stamp{ 0 };
    const char*   file{ nullptr };
    int           line{ 0 };
    std::string   message;
};

// Every breadcrumb and event still held by any thread's rings, oldest first. Lock-free; allocates.
[[nodiscard]] auto snapshot() -> std::vector<Entry>;

namespace detail
{

// Create and publish the calling thread's rings. Cold: once per thread each.
auto registerRing() -> Ring*;
auto registerEventRing() -> EventRing*;

// Constant-initialised, so access needs no TLS init guard.
inline thread_local Ring*      tlsRing      = nullptr;
inline thread_local EventRing* tlsEventRing = nullptr;

template <typename T>
concept StringLike = std::is_convertible_v<const T&, std::string_view>;

template <typename T>
concept RawValue = !StringLike<T> && std::is_trivially_copyable_v<T>;

// Bytes an argument takes in the fixed part of a slot. Strings store their length there and their
// characters in the variable tail.
template <typename T>
consteval auto fixedSize() -> std::size_t
{
    if constexpr (StringLike<T>)
    {
        return sizeof(std::uint16_t);
    }
    else
    {
        return sizeof(T);
    }
}

template <typename T>
using Decoded = std::conditional_t<StringLike<T>, std::string_view, T>;

template <typename T>
void encode(const T& value, std::byte*& fixed, std::byte*& tail, std::byte* const end, bool& truncated) noexcept
{
    if constexpr (StringLike<T>)
    {
        const std::string_view text   = value;
        const auto             room   = static_cast<std::size_t>(end - tail);
        const auto             length = text.size() < room ? text.size() : room;
        std::memcpy(tail, text.data(), length);
        tail += length;
        truncated |= length < text.size();

        const auto stored = static_cast<std::uint16_t>(length);
        std::memcpy(fixed, &stored, sizeof(stored));
        fixed += sizeof(stored);
    }
    else
    {
        std::memcpy(fixed, &value, sizeof(T));
        fixed += sizeof(T);
    }
}

template <typename T>
auto decode(const std::byte*& fixed, const std::byte*& tail) noexcept -> Decoded<T>
{
    if constexpr (StringLike<T>)
    {
        std::uint16_t length = 0;
        std::memcpy(&length, fixed, sizeof(length));
        fixed += sizeof(length);

        const std::string_view text(reinterpret_cast<const char*>(tail), length);
        tail += length;
        return text;
    }
    else
    {
        T value;
        std::memcpy(&value, fixed, sizeof(T));
        fixed += sizeof(T);
        return value;
    }
}

template <typename... Args>
inline constexpr std::size_t kFixedBytes = (fixedSize<Args>() + ... + 0);

template <typename... Args>
void render(const fmt::string_view format, const std::byte* args, std::string& out)
{
    const std::byte* fixed = args;
    const std::byte* tail  = args + kFixedBytes<Args...>;

    // Braced initialisation evaluates left to right, matching the encode order.
    const std::tuple<Decoded<Args>...> values{ decode<Args>(fixed, tail)... };

    std::apply(
        [&](const auto&... value)
        {
            fmt::vformat_to(std::back_inserter(out), format, fmt::make_format_args(value...));
        },
        values);
}

} // namespace detail

namespace detail
{

// Seqlock write of one slot: odd version, then the payload, then even version. Readers skip odd or
// changed slots. Only the ring's owning thread calls this.
template <typename RingT, typename... Args>
void writeInto(RingT& ring, const Site& site, const fmt::string_view format, const Args&... args) noexcept
{
    using Slot = typename RingT::Slot;
    static_assert(kFixedBytes<Args...> <= Slot::kArgBytes, "XI_BREADCRUMB: too many/large arguments for one slot");

    const auto index = ring.head.load(std::memory_order_relaxed);
    Slot&      slot  = ring.slots[index & (RingT::kSlots - 1)];

    const auto version = slot.version.load(std::memory_order_relaxed);
    slot.version.store(version + 1, std::memory_order_relaxed);
    std::atomic_thread_fence(std::memory_order_release);

    std::byte* fixed     = slot.args;
    std::byte* tail      = slot.args + kFixedBytes<Args...>;
    bool       truncated = false;
    (encode<Args>(args, fixed, tail, slot.args + Slot::kArgBytes, truncated), ...);

    slot.site      = &site;
    slot.format    = format;
    slot.render    = &render<Args...>;
    slot.stamp     = now();
    slot.argBytes  = static_cast<std::uint16_t>(tail - slot.args);
    slot.truncated = truncated;

    slot.version.store(version + 2, std::memory_order_release);
    ring.head.store(index + 1, std::memory_order_release);
}

} // namespace detail

// XI_BREADCRUMB backend: record into the calling thread's breadcrumb ring.
template <typename... Args>
void write(const Site& site, fmt::format_string<Args...> format, Args&&... args) noexcept
{
    static_assert((... && (detail::StringLike<std::decay_t<Args>> || detail::RawValue<std::decay_t<Args>>)),
                  "XI_BREADCRUMB arguments must be strings or trivially copyable values");

    Ring* ring = detail::tlsRing;
    if (ring == nullptr) [[unlikely]]
    {
        ring = detail::registerRing();
    }
    detail::writeInto<Ring, std::decay_t<Args>...>(*ring, site, format.get(), args...);
}

// XI_BREADCRUMB_EVENT backend: record an already formatted log line into the calling thread's event ring.
inline void writeEvent(const Site& site, const std::string_view message) noexcept
{
    EventRing* ring = detail::tlsEventRing;
    if (ring == nullptr) [[unlikely]]
    {
        ring = detail::registerEventRing();
    }
    detail::writeInto<EventRing, std::string_view>(*ring, site, "{}", message);
}

} // namespace breadcrumbs

// Record a breadcrumb: XI_BREADCRUMB("format {}", args...). See the top of this file.
#define XI_BREADCRUMB(...)                                                                   \
    do                                                                                       \
    {                                                                                        \
        static constexpr ::breadcrumbs::Site xiBreadcrumbSite_{ __FILE__, __LINE__ };        \
        ::breadcrumbs::write(xiBreadcrumbSite_, __VA_ARGS__);                                \
    } while (false)

// Copy an already formatted log line into the event ring. Used by the logging macros.
#define XI_BREADCRUMB_EVENT(File, Line, Message)                                             \
    do                                                                                       \
    {                                                                                        \
        static constexpr ::breadcrumbs::Site xiBreadcrumbEventSite_{ File, Line };           \
        ::breadcrumbs::writeEvent(xiBreadcrumbEventSite_, Message);                          \
    } while (false)
