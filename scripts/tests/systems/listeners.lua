describe('AoE Listeners', function()
    ---@type CClientEntityPair
    local player

    ---@type CTestEntity
    local mob1

    ---@type CTestEntity
    local mob2

    before_each(function()
        player = xi.test.world:spawnPlayer(
        {
            zone  = xi.zone.WEST_RONFAURE,
            job   = xi.job.BLM,
            level = 99,
        })

        mob1 = player.entities:moveTo('Wild_Rabbit')
        mob2 = player.entities:moveTo('Wild_Sheep')

        local pos = player:getPos()
        mob1:setPos(pos.x, pos.y, pos.z)
        mob2:setPos(pos.x, pos.y, pos.z)
    end)

    it('fires MAGIC_TAKE on all targets of an AoE spell', function()
        local mob1Hit = false
        local mob2Hit = false

        mob1:addListener('MAGIC_TAKE', 'TEST_MAGIC_TAKE_1', function()
            mob1Hit = true
        end)

        mob2:addListener('MAGIC_TAKE', 'TEST_MAGIC_TAKE_2', function()
            mob2Hit = true
        end)

        player:addSpell(xi.magic.spell.FIRAGA)
        player.actions:useSpell(mob1, xi.magic.spell.FIRAGA)
        xi.test.world:tickEntity(player)
        xi.test.world:skipTime(10)

        assert(mob1Hit, 'MAGIC_TAKE should fire on primary target')
        assert(mob2Hit, 'MAGIC_TAKE should fire on AoE subtarget')

        mob1:removeListener('TEST_MAGIC_TAKE_1')
        mob2:removeListener('TEST_MAGIC_TAKE_2')
    end)
end)

describe('Listener re-entrancy', function()
    ---@type CTestEntity
    local mob

    before_each(function()
        local player = xi.test.world:spawnPlayer({ zone = xi.zone.WEST_RONFAURE })
        mob          = player.entities:moveTo('Wild_Rabbit')
    end)

    it('fires every listener when a nested trigger removes one mid-iteration', function()
        local fired = {}

        mob:addListener('TEST_OUTER', 'TEST_OUTER_A', function()
            table.insert(fired, 'A')
            mob:triggerListener('TEST_INNER')
        end)

        mob:addListener('TEST_OUTER', 'TEST_OUTER_B', function()
            table.insert(fired, 'B')
        end)

        -- Removing A from inside a nested trigger must wait for the outer trigger to finish,
        -- otherwise B shifts into A's slot and is skipped.
        mob:addListener('TEST_INNER', 'TEST_INNER_REMOVER', function()
            mob:removeListener('TEST_OUTER_A')
        end)

        mob:triggerListener('TEST_OUTER')
        assert(#fired == 2 and fired[1] == 'A' and fired[2] == 'B', 'expected A then B, got ' .. table.concat(fired, ','))

        -- The deferred removal has now been applied.
        fired = {}
        mob:triggerListener('TEST_OUTER')
        assert(#fired == 1 and fired[1] == 'B', 'expected only B after removal, got ' .. table.concat(fired, ','))

        mob:removeListener('TEST_OUTER_B')
        mob:removeListener('TEST_INNER_REMOVER')
    end)

    it('stops firing once every listener is removed', function()
        local count = 0
        mob:addListener('TEST_EVENT', 'TEST_EVENT_1', function()
            count = count + 1
        end)

        mob:triggerListener('TEST_EVENT')
        mob:removeListener('TEST_EVENT_1')
        mob:triggerListener('TEST_EVENT')
        assert(not mob:hasListener('TEST_EVENT'), 'listener should be gone')

        mob:addListener('TEST_EVENT', 'TEST_EVENT_1', function()
            count = count + 1
        end)
        mob:triggerListener('TEST_EVENT')
        mob:removeListener('TEST_EVENT_1')

        assert(count == 2, 'expected 2 calls, got ' .. count)
    end)

    it('tracks per-tick events across add, remove and re-add', function()
        -- TICK, ROAM_TICK and COMBAT_TICK take a fast path that caches their listener lists.
        local ticks = 0
        mob:addListener('TICK', 'TEST_HOT_TICK', function()
            ticks = ticks + 1
        end)
        mob:addListener('TEST_OTHER', 'TEST_HOT_OTHER', function()
        end)

        mob:triggerListener('TICK', mob, 400)
        assert(ticks == 1, 'TICK listener should fire, got ' .. ticks)

        mob:removeListener('TEST_HOT_TICK')
        mob:triggerListener('TICK', mob, 400)
        assert(ticks == 1, 'removed TICK listener should not fire, got ' .. ticks)

        -- Erasing another event's entry must not disturb a re-added hot listener.
        mob:addListener('TICK', 'TEST_HOT_TICK', function()
            ticks = ticks + 1
        end)
        mob:removeListener('TEST_HOT_OTHER')
        mob:triggerListener('TICK', mob, 400)
        assert(ticks == 2, 're-added TICK listener should fire, got ' .. ticks)

        mob:removeListener('TEST_HOT_TICK')
    end)
end)
