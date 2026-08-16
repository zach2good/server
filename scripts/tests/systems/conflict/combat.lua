-----------------------------------
-- Conflict (Ballista): the combat rules that only apply inside a match.
--
-- A PVP fight should not be decided by whoever lands the first big hit or the first sleep, so
-- damage is softened and status effects are harder to land while a match is running.
-----------------------------------

describe('Conflict (Ballista) combat', function()
    ---@type CClientEntityPair
    local p1
    ---@type CClientEntityPair
    local p2

    local playerConfig =
    {
        zone  = xi.zone.JUGNER_FOREST,
        job   = xi.job.WAR,
        level = 75,
    }

    local function startMatch()
        local zone = p1:getZone()

        zone:initializeConflict({
            team1  = xi.allegiance.SAN_DORIA,
            team2  = xi.allegiance.BASTOK,
            length = 60 * 24,
        })

        local conflict = zone:getConflict()

        conflict:addPlayer(p1, 0)
        conflict:addPlayer(p2, 1)

        return conflict
    end

    before_each(function()
        p1 = xi.test.world:spawnPlayer(playerConfig)
        p2 = xi.test.world:spawnPlayer(playerConfig)

        p2:setPos(p1:getXPos(), p1:getYPos(), p1:getZPos())
    end)

    it('softens damage taken inside a match', function()
        local conflict = startMatch()

        local maxHp = p2:getMaxHP()

        -- The same blow outside a match, for comparison.
        p2:setHP(maxHp)
        p2:takeDamage(1000, p1)
        local outsideLoss = maxHp - p2:getHP()

        conflict:setCombatEnabled(true)
        assert(p2:isInConflict(), 'setup: the target should be in the match')

        p2:setHP(maxHp)
        p2:takeDamage(1000, p1)
        local insideLoss = maxHp - p2:getHP()

        assert(insideLoss < outsideLoss,
            'damage inside a match should be softened: ' .. insideLoss .. ' vs ' .. outsideLoss)
    end)

    it('never turns a large hit into healing', function()
        local conflict = startMatch()

        conflict:setCombatEnabled(true)

        -- The reduction scales with the size of the hit, and a naive formula reaches zero and then
        -- goes negative around 4000.
        for _, hit in ipairs({ 3999, 4000, 4001, 20000 }) do
            local maxHp = p2:getMaxHP()

            p2:setHP(maxHp)
            p2:takeDamage(hit, p1)

            assert(p2:getHP() <= maxHp, 'a hit of ' .. hit .. ' restored HP instead of taking it')
            assert(p2:getHP() < maxHp, 'a hit of ' .. hit .. ' did nothing at all')
        end
    end)

    it('leaves damage alone outside a match', function()
        startMatch()

        local maxHp = p2:getMaxHP()

        -- Combat was never enabled, so nobody is fighting for a nation yet.
        assert(not p2:isInConflict(), 'setup: the target should not be in the match')

        p2:setHP(maxHp)
        p2:takeDamage(500, p1)

        assert(maxHp - p2:getHP() == 500, 'damage outside a match should be untouched')
    end)
end)
