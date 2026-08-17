-----------------------------------
-- Area: Pashhow Marshlands (109)
--  NPC: Rook
-- !pos 107.043 24.999 210.024 109
-- Petras are thrown into these to score during a Conflict (Ballista) match.
-----------------------------------
require('scripts/globals/conflict/rook')
-----------------------------------
---@type TNpcEntity
local entity = {}

entity.onTrigger = function(player, npc)
    xi.conflict.rook.onTrigger(player, npc)
end

entity.onEventFinish = function(player, csid, option, npc)
    xi.conflict.rook.onEventFinish(player, csid, option, npc)
end

return entity
