-----------------------------------
-- Conflict (Ballista): dying in a match.
--
-- A match revives its own dead rather than letting them home point out, so the engine drops the
-- petras they were carrying and hands the reraise to Lua, which returns them to their team camp.
-----------------------------------

describe('Conflict (Ballista) death', function()
    ---@type CClientEntityPair
    local player

    -- Red Mage so MP is worth asserting on.
    local playerConfig =
    {
        zone  = xi.zone.JUGNER_FOREST,
        job   = xi.job.RDM,
        level = 75,
    }

    local function startMatch()
        local zone = player:getZone()

        zone:initializeConflict({
            team1  = xi.allegiance.SAN_DORIA,
            team2  = xi.allegiance.BASTOK,
            length = 60 * 24,
        })

        local conflict = zone:getConflict()
        conflict:addPlayer(player, 0)
        conflict:setCombatEnabled(true)

        return conflict
    end

    before_each(function()
        player = xi.test.world:spawnPlayer(playerConfig)
    end)

    it('drops held petras on death', function()
        startMatch()

        local entry = player:getConflictEntry()
        entry:addPetras(4)
        assert(entry:getHeldPetras() == 4, 'setup: player should be holding 4 petras')

        player:setHP(0)
        xi.test.world:tick(xi.tick.ZONE)

        assert(entry:getHeldPetras() == 0, 'petras should be dropped on death')
    end)

    it('revives the player at their camp instead of home pointing them', function()
        startMatch()

        local zoneInfo = xi.conflict.getZoneInfo(xi.zone.JUGNER_FOREST)
        local camp     = zoneInfo.camps[1]

        -- Drained first, or the reraise's floor of half MP is met by the MP the player never
        -- spent and the assertion below proves nothing.
        player:setMP(0)

        player:setHP(0)
        xi.test.world:tick(xi.tick.ZONE)

        -- The reraise is delayed, so nothing should have happened yet.
        assert(player:getHP() == 0, 'the player should still be dead immediately after dying')
        assert(player:getMP() == 0, 'setup: the player should have died with no MP')

        xi.test.world:skipTime(35)
        xi.test.world:tick(xi.tick.ZONE)

        assert(player:getHP() > 0, 'the player should have been revived')
        assert(player:getMP() >= player:getMaxMP() / 2, 'MP should be restored to at least half')
        assert(player:getZoneID() == xi.zone.JUGNER_FOREST, 'the player should not have left the zone')

        -- Back at their own team's camp, not wherever they fell.
        assert(math.abs(player:getXPos() - camp[1]) < 5, 'the player should be at their team camp')
        assert(math.abs(player:getZPos() - camp[3]) < 5, 'the player should be at their team camp')

        assert(player:hasStatusEffect(xi.effect.INVISIBLE), 'the reraised player should be covered by Invisible')
    end)
end)
