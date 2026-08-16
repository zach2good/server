-----------------------------------
-- Conflict (Ballista) city Pursuivant: lends the Ballista key items, sells the
-- Instaport teleport, and (field variant) appears at the match camps.
--
-- Ported from Eden.
-----------------------------------
require('scripts/globals/conflict/utils')

xi = xi or {}
xi.conflict = xi.conflict or {}
xi.conflict.pursuivant = xi.conflict.pursuivant or {}
xi.conflict.pursuivant.field = xi.conflict.pursuivant.field or {}

local eventByZone =
{
    [xi.zone.RULUDE_GARDENS]      = 69,
    [xi.zone.PORT_BASTOK]         = 304,
    [xi.zone.WINDURST_WATERS]     = 870,
    [xi.zone.NORTHERN_SAN_DORIA]  = 760,
    [xi.zone.AHT_URHGAN_WHITEGATE] = 773,
}

function xi.conflict.pursuivant.onTrigger(player, npc)
    local eventId = eventByZone[player:getZoneID()]
    if eventId == nil then
        return
    end

    local bp = player:getBallistaPoints()
    local params = {}

    -- First two bits are nation.
    params[0] = player:getNation()

    if player:getRank(player:getNation()) >= 3 then
        params[0] = params[0] + 0x20
    end

    if player:hasKeyItem(xi.keyItem.BALLISTA_LICENSE) then
        params[0] = params[0] + 0x40
    end

    if bp >= 100 or player:hasKeyItem(xi.keyItem.BALLISTA_INSTAPORT) then
        params[0] = params[0] + 0x80
    end

    if player:hasKeyItem(xi.keyItem.PETRA_SHOVEL) then
        params[0] = params[0] + 0x200
    end

    if player:hasKeyItem(xi.keyItem.BALLISTA_EARRING) then
        params[0] = params[0] + 0x400
    end

    if player:hasKeyItem(xi.keyItem.BALLISTA_BAND) then
        params[0] = params[0] + 0x800
    end

    -- params[1] is consistent across characters/worlds but changes occasionally (possible 'seasons').
    params[1] = 0x201201C0
    params[2] = bp

    player:startEvent(eventId, params)
end

function xi.conflict.pursuivant.onEventUpdate(player, csid, option)
    local eventId = eventByZone[player:getZoneID()]
    if eventId == nil or eventId ~= csid then
        return
    end

    if option % 65536 == 3 then
        local nextBallistaInfo = GetNextBallistaInfo()
        if nextBallistaInfo ~= nil then
            player:timer(2000, function(player)
                xi.conflict.teleportToZone(player, nextBallistaInfo.zoneId)
            end)
        end
    end
end

function xi.conflict.pursuivant.onEventFinish(player, csid, option, npc)
    local eventId = eventByZone[player:getZoneID()]
    if eventId == nil or eventId ~= csid then
        return
    end

    local keyItem = nil
    if option == 5 then
        keyItem = xi.keyItem.BALLISTA_EARRING
    elseif option == 6 then
        keyItem = xi.keyItem.PETRA_SHOVEL
    elseif option == 7 then
        keyItem = xi.keyItem.BALLISTA_BAND
    end

    if keyItem ~= nil then
        -- NOTE: this client only exposes the borrow/return text as event-dialog strings
        -- ('You borrow $6!' / 'You return the $3!', param slot $6/$3), which don't render via
        -- messageSpecial(id, keyItem) (param 0). There is no standalone param-0 string to source,
        -- so YOU_BORROW_KEYITEM / YOU_RETURN_KEYITEM stay undefined and the message is skipped;
        -- the key item is still granted/returned.
        local zoneText = zones[player:getZoneID()].text
        if player:hasKeyItem(keyItem) then
            player:delKeyItem(keyItem)
            if zoneText.YOU_RETURN_KEYITEM ~= nil then
                player:messageSpecial(zoneText.YOU_RETURN_KEYITEM, keyItem)
            end
        else
            player:addKeyItem(keyItem)
            if zoneText.YOU_BORROW_KEYITEM ~= nil then
                player:messageSpecial(zoneText.YOU_BORROW_KEYITEM, keyItem)
            end
        end
    end
end

function xi.conflict.pursuivant.field.setup(conflict)
    local zoneInfo = xi.conflict.getZoneInfoForConflict(conflict)
    local n1, n2 = conflict:getTeamNations()

    local zone = conflict:getZone()
    local p1   = xi.conflict.getPursuivantEntity(zone, n1)
    local p2   = xi.conflict.getPursuivantEntity(zone, n2)

    local timeline = conflict:getTimelineAt(conflict:getStartTime())
    timeline:addEvent(function()
        if p1 then
            local pos = zoneInfo.pursuivants.pos[1]
            p1:setPos(pos[1], pos[2], pos[3], pos[4])
            p1:setStatus(xi.status.NORMAL)
        end

        if p2 then
            local pos = zoneInfo.pursuivants.pos[2]
            p2:setPos(pos[1], pos[2], pos[3], pos[4])
            p2:setStatus(xi.status.NORMAL)
        end
    end)

    timeline = conflict:getTimelineAt(conflict:getEndTime())
    timeline:addEvent(function()
        if p1 then
            p1:setStatus(xi.status.DISAPPEAR)
        end

        if p2 then
            p2:setStatus(xi.status.DISAPPEAR)
        end
    end)
end

function xi.conflict.pursuivant.field.onTrigger(player, npc)
    -- Field pursuivant interaction is handled by xi.conflict.pursuivant.battle (battle_pursuivant.lua).
end
