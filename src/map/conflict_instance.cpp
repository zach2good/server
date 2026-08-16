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

#include "conflict_instance.h"

#include "conflict_player.h"
#include "conflict_team.h"

#include "common/database.h"
#include "common/logging.h"
#include "common/settings.h"
#include "common/timer.h"

#include "data/enums/status_effect.h"

#include "entities/char_entity.h"
#include "lua/luautils.h"
#include "status_effect_container.h"
#include "utils/charutils.h"
#include "zone.h"

#include <algorithm>
#include <chrono>
#include <utility>

using namespace std::chrono_literals;

namespace
{

// A finished match is kept for a full Vana'diel day so that stragglers can still collect from the Herald.
constexpr uint32 kCleanupGraceVanaMinutes = 60 * 24;

// The client shows both nations as bits counted from San d'Oria.
auto toNationBit(const xi::Allegiance allegiance) -> uint8
{
    return static_cast<uint8>(1 << (std::to_underlying(allegiance) - std::to_underlying(xi::Allegiance::SanDoria)));
}

} // namespace

ConflictInstance::ConflictInstance(ConflictSettings settings, CZone* zone)
: settings(settings)
, zone(zone)
{
    teams[0] = makeBox<ConflictTeam>(settings.team1);
    teams[1] = makeBox<ConflictTeam>(settings.team2);

    nationBits = toNationBit(settings.team1) + toNationBit(settings.team2);

    cleanupTime = timeutils::GetTimePointFromVanaTimestamp(settings.matchStart + settings.matchLength + kCleanupGraceVanaMinutes);

    const auto rset = db::preparedStmt("SELECT instanceid, state, phase, rounds_team1, rounds_team2, max_team_size, rook_count "
                                       "FROM conflict_instances WHERE zoneid = ? AND start = ? AND type = ?",
                                       std::to_underlying(zone->GetID()),
                                       settings.matchStart,
                                       settings.isScheduled ? 1 : 0);

    // Recover a match that was already running before the last restart.
    if (rset && rset->rowsCount() > 0 && rset->next())
    {
        id                  = rset->get<uint32>("instanceid");
        state               = static_cast<xi::ConflictState>(rset->get<uint8>("state"));
        gamePhase           = rset->get<uint8>("phase");
        teams[0]->roundsWon = rset->get<uint8>("rounds_team1");
        teams[1]->roundsWon = rset->get<uint8>("rounds_team2");
        maxTeamSize         = rset->get<uint8>("max_team_size");
        rookCount           = rset->get<uint8>("rook_count");
        activeRooks         = luautils::ConflictGetRookIds(this);

        const auto entryRset = db::preparedStmt("SELECT charid, allegiance, type, job, points, score FROM conflict_entries WHERE instanceid = ?", id);
        while (entryRset && entryRset->next())
        {
            const auto charid     = entryRset->get<uint32>("charid");
            const auto allegiance = static_cast<xi::Allegiance>(entryRset->get<uint8>("allegiance"));
            const auto entryType  = static_cast<ConflictEntryType>(entryRset->get<uint8>("type"));
            const auto job        = static_cast<xi::Job>(entryRset->get<uint8>("job"));
            const auto points     = entryRset->get<uint32>("points");
            const auto score      = entryRset->get<uint32>("score");

            const auto teamIdx = [&]() -> uint8
            {
                if (teams[1]->allegiance == allegiance)
                {
                    return 1;
                }

                return 0;
            }();

            teams[teamIdx]->score += static_cast<int32>(score);

            auto  entry     = makeBox<ConflictEntry>(charid, this, teamIdx, job, entryType, points, score);
            auto* entryView = entry.get();

            if (entryView->HasActiveEntry())
            {
                entries[charid] = std::move(entry);
                teams[teamIdx]->entries.emplace_back(entryView);
            }
            else
            {
                oldEntries[charid] = std::move(entry);
            }

            // The Herald is still holding the fee unless the entry was discharged with a refund.
            if (entryView->HasActiveEntry() || entryType == ConflictEntryType::DischargedNoRefund)
            {
                gilOnHerald += settings.signupFee;
            }

            // Whether the initial items were handed out is not persisted, so assume they were.
            if (IsActive())
            {
                entryView->gotInitialItems = true;
            }
        }

        return;
    }

    const auto insertRset = db::preparedStmt("INSERT INTO conflict_instances (type, zoneid, start, length) VALUES (?, ?, ?, ?)",
                                             settings.isScheduled ? 1 : 0,
                                             std::to_underlying(settings.zoneId),
                                             settings.matchStart,
                                             settings.matchLength);

    if (!insertRset || insertRset->rowsAffected() == 0)
    {
        ShowError("ConflictInstance: Unable to persist the Conflict match to the database.");
        return;
    }

    const auto idRset = db::preparedStmt("SELECT LAST_INSERT_ID() AS id");
    if (idRset && idRset->next())
    {
        id = idRset->get<uint32>("id");
    }
    else
    {
        ShowError("ConflictInstance: Unable to get the match ID of the created Conflict in the database.");
    }
}

