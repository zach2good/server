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
#include "common/types/maybe.h"

#include "luautils.h"

namespace timeutils
{

class Timeline;

}

// A Lua handle onto a timeutils::Timeline, holding a Vana'diel timestamp and a real-time offset
// as a cursor. Match scripts move the cursor and then hang events off it, so the setters return
// this to let calls chain.
class CLuaTimeline
{
public:
    CLuaTimeline(timeutils::Timeline* timeline, uint32 timestamp);

    auto addVanaTime(int32 hours, sol::optional<int32> minutes) -> CLuaTimeline*;
    auto addVanaMinutes(int32 vanaMinutes) -> CLuaTimeline*;
    auto setTime(uint32 hours, sol::optional<uint32> minutes, sol::optional<int32> seconds) -> CLuaTimeline*;
    auto setTimestamp(uint32 timestamp) -> CLuaTimeline*;

    [[nodiscard]] auto getTimestamp() const -> uint32;

    auto offsetMilliseconds(int32 offset) -> CLuaTimeline*;
    auto offsetSeconds(int32 offset) -> CLuaTimeline*;
    auto resetOffset() -> CLuaTimeline*;

    [[nodiscard]] auto eventTime() const -> timer::time_point;

    // Returns the scheduled event id, or no value when the event was dropped as past due.
    auto addEvent(sol::function eventFunc) -> Maybe<uint32>;
    auto addSkippableEvent(sol::function eventFunc) -> Maybe<uint32>;
    auto addImportantEvent(sol::function eventFunc) -> Maybe<uint32>;
    auto addRepeatingEvent(sol::table options, sol::function eventFunc) -> bool;

    static void Register();

    timeutils::Timeline* timeline      = nullptr;
    uint32               vanaTimestamp = 0;
    int32                offsetMs      = 0;
};
