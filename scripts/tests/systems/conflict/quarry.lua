-----------------------------------
-- Conflict (Ballista): quarrying for petras and temporary items.
--
-- The award is a weighted random roll, so these pin the seed and assert the shape of the result
-- rather than a specific item.
-----------------------------------

describe('Conflict (Ballista) quarry', function()
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
        xi.test.world:setSeed(1)

        player = xi.test.world:spawnPlayer({
            zone  = xi.zone.JUGNER_FOREST,
            job   = xi.job.WAR,
            level = 75,
        })
    end)

    it('reports no rook distance before any rooks are placed', function()
        local conflict = startMatch()

        conflict:addPlayer(player, 0)

        local entry = player:getConflictEntry()
        assert(entry ~= nil, 'player has no conflict entry')

        -- A match that has not been configured yet has no active rooks, so there is nothing to
        -- measure against. quarry.lua relies on this being nil rather than zero.
        assert(entry:closestRookDistance() == nil, 'an unconfigured match should report no rook distance')
    end)

    it('measures the distance to the nearest active rook', function()
        local conflict = startMatch()

        conflict:addPlayer(player, 0)
        conflict:configureGameSetup(6, 2)

        local entry    = player:getConflictEntry()
        local distance = entry:closestRookDistance()

        assert(distance ~= nil, 'a configured match should report a rook distance')
        assert(distance >= 0, 'distance should not be negative')
    end)

    it('awards a temp item the player can actually receive', function()
        local conflict = startMatch()

        conflict:addPlayer(player, 0)
        conflict:configureGameSetup(6, 2)

        local entry  = player:getConflictEntry()
        local itemId = xi.conflict.determineQuarryItem(player, entry)

        assert(itemId ~= nil, 'determineQuarryItem returned nothing')
        assert(xi.conflict.tempItemToIndex[itemId] ~= nil, 'quarried item ' .. tostring(itemId) .. ' has no temp-item index')
    end)

    -- These drive the handler the zone script now forwards to. The forwarding itself is wiring in
    -- the three Zone.lua files and is not covered here; what these pin down is that the handler
    -- does something once it is reached, which nothing asserted while it was unreachable.
    it('keeps a quarried temporary item when the dialog accepts it', function()
        local conflict = startMatch()

        conflict:addPlayer(player, 0)
        conflict:configureGameSetup(6, 2)

        local zoneInfo = xi.conflict.getZoneInfo(xi.zone.JUGNER_FOREST)
        local entry    = player:getConflictEntry()

        -- Stand in for the dig: the handler reads the item back off the local var.
        player:setLocalVar('[Conflict]QuarryItemId', xi.item.HI_POTION)
        player:prepareEventForZone()

        assert(entry:getHeldPetras() == 0, 'setup: the player should hold no petras')

        -- Option 0 keeps the item.
        xi.conflict.onEventFinish(player, zoneInfo.events.KEEP_TEMP_ITEM, 0, nil)

        assert(player:hasItem(xi.item.HI_POTION, xi.inv.TEMPITEMS), 'keeping the item did nothing')
    end)

    it('takes the first petra when the dialog accepts it', function()
        local conflict = startMatch()

        conflict:addPlayer(player, 0)

        local zoneInfo = xi.conflict.getZoneInfo(xi.zone.JUGNER_FOREST)
        local entry    = player:getConflictEntry()

        -- Option 1 keeps the petra, per the event 28 bytecode.
        xi.conflict.onEventFinish(player, zoneInfo.events.KEEP_FIRST_PETRA, 1, nil)

        assert(entry:getHeldPetras() == 1, 'accepting the first petra did not hand it over')
    end)

    it('hands out the initial temporary items', function()
        local conflict = startMatch()

        conflict:addPlayer(player, 0)

        assert(xi.conflict.distributeInitialItems(player), 'initial items were not distributed')

        assert(player:hasItem(xi.item.X_POTION, xi.inv.TEMPITEMS), 'no X Potion in temp inventory')
        assert(player:hasItem(xi.item.REMEDY, xi.inv.TEMPITEMS), 'no Remedy in temp inventory')
        assert(player:hasItem(xi.item.PETRA_EATER, xi.inv.TEMPITEMS), 'no Petra Eater in temp inventory')
    end)

    it('does nothing when the player is not in a match', function()
        -- quarry() is reachable from the action packet, so it has to tolerate being called by a
        -- player with no entry rather than erroring.
        xi.conflict.quarry(player)
    end)
end)
