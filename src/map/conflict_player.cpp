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

#include "conflict_player.h"

#include "conflict_instance.h"
#include "conflict_team.h"

#include "common/database.h"
#include "common/logging.h"
#include "common/timer.h"

#include "data/enums/status_effect.h"

#include "enums/msg_std.h"

#include "common/utils.h"
#include "entities/char_entity.h"
#include "lua/luautils.h"
#include "packets/char_update.h"
#include "packets/s2c/0x029_battle_message.h"
#include "packets/s2c/0x053_systemmes.h"
#include "packets/s2c/0x0e6_ballista.h"

#include "status_effect_container.h"
#include "utils/charutils.h"
#include "utils/zoneutils.h"
#include "zone.h"

#include <algorithm>
#include <chrono>
#include <iterator>
#include <utility>

using namespace std::chrono_literals;

namespace
{

// Holders of the Ballista Earring are shown periodic tactical hints during a match.
constexpr auto kBallistaEarringKeyItem = KeyItem{ 500 };

// A single throw scores at most five petras.
constexpr uint32 kMaxPetrasPerScore = 5;

} // namespace

ConflictEntry::ConflictEntry(CCharEntity* player, ConflictInstance* instance, const uint8 teamIdx, const ConflictEntryType entryType)
: player(player)
, charid(player->id)
, teamIdx(teamIdx)
, instance(instance)
, job(player->GetMJob())
, entryType(entryType)
{
    const auto rset = db::preparedStmt("INSERT INTO conflict_entries (instanceid, charid, allegiance, type, job) VALUES (?, ?, ?, ?, ?)",
                                       instance->GetId(),
                                       charid,
                                       std::to_underlying(instance->GetTeam(teamIdx)->allegiance),
                                       std::to_underlying(entryType),
                                       std::to_underlying(job));

    savedToDb = rset && rset->rowsAffected() > 0;
    if (!savedToDb)
    {
        ShowErrorFmt("Unable to persist player entry for {} to the database for match {}.", charid, instance->GetId());
    }
}

ConflictEntry::ConflictEntry(const uint32 charid, ConflictInstance* instance, const uint8 teamIdx, const xi::Job job, const ConflictEntryType entryType, const uint32 points, const uint32 score, const uint32 totalScore)
: charid(charid)
, teamIdx(teamIdx)
, instance(instance)
, ballistaPoints(points)
, score(score)
, totalScoredPetras(totalScore)
, job(job)
, entryType(entryType)
, savedToDb(true)
{
}

ConflictEntry::~ConflictEntry()
{
    if (player)
    {
        player->conflictEntry = nullptr;
        charutils::ClearTempItems(player, true);
    }
}

void ConflictEntry::SendStatusUpdate()
{
    if (player)
    {
        player->pushPacket<GP_SERV_COMMAND_BALLISTA::SCOREBOARD>(player);
    }
}

void ConflictEntry::Tick(const timer::time_point tick)
{
    gateBreachTimeline.Tick(tick);

    if (player == nullptr)
    {
        return;
    }

    // Only a live match reraises the dead; outside combat, normal death rules apply.
    if (instance->IsCombatEnabled() && player->isDead())
    {
        if (!reraiseTime)
        {
            // Petras are dropped where the player fell.
            if (heldPetras > 0)
            {
                heldPetras = 0;
                SendStatusUpdate();
            }

            reraiseTime = tick + conflict::ReraiseDelay + conflict::ReraiseDelayPerRR * autoRaiseCounter;
        }
        else if (tick >= *reraiseTime)
        {
            Reraise();
        }

        return;
    }

    reraiseTime.reset();

    if (instance->IsCombatEnabled() && tick >= nextHint)
    {
        luautils::ConflictGameHint(player);

        nextHint += conflict::HintInterval;
        if (nextHint < tick)
        {
            nextHint = tick + conflict::HintInterval;
        }
    }
}

void ConflictEntry::Reraise()
{
    reraiseTime.reset();

    if (player == nullptr || !player->isDead())
    {
        return;
    }

    ++autoRaiseCounter;

    player->Raise();
    player->health.hp = player->GetMaxHP();
    player->health.mp = std::max(player->health.mp, player->GetMaxMP() / 2);
    player->updatemask |= UPDATE_HP;
    player->StatusEffectContainer->AddStatusEffect(xi::StatusEffect::Weakness, std::to_underlying(xi::StatusEffect::Weakness), 1, 0s, 5min);

    // The camp position and the post-reraise Invisible are zone data, so they live in Lua.
    luautils::ConflictReraise(player);
}

