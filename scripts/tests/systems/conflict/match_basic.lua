-----------------------------------
-- Conflict (Ballista): ad-hoc match lifecycle.
--
-- Covers the engine core and its Lua bindings: creating a match on a zone, flagging players onto
-- teams, the allegiance swap that turns combat on, and petra scoring.
-----------------------------------

describe('Conflict (Ballista) ad-hoc match', function()
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
            length = 60 * 24, -- One Vana'diel day
        })

        return zone:getConflict()
    end

    before_each(function()
        p1 = xi.test.world:spawnPlayer(playerConfig)
        p2 = xi.test.world:spawnPlayer(playerConfig)
    end)

    it('initializes an ad-hoc conflict on the zone', function()
        local conflict = startMatch()

        assert(conflict ~= nil, 'conflict was not created on the zone')
        assert(p1:getZone():getConflict() ~= nil, 'zone:getConflict() returned nil after init')
    end)

    it('flags two players onto opposing teams', function()
        local conflict = startMatch()

        assert(conflict:addPlayer(p1, 0), 'p1 failed to join team 0')
        assert(conflict:addPlayer(p2, 1), 'p2 failed to join team 1')

        local count1, count2 = conflict:getTeamCounts()
        assert(count1 == 1, 'team 0 should have exactly 1 member')
        assert(count2 == 1, 'team 1 should have exactly 1 member')

        assert(p1:getConflictEntry() ~= nil, 'p1 has no active conflict entry')
        assert(p2:getConflictEntry() ~= nil, 'p2 has no active conflict entry')
    end)

    it('swaps player allegiance when combat is enabled', function()
        local conflict = startMatch()

        conflict:addPlayer(p1, 0)
        conflict:addPlayer(p2, 1)

        conflict:setCombatEnabled(true)
        assert(conflict:isCombatEnabled(), 'combat was not enabled')

        assert(p1:getAllegiance() == xi.allegiance.SAN_DORIA, 'p1 allegiance did not swap to its team')
        assert(p2:getAllegiance() == xi.allegiance.BASTOK, 'p2 allegiance did not swap to its team')

        conflict:setCombatEnabled(false)
        assert(p1:getAllegiance() == xi.allegiance.PLAYER, 'p1 allegiance did not reset')
        assert(p2:getAllegiance() == xi.allegiance.PLAYER, 'p2 allegiance did not reset')
    end)

    it('reports being in a conflict only while combat is enabled', function()
        local conflict = startMatch()

        conflict:addPlayer(p1, 0)
        assert(not p1:isInConflict(), 'p1 should not count as in conflict before combat starts')

        conflict:setCombatEnabled(true)
        assert(p1:isInConflict(), 'p1 should count as in conflict once combat starts')

        conflict:setCombatEnabled(false)
        assert(not p1:isInConflict(), 'p1 should not count as in conflict after combat ends')
    end)

    it('tracks petra scoring per team', function()
        local conflict = startMatch()

        conflict:addPlayer(p1, 0)
        conflict:addPlayer(p2, 1)
        conflict:setCombatEnabled(true)

        local entry1 = p1:getConflictEntry()
        assert(entry1 ~= nil, 'p1 has no conflict entry')

        entry1:addPetras(5)
        assert(entry1:getHeldPetras() == 5, 'p1 should be holding 5 petras')

        local scored = entry1:scorePetras()
        assert(scored == 5, 'p1 should have scored 5 petras')
        assert(entry1:getHeldPetras() == 0, 'p1 should have no petras left after scoring')

        local score1, score2 = conflict:getTeamScores()
        assert(score1 == 5, 'team 0 score should be 5')
        assert(score2 == 0, 'team 1 score should be 0')
    end)

    it('scores at most five petras per throw', function()
        local conflict = startMatch()

        conflict:addPlayer(p1, 0)
        conflict:setCombatEnabled(true)

        local entry1 = p1:getConflictEntry()
        entry1:addPetras(8)

        assert(entry1:scorePetras() == 5, 'a throw should score at most 5 petras')
        assert(entry1:getHeldPetras() == 3, 'the remaining petras should still be held')
    end)

    it('rejects a round win for a team index that does not exist', function()
        local conflict = startMatch()

        assert(conflict:addTeamRoundWon(0), 'team 0 should accept a round win')
        assert(conflict:addTeamRoundWon(1), 'team 1 should accept a round win')

        -- A match has exactly two teams, so index 2 is off the end of the array.
        assert(not conflict:addTeamRoundWon(2), 'an out of range team index should be rejected')

        local rounds1, rounds2 = conflict:getTeamRounds()
        assert(rounds1 == 1, 'team 0 should have exactly 1 round won')
        assert(rounds2 == 1, 'team 1 should have exactly 1 round won')
    end)
end)
