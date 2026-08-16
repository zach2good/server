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

#include "conflict_instance.h"

namespace conflictutils
{

// Creates the Conflict match described by the settings and attaches it to its zone, replacing
// whatever match that zone was running. Returns nullptr when the zone is not on this process.
auto CreateConflictInstance(ConflictSettings settings) -> ConflictInstance*;

void DestroyConflictInstance(CZone* zone);

// True when any zone that hosts scheduled Ballista is loaded on this process.
[[nodiscard]] auto IsConflictProcess() -> bool;

// The match the Ballista calendar puts on the given date. Matches run on even days only, so an
// odd day returns settings with no zone set.
[[nodiscard]] auto GetBallistaSettingsFromDate(uint8 dayOfMonth, uint8 month, int32 year) -> ConflictSettings;

// The next scheduled match, which is today's if today is a match day. Cached per Vana'diel day.
[[nodiscard]] auto GetNextBallistaSettings() -> const ConflictSettings&;

// The gil a match costs to enter at a given level cap. A cap of zero means uncapped.
[[nodiscard]] auto GetEntryFeeFromLevelCap(uint8 levelCap) -> uint16;

// Seeds the matches bracketing now, once the zones and Vana'diel time are up.
void Initialize();

// Reaps finished matches and plans the next one. Individual matches are advanced by their own
// zone's tick, not from here.
void Tick(timer::time_point tick);

} // namespace conflictutils