void ConflictEntry::RejoinPlayer(CCharEntity* rejoining)
{
    if (player == rejoining)
    {
        return;
    }

    player                   = rejoining;
    rejoining->conflictEntry = this;

    if (job != rejoining->GetMJob())
    {
        job = rejoining->GetMJob();

        if (savedToDb)
        {
            db::preparedStmt("UPDATE conflict_entries SET job = ? WHERE instanceid = ? AND charid = ?",
                             std::to_underlying(job),
                             instance->GetId(),
                             charid);
        }
    }
}

void ConflictEntry::ChangeTeam(const uint8 newTeamIdx)
{
    if (newTeamIdx == teamIdx)
    {
        return;
    }

    auto* newTeam = instance->GetTeam(newTeamIdx);
    if (newTeam == nullptr)
    {
        return;
    }

    std::erase(instance->GetTeam(teamIdx)->entries, this);
    newTeam->entries.emplace_back(this);
    teamIdx = newTeamIdx;

    if (savedToDb)
    {
        db::preparedStmt("UPDATE conflict_entries SET allegiance = ? WHERE instanceid = ? AND charid = ?",
                         std::to_underlying(newTeam->allegiance),
                         instance->GetId(),
                         charid);
    }
}

void ConflictEntry::PerformJoinUpdates()
{
    if (player == nullptr)
    {
        return;
    }

    EnsureNonAnon();
    EnableCombat(instance->IsCombatEnabled());

    if (instance->IsLevelRestrictionEnabled() && instance->settings.levelCap > 0)
    {
        charutils::SetLevelRestriction(player, instance->settings.levelCap);
    }

    if (!IsInActiveConflict())
    {
        return;
    }

    SetupBattleCommunication();
    SetupTemporaryInventory(SendUpdate::Yes);

    if (instance->GetState() != xi::ConflictState::Active)
    {
        return;
    }

    instance->UpdateOpenRooks();

    if (!gotInitialItems && instance->settings.initialTempItems)
    {
        gotInitialItems = luautils::ConflictDistributeInitialItems(player);
    }
}

auto ConflictEntry::Leave() -> Maybe<uint32>
{
    if (!HasActiveEntry())
    {
        return std::nullopt;
    }

    if (player)
    {
        if (instance->IsLevelRestrictionEnabled() && instance->settings.levelCap > 0)
        {
            player->StatusEffectContainer->DelStatusEffectSilent(xi::StatusEffect::LevelRestriction);
        }

        charutils::ClearTempItems(player, true);
    }

    if (instance->IsCombatEnabled())
    {
        EnableCombat(false);
    }

    const auto payout = instance->RemoveEntryAndTakeGilFromHerald(this);

    // The match keeps this entry so the player can be recognised later, but the two stop pointing
    // at each other: the entry is freed when the match is reaped, long after the player has gone.
    if (player != nullptr)
    {
        player->conflictEntry = nullptr;
        player                = nullptr;
    }

    return payout;
}

void ConflictEntry::ZoneOut()
{
    if (player != nullptr)
    {
        player->conflictEntry = nullptr;
        player                = nullptr;
    }

    instance->UpdateOpenRooks();
}

auto ConflictEntry::AddPetras(const int32 amount) -> int32
{
    heldPetras = static_cast<uint32>(std::max(0, static_cast<int32>(heldPetras) + amount));
    SendStatusUpdate();

    return static_cast<int32>(heldPetras);
}

auto ConflictEntry::ScorePetras() -> int32
{
    const auto toScore = std::min(heldPetras, kMaxPetrasPerScore);
    if (toScore == 0)
    {
        return 0;
    }

    auto* team = instance->GetTeam(teamIdx);
    if (team == nullptr)
    {
        return 0;
    }

    score += toScore;
    heldPetras -= toScore;
    team->score += static_cast<int32>(toScore);
    instance->ScoreUpdate(this);
    SetGateBreach(GateBreachOn::No);

    // TODO: Confirm the retail points award. Scoring against a closed rook is worth more.
    ballistaPoints += toScore * [&]() -> uint32
    {
        if (instance->HasOpenRooks())
        {
            return 1;
        }

        return 3;
    }();

    // The score is already live in memory and nobody reads this back, so it does not belong on the
    // tick. It is only here so a match can be recovered after a restart.
    if (savedToDb && instance->zone != nullptr)
    {
        instance->zone->scheduler().postToWorkerThread(
            [entryScore = score, points = ballistaPoints, instanceId = instance->GetId(), charId = charid]()
            {
                db::preparedStmt("UPDATE conflict_entries SET score = ?, points = ? WHERE instanceid = ? AND charid = ?",
                                 entryScore,
                                 points,
                                 instanceId,
                                 charId);
            });
    }

    return static_cast<int32>(toScore);
}

