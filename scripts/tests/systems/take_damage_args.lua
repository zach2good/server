-- takeDamage's optional arguments: absent ones take their defaults, supplied ones are used, and a
-- wrong type is an error rather than a silent fallback to the default.
describe('takeDamage arguments', function()
    ---@type CClientEntityPair
    local player

    ---@type CTestEntity
    local mob

    before_each(function()
        player = xi.test.world:spawnPlayer({ zone = xi.zone.WEST_RONFAURE, job = xi.job.WAR, level = 99 })
        mob    = player.entities:moveTo('Wild_Rabbit')
        mob:respawn()
        mob:setUnkillable(true)
    end)

    it('applies damage with no optional arguments', function()
        local before = mob:getHP()
        mob:takeDamage(10)
        assert(mob:getHP() == before - 10, string.format('HP %d -> %d', before, mob:getHP()))
    end)

    it('applies damage with every optional argument supplied', function()
        local before = mob:getHP()
        mob:takeDamage(10, player, xi.attackType.PHYSICAL, xi.damageType.SLASHING, { wakeUp = true, breakBind = true, removePetrify = false })
        assert(mob:getHP() == before - 10, string.format('HP %d -> %d', before, mob:getHP()))
    end)

    it('raises on a wrong-typed attacker', function()
        assert(not pcall(function()
            mob:takeDamage(10, 'not an entity')
        end))
    end)

    it('raises on a wrong-typed attack type', function()
        assert(not pcall(function()
            mob:takeDamage(10, player, 'not a number')
        end))
    end)
end)
