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

#include "0x0e6_ballista.h"

#include "conflict_instance.h"
#include "conflict_player.h"
#include "conflict_team.h"
#include "entities/base_entity.h"
#include "entities/char_entity.h"

namespace GP_SERV_COMMAND_BALLISTA
{

SCOREBOARD::SCOREBOARD(const CCharEntity* PChar, const bool enabled)
{
    auto& packet = this->data();

    // The client drops this packet entirely unless Flags is 1, so a cleared board has to be sent
    // as a real update with nothing in it. Sending Flags = 0 instead leaves the last score up.
    if (!enabled)
    {
        packet.Flags = 1;
        packet.Mode  = 2;
        return;
    }

    if (PChar == nullptr || PChar->conflictEntry == nullptr)
    {
        return;
    }

    const auto* entry    = PChar->conflictEntry;
    const auto* instance = entry->instance;
    if (instance == nullptr)
    {
        return;
    }

    const auto* team0 = instance->GetTeam(0);
    const auto* team1 = instance->GetTeam(1);
    if (team0 == nullptr || team1 == nullptr)
    {
        return;
    }

    packet.Flags = 1;
    packet.Mode  = 2; // General scoreboard and information update.

    packet.PetraCount = static_cast<int32_t>(entry->heldPetras);

    packet.Score[0] = team0->score;
    packet.Score[1] = team1->score;

    // Which team's flag hangs on the viewer's side of the board.
    packet.Scoreboard[0] = static_cast<int16_t>(entry->teamIdx != 0);

    // The low three bits are the nations taking part, counted from San d'Oria. The client masks
    // off the viewer's own nation and uses whichever bit is left to pick the opposing team's icon;
    // with none of the three set it falls back on a generic pair of icons instead.
    packet.Scoreboard[1] = instance->GetNationBits();

    // The round markers beside each flag, at most two per side.
    packet.MatchPoints[0] = static_cast<uint8_t>(team0->roundsWon);
    packet.MatchPoints[1] = static_cast<uint8_t>(team1->roundsWon);

    // The client halves this, so the set has to go out doubled. Phases run 1 and 2 for the first
    // set, 3 and 4 for the second: sending the phase itself leaves the counter a set behind for
    // the whole of every round.
    packet.MatchSet = ToMatchSet(instance->gamePhase);

    // The flame lights are Brenner's, and the client draws them under the team icons whenever they
    // are set. A Ballista match has none.
    packet.Flammes   = 0;
    packet.FlammeFlg = 0;
}

SCOUT::SCOUT(const CBaseEntity* PRook, const float distanceToRook)
{
    auto& packet = this->data();

    packet.Flags = 1;
    packet.Mode  = 3; // Scout response.

    if (PRook == nullptr)
    {
        return;
    }

    packet.RookUniqueNo = PRook->id;

    // The client reads this one back as `RookDistance * 0.91399997 + 0.5`, so the distance it
    // finally shows is only the real one if the inverse goes out.
    constexpr auto kScoutDistanceScale  = 0.91399997f;
    constexpr auto kScoutDistanceOffset = 0.5f;

    const auto scoutDistance = (distanceToRook - kScoutDistanceOffset) / kScoutDistanceScale;

    // This packet carries the position as X, Z, Y rather than the usual X, Y, Z. Feeding it the
    // height where it wants the second horizontal axis points the compass somewhere else entirely.
    packet.RookPosition[0] = PRook->loc.p.x;
    packet.RookPosition[1] = PRook->loc.p.z;
    packet.RookPosition[2] = PRook->loc.p.y;
    packet.RookPosition[3] = scoutDistance;

    packet.RookDistance = scoutDistance;
}

} // namespace GP_SERV_COMMAND_BALLISTA
