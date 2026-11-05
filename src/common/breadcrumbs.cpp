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

#include "breadcrumbs.h"

#include <algorithm>
#include <exception>

namespace breadcrumbs
{

namespace
{

// Append-only lists of every ring ever created, one per kind. Readers walk them without locking.
std::atomic<Ring*>      gRings{ nullptr };
std::atomic<EventRing*> gEventRings{ nullptr };

template <typename RingT>
auto publish(std::atomic<RingT*>& registry, RingT* ring) -> RingT*
{
    ring->next = registry.load(std::memory_order_relaxed);
    while (!registry.compare_exchange_weak(ring->next, ring, std::memory_order_release, std::memory_order_relaxed))
    {
    }
    return ring;
}

// A slot copied out while its version was stable.
template <std::size_t SlotBytes>
struct SlotCopy
{
    const Site*      site{ nullptr };
    fmt::string_view format;
    RenderFn         render{ nullptr };
    std::uint64_t    stamp{ 0 };
    bool             truncated{ false };
    std::byte        args[BasicSlot<SlotBytes>::kArgBytes]{};
};

template <std::size_t SlotBytes>
auto tryCopy(const BasicSlot<SlotBytes>& slot, SlotCopy<SlotBytes>& out) -> bool
{
    const auto before = slot.version.load(std::memory_order_acquire);
    if ((before & 1U) != 0 || before == 0) // being written, or never written
    {
        return false;
    }

    out.site      = slot.site;
    out.format    = slot.format;
    out.render    = slot.render;
    out.stamp     = slot.stamp;
    out.truncated = slot.truncated;
    std::memcpy(out.args, slot.args, sizeof(out.args));

    std::atomic_thread_fence(std::memory_order_acquire);
    return slot.version.load(std::memory_order_relaxed) == before;
}

template <typename RingT>
void collect(const std::atomic<RingT*>& registry, std::vector<Entry>& entries)
{
    constexpr auto kSlotBytes = sizeof(typename RingT::Slot);

    for (const RingT* ring = registry.load(std::memory_order_acquire); ring != nullptr; ring = ring->next)
    {
        const auto head  = ring->head.load(std::memory_order_acquire);
        const auto count = head < RingT::kSlots ? head : RingT::kSlots;

        for (auto i = head - count; i < head; ++i)
        {
            SlotCopy<kSlotBytes> copy;
            if (!tryCopy(ring->slots[i & (RingT::kSlots - 1)], copy) || copy.site == nullptr || copy.render == nullptr)
            {
                continue;
            }

            Entry entry;
            entry.stamp = copy.stamp;
            entry.file  = copy.site->file;
            entry.line  = copy.site->line;
            try
            {
                copy.render(copy.format, copy.args, entry.message);
            }
            catch (const std::exception& e)
            {
                entry.message = fmt::format("<breadcrumb format error: {}>", e.what());
            }
            if (copy.truncated)
            {
                entry.message += "…";
            }
            entries.push_back(std::move(entry));
        }
    }
}

} // namespace

// Rings are never freed: crash dumps may read a ring whose thread has exited.
auto detail::registerRing() -> Ring*
{
    tlsRing = publish(gRings, new Ring());
    return tlsRing;
}

auto detail::registerEventRing() -> EventRing*
{
    tlsEventRing = publish(gEventRings, new EventRing());
    return tlsEventRing;
}

auto snapshot() -> std::vector<Entry>
{
    std::vector<Entry> entries;
    collect(gRings, entries);
    collect(gEventRings, entries);

    std::ranges::stable_sort(entries, {}, &Entry::stamp);
    return entries;
}

} // namespace breadcrumbs
