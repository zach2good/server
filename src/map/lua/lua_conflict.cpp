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

#include "lua_conflict.h"

#include "common/logging.h"

#include "conflict_instance.h"
#include "conflict_player.h"
#include "conflict_team.h"
#include "entities/char_entity.h"
#include "lua_base_entity.h"
#include "zone.h"

#include <algorithm>
#include <utility>

namespace
{

// Scripts count nations from zero, while allegiance starts them at San d'Oria.
auto toNationIndex(const xi::Allegiance allegiance) -> int32
{
    return std::to_underlying(allegiance) - std::to_underlying(xi::Allegiance::SanDoria);
}

} // namespace

CLuaConflict::CLuaConflict(ConflictInstance* PConflict)
: m_PConflict(PConflict)
{
    if (PConflict == nullptr)
    {
        ShowError("CLuaConflict created with a null ConflictInstance.");
    }
}

auto CLuaConflict::getTimelineAt(const uint32 timestamp) const -> CLuaTimeline
{
    return CLuaTimeline(&m_PConflict->timeline, timestamp);
}

void CLuaConflict::cleanTimeline()
{
    m_PConflict->timeline.Clean();
}

auto CLuaConflict::getStartTime() const -> uint32
{
    return m_PConflict->settings.matchStart;
}

auto CLuaConflict::getEndTime() const -> uint32
{
    return m_PConflict->settings.matchStart + m_PConflict->settings.matchLength;
}

void CLuaConflict::setStartAndLength(const uint32 start, const uint32 length)
{
    m_PConflict->settings.matchStart  = start;
    m_PConflict->settings.matchLength = length;
}

auto CLuaConflict::getZone() const -> CZone*
{
    return m_PConflict->zone;
}

auto CLuaConflict::getZoneID() const -> xi::ZoneId
{
    return m_PConflict->settings.zoneId;
}

auto CLuaConflict::getRookCount() const -> uint8
{
    return m_PConflict->rookCount;
}

auto CLuaConflict::getMaxTeamSize() const -> uint8
{
    return m_PConflict->maxTeamSize;
}

void CLuaConflict::configureGameSetup(const uint32 maxTeamSize, const uint32 rookCount)
{
    m_PConflict->ConfigureGameSetup(maxTeamSize, rookCount);
}

auto CLuaConflict::getState() const -> xi::ConflictState
{
    return m_PConflict->GetState();
}

void CLuaConflict::setState(const xi::ConflictState state)
{
    m_PConflict->SetState(state);
}

auto CLuaConflict::isCombatEnabled() const -> bool
{
    return m_PConflict->IsCombatEnabled();
}

void CLuaConflict::setCombatEnabled(const bool enabled)
{
    m_PConflict->SetCombatEnabled(enabled);
}

void CLuaConflict::setLevelRestrictionEnabled(const bool enabled)
{
    m_PConflict->SetLevelRestrictionEnabled(enabled);
}

auto CLuaConflict::getType() const -> xi::ConflictType
{
    return m_PConflict->settings.type;
}

auto CLuaConflict::getSignupFee() const -> uint32
{
    return m_PConflict->GetSignupFee();
}

auto CLuaConflict::getLevelCap() const -> uint8
{
    return m_PConflict->settings.levelCap;
}

auto CLuaConflict::hasItemRestriction() const -> bool
{
    return m_PConflict->settings.restrictNormalItems;
}

auto CLuaConflict::getSignupState() const -> xi::ConflictSignupState
{
    return m_PConflict->signupState;
}

void CLuaConflict::setSignupState(const xi::ConflictSignupState state)
{
    m_PConflict->signupState = state;
}

void CLuaConflict::setPhase(const uint8 phase)
{
    m_PConflict->SetPhase(phase);
}

