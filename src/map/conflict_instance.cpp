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

constexpr auto toNationBit(const xi::Allegiance allegiance) -> uint8
{
    return static_cast<uint8>(1 << toNationIndex(allegiance));
}

} // namespace

ConflictInstance::ConflictInstance(ConflictSettings newSettings, CZone* zone)
: settings(std::move(newSettings))
, zone(zone)
{
    teams[0] = makeBox<ConflictTeam>(settings.team1);
    teams[1] = makeBox<ConflictTeam>(settings.team2);

    nationBits = static_cast<uint8>(toNationBit(settings.team1) | toNationBit(settings.team2));

    cleanupTime = timeutils::GetTimePointFromVanaTimestamp(settings.matchStart + settings.matchLength + kCleanupGraceVanaMinutes);

    const auto rset = db::preparedStmt("SELECT instanceid, state, phase, rounds_team1, rounds_team2, max_team_size, rook_count, "
                                       "combat_enabled, gil_on_herald "
                                       "FROM conflict_instances WHERE zoneid = ? AND start = ? AND type = ?",
                                       std::to_underlying(zone->GetID()),
                                       settings.matchStart,
                                       settings.isScheduled);

    // Recover a match that was already running before the last restart.
    if (rset && rset->next())
    {
        id                  = rset->get<uint32>("instanceid");
        state               = static_cast<xi::ConflictState>(rset->get<uint8>("state"));
        gamePhase           = rset->get<uint8>("phase");
        teams[0]->roundsWon = rset->get<uint8>("rounds_team1");
        teams[1]->roundsWon = rset->get<uint8>("rounds_team2");
        maxTeamSize         = rset->get<uint8>("max_team_size");
        rookCount           = rset->get<uint8>("rook_count");
        combatEnabled       = rset->get<bool>("combat_enabled");
        gilOnHerald         = rset->get<uint32>("gil_on_herald");
        activeRooks         = luautils::ConflictGetRookIds(this);

        const auto matchIsActive = IsActive();

        const auto entryRset = db::preparedStmt("SELECT charid, allegiance, type, job, points, score, total_score FROM conflict_entries WHERE instanceid = ?", id);
        while (entryRset && entryRset->next())
        {
            const auto charid     = entryRset->get<uint32>("charid");
            const auto allegiance = static_cast<xi::Allegiance>(entryRset->get<uint8>("allegiance"));
            const auto entryType  = static_cast<ConflictEntryType>(entryRset->get<uint8>("type"));
            const auto job        = static_cast<xi::Job>(entryRset->get<uint8>("job"));
            const auto points     = entryRset->get<uint32>("points");
            const auto score      = entryRset->get<uint32>("score");
            const auto totalScore = entryRset->get<uint32>("total_score");

            const auto teamIdx = [&]() -> uint8
            {
                if (teams[1]->allegiance == allegiance)
                {
                    return 1;
                }

                return 0;
            }();

            teams[teamIdx]->score += static_cast<int32>(score);

            auto  entry     = makeBox<ConflictEntry>(charid, this, teamIdx, job, entryType, points, score, totalScore);
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

            // Whether the initial items were handed out is not persisted, so assume they were.
            entryView->gotInitialItems = matchIsActive;
        }

        return;
    }

    const auto insertRset = db::preparedStmt("INSERT INTO conflict_instances (type, zoneid, start, length) VALUES (?, ?, ?, ?)",
                                             settings.isScheduled,
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

    // The player was in this match and left; they do not get a second entry. The entry pointer is
    // cleared when they zone, so the record of who left is what actually decides this.
    if (player->conflictEntry || oldEntries.contains(player->id))
    {
        return std::nullopt;
    }

    if (state > xi::ConflictState::Active)
    {
        return std::nullopt;
    }

    if (settings.signupFee > 0)
    {
        // Seating someone who did not pay would let them draw on a pot they never contributed to,
        // and a draw refunds the full fee to everyone.
        if (!charutils::UpdateGil(player, -static_cast<int32>(settings.signupFee)))
        {
            return std::nullopt;
        }

        gilOnHerald += settings.signupFee;
        PersistGilOnHerald();
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

auto ConflictInstance::SnapshotEntries() const -> std::vector<ConflictEntry*>
{
    auto snapshot = std::vector<ConflictEntry*>();
    snapshot.reserve(entries.size());

    for (const auto& [charid, entry] : entries)
    {
        snapshot.emplace_back(entry.get());
    }

    return snapshot;
}

void ConflictInstance::RemovePlayerEntry(const uint32 charId)
{
    const auto entry = entries.find(charId);
    if (entry == entries.end())
    {
        return;
    }

    std::erase(teams[entry->second->teamIdx]->entries, entry->second.get());

    oldEntries[charId] = std::move(entry->second);
    entries.erase(entry);
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
        for (auto* entry : SnapshotEntries())
        {
            entry->SetupBattleCommunication();
            entry->SetupTemporaryInventory(ConflictEntry::SendUpdate::Yes);
        }
    }
    else if (newState == xi::ConflictState::Active)
    {
        for (auto* entry : SnapshotEntries())
        {
            if (entry->player == nullptr)
            {
                continue;
            }

            // A voucher is spent at the start of whichever match comes next, so this runs for
            // every match rather than only the one that hands out items of its own.
            std::ignore = luautils::ConflictRedeemVouchers(entry->player, settings.levelCap);

            if (settings.initialTempItems && !entry->gotInitialItems)
            {
                entry->gotInitialItems = luautils::ConflictDistributeInitialItems(entry->player);
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

        for (auto* entry : SnapshotEntries())
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

            // Paid by id, so a participant who zoned out or logged off still collects what they
            // earned. The award reads no game state and nobody waits on its result, so it goes to
            // a worker thread: a full match would otherwise stall every zone in this process for
            // as long as it takes to write one row per participant.
            zone->scheduler().postToWorkerThread(
                [charid = entry->charid, points = static_cast<int32>(entry->ballistaPoints), ballistaCap]()
                {
                    charutils::AddPointsByCharId(charid, "ballista_point", points, ballistaCap);
                });
        }
    }
}

void ConflictInstance::PersistGilOnHerald() const
{
    if (id == 0)
    {
        return;
    }

    if (!db::preparedStmt("UPDATE conflict_instances SET gil_on_herald = ? WHERE instanceid = ?", gilOnHerald, id))
    {
        ShowErrorFmt("ConflictInstance: Failed to persist the pot for match {}.", id);
    }
}

auto ConflictInstance::GetSignupFee() const -> uint32
{
    return settings.signupFee;
}

auto ConflictInstance::GetGilOnHerald() const -> uint32
{
    return gilOnHerald;
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

    for (auto* entry : SnapshotEntries())
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
        db::preparedStmt("UPDATE conflict_instances SET combat_enabled = ? WHERE instanceid = ?", combatEnabled, id);
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
    // Across the whole match, not the round in hand. Both the periodic announcement and the
    // closing cutscene call this player today's high scorer and quote a total, so a best of three
    // cannot pick whoever happened to lead the last round.
    const auto matchTotal = [](const ConflictEntry* candidate) -> uint32
    {
        return candidate->totalScoredPetras + candidate->score;
    };

    if (entry && (highScorer == nullptr || matchTotal(entry) > matchTotal(highScorer)))
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
        db::preparedStmt("UPDATE conflict_entries SET total_score = total_score + score, score = 0 WHERE instanceid = ?", id);
    }
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

    if (id == 0)
    {
        return;
    }

    const auto query = [&]
    {
        if (teamIdx == 0)
        {
            return "UPDATE conflict_instances SET rounds_team1 = ? WHERE instanceid = ?";
        }

        return "UPDATE conflict_instances SET rounds_team2 = ? WHERE instanceid = ?";
    }();

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
    return winningTeam.getOrCompute(
        [&]() -> Maybe<uint8>
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
                return 0;
            }

            if (scoreOf(0) < scoreOf(1))
            {
                return 1;
            }

            return std::nullopt;
        });
}

