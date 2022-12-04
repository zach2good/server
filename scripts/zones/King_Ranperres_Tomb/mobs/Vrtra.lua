-----------------------------------
-- Area: King Ranperre's Tomb
--   NM: Vrtra
-----------------------------------
---@type TMobEntity
local entity = {}

local offsets = { 1, 3, 5, 2, 4, 6 }

entity.onMobEngage = function(mob, target)
    -- Reset the onMobFight variables
    mob:setLocalVar('spawnTime', 0)
    mob:setLocalVar('twohourTime', 0)
end

entity.onMobFight = function(mob, target)
    local spawnTime = mob:getLocalVar('spawnTime')
    local twohourTime = mob:getLocalVar('twohourTime')
    local fifteenBlock = mob:getBattleTime() / 15
    local drawInTableRoom =
    {
        condition1 = target:getXPos() < 180 and target:getZPos() > -305 and target:getZPos() < -290,
        position = { 180.79, 7.5, -299.96, target:getRotPos() },
    }

    if twohourTime == 0 then
        twohourTime = math.random(4, 6)
        mob:setLocalVar('twohourTime', twohourTime)
    end

    if spawnTime == 0 then
        spawnTime = math.random(3, 5)
        mob:setLocalVar('spawnTime', spawnTime)
    end

    if fifteenBlock > twohourTime then
        mob:useMobAbility(710)
        mob:setLocalVar('twohourTime', fifteenBlock + math.random(4, 6))
    elseif fifteenBlock > spawnTime then
        local mobId = mob:getID()

        for i, offset in ipairs(offsets) do
            local pet = GetMobByID(mobId + offset)

            if pet and not pet:isSpawned() then
                pet:spawn(60)
                local pos = mob:getPos()
                pet:setPos(pos.x, pos.y, pos.z)
                pet:updateEnmity(target)
                break
            end
        end

        mob:setLocalVar('spawnTime', fifteenBlock + 4)
    end
    -- Vrtra draws in if you attempt to leave the room
    utils.arenaDrawIn(mob, target, drawInTableRoom)
end

entity.onMobDisengage = function(mob)
    for i, offset in ipairs(offsets) do
        DespawnMob(mob:getID() + offset)
    end
end

entity.onMobDeath = function(mob, player, optParams)
    player:addTitle(xi.title.VRTRA_VANQUISHER)
end

entity.onMobDespawn = function(mob)
    -- Set Vrtra's spawnpoint and respawn time (3-5 days)
    UpdateNMSpawnPoint(mob:getID())
    mob:setRespawnTime(math.random(259200, 432000))
end

return entity