auto CLuaConflict::addTeamRoundWon(const uint8 teamIdx, const sol::optional<int32> roundsToAdd) -> bool
{
    if (teamIdx >= kConflictTeamCount)
    {
        ShowErrorFmt("CLuaConflict::addTeamRoundWon: invalid team index {}.", teamIdx);
        return false;
    }

    m_PConflict->AddTeamRounds(teamIdx, roundsToAdd.value_or(1));

    return true;
}

auto CLuaConflict::addPlayer(CLuaBaseEntity& entity, const sol::optional<uint8> teamIdx) -> bool
{
    auto* player = dynamic_cast<CCharEntity*>(entity.GetBaseEntity());
    if (player == nullptr)
    {
        return false;
    }

    const auto requestedTeam = [&]() -> Maybe<uint8>
    {
        if (teamIdx)
        {
            return *teamIdx;
        }

        return std::nullopt;
    }();

    return m_PConflict->AddPlayer(player, requestedTeam).has_value();
}

auto CLuaConflict::hasPlayerLeft(CLuaBaseEntity& entity) const -> bool
{
    const auto* player = dynamic_cast<CCharEntity*>(entity.GetBaseEntity());
    if (player == nullptr)
    {
        return false;
    }

    return m_PConflict->oldEntries.contains(player->id);
}

auto CLuaConflict::getPlayers(sol::this_state ts) const -> sol::table
{
    auto lua   = sol::state_view(ts);
    auto table = lua.create_table();

    for (const auto& [charid, entry] : m_PConflict->entries)
    {
        if (entry->player && entry->HasActiveEntry())
        {
            table.add(entry->player);
        }
    }

    return table;
}

auto CLuaConflict::getEntries(sol::this_state ts) const -> sol::table
{
    auto lua   = sol::state_view(ts);
    auto table = lua.create_table();

    for (const auto& [charid, entry] : m_PConflict->entries)
    {
        table.add(entry.get());
    }

    return table;
}

auto CLuaConflict::getTeamPlayers(sol::this_state ts) const -> std::tuple<sol::table, sol::table>
{
    auto lua = sol::state_view(ts);

    const auto playersOf = [&](const uint8 teamIdx)
    {
        auto table = lua.create_table();

        const auto* team = m_PConflict->GetTeam(teamIdx);
        if (team == nullptr)
        {
            return table;
        }

        for (const auto* entry : team->entries)
        {
            if (entry->player)
            {
                table.add(entry->player);
            }
        }

        return table;
    };

    return { playersOf(0), playersOf(1) };
}

auto CLuaConflict::getTeamCounts() const -> std::tuple<std::size_t, std::size_t>
{
    return { m_PConflict->GetTeam(0)->entries.size(), m_PConflict->GetTeam(1)->entries.size() };
}

auto CLuaConflict::getTeamWinnings() const -> std::tuple<int32, int32>
{
    const auto total = static_cast<int32>(m_PConflict->entries.size()) * m_PConflict->settings.signupFee;

    const auto shareFor = [&](const uint8 teamIdx) -> int32
    {
        return total / std::max<int32>(1, static_cast<int32>(m_PConflict->GetTeam(teamIdx)->entries.size()));
    };

    return { shareFor(0), shareFor(1) };
}

auto CLuaConflict::getTeamScores() const -> std::tuple<int32, int32>
{
    return { m_PConflict->GetTeam(0)->score, m_PConflict->GetTeam(1)->score };
}

auto CLuaConflict::getTeamRounds() const -> std::tuple<int32, int32>
{
    return { m_PConflict->GetTeam(0)->roundsWon, m_PConflict->GetTeam(1)->roundsWon };
}

auto CLuaConflict::getTeamNations() const -> std::tuple<int32, int32>
{
    return { toNationIndex(m_PConflict->GetTeam(0)->allegiance), toNationIndex(m_PConflict->GetTeam(1)->allegiance) };
}