ConflictInstance::~ConflictInstance()
{
    luautils::ConflictCleanup(this);
    SetLevelRestrictionEnabled(false);
    SetCombatEnabled(false);

    // An ad-hoc match has no calendar slot to recover into, so its row goes with it.
    if (!settings.isScheduled && id != 0)
    {
        if (const auto rset = db::preparedStmt("DELETE FROM conflict_instances WHERE instanceid = ?", id); !rset)
        {
            ShowError("ConflictInstance: Unable to clean up the ad hoc Conflict match.");
        }
    }
}

auto ConflictInstance::AddPlayer(CCharEntity* player, const Maybe<uint8> requestedTeamIdx) -> Maybe<uint8>
{
    if (TryRejoinPlayer(player))
    {
        return player->conflictEntry->teamIdx;
    }

    // The player was in this match and left; they do not get a second entry.
    if (player->conflictEntry)
    {
        return std::nullopt;
    }

    if (state > xi::ConflictState::Active)
    {
        return std::nullopt;
    }

    if (settings.signupFee > 0 && charutils::UpdateGil(player, -static_cast<int32>(settings.signupFee)))
    {
        gilOnHerald += settings.signupFee;
    }

    const auto teamIdx = [&]() -> uint8
    {
        if (requestedTeamIdx && *requestedTeamIdx < kConflictTeamCount)
        {
            return *requestedTeamIdx;
        }

        // No preference, so even the sides up.
        if (teams[0]->entries.size() > teams[1]->entries.size())
        {
            return 1;
        }

        return 0;
    }();

    const auto entryType = [&]
    {
        // Nation and guest entries are committed, and auto-balance will not move them.
        if (signupState == xi::ConflictSignupState::Nations || signupState == xi::ConflictSignupState::Guest)
        {
            return ConflictEntryType::Locked;
        }

        return ConflictEntryType::Temporary;
    }();

    auto  entry     = makeBox<ConflictEntry>(player, this, teamIdx, entryType);
    auto* entryView = entry.get();

    entries[player->id] = std::move(entry);
    teams[teamIdx]->entries.emplace_back(entryView);
    player->conflictEntry = entryView;

    entryView->EnsureNonAnon();

    if (state >= xi::ConflictState::Preparing)
    {
        entryView->PerformJoinUpdates();

        // Joining a live match grants a grace period before the player can be attacked.
        if (state == xi::ConflictState::Active)
        {
            player->StatusEffectContainer->AddStatusEffect(xi::StatusEffect::Preparations, std::to_underlying(xi::StatusEffect::Preparations), 0, 10s, 32s);
        }
    }

    return teamIdx;
}

auto ConflictInstance::TryRejoinPlayer(CCharEntity* player) -> bool
{
    const auto existingEntry = entries.find(player->id);
    if (existingEntry == entries.end())
    {
        return false;
    }

    existingEntry->second->RejoinPlayer(player);

    return true;
}

