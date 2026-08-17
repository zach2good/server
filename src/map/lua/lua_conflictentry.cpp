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

#include "lua_conflictentry.h"

#include "common/logging.h"

#include "conflict_instance.h"
#include "conflict_player.h"
#include "conflict_team.h"
#include "entities/char_entity.h"
#include "utils/conflictutils.h"
#include "zone.h"

#include <utility>

CLuaConflictEntry::CLuaConflictEntry(ConflictEntry* PEntry)
: m_PEntry(PEntry)
{
    if (PEntry == nullptr)
    {
        ShowError("CLuaConflictEntry created with a null ConflictEntry.");
    }
}

auto CLuaConflictEntry::getHeldPetras() const -> uint32
{
    return m_PEntry->heldPetras;
}

auto CLuaConflictEntry::getScoredPetras() const -> uint32
{
    return m_PEntry->score;
}

// Across the whole match rather than the round in hand. A best of three banks each round's score
// and starts the next from zero, so the running figure alone understates a finished match.
auto CLuaConflictEntry::getTotalScoredPetras() const -> uint32
{
    return m_PEntry->totalScoredPetras + m_PEntry->score;
}

// Puts this match on the Marshal's board. Registering twice replaces rather than stacks.
auto CLuaConflictEntry::registerForRanking() -> bool
{
    const auto* instance = m_PEntry->instance;
    if (instance == nullptr || instance->zone == nullptr)
    {
        return false;
    }

    return conflictutils::RegisterForRanking(instance->GetId(),
                                             m_PEntry->charid,
                                             instance->zone->GetID(),
                                             instance->settings.matchStart,
                                             m_PEntry->ballistaPoints,
                                             m_PEntry->job);
}

auto CLuaConflictEntry::getPoints() const -> uint32
{
    return m_PEntry->ballistaPoints;
}

auto CLuaConflictEntry::addPetras(const int32 petras) -> int32
{
    return m_PEntry->AddPetras(petras);
}

auto CLuaConflictEntry::scorePetras() -> int32
{
    return m_PEntry->ScorePetras();
}

auto CLuaConflictEntry::hasGateBreach() const -> bool
{
    return m_PEntry->hasGateBreach;
}

auto CLuaConflictEntry::addGateBreach() -> bool
{
    m_PEntry->SetGateBreach(ConflictEntry::GateBreachOn::Yes);

    return true;
}

auto CLuaConflictEntry::removeGateBreach() -> bool
{
    const auto didRemove = m_PEntry->hasGateBreach;

    m_PEntry->SetGateBreach(ConflictEntry::GateBreachOn::No);

    return didRemove;
}

auto CLuaConflictEntry::getConflict() const -> ConflictInstance*
{
    return m_PEntry->instance;
}

auto CLuaConflictEntry::getPlayer() const -> CBaseEntity*
{
    return m_PEntry->player;
}

auto CLuaConflictEntry::getName() const -> Maybe<std::string>
{
    if (m_PEntry->player == nullptr)
    {
        return std::nullopt;
    }

    return m_PEntry->player->name;
}

auto CLuaConflictEntry::getJob() const -> uint8
{
    return std::to_underlying(m_PEntry->job);
}

auto CLuaConflictEntry::canLeave() const -> bool
{
    return m_PEntry->HasActiveEntry();
}

auto CLuaConflictEntry::leave() -> Maybe<uint32>
{
    return m_PEntry->Leave();
}

auto CLuaConflictEntry::getIndex() const -> uint8
{
    return m_PEntry->GetIndex();
}

auto CLuaConflictEntry::getTeamIndex() const -> uint8
{
    return m_PEntry->teamIdx;
}

auto CLuaConflictEntry::getTeamAllegiance() const -> uint8
{
    const auto* team = m_PEntry->GetTeam();
    if (team == nullptr)
    {
        return std::to_underlying(xi::Allegiance::Mob);
    }

    return std::to_underlying(team->allegiance);
}

auto CLuaConflictEntry::getTeamNation() const -> uint8
{
    const auto* team = m_PEntry->GetTeam();
    if (team == nullptr)
    {
        return 0;
    }

    return toNationIndex(team->allegiance);
}

auto CLuaConflictEntry::isTempEntry() const -> bool
{
    return m_PEntry->GetEntryType() == ConflictEntryType::Temporary;
}

auto CLuaConflictEntry::canScore() const -> bool
{
    return m_PEntry->hasGateBreach || m_PEntry->instance->HasOpenRooks();
}

auto CLuaConflictEntry::closestRookDistance() const -> Maybe<float>
{
    return m_PEntry->ClosestRookDistance();
}

void CLuaConflictEntry::changeTeam(const sol::optional<uint8> teamIdx)
{
    // With no argument, swap to the other side.
    m_PEntry->ChangeTeam(teamIdx.value_or(static_cast<uint8>(1 - m_PEntry->teamIdx)));
}

void CLuaConflictEntry::quarry()
{
    m_PEntry->Quarry();
}

void CLuaConflictEntry::sprint()
{
    m_PEntry->Sprint();
}

void CLuaConflictEntry::scout()
{
    m_PEntry->Scout();
}

//======================================================//

void CLuaConflictEntry::Register()
{
    SOL_USERTYPE("CConflictEntry", CLuaConflictEntry);

    SOL_REGISTER("getHeldPetras", CLuaConflictEntry::getHeldPetras);
    SOL_REGISTER("getScoredPetras", CLuaConflictEntry::getScoredPetras);
    SOL_REGISTER("getTotalScoredPetras", CLuaConflictEntry::getTotalScoredPetras);
    SOL_REGISTER("registerForRanking", CLuaConflictEntry::registerForRanking);
    SOL_REGISTER("getPoints", CLuaConflictEntry::getPoints);
    SOL_REGISTER("addPetras", CLuaConflictEntry::addPetras);
    SOL_REGISTER("scorePetras", CLuaConflictEntry::scorePetras);
    SOL_REGISTER("hasGateBreach", CLuaConflictEntry::hasGateBreach);
    SOL_REGISTER("addGateBreach", CLuaConflictEntry::addGateBreach);
    SOL_REGISTER("removeGateBreach", CLuaConflictEntry::removeGateBreach);
    SOL_REGISTER("getConflict", CLuaConflictEntry::getConflict);
    SOL_REGISTER("getPlayer", CLuaConflictEntry::getPlayer);
    SOL_REGISTER("getName", CLuaConflictEntry::getName);
    SOL_REGISTER("getJob", CLuaConflictEntry::getJob);
    SOL_REGISTER("canLeave", CLuaConflictEntry::canLeave);
    SOL_REGISTER("leave", CLuaConflictEntry::leave);
    SOL_REGISTER("getIndex", CLuaConflictEntry::getIndex);
    SOL_REGISTER("getTeamIndex", CLuaConflictEntry::getTeamIndex);
    SOL_REGISTER("getTeamAllegiance", CLuaConflictEntry::getTeamAllegiance);
    SOL_REGISTER("getTeamNation", CLuaConflictEntry::getTeamNation);
    SOL_REGISTER("isTempEntry", CLuaConflictEntry::isTempEntry);
    SOL_REGISTER("changeTeam", CLuaConflictEntry::changeTeam);
    SOL_REGISTER("canScore", CLuaConflictEntry::canScore);
    SOL_REGISTER("closestRookDistance", CLuaConflictEntry::closestRookDistance);
    SOL_REGISTER("quarry", CLuaConflictEntry::quarry);
    SOL_REGISTER("sprint", CLuaConflictEntry::sprint);
    SOL_REGISTER("scout", CLuaConflictEntry::scout);
}
