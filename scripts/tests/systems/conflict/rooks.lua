-----------------------------------
-- Conflict (Ballista): rook data and the engine hooks that read it.
--
-- The engine asks Lua which rooks a match uses and when their gates should stand open, because
-- both answers are per-zone data rather than engine state.
-----------------------------------

describe('Conflict (Ballista) rooks', function()
    ---@type CClientEntityPair
    local player

    local function startMatch()
        local zone = player:getZone()

        zone:initializeConflict({
            team1  = xi.allegiance.SAN_DORIA,
            team2  = xi.allegiance.BASTOK,
            length = 60 * 24,
        })

        return zone:getConflict()
    end

    before_each(function()
        player = xi.test.world:spawnPlayer({
            zone  = xi.zone.JUGNER_FOREST,
            job   = xi.job.WAR,
            level = 75,
        })
    end)

    it('resolves zone info for every Ballista zone', function()
        for _, zoneId in ipairs({ xi.zone.JUGNER_FOREST, xi.zone.PASHHOW_MARSHLANDS, xi.zone.MERIPHATAUD_MOUNTAINS }) do
            local zoneInfo = xi.conflict.getZoneInfo(zoneId)

            assert(zoneInfo ~= nil, 'no conflict zone info for zone ' .. tostring(zoneId))
            assert(zoneInfo.herald ~= nil, 'zone ' .. tostring(zoneId) .. ' has no Herald')
            assert(#zoneInfo.rooks > 0, 'zone ' .. tostring(zoneId) .. ' has no rooks')
            assert(#zoneInfo.camps == 2, 'zone ' .. tostring(zoneId) .. ' should have one camp per team')
        end
    end)

    it('returns the requested number of rook ids', function()
        local conflict = startMatch()

        local rooks = xi.conflict.getRookIds(conflict, 2)
        assert(#rooks == 2, 'expected 2 rook ids, got ' .. tostring(#rooks))

        local entities = xi.conflict.getRookEntities(conflict:getZone())
        assert(rooks[1] == entities[1]:getID(), 'first rook id does not match the resolved entity')
        assert(rooks[2] == entities[2]:getID(), 'second rook id does not match the resolved entity')
    end)

    it('asks for no more rooks than the zone defines', function()
        local conflict = startMatch()

        local zoneInfo = xi.conflict.getZoneInfo(xi.zone.JUGNER_FOREST)
        local rooks    = xi.conflict.getRookIds(conflict, #zoneInfo.rooks + 5)

        assert(#rooks == #zoneInfo.rooks, 'should not invent rooks the zone does not have')
    end)

    it('opens and closes the rook gates', function()
        local conflict = startMatch()

        conflict:configureGameSetup(6, 1)

        local rook = xi.conflict.getRookEntities(conflict:getZone())[1]
        assert(rook ~= nil, 'the first Jugner Forest rook could not be resolved by name')

        xi.conflict.updateRookState(conflict, true)
        assert(rook:getAnimation() == 34, 'the rook gate should be open')

        xi.conflict.updateRookState(conflict, false)
        assert(rook:getAnimation() == 0, 'the rook gate should be closed')
    end)
end)
