-----------------------------------
-- Conflict (Ballista) out-of-match notifications: tells players (in the match
-- zone, or in cities if they hold the Ballista Earring) about the next match.
--
-- Ported from Eden. Reads the match calendar through GetNextBallistaInfo.
-----------------------------------
require('scripts/globals/conflict/zoneinfo')

local nationSumToMatchup =
{
    [1] = 0,
    [3] = 1,
    [2] = 2,
}

local zoneToType =
{
    [xi.zone.JUGNER_FOREST]         = 0,
    [xi.zone.PASHHOW_MARSHLANDS]    = 1,
    [xi.zone.MERIPHATAUD_MOUNTAINS] = 2,
}

function xi.conflict.nextBallistaMatchNotification(player, force)
    local conflictZoneInfo = xi.conflict.getZoneInfoForEntity(player)
    local isCity = conflictZoneInfo == nil
    if isCity and not player:hasKeyItem(xi.keyItem.BALLISTA_EARRING) then
        -- Only inform players about the next match in cities if they hold the Ballista Earring.
        return
    end

    local dayOfMonth = VanadielDayOfTheMonth()
    if dayOfMonth % 2 == 0 then
        -- No messages on even days (Ballista match days).
        return
    end

    local info = GetNextBallistaInfo()
    if info == nil then
        return
    end

    if isCity then
        if not force and player:getCharVar('[Ballista]CityNextMatchInfo') == info.startTime then
            return
        else
            player:setCharVar('[Ballista]CityNextMatchInfo', info.startTime)
        end
    elseif info.zoneId ~= player:getZoneID() then
        -- Only inform of a match in the current zone when not in a city.
        return
    end

    local text =
    {
        MATCH_INFO   = 0,
        MATCH_ENTRY  = 0,
        MATCH_START  = 0,
        ENTRIES_OPEN = 0,
    }

    if conflictZoneInfo ~= nil then
        text.MATCH_INFO   = conflictZoneInfo.text.NEXT_MATCH_INFO
        text.MATCH_START  = conflictZoneInfo.text.NEXT_MATCH_START
        text.MATCH_ENTRY  = conflictZoneInfo.text.NEXT_MATCH_ENTRY
        text.ENTRIES_OPEN = conflictZoneInfo.text.TAKE_PART
    else
        text.MATCH_INFO   = zones[player:getZoneID()].text.NEXT_BALLISTA_MATCH or 0
        text.ENTRIES_OPEN = text.MATCH_INFO + 1
        text.MATCH_ENTRY  = text.MATCH_INFO + 2
        text.MATCH_START  = text.MATCH_INFO + 3
    end

    if text.MATCH_INFO == nil or text.MATCH_INFO == 0 then
        return
    end

    player:messageSpecial(text.MATCH_INFO, nationSumToMatchup[info.nation1 + info.nation2], info.levelCap / 10, info.signupFee, zoneToType[info.zoneId])

    local now       = VanadielUniqueDay() * 1440 + VanadielHour() * 60 + VanadielMinute()
    local entryTime = info.startTime - 720

    if not isCity or now >= entryTime then
        local startYear  = math.floor(info.startTime / 518400) + 886
        local startMonth = math.floor(info.startTime / 43200) % 12 + 1
        local startDay   = math.floor(info.startTime / 1440) % 30 + 1
        player:messageSpecial(text.MATCH_START, startYear, startMonth, startDay, info.startTime * 2.4)
    end

    if now < entryTime then
        local entryYear  = math.floor(entryTime / 518400) + 886
        local entryMonth = math.floor(entryTime / 43200) % 12 + 1
        local entryDay   = math.floor(entryTime / 1440) % 30 + 1
        player:messageSpecial(text.MATCH_ENTRY, entryYear, entryMonth, entryDay, entryTime * 2.4)
    else
        player:messageSpecial(text.ENTRIES_OPEN)
    end
end
