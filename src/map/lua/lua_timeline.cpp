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

#include "lua_timeline.h"

#include "common/logging.h"

#include "utils/timeutils.h"

#include <chrono>
#include <utility>

using namespace std::chrono_literals;

namespace
{

// Adapts a Lua callback to the Timeline's action type. A callback that errors is reported once
// and then treated as "stop repeating", so a broken script cannot spam the log every interval.
auto toTimelineAction(sol::function eventFunc) -> Fn<bool()>
{
    return [eventFunc = std::move(eventFunc)]() -> bool
    {
        const auto result = eventFunc();
        if (!result.valid())
        {
            const sol::error err = result;
            ShowErrorFmt("CLuaTimeline: event failed: {}", err.what());

            return true;
        }

        return result.get<sol::optional<bool>>().value_or(false);
    };
}

} // namespace

CLuaTimeline::CLuaTimeline(timeutils::Timeline* timeline, const uint32 timestamp)
: timeline(timeline)
, vanaTimestamp(timestamp)
{
    if (timeline == nullptr)
    {
        ShowError("CLuaTimeline created with a null Timeline.");
    }
}

auto CLuaTimeline::addVanaTime(const int32 hours, const sol::optional<int32> minutes) -> CLuaTimeline*
{
    vanaTimestamp += hours * 60;
    vanaTimestamp += minutes.value_or(0);

    return this;
}

auto CLuaTimeline::addVanaMinutes(const int32 vanaMinutes) -> CLuaTimeline*
{
    vanaTimestamp += vanaMinutes;

    return this;
}

auto CLuaTimeline::setTime(const uint32 hours, const sol::optional<uint32> minutes, const sol::optional<int32> seconds) -> CLuaTimeline*
{
    vanaTimestamp = timeutils::GetVanaTimestampAt(hours, minutes.value_or(0));
    offsetMs      = seconds.value_or(0) * 1000;

    return this;
}

auto CLuaTimeline::setTimestamp(const uint32 timestamp) -> CLuaTimeline*
{
    vanaTimestamp = timestamp;
    offsetMs      = 0;

    return this;
}

auto CLuaTimeline::getTimestamp() const -> uint32
{
    return vanaTimestamp;
}

auto CLuaTimeline::offsetMilliseconds(const int32 offset) -> CLuaTimeline*
{
    offsetMs += offset;

    return this;
}

auto CLuaTimeline::offsetSeconds(const int32 offset) -> CLuaTimeline*
{
    offsetMs += offset * 1000;

    return this;
}

auto CLuaTimeline::resetOffset() -> CLuaTimeline*
{
    offsetMs = 0;

    return this;
}

auto CLuaTimeline::addEvent(sol::function eventFunc) -> Maybe<uint32>
{
    return timeline->AddEvent(timeutils::GetTimePointFromVanaTimestamp(vanaTimestamp) + std::chrono::milliseconds(offsetMs),
                              toTimelineAction(std::move(eventFunc)));
}

void CLuaTimeline::addSkippableEvent(sol::function eventFunc)
{
    timeline->AddEvent(timeutils::GetTimePointFromVanaTimestamp(vanaTimestamp) + std::chrono::milliseconds(offsetMs),
                       toTimelineAction(std::move(eventFunc)),
                       timeutils::ForceAdd::No);
}

void CLuaTimeline::addImportantEvent(sol::function eventFunc)
{
    timeline->AddPriorityEvent(timeutils::GetTimePointFromVanaTimestamp(vanaTimestamp) + std::chrono::milliseconds(offsetMs),
                               toTimelineAction(std::move(eventFunc)));
}

auto CLuaTimeline::addRepeatingEvent(sol::table options, sol::function eventFunc) -> bool
{
    const auto getU32 = [&](const char* key) -> uint32
    {
        return options.get<sol::optional<uint32>>(key).value_or(0);
    };

    auto repeatInterval = std::chrono::milliseconds{ 0 };

    // A Vana'diel minute is 2.4 Earth seconds.
    repeatInterval += getU32("vanaMinutes") * 2400ms;
    repeatInterval += getU32("vanaHours") * 60 * 2400ms;
    repeatInterval += std::chrono::duration_cast<std::chrono::milliseconds>(getU32("seconds") * 1s);
    repeatInterval += std::chrono::duration_cast<std::chrono::milliseconds>(getU32("minutes") * 1min);

    if (repeatInterval <= 0ms)
    {
        ShowWarning("CLuaTimeline: could not add a repeating event, because no interval was given.");
        return false;
    }

    // Absent means repeat until the action returns true.
    const auto repeatTimes = [&]() -> Maybe<uint32>
    {
        if (const auto times = options.get<sol::optional<uint32>>("times"))
        {
            return *times;
        }

        return std::nullopt;
    }();

    const auto forceAdd = [&]
    {
        if (const auto force = options.get<sol::optional<bool>>("force"))
        {
            return timeutils::ForceAdd{ *force };
        }

        return timeutils::ForceAdd{ !options.get<sol::optional<bool>>("skip").value_or(false) };
    }();

    timeline->AddEvent(timeutils::GetTimePointFromVanaTimestamp(vanaTimestamp) + std::chrono::milliseconds(offsetMs),
                       toTimelineAction(std::move(eventFunc)),
                       forceAdd,
                       repeatInterval,
                       repeatTimes);

    return true;
}

//======================================================//

void CLuaTimeline::Register()
{
    SOL_USERTYPE("CTimeline", CLuaTimeline);

    SOL_REGISTER("addVanaMinutes", CLuaTimeline::addVanaMinutes);
    SOL_REGISTER("addVanaTime", CLuaTimeline::addVanaTime);
    SOL_REGISTER("setTime", CLuaTimeline::setTime);
    SOL_REGISTER("setTimestamp", CLuaTimeline::setTimestamp);
    SOL_REGISTER("getTimestamp", CLuaTimeline::getTimestamp);
    SOL_REGISTER("offsetSeconds", CLuaTimeline::offsetSeconds);
    SOL_REGISTER("offsetMilliseconds", CLuaTimeline::offsetMilliseconds);
    SOL_REGISTER("resetOffset", CLuaTimeline::resetOffset);
    SOL_REGISTER("addEvent", CLuaTimeline::addEvent);
    SOL_REGISTER("addSkippableEvent", CLuaTimeline::addSkippableEvent);
    SOL_REGISTER("addImportantEvent", CLuaTimeline::addImportantEvent);
    SOL_REGISTER("addRepeatingEvent", CLuaTimeline::addRepeatingEvent);
}
