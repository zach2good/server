-----------------------------------
-- Conflict (Ballista): sign-up, balancing and match start with a full roster.
--
-- Retail wants three per side. Sign-ups funnel early entries onto the thinner team, and once both
-- sides are viable the balancer shuffles only the entries that were taken on a temporary ticket,
-- never the ones that paid to fight for a particular nation.
--
-- This drives the sign-up rules and the state machine directly. The Herald's conversation is
-- driven only where the client dumps pin the option values down; the rest are still reverse
-- engineered, and asserting those would lock in a guess.
-----------------------------------

describe('Conflict (Ballista) sign-up', function()
    local players = {}

    -- Jobs are stacked per side so the job-role balancer has a positive-scoring candidate on each.
    local roster =
    {
        xi.job.WAR, xi.job.WAR, xi.job.WHM,
        xi.job.WHM, xi.job.WHM, xi.job.WAR,
    }

    -- tryConfiguringMatch drops the minimum to 1 on a test server, so every call here passes the
    -- retail value explicitly. Without it a 1v1 would start and prove nothing.
    local retailMinimum = { minTeamSize = 3 }

    local function startMatch(options)
        options = options or {}

        local zone = players[1]:getZone()

        zone:initializeConflict({
            team1     = xi.allegiance.SAN_DORIA,
            team2     = xi.allegiance.BASTOK,
            levelCap  = options.levelCap or 0,
            signupFee = options.signupFee or 0,
            length    = 60 * 24,
        })

        local conflict = zone:getConflict()

        conflict:setState(xi.conflictState.SIGN_UP)
        conflict:setSignupState(xi.conflictSignupState.NATIONS)

        return conflict
    end

    before_each(function()
        xi.test.world:setSeed(1)

        for i, job in ipairs(roster) do
            players[i] = xi.test.world:spawnPlayer({
                zone  = xi.zone.JUGNER_FOREST,
                job   = job,
                level = 75,
            })

            -- A real sign-up needs the licence, and the Herald now checks for it at the point the
            -- client picks its option rather than only when the conversation opens.
            players[i]:addKeyItem(xi.keyItem.BALLISTA_LICENSE)
        end
    end)

    it('funnels entries onto the thinner side until both are viable', function()
        local conflict = startMatch()

        local allowances = xi.conflict.getTeamEntryAllowances(conflict)
        assert(allowances[0] == xi.conflict.entryAllowance.ALLOWED, 'both sides should be open while empty')
        assert(allowances[1] == xi.conflict.entryAllowance.ALLOWED, 'both sides should be open while empty')

        for i = 1, 3 do
            conflict:addPlayer(players[i], 0)
        end

        -- Team 0 has reached the minimum and team 1 has not, so team 0 is closed until team 1
        -- catches up.
        allowances = xi.conflict.getTeamEntryAllowances(conflict)
        assert(allowances[0] == xi.conflict.entryAllowance.RESTRICTED_START, 'the viable side should be closed')
        assert(allowances[1] == xi.conflict.entryAllowance.ALLOWED, 'the thin side should stay open')
    end)

    it('takes the entry fee and locks a nation entry', function()
        local conflict = startMatch({ signupFee = 2000 })

        -- A freshly spawned character carries no gil, and the fee is only taken from someone who
        -- can afford it.
        players[1]:addGil(10000)

        local before = players[1]:getGil()

        conflict:addPlayer(players[1], 0)

        assert(players[1]:getGil() == before - 2000, 'the entry fee was not taken')

        local entry = players[1]:getConflictEntry()
        assert(entry ~= nil, 'no entry was created')
        assert(not entry:isTempEntry(), 'a nation entry should be locked, not temporary')
    end)

    -- Menu 7312 offers "Only in the <nation>'s forces" twice, naming the two teams in order. The
    -- client returns 14 for the first and 15 for the second, per the Jugner event 22 and Pashhow
    -- event 18 bytecode.
    it('honours a request for a named nation', function()
        local conflict = startMatch()
        local heraldEvent = xi.conflict.getZoneInfoForEntity(players[1]).events.HERALD

        xi.conflict.herald.onEventUpdate(players[2], heraldEvent, 15)

        local entry = players[2]:getConflictEntry()
        assert(entry ~= nil, 'asking for the second nation by name did not seat the player')
        assert(entry:getTeamIndex() == 1, 'the player was seated on the wrong team')

        -- Left to itself the Herald would put the next entry on the thinner side, which is team 0.
        -- Naming team 1 has to override that, not defer to it.
        xi.conflict.herald.onEventUpdate(players[3], heraldEvent, 15)

        local counts1, counts2 = conflict:getTeamCounts()
        assert(counts1 == 0, 'a named request was balanced onto the other team')
        assert(counts2 == 2, 'the second named request did not land on the requested team')
    end)

    -- The trigger only decides what the Herald says; the client picks which option it sends back.
    -- These drive the update directly, the way a crafted packet would.
    it('refuses a player without a Ballista License', function()
        local conflict = startMatch()
        local heraldEvent = xi.conflict.getZoneInfoForEntity(players[1]).events.HERALD

        players[1]:delKeyItem(xi.keyItem.BALLISTA_LICENSE)

        xi.conflict.herald.onEventUpdate(players[1], heraldEvent, 2)

        assert(players[1]:getConflictEntry() == nil, 'an unlicensed player was seated')
    end)

    it('refuses a player under the level bracket', function()
        local conflict = startMatch({ levelCap = 60 })
        local heraldEvent = xi.conflict.getZoneInfoForEntity(players[1]).events.HERALD

        players[1]:setLevel(20)

        xi.conflict.herald.onEventUpdate(players[1], heraldEvent, 2)

        assert(players[1]:getConflictEntry() == nil, 'a player under the bracket minimum was seated')
    end)

    it('seats a licensed player of the right level', function()
        local conflict = startMatch({ levelCap = 60 })
        local heraldEvent = xi.conflict.getZoneInfoForEntity(players[1]).events.HERALD

        xi.conflict.herald.onEventUpdate(players[1], heraldEvent, 2)

        assert(players[1]:getConflictEntry() ~= nil, 'a licensed player of the right level was refused')
    end)

    it('refuses a player who cannot afford the fee', function()
        local conflict = startMatch({ signupFee = 2000 })

        assert(players[1]:getGil() < 2000, 'setup: the player should not be able to afford the fee')

        -- Seating them would let them draw on a pot they never paid into, and a drawn match
        -- refunds the full fee to everyone.
        assert(not conflict:addPlayer(players[1], 0), 'a player who cannot pay should be refused')

        assert(players[1]:getConflictEntry() == nil, 'no entry should have been created')
        assert(players[1]:getGil() == 0, 'no gil should have been taken')
    end)

    it('takes later entries as temporary so they can be balanced', function()
        local conflict = startMatch()

        conflict:addPlayer(players[1], 0)
        conflict:setSignupState(xi.conflictSignupState.TEMPORARY)
        conflict:addPlayer(players[2], 0)

        assert(not players[1]:getConflictEntry():isTempEntry(), 'the nation entry should stay locked')
        assert(players[2]:getConflictEntry():isTempEntry(), 'a late entry should be temporary')
    end)

    it('evens out lopsided sides by moving temporary entries', function()
        local conflict = startMatch()

        conflict:setSignupState(xi.conflictSignupState.TEMPORARY)

        for i = 1, 3 do
            conflict:addPlayer(players[i], 0)
        end

        conflict:addPlayer(players[4], 1)

        local before1, before2 = conflict:getTeamCounts()
        assert(before1 == 3 and before2 == 1, 'setup: teams should start 3v1')

        xi.conflict.teamSizeBalance(conflict:getEntries())

        local after1, after2 = conflict:getTeamCounts()
        assert(after1 == 2 and after2 == 2, 'the sides should have been evened out, got ' .. after1 .. 'v' .. after2)
    end)

    it('never moves an entry that paid for a nation', function()
        local conflict = startMatch()

        -- Every entry is locked, so the balancer has nothing it is allowed to move.
        for i = 1, 3 do
            conflict:addPlayer(players[i], 0)
        end

        conflict:addPlayer(players[4], 1)

        xi.conflict.teamSizeBalance(conflict:getEntries())

        local after1, after2 = conflict:getTeamCounts()
        assert(after1 == 3 and after2 == 1, 'locked entries must not be moved by balancing')
    end)

    it('will not start a match that is short on players', function()
        local conflict = startMatch()

        for i = 1, 3 do
            conflict:addPlayer(players[i], 0)
        end

        conflict:addPlayer(players[4], 1)
        conflict:addPlayer(players[5], 1)

        assert(not xi.conflict.tryConfiguringMatch(conflict, retailMinimum), 'a 3v2 should not start')
        assert(conflict:getState() == xi.conflictState.CANCELLED, 'a short match should be cancelled')
    end)

    it('configures and starts a full match', function()
        local conflict = startMatch({ levelCap = 60 })

        for i = 1, 3 do
            conflict:addPlayer(players[i], 0)
        end

        for i = 4, 6 do
            conflict:addPlayer(players[i], 1)
        end

        assert(xi.conflict.tryConfiguringMatch(conflict, retailMinimum), 'a 3v3 should start')
        assert(conflict:getState() == xi.conflictState.PREPARING, 'the match should be preparing')
        assert(conflict:getMaxTeamSize() == 3, 'max team size should match the roster')

        -- Even sides are contested by a single rook.
        assert(conflict:getRookCount() == 1, 'even sides should use one rook')

        conflict:setLevelRestrictionEnabled(true)
        assert(players[1]:hasStatusEffect(xi.effect.LEVEL_RESTRICTION), 'the level cap was not applied')

        xi.conflict.giveInvisibleSneak(conflict)
        assert(players[1]:hasStatusEffect(xi.effect.INVISIBLE), 'players should be hidden before the start')
        assert(players[1]:hasStatusEffect(xi.effect.SNEAK), 'players should be hidden before the start')

        conflict:setState(xi.conflictState.ACTIVE)
        conflict:setCombatEnabled(true)
        xi.conflict.removeInvisibleSneak(conflict)
        xi.test.world:tick(xi.tick.ZONE)

        assert(players[1]:getAllegiance() == xi.allegiance.SAN_DORIA, 'team 0 should be fighting for San d\'Oria')
        assert(players[4]:getAllegiance() == xi.allegiance.BASTOK, 'team 1 should be fighting for Bastok')
        assert(players[1]:isInConflict(), 'players should be in conflict once combat starts')
        assert(not players[1]:hasStatusEffect(xi.effect.INVISIBLE), 'the covering Invisible should be gone')
        assert(not conflict:areRooksOpen(), 'rooks should be contested with both sides present')
    end)

    it('seats a returning player back into the entry they already hold', function()
        local conflict = startMatch()

        conflict:addPlayer(players[1], 0)

        local entry = players[1]:getConflictEntry()
        assert(entry ~= nil, 'setup: the player should hold an entry')

        -- Asking again must find the existing entry rather than opening a second one, which is
        -- what happens when a player zones out of a live match and comes back.
        conflict:addPlayer(players[1], 1)

        local count1, count2 = conflict:getTeamCounts()
        assert(count1 == 1, 'the player should still be counted once')
        assert(count2 == 0, 'a rejoin must not seat the player on the other side')
        assert(players[1]:getConflictEntry():getTeamIndex() == 0, 'the original team should be kept')
    end)
end)
