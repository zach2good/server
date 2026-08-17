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
#include "common/types/box.h"
#include "common/types/cached.h"
#include "common/types/flat_hash_map.h"
#include "common/types/maybe.h"

#include "data/enums/allegiance.h"
#include "data/enums/conflict_signup_state.h"
#include "data/enums/conflict_state.h"
#include "data/enums/conflict_type.h"
#include "data/enums/zone.h"

#include "conflict_team.h"
#include "utils/timeutils.h"

#include <array>
#include <vector>

class CZone;
class CCharEntity;
class ConflictEntry;

constexpr uint8 kConflictTeamCount = 2;

// An entry that has not been seated yet carries a team index outside the pair, so the other side
// of that is not a team either. Subtracting from one would promote to int and wrap back onto a
// real index instead.
constexpr auto OtherTeamIndex(const uint8 teamIdx) -> uint8
{
    if (teamIdx >= kConflictTeamCount)
    {
        return teamIdx;
    }

    return static_cast<uint8>(kConflictTeamCount - 1 - teamIdx);
}

// A finished match is kept for a full Vana'diel day so that stragglers can still collect from the
// Herald. Its database row has to outlive it by at least as long.
constexpr uint32 kCleanupGraceVanaMinutes = 60 * 24;

struct ConflictSettings
{
    xi::ZoneId       zoneId = xi::ZoneId::Unknown;
    xi::Allegiance   team1  = xi::Allegiance::Mob;
    xi::Allegiance   team2  = xi::Allegiance::Mob;
    xi::ConflictType type   = xi::ConflictType::AllOrNothing;

    uint8  levelCap            = 0;
    bool   restrictNormalItems = true;
    uint8  tempItemSize        = 10;
    bool   initialTempItems    = false;
    uint16 signupFee           = 0;

    // A scheduled match runs the Herald sign-up flow. An ad-hoc match skips straight to play.
    bool   isScheduled = true;
    uint32 matchStart  = 0; // Vana'diel timestamp
    uint32 matchLength = 0; // Vana'diel minutes
};

// One Conflict (Ballista) match. Owns its teams and every entry in it, including the entries of
// players who have left, so that they can rejoin.
class ConflictInstance
{
public:
    ConflictInstance(ConflictSettings settings, CZone* zone);

    // Detaches from the zone, tears the match down in Lua, and drops an ad-hoc match's database row.
    ~ConflictInstance();

    ConflictInstance(const ConflictInstance&)                    = delete;
    auto operator=(const ConflictInstance&) -> ConflictInstance& = delete;
    ConflictInstance(ConflictInstance&&)                         = delete;
    auto operator=(ConflictInstance&&) -> ConflictInstance&      = delete;

    // Returns the index of the team the player joined.
    [[nodiscard]] auto AddPlayer(CCharEntity* player, Maybe<uint8> requestedTeamIdx) -> Maybe<uint8>;
    [[nodiscard]] auto TryRejoinPlayer(CCharEntity* player) -> bool;

    void Tick(timer::time_point tick);
    void BroadcastStatusUpdate();
    void ScoreUpdate(ConflictEntry* entry = nullptr);
    void SetPhase(uint8 newPhase);
    void AddTeamRounds(uint8 teamIdx, int32 rounds = 1);
    void ConfigureGameSetup(uint32 maxTeamSize, uint32 rookCount);

    void SetCombatEnabled(bool enable);
    void SetLevelRestrictionEnabled(bool enable);
    void SetState(xi::ConflictState newState);

    void UpdateOpenRooks();

    [[nodiscard]] auto RemoveEntryAndTakeGilFromHerald(ConflictEntry* entry) -> Maybe<uint32>;

    // The pot cannot be rebuilt from the entries: a winner who already collected took more than
    // they put in, so counting the fees back would hand the rest a share that was already paid.
    void PersistGilOnHerald() const;

    [[nodiscard]] auto GetWinningTeamIndex() -> Maybe<uint8>;
    [[nodiscard]] auto GetId() const -> uint32;
    [[nodiscard]] auto GetState() const -> xi::ConflictState;
    [[nodiscard]] auto GetSignupFee() const -> uint32;
    [[nodiscard]] auto GetGilOnHerald() const -> uint32;
    [[nodiscard]] auto GetNationBits() const -> uint8;
    [[nodiscard]] auto IsActive() const -> bool;
    [[nodiscard]] auto IsCombatEnabled() const -> bool;
    [[nodiscard]] auto IsLevelRestrictionEnabled() const -> bool;
    [[nodiscard]] auto HasOpenRooks() const -> bool;
    [[nodiscard]] auto GetTeam(uint8 teamIdx) const -> ConflictTeam*;

    ConflictSettings        settings;
    timer::time_point       cleanupTime = timer::time_point::max();
    timeutils::Timeline     timeline;
    xi::ConflictSignupState signupState = xi::ConflictSignupState::Nations;

    CZone*                                            zone = nullptr;
    std::array<Box<ConflictTeam>, kConflictTeamCount> teams;
    FlatHashMap<uint32, Box<ConflictEntry>>           entries;
    FlatHashMap<uint32, Box<ConflictEntry>>           oldEntries;

    uint8               maxTeamSize = 0;
    uint8               rookCount   = 0;
    std::vector<uint32> activeRooks;

    uint8 gamePhase = 0;

    ConflictEntry* highScorer = nullptr;

private:
    [[nodiscard]] auto RemovePlayerEntry(uint32 charId) -> bool;

    // Entries as they stand right now. Anything that calls into Lua while walking them needs this:
    // a script can seat or discharge a player, and either rehashes the map out from under a
    // range-for. Discharging moves the entry into oldEntries rather than freeing it, so the
    // pointers stay good for the rest of the pass.
    [[nodiscard]] auto SnapshotEntries() const -> std::vector<ConflictEntry*>;

    uint32            id         = 0;
    xi::ConflictState state      = xi::ConflictState::Setup;
    uint8             nationBits = 0;

    bool combatEnabled           = false;
    bool levelRestrictionEnabled = false;
    bool openRooks               = false;

    // Outer: whether the result has been worked out yet. Inner: no value for a draw.
    Cached<Maybe<uint8>> winningTeam;

    uint32 gilOnHerald = 0;
};
