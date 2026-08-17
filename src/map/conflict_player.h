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
#include "common/types/flag.h"
#include "common/types/maybe.h"

#include "data/enums/job.h"

#include "utils/timeutils.h"

#include <chrono>

class CBaseEntity;
class CCharEntity;
class ConflictInstance;
class ConflictTeam;

namespace conflict
{

using namespace std::chrono_literals;

constexpr auto QuarryCooldown = 13s;
constexpr auto SprintCooldown = 45s;
constexpr auto ScoutCooldown  = 5s;
constexpr auto HintInterval   = 3min;

// A player dead in a match is revived at their camp after this delay, which grows with each
// reraise they have already taken this match.
constexpr auto ReraiseDelay      = 30s;
constexpr auto ReraiseDelayPerRR = 15s;

} // namespace conflict

// How firmly a character is committed to the match, which decides whether their entry fee is
// refundable and whether the entry survives them leaving.
enum class ConflictEntryType : uint8
{
    None               = 0,
    Locked             = 1,
    Temporary          = 2,
    Finalized          = 3,
    DischargedRefund   = 4,
    DischargedNoRefund = 5,
};

// One character's participation in a match. Outlives the CCharEntity, so that a player who
// zones out or logs off can rejoin the match they paid for.
class ConflictEntry
{
public:
    using Silent       = xi::Flag<struct SilentTag>;
    using SendUpdate   = xi::Flag<struct SendUpdateTag>;
    using GateBreachOn = xi::Flag<struct GateBreachOnTag>;

    ConflictEntry(CCharEntity* player, ConflictInstance* instance, uint8 teamIdx, ConflictEntryType entryType);
    // Recovers an entry from the database. score is the round in hand, totalScore the rounds
    // already banked; a best of three restarts the first between rounds.
    ConflictEntry(uint32 charid, ConflictInstance* instance, uint8 teamIdx, xi::Job job, ConflictEntryType entryType, uint32 points, uint32 score, uint32 totalScore);
    ~ConflictEntry();

    ConflictEntry(const ConflictEntry&)                    = delete;
    auto operator=(const ConflictEntry&) -> ConflictEntry& = delete;
    ConflictEntry(ConflictEntry&&)                         = delete;
    auto operator=(ConflictEntry&&) -> ConflictEntry&      = delete;

    void Tick(timer::time_point tick);
    void SendStatusUpdate();

    void RejoinPlayer(CCharEntity* player);
    void ChangeTeam(uint8 newTeamIdx);
    void PerformJoinUpdates();
    void ZoneOut();

    // Returns the gil the Herald hands back, if the entry is owed a refund.
    [[nodiscard]] auto Leave() -> Maybe<uint32>;

    auto AddPetras(int32 amount) -> int32;
    auto ScorePetras() -> int32;
    void SetGateBreach(GateBreachOn on = GateBreachOn::Yes, Silent silent = Silent::No);

    void Quarry();
    void Sprint();
    void Scout();

    void EnableCombat(bool enable);
    void Reraise();
    void UpdateMusic();
    void EnsureNonAnon();
    void SetupBattleCommunication();
    void SetupTemporaryInventory(SendUpdate sendUpdate = SendUpdate::No);

    // The active rook nearest the player, or nullptr when the player is out of the zone or the
    // match has no rooks placed yet.
    [[nodiscard]] auto ClosestRook() const -> CBaseEntity*;
    [[nodiscard]] auto ClosestRookDistance() const -> Maybe<float>;

    [[nodiscard]] auto HasActiveEntry() const -> bool;
    [[nodiscard]] auto IsInActiveConflict() const -> bool;
    [[nodiscard]] auto GetEntryType() const -> ConflictEntryType;
    [[nodiscard]] auto GetIndex() const -> uint8;
    [[nodiscard]] auto GetTeam() const -> ConflictTeam*;

    void SetEntryType(ConflictEntryType entryType);

    CCharEntity*      player   = nullptr;
    uint32            charid   = 0;
    uint8             teamIdx  = 0xFF;
    ConflictInstance* instance = nullptr;

    uint32  ballistaPoints    = 0;
    uint32  heldPetras        = 0;
    uint32  score             = 0;
    uint32  totalScoredPetras = 0;
    uint8   autoRaiseCounter  = 0;
    bool    hasGateBreach     = false;
    xi::Job job               = xi::Job::NONE;
    bool    gotInitialItems   = false;

private:
    timer::time_point nextSprint;
    timer::time_point nextQuarry;
    timer::time_point nextScout;
    timer::time_point nextHint = timer::time_point::max();

    // When a player who died in the match is due to be revived. No value means none is pending.
    Maybe<timer::time_point> reraiseTime;

    timeutils::Timeline gateBreachTimeline;

    ConflictEntryType entryType = ConflictEntryType::None;
    bool              savedToDb = false;
};
