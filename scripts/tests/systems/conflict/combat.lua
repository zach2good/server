-----------------------------------
-- Conflict (Ballista): the combat rules that only apply inside a match.
--
-- Damage is passed through unchanged, but status effects are harder to land and melee reach is
-- wider while a match is running.
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

    -- A retail capture of a private match in Diorama Abdhaljs-Ghelsba (2019-12-15) has one player
    -- killing another with a 1833 damage weaponskill. Eden scales PVP damage by (1 - damage/4000),
    -- which cannot produce anything above 1000, so retail is not doing that and nothing else
    -- suggests a curve of its own. Damage is passed through untouched.
    it('does not scale damage taken inside a match', function()
        local conflict = startMatch()

        local maxHp = p2:getMaxHP()

        p2:setHP(maxHp)
        p2:takeDamage(1000, p1)
        local outsideLoss = maxHp - p2:getHP()

        conflict:setCombatEnabled(true)
        assert(p2:isInConflict(), 'setup: the target should be in the match')

        p2:setHP(maxHp)
        p2:takeDamage(1000, p1)
        local insideLoss = maxHp - p2:getHP()

        assert(insideLoss == outsideLoss,
            'a match should not change damage taken: ' .. insideLoss .. ' inside vs ' .. outsideLoss .. ' outside')
    end)

    -- The capture's killing blow, which any softening curve would have cut down.
    it('lands a weaponskill-sized hit in full', function()
        local conflict = startMatch()

        conflict:setCombatEnabled(true)

        p2:setMaxHP(5000)
        p2:setHP(5000)
        p2:takeDamage(1833, p1)

        assert(5000 - p2:getHP() == 1833, 'expected the full 1833 to land, took ' .. (5000 - p2:getHP()))
    end)

    -- The wider reach is there because players are harder to stay next to than mobs, so it has to
    -- depend on who is being hit, not only on who is swinging.
    it('widens melee reach between two participants', function()
        local conflict = startMatch()

        local baseline = p1:getMeleeRange(p2)

        conflict:setCombatEnabled(true)

        assert(p1:isInConflict(), 'setup: the attacker should be in the match')
        assert(p2:isInConflict(), 'setup: the target should be in the match')

        assert(p1:getMeleeRange(p2) > baseline, 'two participants should reach further')
    end)

    it('leaves melee reach alone against something outside the match', function()
        local conflict = startMatch()

        local mob = xi.test.world:spawnPlayer(playerConfig)
        local baseline = p1:getMeleeRange(mob)

        conflict:setCombatEnabled(true)

        assert(p1:isInConflict(), 'setup: the attacker should be in the match')
        assert(not mob:isInConflict(), 'setup: the target should not be in the match')

        assert(p1:getMeleeRange(mob) == baseline, 'a participant should not out-reach a bystander')
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
