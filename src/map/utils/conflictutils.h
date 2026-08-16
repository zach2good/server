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

} // namespace conflictutils
