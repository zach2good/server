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

#include "data/enums/allegiance.h"

#include <vector>

class ConflictEntry;

enum class ConflictMusic : uint16
{
    None                 = 0,
    MarchOfTheHero       = 223,
    YouWantToLiveForever = 226,
};

// One side of a Conflict match. The instance owns the entries; this only points at them.
class ConflictTeam
{
public:
    explicit ConflictTeam(xi::Allegiance allegiance);

    void Tick(timer::time_point tick);
    void ResetRound();
    void UpdateMusic(bool isWinning);
    void UpdatePlayersInZone();

    [[nodiscard]] auto HasPlayersInZone() const -> bool;

    xi::Allegiance allegiance;
    int32          score     = 0;
    int32          roundsWon = 0;

    ConflictMusic     currentMusic    = ConflictMusic::None;
    ConflictMusic     nextMusic       = ConflictMusic::YouWantToLiveForever;
    timer::time_point nextMusicChange = timer::time_point::max();

    std::vector<ConflictEntry*> entries;

private:
    bool playersInZone = false;
};
