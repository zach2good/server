/*
===========================================================================

  Copyright (c) 2025 LandSandBoat Dev Teams

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

#include "base.h"

class CBaseEntity;
class CCharEntity;

// https://github.com/atom0s/XiPackets/tree/main/world/server/0x00E6
// This packet is sent by the server to inform the client of information related to PvP content. (ie. Ballista)
namespace GP_SERV_COMMAND_BALLISTA
{

// The client displays the set counter as MatchSet / 2, so a set goes out doubled. Phases count
// each set twice, once for the round and once for the break after it.
constexpr auto ToMatchSet(const uint8_t gamePhase) -> uint8_t
{
    return static_cast<uint8_t>(((gamePhase + 1) / 2) * 2);
}

// Mode=2 General Scoreboard / Information Update
class SCOREBOARD final : public GP_SERV_PACKET<PacketS2C::GP_SERV_COMMAND_BALLISTA, SCOREBOARD>
{
public:
    struct PacketData
    {
        uint16_t Flags : 6;      // PS2: Flags
        uint16_t Mode : 10;      // PS2: Mode
        uint16_t padding06;      // PS2: (New; did not exist.)
        int32_t  PetraCount;     // PS2: (New; did not exist.)
        int32_t  Score[3];       // PS2: (New; did not exist.)
        int16_t  Scoreboard[2];  // PS2: (New; did not exist.)
        uint8_t  MatchPoints[3]; // PS2: (New; did not exist.)
        uint8_t  MatchSet;       // PS2: (New; did not exist.)
        uint32_t Flammes;        // PS2: (New; did not exist.)
        int32_t  FlammeFlg;      // PS2: (New; did not exist.)
    };

    // The scoreboard as one player sees it. Pass enabled = false to send a cleared board, which
    // hides the client UI when the player leaves a match or combat is switched off.
    explicit SCOREBOARD(const CCharEntity* PChar, bool enabled = true);
};

// Mode=3 Scout Response
class SCOUT final : public GP_SERV_PACKET<PacketS2C::GP_SERV_COMMAND_BALLISTA, SCOUT>
{
public:
    struct PacketData
    {
        uint16_t Flags : 6;       // PS2: Flags
        uint16_t Mode : 10;       // PS2: Mode
        uint16_t padding06;       // PS2: (New; did not exist.)
        uint32_t RookUniqueNo;    // PS2: (New; did not exist.)
        uint32_t padding0C;       // PS2: (New; did not exist.)
        float    RookPosition[4]; // PS2: (New; did not exist.)
        float    RookDistance;    // PS2: (New; did not exist.)
    };

    // Answers a scout with where the nearest rook stands and how far off it is.
    SCOUT(const CBaseEntity* PRook, float distanceToRook);
};

} // namespace GP_SERV_COMMAND_BALLISTA
