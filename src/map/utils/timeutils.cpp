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

#include "timeutils.h"

#include "common/vana_time.h"

#include <chrono>
#include <utility>

namespace
{

using VanaDays    = vanadiel_time::clock::days;
using VanaHours   = vanadiel_time::clock::hours;
using VanaMinutes = vanadiel_time::clock::minutes;
using VanaMonths  = vanadiel_time::clock::months;
using VanaYears   = vanadiel_time::clock::years;

auto toVanaTimestamp(const vanadiel_time::duration& sinceEpoch) -> uint32
{
    return static_cast<uint32>(std::chrono::floor<VanaMinutes>(sinceEpoch).count());
}

} // namespace

namespace timeutils
{

void Timeline::Tick(const timer::time_point tick)
{
    // An action may schedule more work, and a forced add can land in the past, so the drain needs
    // a ceiling of its own rather than trusting the heap to empty.
    constexpr auto kMaxEventsPerTick = 256;

    for (auto fired = 0; fired < kMaxEventsPerTick && !events.empty(); ++fired)
    {
        if (events.top().time > tick)
        {
            break;
        }

        auto timelineEvent = events.pop();

        const auto generationBefore = generation;
        const auto shouldStop       = timelineEvent.action();

        // The action emptied the timeline, so this event went with it and must not come back.
        if (generation != generationBefore)
        {
            return;
        }

        if (shouldStop || timelineEvent.repeatInterval == timer::duration::zero())
        {
            continue;
        }

        if (timelineEvent.repeatsLeft)
        {
            if (--*timelineEvent.repeatsLeft == 0)
            {
                continue;
            }
        }

        // Advance to the next occurrence strictly in the future. An event that is past due by
        // several intervals, such as a match recovered from the database, coalesces its whole
        // backlog into this single fire instead of announcing once per missed interval. The skip is
        // computed rather than stepped so a long backlog costs one division, not one iteration per
        // missed interval.
        const auto missed = static_cast<uint32>((tick - timelineEvent.time) / timelineEvent.repeatInterval);

        timelineEvent.time += (missed + 1) * timelineEvent.repeatInterval;

        timelineEvent.eventId = nextEventId++;
        events.push(std::move(timelineEvent));
    }
}

void Timeline::Clean()
{
    ++generation;
    events.clear();
}

auto Timeline::AddEvent(const timer::time_point tp, Fn<bool()> action, const ForceAdd forceAdd, const timer::duration repeatInterval, const Maybe<uint32> repeatTimes) -> Maybe<uint32>
{
    return Schedule(TimelineEvent{
                        .eventId        = nextEventId++,
                        .priority       = 1,
                        .time           = tp,
                        .action         = std::move(action),
                        .repeatInterval = repeatInterval,
                        .repeatsLeft    = repeatTimes,
                    },
                    forceAdd);
}

auto Timeline::AddPriorityEvent(const timer::time_point tp, Fn<bool()> action) -> Maybe<uint32>
{
    return Schedule(TimelineEvent{
                        .eventId  = nextEventId++,
                        .priority = 0,
                        .time     = tp,
                        .action   = std::move(action),
                    },
                    ForceAdd::Yes);
}

auto Timeline::Schedule(TimelineEvent timelineEvent, const ForceAdd forceAdd) -> Maybe<uint32>
{
    const auto now = timer::now();

    if (!forceAdd && timelineEvent.time < now)
    {
        // A one-shot event that is already late is simply dropped.
        if (timelineEvent.repeatInterval == timer::duration::zero())
        {
            return std::nullopt;
        }

        // Skip a repeating event forward to its first occurrence in the future, and charge the
        // skipped occurrences against its remaining repeats.
        auto skipped = static_cast<uint32>((now - timelineEvent.time) / timelineEvent.repeatInterval);
        timelineEvent.time += skipped * timelineEvent.repeatInterval;

        // Strictly in the future: landing exactly on now would fire on the very next tick, which
        // is the past-due replay this skip exists to avoid.
        if (timelineEvent.time <= now)
        {
            timelineEvent.time += timelineEvent.repeatInterval;
            ++skipped;
        }

        if (timelineEvent.repeatsLeft)
        {
            if (*timelineEvent.repeatsLeft <= skipped)
            {
                return std::nullopt;
            }

            *timelineEvent.repeatsLeft -= skipped;
        }
    }

    const auto eventId = timelineEvent.eventId;
    events.push(std::move(timelineEvent));

    return eventId;
}

auto Timeline::empty() const noexcept -> bool
{
    return events.empty();
}

auto Timeline::size() const noexcept -> std::size_t
{
    return events.size();
}

auto GetTimePointFromVanaTimestamp(const uint32 vanaTimestamp) -> timer::time_point
{
    const auto vanaTp = vanadiel_time::time_point{ VanaMinutes{ vanaTimestamp } };

    return timer::from_utc(vanadiel_time::to_earth_time(vanaTp));
}

auto GetCurrentVanaTimestamp() -> uint32
{
    return toVanaTimestamp(vanadiel_time::now().time_since_epoch());
}

auto GetVanaTimestampAt(const uint32 hour, const uint32 minute, const int32 addedDays) -> uint32
{
    const auto midnight = std::chrono::floor<VanaDays>(vanadiel_time::now().time_since_epoch());

    return toVanaTimestamp(midnight + VanaDays{ addedDays } + VanaHours{ hour } + VanaMinutes{ minute });
}

auto GetVanaTimestampFromDate(const int32 year, const uint32 month, const uint32 day) -> uint32
{
    return toVanaTimestamp(VanaYears{ year } + VanaMonths{ month - 1 } + VanaDays{ day - 1 });
}

} // namespace timeutils
