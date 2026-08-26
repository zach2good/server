/*
===========================================================================

  Copyright (c) 2021 Eden Dev Teams

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

#include "common/cbasetypes.h"
#include "common/timer.h"
#include "common/types/flag.h"
#include "common/types/fn.h"
#include "common/types/heap.h"
#include "common/types/maybe.h"

#include <compare>
#include <cstddef>

// Event scheduling for the Conflict (Ballista) system.
//
// A Vana'diel timestamp here is the count of Vana'diel minutes since the start of
// year 886, which is exactly vanadiel_clock::minutes since its epoch. It is the unit
// the Conflict scheduler, its Lua API and its database rows all speak in.
namespace timeutils
{

// Yes queues an event whose time has already passed so it fires on the next tick. No drops it
// instead, which is what a match recovered from the database wants for the ceremony it missed.
using ForceAdd = xi::Flag<struct ForceAddTag>;

struct TimelineEvent
{
    uint32            eventId  = 0;
    uint8             priority = 1; // Lower sorts first among events sharing a timestamp.
    timer::time_point time{};
    Fn<bool()>        action; // Returning true stops a repeating event.

    timer::duration repeatInterval = timer::duration::zero();
    Maybe<uint32>   repeatsLeft; // No value repeats until the action returns true.
};

inline auto operator<=>(const TimelineEvent& lhs, const TimelineEvent& rhs) noexcept -> std::strong_ordering
{
    if (const auto byTime = lhs.time <=> rhs.time; byTime != std::strong_ordering::equal)
    {
        return byTime;
    }

    if (const auto byPriority = lhs.priority <=> rhs.priority; byPriority != std::strong_ordering::equal)
    {
        return byPriority;
    }

    return lhs.eventId <=> rhs.eventId;
}

inline auto operator==(const TimelineEvent& lhs, const TimelineEvent& rhs) noexcept -> bool
{
    return (lhs <=> rhs) == std::strong_ordering::equal;
}

// A min-heap of pending events, drained by Tick as their timestamps come due.
class Timeline
{
public:
    void Tick(timer::time_point tick);
    void Clean();

    // Returns the id of the scheduled event, or no value when a skippable past-due event was dropped.
    [[nodiscard]] auto AddEvent(timer::time_point tp, Fn<bool()> action, ForceAdd forceAdd = ForceAdd::Yes, timer::duration repeatInterval = timer::duration::zero(), Maybe<uint32> repeatTimes = std::nullopt) -> Maybe<uint32>;

    // Runs ahead of every regular event sharing its timestamp.
    [[nodiscard]] auto AddPriorityEvent(timer::time_point tp, Fn<bool()> action) -> Maybe<uint32>;

    [[nodiscard]] auto empty() const noexcept -> bool;
    [[nodiscard]] auto size() const noexcept -> std::size_t;

private:
    auto Schedule(TimelineEvent timelineEvent, ForceAdd forceAdd) -> Maybe<uint32>;

    uint32                 nextEventId = 0;
    uint32                 generation  = 0; // Bumped by Clean, so a fired action can cancel the rest.
    MinHeap<TimelineEvent> events;
};

// Converts a Vana'diel timestamp to the tick clock the zone server runs on.
[[nodiscard]] auto GetTimePointFromVanaTimestamp(uint32 vanaTimestamp) -> timer::time_point;

[[nodiscard]] auto GetCurrentVanaTimestamp() -> uint32;

// The given time of day, offset by whole Vana'diel days from today.
[[nodiscard]] auto GetVanaTimestampAt(uint32 hour, uint32 minute = 0, int32 addedDays = 0) -> uint32;

// Midnight on the given date. The year is years since 886, matching vanadiel_time::get_year().
[[nodiscard]] auto GetVanaTimestampFromDate(int32 year, uint32 month, uint32 day) -> uint32;

} // namespace timeutils
