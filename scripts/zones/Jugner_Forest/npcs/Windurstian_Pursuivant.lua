-----------------------------------
-- Area: Jugner Forest (104)
--  NPC: Windurstian Pursuivant
-- !pos placed by the match; see scripts/globals/conflict/zoneinfo.lua
-- Handles entry and rewards on the field during a Conflict (Ballista) match.
-----------------------------------
require('scripts/globals/conflict/battle_pursuivant')
-----------------------------------
---@type TNpcEntity
local entity = {}

entity.onTrigger = function(player, npc)
    xi.conflict.pursuivant.battle.onTrigger(player, npc)
end

entity.onEventFinish = function(player, csid, option, npc)
    xi.conflict.pursuivant.battle.onEventFinish(player, csid, option, npc)
end

return entity
