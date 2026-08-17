-----------------------------------
-- Area: Jugner Forest (104)
--  NPC: Herald
-- !pos 45.258 0.26 -9.622 104
-- Runs Conflict (Ballista) sign-up for this zone.
-----------------------------------
require('scripts/globals/conflict/herald')
-----------------------------------
---@type TNpcEntity
local entity = {}

entity.onTrigger = function(player, npc)
    xi.conflict.herald.onTrigger(player, npc)
end

entity.onEventUpdate = function(player, csid, option, npc)
    xi.conflict.herald.onEventUpdate(player, csid, option)
end

entity.onEventFinish = function(player, csid, option, npc)
    xi.conflict.herald.onEventFinish(player, csid, option, npc)
end

return entity
