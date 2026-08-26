-----------------------------------
-- Conflict (Ballista) shared helpers: broadcasting messages/animations to a
-- match or zone, teleporting, and the pre-match invisible/sneak handling.
-----------------------------------
xi = xi or {}
xi.conflict = xi.conflict or {}

function xi.conflict.messageSpecial(conflict, ...)
    for _, player in pairs(conflict:getPlayers()) do
        player:messageSpecial(...)
    end
end

function xi.conflict.messageText(conflict, ...)
    for _, player in pairs(conflict:getPlayers()) do
        player:messageText(...)
    end
end

function xi.conflict.entityMessageSpecial(conflict, entity, ...)
    for _, player in pairs(conflict:getPlayers()) do
        player:showText(entity, ...)
    end
end

function xi.conflict.animation(conflict, ...)
    for _, player in pairs(conflict:getPlayers()) do
        player:independentAnimation(player, ...)
    end
end

function xi.conflict.zoneMessageText(zone, ...)
    for _, player in pairs(zone:getPlayers()) do
        player:messageText(...)
    end
end

function xi.conflict.zoneFn(zone, fn)
    for _, player in pairs(zone:getPlayers()) do
        fn(player)
    end
end

-- Warping to a Ballista zone costs either the key item or this many Ballista Points.
local teleportCost = 100

local teleportZonePositions =
{
    [xi.zone.JUGNER_FOREST]        = { 33.832, 0.365, -31.15, 214, xi.zone.JUGNER_FOREST },
    [xi.zone.PASHHOW_MARSHLANDS]   = { 130.876, 24.542, 134.895, 167, xi.zone.PASHHOW_MARSHLANDS },
    [xi.zone.MERIPHATAUD_MOUNTAINS] = { -45.43, -15.147, 174.604, 190, xi.zone.MERIPHATAUD_MOUNTAINS },
}

function xi.conflict.teleportToZone(player, zoneId)
    local target = teleportZonePositions[zoneId]
    if target == nil then
        return false
    end

    if player:hasKeyItem(xi.keyItem.BALLISTA_INSTAPORT) then
        player:delKeyItem(xi.keyItem.BALLISTA_INSTAPORT)
        player:messageSpecial(zones[player:getZoneID()].text.HAND_OVER_KI, xi.keyItem.BALLISTA_INSTAPORT)
    elseif player:getCurrency('ballista_point') >= teleportCost then
        player:delCurrency('ballista_point', teleportCost)
        player:messageSpecial(zones[player:getZoneID()].text.USE_BALLISTA_POINTS, teleportCost)
    else
        return false
    end

    player:timer(500, function(player)
        player:setPos(unpack(target))
    end)

    return true
end

-- Engine hook: a player who died in a match has just been reraised (HP/MP restored engine-side).
-- Send them back to their team camp and grant a short Invisible so they can reposition safely.
function xi.conflict.reraiseAtCamp(player)
    local entry    = player:getConflictEntry()
    local zoneInfo = xi.conflict.getZoneInfoForEntity(player)
    if entry == nil or zoneInfo == nil or zoneInfo.camps == nil then
        return
    end

    local camp = zoneInfo.camps[entry:getTeamIndex() + 1]
    if camp ~= nil then
        player:setPos(camp[1], camp[2], camp[3], camp[4] or 0)
    end

    player:addStatusEffect(xi.effect.INVISIBLE, { tick = 10, duration = 30, origin = player })
end

function xi.conflict.giveInvisibleSneak(conflict)
    local zoneInfo = xi.conflict.getZoneInfoForConflict(conflict)
    if zoneInfo == nil then
        return
    end

    for _, player in pairs(conflict:getPlayers()) do
        player:messageText(player, zoneInfo.text.GAIN_INVISIBLE)
        player:addStatusEffect(xi.effect.INVISIBLE, { tick = 10, duration = 300, origin = player })
        player:messageText(player, zoneInfo.text.GAIN_SNEAK)
        player:addStatusEffect(xi.effect.SNEAK, { tick = 10, duration = 300, origin = player })
    end
end

function xi.conflict.removeInvisibleSneak(conflict)
    local zoneInfo = xi.conflict.getZoneInfoForConflict(conflict)
    if zoneInfo == nil then
        return
    end

    for _, player in pairs(conflict:getPlayers()) do
        player:delStatusEffect(xi.effect.INVISIBLE)
        player:delStatusEffect(xi.effect.SNEAK)
    end
end
