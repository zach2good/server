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

#include "conflictutils.h"

#include "common/database.h"
#include "common/logging.h"
#include "common/vana_time.h"

#include "lua/luautils.h"
#include "utils/timeutils.h"
#include "utils/zoneutils.h"
#include "zone.h"

#include <array>
#include <utility>

namespace
{

// The zones that host scheduled Ballista. A process that loads none of them does no scheduling.
constexpr std::array kConflictZones = {
    xi::ZoneId::JugnerForest,
    xi::ZoneId::PashhowMarshlands,
    xi::ZoneId::MeriphataudMountains,
};

bool              isConflictProcess = false;
timer::time_point scheduleUpdate    = timer::time_point::max();

// GetNextBallistaSettings is asked for on every Herald visit, so the answer is cached per match.
uint32           nextBallistaSettingsStart = 0;
ConflictSettings nextBallistaSettings;

struct VanaDate
{
    int32 year  = 0; // Years since 886, matching vanadiel_time::get_year()
    uint8 month = 1;
    uint8 day   = 1;
};

auto currentVanaDate() -> VanaDate
{
    const auto now = vanadiel_time::now();

    return VanaDate{
        .year  = vanadiel_time::get_year(now),
        .month = static_cast<uint8>(vanadiel_time::get_month(now)),
        .day   = static_cast<uint8>(vanadiel_time::get_monthday(now)),
    };
}

// Drops the database rows of matches that finished long enough ago that nobody can still collect
// from the Herald.
void cleanupFinishedMatches(const uint32 vanaTimestamp)
{
    if (!db::preparedStmt("DELETE FROM conflict_instances WHERE start + length + ? < ?", kCleanupGraceVanaMinutes, vanaTimestamp))
    {
        ShowError("conflictutils: failed to clean up finished Conflict matches.");
    }
}

// 06:00 tomorrow, when the scheduler next looks ahead.
auto nextScheduleUpdate() -> timer::time_point
{
    return timeutils::GetTimePointFromVanaTimestamp(timeutils::GetVanaTimestampAt(6, 0, 1));
}

void seedMatch(const ConflictSettings& settings)
{
    // An odd day, or a slot the calendar leaves empty, produces settings with no zone.
    if (settings.zoneId == xi::ZoneId::Unknown)
    {
        return;
    }

    conflictutils::CreateConflictInstance(settings);
}

} // namespace

