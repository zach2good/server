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

    -- The award is written off the main thread, so it does not land the instant the match ends.
    local function waitForPayout(player)
        for _ = 1, 100 do
            if player:getCurrency('ballista_point') > 0 then
                return
            end

            xi.test.world:tick()
        end
    end

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

    -- Points are awarded by character id rather than through the online character, both so that a
    -- participant who zoned out still collects and so the award is one statement instead of two.
    it('pays ballista points to both sides when the match ends', function()
        local conflict = startMatch()

        conflict:addPlayer(p1, 0)
        conflict:addPlayer(p2, 1)

        local entry1 = p1:getConflictEntry()
        entry1:addPetras(5)
        entry1:scorePetras()

        assert(p1:getCurrency('ballista_point') == 0, 'setup: nothing should be banked before the match ends')

        conflict:setState(xi.conflictState.POST_GAME)

        assert(conflict:getWinningTeam() == 0, 'setup: team 0 should have taken it')

        waitForPayout(p1)

        local winnerPoints = p1:getCurrency('ballista_point')
        local loserPoints  = p2:getCurrency('ballista_point')

        assert(winnerPoints > 0, 'the winning side was paid nothing')
        assert(loserPoints > 0, 'the losing side was paid nothing')
        assert(winnerPoints > loserPoints, 'winning should be worth more than losing')
    end)

    it('still pays a participant who zoned out before the match ended', function()
        local conflict = startMatch()

        conflict:addPlayer(p1, 0)
        conflict:addPlayer(p2, 1)

        p2:gotoZone(xi.zone.BASTOK_MARKETS)

        -- Zoning out drops the entry's pointer to the character, which is exactly why the award
        -- goes by character id. Paying through the online character skipped this player entirely.
        assert(p2:getConflictEntry() == nil, 'setup: the player should no longer hold an entry')

        conflict:setState(xi.conflictState.POST_GAME)

        waitForPayout(p2)

        assert(p2:getCurrency('ballista_point') > 0, 'a participant who zoned out was paid nothing')
    end)

    -- The pot cannot be rebuilt from the entries after anyone has collected: a winner takes more
    -- than they put in, so counting the fees back would hand the rest a share already paid out.
    it('tracks the pot as gil moves on and off the Herald', function()
        local conflict = startMatch()

        conflict:addPlayer(p1, 0)
        conflict:addPlayer(p2, 1)

        assert(conflict:getGilOnHerald() == entryFee * 2, 'both fees should be on the Herald')

        conflict:setState(xi.conflictState.ACTIVE)

        local entry1 = p1:getConflictEntry()
        entry1:addPetras(3)
        entry1:scorePetras()

        conflict:setState(xi.conflictState.POST_GAME)

        assert(p1:getConflictEntry():leave() == entryFee * 2, 'the winner should take the whole pot')
        assert(conflict:getGilOnHerald() == 0, 'the Herald should be holding nothing afterwards')
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