void ConflictEntry::SetGateBreach(const GateBreachOn on, const Silent silent)
{
    const auto had = hasGateBreach;

    hasGateBreach = static_cast<bool>(on);

    if (player && had != static_cast<bool>(on))
    {
        player->pushPacket<CCharUpdatePacket>(player, ENTITY_UPDATE, static_cast<uint8>(UPDATE_HP));
    }

    if (player && !silent && had && !on)
    {
        player->pushPacket<GP_SERV_COMMAND_SYSTEMMES>(0, 0, MsgStd::GateBreachDisengaged);
    }

    if (player && !silent && !had && on)
    {
        player->pushPacket<GP_SERV_COMMAND_BATTLE_MESSAGE>(player, player, 0, 0, MsgBasic::AchievesGateBreach);
    }

    gateBreachTimeline.Clean();

    if (!on)
    {
        return;
    }

    const auto* team      = instance->GetTeam(teamIdx);
    const auto* otherTeam = instance->GetTeam(OtherTeamIndex(teamIdx));
    if (team == nullptr || otherTeam == nullptr)
    {
        return;
    }

    const auto scoreAdvantage = team->score - otherTeam->score;
    luautils::OnConflictGateBreach(this, &gateBreachTimeline, scoreAdvantage > 0, had);

    // Only a breach that was actually gained pays. Re-breaching while one is already held would
    // otherwise bank a point per call.
    if (!had)
    {
        // TODO: Confirm the retail points award.
        ballistaPoints += 1;
    }
}

void ConflictEntry::Quarry()
{
    if (player == nullptr)
    {
        return;
    }

    const auto now = timer::now();
    if (now < nextQuarry)
    {
        const auto remaining = std::chrono::ceil<std::chrono::seconds>(nextQuarry - now).count();
        player->pushPacket<GP_SERV_COMMAND_SYSTEMMES>(static_cast<uint32>(remaining), 0, MsgStd::WaitLonger);

        return;
    }

    nextQuarry = [&]
    {
        // A GM test lever, so a match can be driven without waiting out the cooldown.
        if (player->GetLocalVar("FastQuarry") > 0)
        {
            return now;
        }

        return now + conflict::QuarryCooldown;
    }();

    luautils::OnConflictQuarry(player);
}

void ConflictEntry::Sprint()
{
    if (player == nullptr)
    {
        return;
    }

    if (player->StatusEffectContainer->HasStatusEffect(xi::StatusEffect::Flee))
    {
        return;
    }

    if (heldPetras > 0)
    {
        player->pushPacket<GP_SERV_COMMAND_SYSTEMMES>(0, 0, MsgStd::CannotPerformPetra);

        return;
    }

    const auto now = timer::now();
    if (now < nextSprint)
    {
        const auto remaining = std::chrono::ceil<std::chrono::seconds>(nextSprint - now).count();
        player->pushPacket<GP_SERV_COMMAND_SYSTEMMES>(static_cast<uint32>(remaining), 0, MsgStd::WaitLonger);

        return;
    }

    nextSprint = now + conflict::SprintCooldown;
    player->StatusEffectContainer->AddStatusEffect(xi::StatusEffect::Sprint, std::to_underlying(xi::StatusEffect::Sprint), 100, 0s, 10s);
}

void ConflictEntry::Scout()
{
    if (player == nullptr)
    {
        return;
    }

    if (heldPetras < 1)
    {
        player->pushPacket<GP_SERV_COMMAND_SYSTEMMES>(0, 0, MsgStd::CannotPerformNoPetra);

        return;
    }

    const auto now = timer::now();
    if (now < nextScout)
    {
        return;
    }

    const auto* rook = ClosestRook();
    if (rook == nullptr)
    {
        return;
    }

    nextScout = now + conflict::ScoutCooldown;

    player->pushPacket<GP_SERV_COMMAND_BALLISTA::SCOUT>(rook, distance(player->loc.p, rook->loc.p));
}

