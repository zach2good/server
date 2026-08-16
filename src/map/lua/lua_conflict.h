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
#include "common/types/maybe.h"

#include "data/enums/conflict_signup_state.h"
#include "data/enums/conflict_state.h"
#include "data/enums/conflict_type.h"
#include "data/enums/zone.h"

#include "lua_timeline.h"
#include "luautils.h"

#include <cstddef>
#include <tuple>

class CBaseEntity;
class CLuaBaseEntity;
class CZone;
class ConflictEntry;
class ConflictInstance;

// The getTeam* methods each return two values, one per side, rather than a table. In Lua that
// reads as `local a, b = conflict:getTeamScores()`.
class CLuaConflict
{
public:
    explicit CLuaConflict(ConflictInstance* PConflict);

    [[nodiscard]] auto GetConflict() const -> ConflictInstance*
    {
        return m_PConflict;
    }

    [[nodiscard]] auto getTimelineAt(uint32 timestamp) const -> CLuaTimeline;
    void               cleanTimeline();

    [[nodiscard]] auto getStartTime() const -> uint32;
    [[nodiscard]] auto getEndTime() const -> uint32;
    void               setStartAndLength(uint32 start, uint32 length);

    [[nodiscard]] auto getZone() const -> CZone*;
    [[nodiscard]] auto getZoneID() const -> xi::ZoneId;
    [[nodiscard]] auto getRookCount() const -> uint8;
    [[nodiscard]] auto getMaxTeamSize() const -> uint8;
    void               configureGameSetup(uint32 maxTeamSize, uint32 rookCount);

    [[nodiscard]] auto getState() const -> xi::ConflictState;
    void               setState(xi::ConflictState state);

    [[nodiscard]] auto isCombatEnabled() const -> bool;
    void               setCombatEnabled(bool enabled);
    void               setLevelRestrictionEnabled(bool enabled);

    [[nodiscard]] auto getType() const -> xi::ConflictType;
    [[nodiscard]] auto getSignupFee() const -> uint32;
    [[nodiscard]] auto getLevelCap() const -> uint8;
    [[nodiscard]] auto hasItemRestriction() const -> bool;

    [[nodiscard]] auto getSignupState() const -> xi::ConflictSignupState;
    void               setSignupState(xi::ConflictSignupState state);

    void setPhase(uint8 phase);
    auto addTeamRoundWon(uint8 teamIdx, sol::optional<int32> roundsToAdd) -> bool;

    auto               addPlayer(CLuaBaseEntity& entity, sol::optional<uint8> teamIdx) -> bool;
    [[nodiscard]] auto hasPlayerLeft(CLuaBaseEntity& entity) const -> bool;

    [[nodiscard]] auto getPlayers(sol::this_state ts) const -> sol::table;
    [[nodiscard]] auto getEntries(sol::this_state ts) const -> sol::table;
    [[nodiscard]] auto getTeamPlayers(sol::this_state ts) const -> std::tuple<sol::table, sol::table>;
    [[nodiscard]] auto getTeamCounts() const -> std::tuple<std::size_t, std::size_t>;

    // The gil each member of a team would take home if they won, given the pot on the Herald.
    [[nodiscard]] auto getTeamWinnings() const -> std::tuple<int32, int32>;

    [[nodiscard]] auto getTeamScores() const -> std::tuple<int32, int32>;
    [[nodiscard]] auto getTeamRounds() const -> std::tuple<int32, int32>;
    [[nodiscard]] auto getTeamNations() const -> std::tuple<int32, int32>;
    [[nodiscard]] auto getTeamAllegiances() const -> std::tuple<int32, int32>;

    [[nodiscard]] auto getHighScorer() const -> ConflictEntry*;
    [[nodiscard]] auto getWinningTeam() -> Maybe<uint8>;

    [[nodiscard]] auto areRooksOpen() const -> bool;

    static void Register();

private:
    ConflictInstance* m_PConflict = nullptr;
};
