-----------------------------------
-- Conflict (Ballista) field ('battle') Pursuivant: lends and takes back the Ballista Earring
-- during a match. Placing them at the camps is xi.conflict.pursuivant.field.setup's job.
-----------------------------------
require('scripts/globals/conflict/zoneinfo')

xi = xi or {}
xi.conflict = xi.conflict or {}
xi.conflict.pursuivant = xi.conflict.pursuivant or {}
xi.conflict.pursuivant.battle = xi.conflict.pursuivant.battle or {}

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

    -- The client picks which option it sends, so the gate the city Pursuivant applies to the same
    -- key item has to hold here too. This one only stands in the field during a match, so being in
    -- the match is part of it.
    if
        player:getConflictEntry() == nil or
        player:getRank(player:getNation()) < 3 or
        not player:hasKeyItem(xi.keyItem.BALLISTA_LICENSE)
    then
        return
    end

    if option == 1 then
        npcUtil.giveKeyItem(player, xi.keyItem.BALLISTA_EARRING)
    elseif option == 2 then
        player:delKeyItem(xi.keyItem.BALLISTA_EARRING)
        player:messageSpecial(zones[player:getZoneID()].text.HAND_OVER_KI, xi.keyItem.BALLISTA_EARRING)
    end
end
