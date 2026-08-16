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

#include "conflictutils.h"

#include "common/logging.h"

#include "lua/luautils.h"
#include "utils/zoneutils.h"
#include "zone.h"

namespace conflictutils
{

auto CreateConflictInstance(ConflictSettings settings) -> ConflictInstance*
{
    auto* zone = zoneutils::GetZone(settings.zoneId);
    if (zone == nullptr)
    {
        ShowErrorFmt("conflictutils: zone {} is not loaded on this process, cannot start a Conflict match.",
                     std::to_underlying(settings.zoneId));
        return nullptr;
    }

    // Replacing a match tears the old one down first, so its players are released cleanly.
    zone->conflict = makeBox<ConflictInstance>(settings, zone);

    luautils::ConflictSetup(zone->conflict.get());

    return zone->conflict.get();
}

void DestroyConflictInstance(CZone* zone)
{
    if (zone == nullptr)
    {
        return;
    }

    zone->conflict.reset();
}

} // namespace conflictutils
