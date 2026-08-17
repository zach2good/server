-----------------------------------
-- Conflict (Ballista) field ('battle') Pursuivant: appears at the match camps
-- to lend/return the Ballista Earring during a match.
--
-- Ported from Eden; xi.ki -> xi.keyItem.
-----------------------------------
require('scripts/globals/conflict/zoneinfo')

xi = xi or {}
xi.conflict = xi.conflict or {}
xi.conflict.pursuivant = xi.conflict.pursuivant or {}
xi.conflict.pursuivant.battle = xi.conflict.pursuivant.battle or {}

function xi.conflict.pursuivant.battle.setup(conflict)
    local zoneInfo = xi.conflict.getZoneInfoForConflict(conflict)
    if zoneInfo == nil then
        return
    end

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

function xi.conflict.pursuivant.battle.onTrigger(player, npc)
    local zoneInfo = xi.conflict.getZoneInfoForEntity(player)
    if zoneInfo == nil then
        return
    end

    local params = {}
    params[0] = player:getAllegiance()
    params[1] = xi.conflict.getPursuivantIndex(zoneInfo, npc)
    params[2] = player:getCurrency('ballista_point')
    params[3] = player:hasKeyItem(xi.keyItem.BALLISTA_EARRING) and 1 or 0

    player:startEvent(zoneInfo.events.PURSUIVANT, params)
end

function xi.conflict.pursuivant.battle.onEventFinish(player, csid, option, npc)
    local zoneInfo = xi.conflict.getZoneInfoForEntity(player)
    if zoneInfo == nil or csid ~= zoneInfo.events.PURSUIVANT then
        return
    end

    if option == 1 then
        npcUtil.giveKeyItem(player, xi.keyItem.BALLISTA_EARRING)
    elseif option == 2 then
        player:delKeyItem(xi.keyItem.BALLISTA_EARRING)
        player:messageSpecial(zones[player:getZoneID()].text.HAND_OVER_KI, xi.keyItem.BALLISTA_EARRING)
    end
end
