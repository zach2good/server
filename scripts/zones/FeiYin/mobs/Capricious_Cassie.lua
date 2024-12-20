-----------------------------------
-- Area: Fei'Yin
--   NM: Capricious Cassie
-----------------------------------
mixins = { require('scripts/mixins/rage') }
-----------------------------------
---@type TMobEntity
local entity = {}

entity.onMobSpawn = function(mob)
    mob:setMobMod(xi.mobMod.ALWAYS_AGGRO, 1)
    mob:setMobMod(xi.mobMod.NO_MOVE, 0)
end

entity.onMobRoam = function(mob)
    mob:setMobMod(xi.mobMod.NO_MOVE, 0)
end

entity.onMobFight = function(mob, target)
    local spawnPos = mob:getSpawnPos()
    local drawInTable =
    {
        conditions =
        {
            target:checkDistance(spawnPos.x, spawnPos.y, spawnPos.z) > 40,
        },
        position = mob:getPos(),
        wait = 3,
    }
    if drawInTable.conditions[1] then
        mob:setMobMod(xi.mobMod.NO_MOVE, 1)
        utils.drawIn(target, drawInTable)
    else
        mob:setMobMod(xi.mobMod.NO_MOVE, 0)
    end
end

entity.onMobDeath = function(mob, player, optParams)
    player:addTitle(xi.title.CASSIENOVA)
end

entity.onMobDespawn = function(mob)
    UpdateNMSpawnPoint(mob:getID())
    mob:setRespawnTime(math.random(75600, 86400)) -- 21-24 hours
end

return entity
