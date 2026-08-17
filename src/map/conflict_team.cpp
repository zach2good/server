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

#include "conflict_team.h"

#include "conflict_player.h"

#include <algorithm>
#include <chrono>

using namespace std::chrono_literals;

namespace
{

// A track is left alone for at least its own length, so a lead that changes hands repeatedly
// does not restart the music on every swing.
constexpr auto getMusicLength(const ConflictMusic music) -> timer::duration
{
    if (music == ConflictMusic::MarchOfTheHero)
    {
        return 3min + 15s;
    }

    return 3min;
}

} // namespace

ConflictTeam::ConflictTeam(const xi::Allegiance allegiance)
: allegiance(allegiance)
{
}

void ConflictTeam::Tick(const timer::time_point tick)
{
    if (currentMusic == nextMusic || tick < nextMusicChange)
    {
        return;
    }

    // The track about to play, not the one leaving. The guard exists so a track is left alone for
    // its own length, which is a fact about the new one.
    currentMusic    = nextMusic;
    nextMusicChange = tick + getMusicLength(currentMusic);

    for (auto* entry : entries)
    {
        entry->UpdateMusic();
    }
}

void ConflictTeam::ResetRound()
{
    score           = 0;
    currentMusic    = ConflictMusic::None;
    nextMusic       = ConflictMusic::YouWantToLiveForever;
    nextMusicChange = timer::time_point::min();
}

void ConflictTeam::UpdateMusic(const bool isWinning)
{
    nextMusic = [&]
    {
        if (isWinning)
        {
            return ConflictMusic::MarchOfTheHero;
        }

        return ConflictMusic::YouWantToLiveForever;
    }();
}
