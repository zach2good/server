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
#include "entities/char_entity.h"

namespace GP_SERV_COMMAND_BALLISTA
{

SCOREBOARD::SCOREBOARD(const CCharEntity* PChar, const bool enabled)
{
    auto& packet = this->data();

    // Flags = 0 tells the client to take the scoreboard off screen.
    if (!enabled)
    {
        packet.Flags = 0;
        packet.Mode  = 0;
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
    packet.Scoreboard[1] = instance->GetNationBits();

    // The round markers beside each flag, at most two per side.
    packet.MatchPoints[0] = static_cast<uint8_t>(team0->roundsWon);
    packet.MatchPoints[1] = static_cast<uint8_t>(team1->roundsWon);

    // 1 is the first set, 2 is the break after it, 3 is the second set, and so on.
    packet.MatchSet = instance->gamePhase;

    // The flame lights belong to Brenner and stay constant throughout a Ballista match.
    packet.Flammes   = 0x48;
    packet.FlammeFlg = 0;
}

} // namespace GP_SERV_COMMAND_BALLISTA
