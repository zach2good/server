-----------------------------------
-- Conflict (Ballista): gate breach and team balancing.
--
-- Sign-ups arrive unevenly, so the match moves temporary entries between sides before it starts.
-- Locked entries, the ones that paid for a specific nation, are never moved.
-----------------------------------

describe('Conflict (Ballista) balancing', function()
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

        return zone:getConflict()
    end

    before_each(function()
        p1 = xi.test.world:spawnPlayer(playerConfig)
        p2 = xi.test.world:spawnPlayer(playerConfig)
    end)

    it('a gate breach lets a player score, and scoring consumes it', function()
        local conflict = startMatch()

        conflict:addPlayer(p1, 0)
        conflict:setCombatEnabled(true)

        local entry = p1:getConflictEntry()

        -- With both teams present the rooks are contested, so a breach is the only way to score.
        conflict:addPlayer(p2, 1)
        assert(not entry:canScore(), 'a contested rook should not be scoreable without a gate breach')

        entry:addGateBreach()
        assert(entry:hasGateBreach(), 'the gate breach was not applied')
        assert(entry:canScore(), 'a gate breach should allow scoring')

        entry:addPetras(1)
        entry:scorePetras()

        assert(not entry:hasGateBreach(), 'scoring should consume the gate breach')
    end)

    -- MsgBasic 124 and MsgStd 212, both read out of the client message dumps in documentation/.
    it('announces a gate breach being gained and lost', function()
        local conflict = startMatch()

        conflict:addPlayer(p1, 0)
        conflict:addPlayer(p2, 1)
        conflict:setCombatEnabled(true)

        local entry = p1:getConflictEntry()

        local function sawMessage(packetType, offset, messageId)
            for _, packet in ipairs(p1.packets:getIncoming()) do
                if packet.type == packetType then
                    local seen = packet.data[offset] + packet.data[offset + 1] * 256
                    if seen == messageId then
                        return true
                    end
                end
            end

            return false
        end

        p1.packets:clear()
        entry:addGateBreach()

        assert(sawMessage(0x029, 0x18, 124), 'gaining a gate breach should be announced')

        p1.packets:clear()
        entry:addPetras(1)
        entry:scorePetras()

        assert(sawMessage(0x053, 0x0C, 212), 'losing a gate breach should be announced')
    end)

    it('leaves the rooks open while only one side is present', function()
        local conflict = startMatch()

        conflict:addPlayer(p1, 0)
        conflict:setCombatEnabled(true)

        -- The open-rook state is only recomputed once the match goes live.
        conflict:setState(xi.conflictState.ACTIVE)

        -- Nobody to contest a throw, so no breach is needed.
        assert(conflict:areRooksOpen(), 'rooks should stand open with a single team present')
        assert(p1:getConflictEntry():canScore(), 'an open rook should be scoreable')
    end)

    it('closes the rooks once both sides are present', function()
        local conflict = startMatch()

        conflict:addPlayer(p1, 0)
        conflict:addPlayer(p2, 1)
        conflict:setCombatEnabled(true)
        conflict:setState(xi.conflictState.ACTIVE)

        assert(not conflict:areRooksOpen(), 'rooks should be contested with both teams present')
    end)

    it('reports the entry types that balancing is allowed to move', function()
        local conflict = startMatch()

        conflict:addPlayer(p1, 0)
        conflict:addPlayer(p2, 0)

        -- Both joined during nation sign-up, so both are locked to the side they paid for.
        assert(not p1:getConflictEntry():isTempEntry(), 'a nation entry should not be temporary')
        assert(not p2:getConflictEntry():isTempEntry(), 'a nation entry should not be temporary')
    end)

    it('moves a player between teams on request', function()
        local conflict = startMatch()

        conflict:addPlayer(p1, 0)

        local entry = p1:getConflictEntry()
        assert(entry:getTeamIndex() == 0, 'setup: player should start on team 0')

        entry:changeTeam()
        assert(entry:getTeamIndex() == 1, 'changeTeam with no argument should swap sides')

        entry:changeTeam(0)
        assert(entry:getTeamIndex() == 0, 'changeTeam should honour an explicit team index')

        local count1, count2 = conflict:getTeamCounts()
        assert(count1 == 1, 'team 0 should hold the player after the swaps')
        assert(count2 == 0, 'team 1 should be empty after the swaps')
    end)
end)