namespace conflictutils
{

auto CreateConflictInstance(ConflictSettings settings) -> ConflictInstance*
{
    auto* zone = zoneutils::GetZone(settings.zoneId);
    if (zone == nullptr)
    {
        ShowErrorFmt("conflictutils: zone {} is not loaded on this process, cannot start a Conflict match.",
                     std::to_underlying(settings.zoneId));
        return nullptr;
    }

    // Torn down before the replacement is installed: assigning through the Box would destroy the
    // old match afterwards, and its Lua cleanup would then hide the new match's NPCs.
    zone->conflict.reset();
    zone->conflict = makeBox<ConflictInstance>(settings, zone);

    luautils::ConflictSetup(zone->conflict.get());

    return zone->conflict.get();
}

void DestroyConflictInstance(CZone* zone)
{
    if (zone == nullptr)
    {
        return;
    }

    zone->conflict.reset();
}

auto IsConflictProcess() -> bool
{
    for (const auto zoneId : kConflictZones)
    {
        if (zoneutils::GetZone(zoneId) != nullptr)
        {
            return true;
        }
    }

    return false;
}

auto GetEntryFeeFromLevelCap(const uint8 levelCap) -> uint16
{
    switch (levelCap)
    {
        case 30:
            return 500;
        case 40:
            return 1000;
        case 50:
            return 1500;
        case 60:
            return 2000;
        case 0:
            return 3000; // Uncapped
        default:
            return 0;
    }
}

auto GetBallistaSettingsFromDate(uint8 dayOfMonth, uint8 month, int32 year) -> ConflictSettings
{
    // Ballista runs on even days only.
    if (dayOfMonth % 2 == 1)
    {
        return {};
    }

    // Callers ask about the day either side of today, which can fall outside this month.
    auto day       = static_cast<int32>(dayOfMonth);
    auto thisMonth = static_cast<int32>(month);

    while (day <= 0)
    {
        day += 30;
        --thisMonth;
    }

    while (day > 30)
    {
        day -= 30;
        ++thisMonth;
    }

    while (thisMonth > 12)
    {
        thisMonth -= 12;
        ++year;
    }

    while (thisMonth <= 0)
    {
        thisMonth += 12;
        --year;
    }

    auto settings = ConflictSettings();

    settings.isScheduled = true;
    settings.matchStart  = timeutils::GetVanaTimestampFromDate(year, static_cast<uint8>(thisMonth), static_cast<uint8>(day));
    settings.matchLength = 60 * 24; // One Vana'diel day

    // The three zones take turns, and the nations they pit against each other rotate by season.
    const auto matchup = [&](xi::Allegiance early, xi::Allegiance mid, xi::Allegiance late)
    {
        if (thisMonth <= 4)
        {
            return early;
        }

        if (thisMonth <= 8)
        {
            return mid;
        }

        return late;
    };

    switch ((day - 1) % 6)
    {
        case 1:
            settings.zoneId              = xi::ZoneId::JugnerForest;
            settings.restrictNormalItems = false;
            settings.tempItemSize        = 10;
            settings.type                = xi::ConflictType::AllOrNothing;
            settings.team1               = matchup(xi::Allegiance::SanDoria, xi::Allegiance::Bastok, xi::Allegiance::SanDoria);
            settings.team2               = matchup(xi::Allegiance::Bastok, xi::Allegiance::Windurst, xi::Allegiance::Windurst);
            break;

        case 3:
            settings.zoneId              = xi::ZoneId::PashhowMarshlands;
            settings.restrictNormalItems = true;
            // The 2005/02/24 update raised the allowance from ten to fifteen, naming Pashhow as
            // the one area where a player's own items cannot be used. String 7258 offers only
            // three match styles and has no restricted Best of Three, so this is the only zone.
            settings.tempItemSize     = 15;
            settings.initialTempItems = true;
            settings.type             = xi::ConflictType::AllOrNothing;
            settings.team1            = matchup(xi::Allegiance::Bastok, xi::Allegiance::SanDoria, xi::Allegiance::SanDoria);
            settings.team2            = matchup(xi::Allegiance::Windurst, xi::Allegiance::Windurst, xi::Allegiance::Bastok);
            break;

        case 5:
            settings.zoneId              = xi::ZoneId::MeriphataudMountains;
            settings.restrictNormalItems = false;
            settings.tempItemSize        = 10;
            settings.type                = xi::ConflictType::BestOfThree;
            settings.team1               = matchup(xi::Allegiance::SanDoria, xi::Allegiance::SanDoria, xi::Allegiance::Bastok);
            settings.team2               = matchup(xi::Allegiance::Windurst, xi::Allegiance::Bastok, xi::Allegiance::Windurst);
            break;

        default:
            // An even day the calendar leaves empty.
            return {};
    }

    // The cap climbs through the month and the last few days are uncapped.
    if (day < 26)
    {
        settings.levelCap = static_cast<uint8>((day - 1) / 6 * 10 + 30);
    }

    settings.signupFee = GetEntryFeeFromLevelCap(settings.levelCap);

    return settings;
}

auto GetNextBallistaSettings() -> const ConflictSettings&
{
    const auto date = currentVanaDate();

    // Today if today is a match day, otherwise tomorrow.
    const auto nextMatchDay = static_cast<uint8>(date.day + (date.day % 2));

    // Keyed on the whole date rather than the day alone. A Vana'diel month is under thirty hours,
    // so a day number comes round again while the process is still up, and the same day of the
    // next month would be answered with last month's pairing and a start time in the past.
    const auto nextMatchStart = timeutils::GetVanaTimestampFromDate(date.year, date.month, nextMatchDay);

    if (nextBallistaSettingsStart != nextMatchStart)
    {
        nextBallistaSettings      = GetBallistaSettingsFromDate(nextMatchDay, date.month, date.year);
        nextBallistaSettingsStart = nextMatchStart;
    }

    return nextBallistaSettings;
}

void Initialize()
{
    // Ad-hoc matches do not survive a restart; only scheduled ones are recovered.
    if (!db::preparedStmt("DELETE FROM conflict_instances WHERE type = 0"))
    {
        ShowError("conflictutils: failed to clean up ad hoc Conflict matches.");
    }

    if (!IsConflictProcess())
    {
        return;
    }

    isConflictProcess = true;

    const auto date = currentVanaDate();

    cleanupFinishedMatches(timeutils::GetCurrentVanaTimestamp());

    // Seed the matches bracketing now: on an odd day that is yesterday's and tomorrow's, so a
    // match still in its collection window is recovered alongside the one about to open.
    if (date.day % 2 == 1)
    {
        seedMatch(GetBallistaSettingsFromDate(date.day - 1, date.month, date.year));
        seedMatch(GetBallistaSettingsFromDate(date.day + 1, date.month, date.year));
    }
    else
    {
        seedMatch(GetBallistaSettingsFromDate(date.day, date.month, date.year));
    }

    scheduleUpdate = nextScheduleUpdate();

    ShowInfo("conflictutils: Conflict (Ballista) scheduler initialised for this process.");
}

void Tick(const timer::time_point tick)
{
    if (!isConflictProcess)
    {
        return;
    }

    // Reap matches whose collection window has closed. A live match is advanced by its own zone's
    // tick, so this only tears finished ones down.
    for (const auto zoneId : kConflictZones)
    {
        auto* zone = zoneutils::GetZone(zoneId);
        if (zone == nullptr || !zone->conflict)
        {
            continue;
        }

        if (tick > zone->conflict->cleanupTime)
        {
            zone->conflict.reset();
        }
    }

    if (tick < scheduleUpdate)
    {
        return;
    }

    const auto date = currentVanaDate();

    // On an odd day tomorrow's match can be planned.
    if (date.day % 2 == 1)
    {
        seedMatch(GetBallistaSettingsFromDate(date.day + 1, date.month, date.year));
    }

    scheduleUpdate = nextScheduleUpdate();

    cleanupFinishedMatches(timeutils::GetCurrentVanaTimestamp());
}

} // namespace conflictutils