auto ConflictInstance::RemovePlayerEntry(const uint32 charId) -> bool
{
    const auto entry = entries.find(charId);
    if (entry == entries.end())
    {
        return false;
    }

    std::erase(teams[entry->second->teamIdx]->entries, entry->second.get());

    oldEntries[charId] = std::move(entry->second);
    entries.erase(entry);

    return true;
}

auto ConflictInstance::GetId() const -> uint32
{
    return id;
}

auto ConflictInstance::GetState() const -> xi::ConflictState
{
    return state;
}

auto ConflictInstance::GetTeam(const uint8 teamIdx) const -> ConflictTeam*
{
    if (teamIdx >= kConflictTeamCount)
    {
        return nullptr;
    }

    return teams[teamIdx].get();
}

void ConflictInstance::SetState(const xi::ConflictState newState)
{
    // A match only ever moves forward.
    if (newState <= state)
    {
        return;
    }

    state = newState;

    if (id != 0)
    {
        db::preparedStmt("UPDATE conflict_instances SET state = ? WHERE instanceid = ?", std::to_underlying(newState), id);
    }

    if (newState == xi::ConflictState::Preparing)
    {
        for (const auto& [charid, entry] : entries)
        {
            entry->SetupBattleCommunication();
            entry->SetupTemporaryInventory(ConflictEntry::SendUpdate::Yes);
        }
    }
    else if (newState == xi::ConflictState::Active)
    {
        if (settings.initialTempItems)
        {
            for (const auto& [charid, entry] : entries)
            {
                if (entry->player && !entry->gotInitialItems)
                {
                    entry->gotInitialItems = luautils::ConflictDistributeInitialItems(entry->player);
                }
            }
        }

        UpdateOpenRooks();
    }
    else if (newState == xi::ConflictState::PostGame)
    {
        SetLevelRestrictionEnabled(false);
        SetCombatEnabled(false);

        const auto winningIdx  = GetWinningTeamIndex();
        const auto ballistaCap = settings::get<int32>("main.CAP_CURRENCY_BALLISTA");

        for (const auto& [charid, entry] : entries)
        {
            entry->SetGateBreach(ConflictEntry::GateBreachOn::No, ConflictEntry::Silent::Yes);

            if (entry->player)
            {
                charutils::ClearTempItems(entry->player, true);
            }

            // TODO: Confirm the retail award. A draw pays the losing rate to both sides.
            entry->ballistaPoints += [&]() -> uint32
            {
                if (winningIdx == entry->teamIdx)
                {
                    return 60;
                }

                return 30;
            }();

            // TODO(conflict): pay out participants who are offline, which Eden did by charid.
            if (entry->player)
            {
                charutils::AddPoints(entry->player, "ballista_point", static_cast<int32>(entry->ballistaPoints), ballistaCap);
            }
        }
    }
}

auto ConflictInstance::GetSignupFee() const -> uint32
{
    return settings.signupFee;
}

auto ConflictInstance::GetNationBits() const -> uint8
{
    return nationBits;
}

auto ConflictInstance::IsActive() const -> bool
{
    return state >= xi::ConflictState::Preparing && state <= xi::ConflictState::Active;
}

void ConflictInstance::Tick(const timer::time_point tick)
{
    timeline.Tick(tick);

    for (const auto& team : teams)
    {
        team->Tick(tick);
    }

    for (const auto& [charid, entry] : entries)
    {
        entry->Tick(tick);
    }
}

void ConflictInstance::BroadcastStatusUpdate()
{
    for (const auto& [charid, entry] : entries)
    {
        entry->SendStatusUpdate();
    }
}

auto ConflictInstance::IsCombatEnabled() const -> bool
{
    return combatEnabled;
}

