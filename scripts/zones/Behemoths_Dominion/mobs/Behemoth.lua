-----------------------------------
-- Area: Behemoth's Dominion
--  HNM: Behemoth
-----------------------------------
local ID = zones[xi.zone.BEHEMOTHS_DOMINION]
mixins = { require('scripts/mixins/rage') }
-----------------------------------
---@type TMobEntity
local entity = {}

entity.onMobSpawn = function(mob)
    mob:setLocalVar('[rage]timer', 1800) -- 30 minutes

    -- Despawn the ???
    GetNPCByID(ID.npc.BEHEMOTH_QM):setStatus(xi.status.DISAPPEAR)
end

entity.onMobFight = function(mob, target)
    local drawInTableNorth =
    {
        condition1 = target:getXPos() > -180 and target:getZPos() > 53,
        position   = { -182.19, -19.83, 58.34, target:getRotPos() },
    }
    local drawInTableSouth =
    {
        condition1 = target:getXPos() > -230 and target:getZPos() < 5,
        position   = { -235.35, -20.01, -4.47, target:getRotPos() },
    }

    utils.arenaDrawIn(mob, target, drawInTableNorth)
    utils.arenaDrawIn(mob, target, drawInTableSouth)
end

entity.onMobDeath = function(mob, player, optParams)
    player:addTitle(xi.title.BEHEMOTHS_BANE)
end

entity.onMobDespawn = function(mob)
    -- Respawn the ???
    GetNPCByID(ID.npc.BEHEMOTH_QM):updateNPCHideTime(xi.settings.main.FORCE_SPAWN_QM_RESET_TIME)
end

return entity
