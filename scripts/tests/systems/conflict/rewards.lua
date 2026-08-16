-----------------------------------
-- Conflict (Ballista): leaving a match, and what the Herald pays out.
--
-- The Herald holds every entry fee until the match resolves. Walking away before it starts is
-- free, walking out of a live match forfeits the fee, the winning side splits the pot, and a draw
-- returns what each player put in.
-----------------------------------

describe('Conflict (Ballista) rewards', function()
    ---@type CClientEntityPair
    local p1
    ---@type CClientEntityPair
    local p2

    local entryFee = 2000

    local function startMatch()
        local zone = p1:getZone()

        zone:initializeConflict({
            team1     = xi.allegiance.SAN_DORIA,
            team2     = xi.allegiance.BASTOK,
            signupFee = entryFee,
            length    = 60 * 24,
        })

        local conflict = zone:getConflict()

        conflict:setState(xi.conflictState.SIGN_UP)
        conflict:setSignupState(xi.conflictSignupState.NATIONS)

        return conflict
    end

    before_each(function()
        p1 = xi.test.world:spawnPlayer({ zone = xi.zone.JUGNER_FOREST, job = xi.job.WAR, level = 75 })
        p2 = xi.test.world:spawnPlayer({ zone = xi.zone.JUGNER_FOREST, job = xi.job.WAR, level = 75 })

        p1:addGil(10000)
        p2:addGil(10000)
    end)

    it('refunds the fee to someone who leaves before the match starts', function()
        local conflict = startMatch()

        conflict:addPlayer(p1, 0)

        local afterPaying = p1:getGil()
        assert(afterPaying == 8000, 'setup: the fee should have been taken')

        local refund = p1:getConflictEntry():leave()

        assert(refund == entryFee, 'leaving during sign-up should refund the fee, got ' .. tostring(refund))
    end)

    it('keeps the fee when someone walks out of a live match', function()
        local conflict = startMatch()

        conflict:addPlayer(p1, 0)
        conflict:setState(xi.conflictState.ACTIVE)

        local payout = p1:getConflictEntry():leave()

        assert(payout == 0, 'leaving a live match should forfeit the fee, got ' .. tostring(payout))
    end)

    it('returns the fee to everyone when the match is drawn', function()
        local conflict = startMatch()

        conflict:addPlayer(p1, 0)
        conflict:addPlayer(p2, 1)

        conflict:setState(xi.conflictState.ACTIVE)

        -- Neither side scored, so there is no winner.
        conflict:setState(xi.conflictState.POST_GAME)

        assert(conflict:getWinningTeam() == nil, 'a level score should have no winner')

        -- A draw hands each player back what they put in. This is the case that silently paid
        -- nothing while a draw was represented as a winning team index of -1.
        assert(p1:getConflictEntry():leave() == entryFee, 'a draw should refund team 0')
        assert(p2:getConflictEntry():leave() == entryFee, 'a draw should refund team 1')
    end)

    it('pays the pot to the winning side and nothing to the loser', function()
        local conflict = startMatch()

        conflict:addPlayer(p1, 0)
        conflict:addPlayer(p2, 1)

        conflict:setState(xi.conflictState.ACTIVE)

        -- Team 0 scores, so it takes the match.
        local entry1 = p1:getConflictEntry()
        entry1:addPetras(3)
        entry1:scorePetras()

        conflict:setState(xi.conflictState.POST_GAME)

        assert(conflict:getWinningTeam() == 0, 'team 0 scored and should have won')

        -- Both fees are on the Herald, and the one winner takes them.
        assert(p1:getConflictEntry():leave() == entryFee * 2, 'the winner should take the whole pot')
        assert(p2:getConflictEntry():leave() == 0, 'the losing side should get nothing')
    end)

    it('decides a best of three on rounds rather than score', function()
        local zone = p1:getZone()

        zone:initializeConflict({
            team1  = xi.allegiance.SAN_DORIA,
            team2  = xi.allegiance.BASTOK,
            type   = xi.conflictType.BEST_OF_THREE,
            length = 60 * 24,
        })

        local conflict = zone:getConflict()

        conflict:addPlayer(p1, 0)
        conflict:addPlayer(p2, 1)

        -- Team 1 takes two rounds while team 0 holds the higher running score.
        local entry1 = p1:getConflictEntry()
        entry1:addPetras(5)
        entry1:scorePetras()

        conflict:addTeamRoundWon(1)
        conflict:addTeamRoundWon(1)
        conflict:addTeamRoundWon(0)

        conflict:setState(xi.conflictState.POST_GAME)

        assert(conflict:getWinningTeam() == 1, 'a best of three is won on rounds, not on score')
    end)
end)