void ConflictInstance::SetCombatEnabled(const bool enable)
{
    if (combatEnabled == enable)
    {
        return;
    }

    combatEnabled = enable;

    if (id != 0)
    {
        db::preparedStmt("UPDATE conflict_instances SET combat_enabled = ? WHERE instanceid = ?", combatEnabled ? 1 : 0, id);
    }

    if (enable)
    {
        // The opening track starts shortly after the match goes live, not on the same tick.
        const auto firstMusicChange = timer::now() + 10s;

        teams[0]->nextMusicChange = firstMusicChange;
        teams[1]->nextMusicChange = firstMusicChange;
    }

    for (const auto& [charid, entry] : entries)
    {
        entry->EnableCombat(enable);
    }
}

auto ConflictInstance::IsLevelRestrictionEnabled() const -> bool
{
    return levelRestrictionEnabled;
}

void ConflictInstance::SetLevelRestrictionEnabled(const bool enable)
{
    if (levelRestrictionEnabled == enable || settings.levelCap == 0)
    {
        levelRestrictionEnabled = enable;
        return;
    }

    levelRestrictionEnabled = enable;

    for (const auto& [charid, entry] : entries)
    {
        auto* player = entry->player;
        if (player == nullptr)
        {
            continue;
        }

        if (enable)
        {
            charutils::SetLevelRestriction(player, settings.levelCap);
        }
        else
        {
            player->StatusEffectContainer->DelStatusEffectSilent(xi::StatusEffect::LevelRestriction);
            player->UpdateHealth();
            player->health.hp = player->GetMaxHP();
            player->health.mp = player->GetMaxMP();
        }
    }
}

void ConflictInstance::ScoreUpdate(ConflictEntry* entry)
{
    if (entry && (highScorer == nullptr || entry->score > highScorer->score))
    {
        highScorer = entry;
    }

    teams[0]->UpdateMusic(teams[0]->score > teams[1]->score);
    teams[1]->UpdateMusic(teams[1]->score > teams[0]->score);

    BroadcastStatusUpdate();
}

void ConflictInstance::SetPhase(const uint8 newPhase)
{
    if (newPhase <= gamePhase)
    {
        return;
    }

    gamePhase = newPhase;

    for (const auto& team : teams)
    {
        team->ResetRound();
    }

    for (const auto& [charid, entry] : entries)
    {
        entry->totalScoredPetras += entry->score;
        entry->score      = 0;
        entry->heldPetras = 0;
        entry->SetGateBreach(ConflictEntry::GateBreachOn::No, ConflictEntry::Silent::Yes);
    }

    for (const auto& [charid, entry] : oldEntries)
    {
        entry->totalScoredPetras += entry->score;
        entry->score      = 0;
        entry->heldPetras = 0;
    }

    // Only the even phases are round boundaries worth persisting.
    if (id != 0 && gamePhase % 2 == 0)
    {
        db::preparedStmt("UPDATE conflict_instances SET phase = ? WHERE instanceid = ?", gamePhase, id);
        db::preparedStmt("UPDATE conflict_entries SET score = 0 WHERE instanceid = ?", id);
    }

    highScorer = nullptr;
}

void ConflictInstance::AddTeamRounds(const uint8 teamIdx, const int32 rounds)
{
    if (rounds == 0)
    {
        return;
    }

    if (teamIdx >= kConflictTeamCount)
    {
        ShowErrorFmt("ConflictInstance: Invalid team index given when trying to add {} rounds: {}.", rounds, teamIdx);
        return;
    }

    teams[teamIdx]->roundsWon += rounds;

    const auto query = fmt::format("UPDATE conflict_instances SET rounds_team{} = ? WHERE instanceid = ?", teamIdx + 1);
    if (const auto rset = db::preparedStmt(query, teams[teamIdx]->roundsWon, id); !rset)
    {
        ShowErrorFmt("ConflictInstance: Failed to update rounds for team {}.", teamIdx + 1);
    }
}