void ConflictInstance::UpdateOpenRooks()
{
    // The gates open when a side can no longer contest a throw, which retail describes as most of
    // the opposing team having left the field rather than all of it. The proportion is not
    // documented anywhere, so a majority is the reading taken here.
    constexpr auto presentShareToContest = 0.5f;

    auto sidesAbleToContest = 0;
    for (const auto& team : teams)
    {
        if (team->entries.empty())
        {
            continue;
        }

        const auto present = std::ranges::count_if(
            team->entries,
            [](const ConflictEntry* entry)
            {
                return entry->player != nullptr;
            });

        if (static_cast<float>(present) > static_cast<float>(team->entries.size()) * presentShareToContest)
        {
            ++sidesAbleToContest;
        }
    }

    const auto newValue = sidesAbleToContest <= 1;
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
    // Membership is checked here rather than at the removal below, because the gil is credited
    // first: a removal that failed after the credit would pay the player and leave the entry
    // standing for them to claim again.
    if (!entry->HasActiveEntry() || !entries.contains(entry->charid))
    {
        return std::nullopt;
    }

    const auto teamIdx = entry->teamIdx;

    // Counted before the entry is removed: the pot is shared between everyone who won it, not
    // between whoever has not claimed yet. Reading it afterwards pays the first claimant more.
    const auto winnerCount = std::max<std::size_t>(1, teams[teamIdx]->entries.size());

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
                gilToGive = gilOnHerald / static_cast<uint32>(winnerCount);
            }

            break;
        }

        case xi::ConflictState::Finished:
            break;
    }

    gilToGive = std::min(gilToGive, gilOnHerald);

    // The gil, the pot and the entry's type land together or not at all. Written one at a time, a
    // restart between the gil credit and the type would leave the entry recoverable as still
    // active with the pot untouched, and the same share could be claimed a second time.
    //
    // Pay before the entry is taken away too: a credit the player cannot take right now has to
    // leave them able to come back to the Herald rather than forfeiting the whole payout.
    const auto payOut = [&]()
    {
        if (gilToGive > 0 && (entry->player == nullptr || !charutils::UpdateGil(entry->player, static_cast<int32>(gilToGive))))
        {
            throw std::runtime_error("Conflict: the payout could not be credited");
        }

        const auto remainingGil = gilOnHerald - gilToGive;
        if (!db::preparedStmt("UPDATE conflict_instances SET gil_on_herald = ? WHERE instanceid = ?", remainingGil, id))
        {
            throw std::runtime_error("Conflict: the pot could not be written");
        }

        entry->PersistEntryType(newEntryType);
    };

    const auto committed = [&]
    {
        // A match that was never written has nothing to recover from, so there is no torn state to
        // protect and nothing to roll back to.
        if (id == 0)
        {
            try
            {
                if (gilToGive > 0 && (entry->player == nullptr || !charutils::UpdateGil(entry->player, static_cast<int32>(gilToGive))))
                {
                    return false;
                }
            }
            catch (const std::exception&)
            {
                return false;
            }

            return true;
        }

        return db::transaction(payOut);
    }();

    if (!committed)
    {
        return std::nullopt;
    }

    RemovePlayerEntry(entry->charid);

    gilOnHerald -= gilToGive;
    entry->SetEntryType(newEntryType);

    return gilToGive;
}