void ConflictEntry::EnableCombat(const bool enable)
{
    if (player == nullptr)
    {
        return;
    }

    player->changeAllegiance(
        [&]
        {
            // An entry that has not been seated has no team, so it fights for nobody.
            const auto* team = instance->GetTeam(teamIdx);
            if (!enable || team == nullptr)
            {
                return xi::Allegiance::Player;
            }

            return team->allegiance;
        }());

    nextHint = [&]
    {
        if (charutils::hasKeyItem(player, kBallistaEarringKeyItem))
        {
            return timer::time_point::min();
        }

        return timer::time_point::max();
    }();

    if (enable)
    {
        player->health.tp = 0;
        player->updatemask |= UPDATE_HP;

        SendStatusUpdate();
    }
    else
    {
        if (player->isDead())
        {
            player->Raise();
        }

        player->UpdateHealth();
        player->health.hp = player->GetMaxHP();
        player->health.mp = player->GetMaxMP();

        // Nearby clients pick the allegiance change up from the updatemask changeAllegiance set;
        // the owning client needs to be told directly.
        player->pushPacket<CCharUpdatePacket>(player, ENTITY_UPDATE, static_cast<uint8>(UPDATE_LOOK | UPDATE_NAME));
        player->pushPacket<GP_SERV_COMMAND_BALLISTA::SCOREBOARD>(player, false);
    }

    UpdateMusic();
}

void ConflictEntry::UpdateMusic()
{
    if (player == nullptr)
    {
        return;
    }

    // TODO(conflict-music): swap the four zone music slots between the team track and the zone default.
}

void ConflictEntry::EnsureNonAnon()
{
    if (player == nullptr || !player->isAnon())
    {
        return;
    }

    // Anonymous hides the flag that tells other players which side someone is on.
    player->playerConfig.AnonymityFlg = false;
    charutils::SaveCharStats(player);
    player->pushPacket<CCharUpdatePacket>(player, ENTITY_UPDATE, static_cast<uint8>(UPDATE_NAME));
}

void ConflictEntry::SetupBattleCommunication()
{
    if (player)
    {
        charutils::UnequipLinkshells(player);

        // TODO(conflict-messages): send the menu config packet that locks chat during a match.
    }
}

void ConflictEntry::SetupTemporaryInventory(const SendUpdate sendUpdate)
{
    if (player == nullptr)
    {
        return;
    }

    // A container refuses to shrink below what it already holds, so a player who walks in carrying
    // more temporary items than the match allows would keep their full allowance for the whole
    // match. The Herald collects this storage at the end regardless, so it is emptied first.
    const auto* temp = player->getStorage(LOC_TEMPITEMS);
    if (temp != nullptr && temp->GetSize() - temp->GetFreeSlotsCount() > instance->settings.tempItemSize)
    {
        charutils::ClearTempItems(player, false);
    }

    charutils::SetTempInventorySize(player, instance->settings.tempItemSize, static_cast<bool>(sendUpdate));
}

auto ConflictEntry::ClosestRook() const -> CBaseEntity*
{
    if (player == nullptr)
    {
        return nullptr;
    }

    CBaseEntity* closest         = nullptr;
    auto         closestDistance = 0.0f;

    for (const auto rookId : instance->activeRooks)
    {
        auto* rook = zoneutils::GetEntity(rookId, TYPE_NPC);
        if (rook == nullptr)
        {
            continue;
        }

        const auto rookDistance = distance(player->loc.p, rook->loc.p);
        if (closest == nullptr || rookDistance < closestDistance)
        {
            closest         = rook;
            closestDistance = rookDistance;
        }
    }

    return closest;
}

auto ConflictEntry::ClosestRookDistance() const -> Maybe<float>
{
    const auto* rook = ClosestRook();
    if (rook == nullptr)
    {
        return std::nullopt;
    }

    return distance(player->loc.p, rook->loc.p);
}

auto ConflictEntry::HasActiveEntry() const -> bool
{
    return entryType == ConflictEntryType::Temporary || entryType == ConflictEntryType::Locked;
}

auto ConflictEntry::IsInActiveConflict() const -> bool
{
    return instance->IsActive() && HasActiveEntry();
}

void ConflictEntry::SetEntryType(const ConflictEntryType newEntryType)
{
    entryType = newEntryType;

    if (savedToDb)
    {
        db::preparedStmt("UPDATE conflict_entries SET type = ? WHERE instanceid = ? AND charid = ?",
                         std::to_underlying(entryType),
                         instance->GetId(),
                         charid);
    }
}

auto ConflictEntry::GetEntryType() const -> ConflictEntryType
{
    return entryType;
}

auto ConflictEntry::GetIndex() const -> uint8
{
    const auto* team = instance->GetTeam(teamIdx);
    if (team == nullptr)
    {
        return 0xFF;
    }

    const auto it = std::ranges::find(team->entries, this);
    if (it == team->entries.end())
    {
        return 0xFF;
    }

    return static_cast<uint8>(std::distance(team->entries.begin(), it));
}

auto ConflictEntry::GetTeam() const -> ConflictTeam*
{
    return instance->GetTeam(teamIdx);
}