auto CLuaConflict::getTeamAllegiances() const -> std::tuple<int32, int32>
{
    return { std::to_underlying(m_PConflict->GetTeam(0)->allegiance), std::to_underlying(m_PConflict->GetTeam(1)->allegiance) };
}

auto CLuaConflict::getHighScorer() const -> ConflictEntry*
{
    return m_PConflict->highScorer;
}

auto CLuaConflict::getWinningTeam() -> Maybe<uint8>
{
    return m_PConflict->GetWinningTeamIndex();
}

auto CLuaConflict::areRooksOpen() const -> bool
{
    return m_PConflict->HasOpenRooks();
}

//======================================================//

void CLuaConflict::Register()
{
    SOL_USERTYPE("CConflict", CLuaConflict);

    SOL_REGISTER("getTimelineAt", CLuaConflict::getTimelineAt);
    SOL_REGISTER("cleanTimeline", CLuaConflict::cleanTimeline);
    SOL_REGISTER("getStartTime", CLuaConflict::getStartTime);
    SOL_REGISTER("getEndTime", CLuaConflict::getEndTime);
    SOL_REGISTER("setStartAndLength", CLuaConflict::setStartAndLength);
    SOL_REGISTER("getZone", CLuaConflict::getZone);
    SOL_REGISTER("getZoneID", CLuaConflict::getZoneID);
    SOL_REGISTER("getRookCount", CLuaConflict::getRookCount);
    SOL_REGISTER("getMaxTeamSize", CLuaConflict::getMaxTeamSize);
    SOL_REGISTER("configureGameSetup", CLuaConflict::configureGameSetup);
    SOL_REGISTER("getState", CLuaConflict::getState);
    SOL_REGISTER("setState", CLuaConflict::setState);
    SOL_REGISTER("isCombatEnabled", CLuaConflict::isCombatEnabled);
    SOL_REGISTER("setCombatEnabled", CLuaConflict::setCombatEnabled);
    SOL_REGISTER("setLevelRestrictionEnabled", CLuaConflict::setLevelRestrictionEnabled);
    SOL_REGISTER("getType", CLuaConflict::getType);
    SOL_REGISTER("getSignupFee", CLuaConflict::getSignupFee);
    SOL_REGISTER("getLevelCap", CLuaConflict::getLevelCap);
    SOL_REGISTER("hasItemRestriction", CLuaConflict::hasItemRestriction);
    SOL_REGISTER("getSignupState", CLuaConflict::getSignupState);
    SOL_REGISTER("setSignupState", CLuaConflict::setSignupState);
    SOL_REGISTER("setPhase", CLuaConflict::setPhase);
    SOL_REGISTER("addTeamRoundWon", CLuaConflict::addTeamRoundWon);
    SOL_REGISTER("addPlayer", CLuaConflict::addPlayer);
    SOL_REGISTER("hasPlayerLeft", CLuaConflict::hasPlayerLeft);
    SOL_REGISTER("getPlayers", CLuaConflict::getPlayers);
    SOL_REGISTER("getEntries", CLuaConflict::getEntries);
    SOL_REGISTER("getTeamPlayers", CLuaConflict::getTeamPlayers);
    SOL_REGISTER("getTeamCounts", CLuaConflict::getTeamCounts);
    SOL_REGISTER("getTeamWinnings", CLuaConflict::getTeamWinnings);
    SOL_REGISTER("getTeamScores", CLuaConflict::getTeamScores);
    SOL_REGISTER("getTeamRounds", CLuaConflict::getTeamRounds);
    SOL_REGISTER("getTeamNations", CLuaConflict::getTeamNations);
    SOL_REGISTER("getTeamAllegiances", CLuaConflict::getTeamAllegiances);
    SOL_REGISTER("getHighScorer", CLuaConflict::getHighScorer);
    SOL_REGISTER("getWinningTeam", CLuaConflict::getWinningTeam);
    SOL_REGISTER("areRooksOpen", CLuaConflict::areRooksOpen);
}