void ConflictInstance::ConfigureGameSetup(const uint32 newMaxTeamSize, const uint32 newRookCount)
{
    if (id != 0 && (maxTeamSize != newMaxTeamSize || rookCount != newRookCount))
    {
        db::preparedStmt("UPDATE conflict_instances SET max_team_size = ?, rook_count = ? WHERE instanceid = ?", newMaxTeamSize, newRookCount, id);
    }

    maxTeamSize = static_cast<uint8>(newMaxTeamSize);
    rookCount   = static_cast<uint8>(newRookCount);
    activeRooks = luautils::ConflictGetRookIds(this);
}

auto ConflictInstance::GetWinningTeamIndex() -> Maybe<uint8>
{
    if (state != xi::ConflictState::PostGame)
    {
        return std::nullopt;
    }

    // No value means a draw, which is what refunds an entry fee.
    if (!winningTeamDetermined)
    {
        const auto scoreOf = [&](const uint8 teamIdx) -> int32
        {
            if (settings.type == xi::ConflictType::BestOfThree)
            {
                return teams[teamIdx]->roundsWon;
            }

            return teams[teamIdx]->score;
        };

        if (scoreOf(0) > scoreOf(1))
        {
            winningTeamIdx = 0;
        }
        else if (scoreOf(0) < scoreOf(1))
        {
            winningTeamIdx = 1;
        }

        winningTeamDetermined = true;
    }

    return winningTeamIdx;
}

void ConflictInstance::UpdateOpenRooks()
{
    auto teamsWithMembers = 0;
    for (const auto& team : teams)
    {
        const auto hasPlayer = std::ranges::any_of(team->entries, [](const ConflictEntry* entry)
                                                   {
                                                       return entry->player != nullptr;
                                                   });

        if (hasPlayer)
        {
            ++teamsWithMembers;
        }
    }

    // With only one side present there is nobody to contest a rook, so they all stand open.
    const auto newValue = teamsWithMembers <= 1;
    if (newValue != openRooks)
    {
        openRooks = newValue;
        luautils::ConflictUpdateRookState(this);
    }
}

auto ConflictInstance::HasOpenRooks() const -> bool
{
    return openRooks;
}

auto ConflictInstance::RemoveEntryAndTakeGilFromHerald(ConflictEntry* entry) -> Maybe<uint32>
{
    if (!entry->HasActiveEntry())
    {
        return std::nullopt;
    }

    const auto teamIdx = entry->teamIdx;
    if (!RemovePlayerEntry(entry->charid))
    {
        return std::nullopt;
    }

    const auto membersLeftOnTeam = std::max<std::size_t>(1, teams[teamIdx]->entries.size());

    auto newEntryType = ConflictEntryType::DischargedNoRefund;
    auto gilToGive    = uint32{ 0 };

    switch (state)
    {
        case xi::ConflictState::Setup:
        case xi::ConflictState::SignUp:
            // Leaving before the match starts is free.
            newEntryType = ConflictEntryType::DischargedRefund;
            gilToGive    = settings.signupFee;
            break;

        case xi::ConflictState::Preparing:
        case xi::ConflictState::Active:
            // Walking out of a live match forfeits the fee.
            newEntryType = ConflictEntryType::DischargedNoRefund;
            break;

        case xi::ConflictState::PostGame:
        case xi::ConflictState::Cancelled:
        {
            newEntryType = ConflictEntryType::Finalized;

            const auto winningTeamIndex = GetWinningTeamIndex();
            if (!winningTeamIndex)
            {
                // A draw or a cancelled match returns the entry fee.
                gilToGive = settings.signupFee;
            }
            else if (*winningTeamIndex == teamIdx)
            {
                gilToGive = gilOnHerald / static_cast<uint32>(membersLeftOnTeam);
            }

            break;
        }

        case xi::ConflictState::Finished:
            break;
    }

    gilToGive = std::min(gilToGive, gilOnHerald);

    if (!entry->player || (gilToGive > 0 && !charutils::UpdateGil(entry->player, static_cast<int32>(gilToGive))))
    {
        gilToGive = 0;
    }

    gilOnHerald -= gilToGive;

    entry->SetEntryType(newEntryType);

    return gilToGive;
}
