-----------------------------------
-- Conflict (Ballista): the match calendar.
--
-- Matches run on even Vana'diel days, rotating between the three zones. The nations that meet
-- depend on the season, the level cap climbs through the month, and the entry fee follows the cap.
--
-- These read the calendar rather than start anything, so no zone needs to be loaded.
-----------------------------------

describe('Conflict (Ballista) calendar', function()
    local ballistaZones =
    {
        [xi.zone.JUGNER_FOREST]         = true,
        [xi.zone.PASHHOW_MARSHLANDS]    = true,
        [xi.zone.MERIPHATAUD_MOUNTAINS] = true,
    }

    -- The fee is a function of the level cap, and an uncapped match is the dearest.
    local feeForCap =
    {
        [30] = 500,
        [40] = 1000,
        [50] = 1500,
        [60] = 2000,
        [0]  = 3000,
    }

    it('always describes a match in one of the three Ballista zones', function()
        local info = GetNextBallistaInfo()

        assert(info ~= nil, 'the calendar returned nothing')

        -- Zone 0 means the calendar has no match for the day it landed on.
        if info.zoneId ~= 0 then
            assert(ballistaZones[info.zoneId], 'scheduled in a zone that does not host Ballista: ' .. tostring(info.zoneId))
        end
    end)

    it('charges the fee that matches the level cap', function()
        local info = GetNextBallistaInfo()

        if info.zoneId == 0 then
            return
        end

        assert(feeForCap[info.levelCap] ~= nil, 'unexpected level cap ' .. tostring(info.levelCap))
        assert(info.signupFee == feeForCap[info.levelCap],
            'cap ' .. tostring(info.levelCap) .. ' should cost ' .. tostring(feeForCap[info.levelCap]) ..
            ', got ' .. tostring(info.signupFee))
    end)

    it('pits two different nations against each other', function()
        local info = GetNextBallistaInfo()

        if info.zoneId == 0 then
            return
        end

        assert(info.nation1 >= 0 and info.nation1 <= 2, 'nation1 out of range: ' .. tostring(info.nation1))
        assert(info.nation2 >= 0 and info.nation2 <= 2, 'nation2 out of range: ' .. tostring(info.nation2))
        assert(info.nation1 ~= info.nation2, 'a nation cannot fight itself')
    end)

    it('keeps rotating as the calendar advances', function()
        local seenZones = {}
        local seenCaps  = {}

        -- Two full Vana'diel months, which is long enough to visit every slot in the six day
        -- rotation and every level bracket.
        for _ = 1, 60 do
            local info = GetNextBallistaInfo()

            if info.zoneId ~= 0 then
                seenZones[info.zoneId] = true
                seenCaps[info.levelCap] = true
            end

            xi.test.world:skipVanaDays(1)
        end

        local zoneCount = 0
        for _ in pairs(seenZones) do
            zoneCount = zoneCount + 1
        end

        assert(zoneCount == 3, 'all three zones should host a match across two months, saw ' .. zoneCount)

        assert(seenCaps[0], 'the uncapped bracket should appear')
        assert(seenCaps[30], 'the level 30 bracket should appear')
    end)
end)
