-----------------------------------
-- Conflict (Ballista): the scheduled match timeline.
--
-- A scheduled match runs itself. Sign-ups open twelve Vana'diel hours before the start, the teams
-- are configured and lined up at 22:00, and combat is enabled at 00:00. Nothing here waits on a
-- player, so the whole flow is driven by advancing the clock.
--
-- Timeline events are scheduled against the steady clock, so only skipTime advances them.
-- setVanaTime moves the Vana'diel offset without ticking and would desynchronise the two.
-----------------------------------

describe('Conflict (Ballista) scheduled timeline', function()
    ---@type CClientEntityPair
    local player

    -- One Vana'diel minute is 2.4 Earth seconds.
    local realSecondsPerVanaMinute = 2.4

    local function vanaMinutesInSeconds(vanaMinutes)
        return math.ceil(vanaMinutes * realSecondsPerVanaMinute)
    end

    -- Sign-ups open twelve Vana'diel hours before the match starts.
    local signupLeadVanaMinutes = 12 * 60

    -- A Vana'diel timestamp is minutes since the calendar epoch, which is what the match settings
    -- speak in.
    local function currentVanaTimestamp()
        return VanadielUniqueDay() * 1440 + VanadielHour() * 60 + VanadielMinute()
    end

    local function startScheduledMatch()
        local zone = player:getZone()

        zone:initializeConflict({
            team1       = xi.allegiance.SAN_DORIA,
            team2       = xi.allegiance.BASTOK,
            isScheduled = true,
            -- Start far enough out that the whole sign-up window is still ahead of us, so the
            -- timeline has something to schedule rather than dropping past-due events.
            startTime   = currentVanaTimestamp() + signupLeadVanaMinutes + 60,
            length      = 60 * 24,
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

    it('schedules the sign-up timeline for a scheduled match', function()
        local conflict = startScheduledMatch()

        assert(conflict ~= nil, 'the scheduled conflict was not created')

        -- A scheduled match starts in Setup and is walked forward by the timeline, unlike an
        -- ad-hoc match which is playable immediately.
        assert(conflict:getState() == xi.conflictState.SETUP, 'a scheduled match should begin in Setup')
    end)

    it('opens sign-ups once the sign-up time is reached', function()
        local conflict = startScheduledMatch()

        -- The sign-up event sits twelve Vana'diel hours before the match start, so it is one
        -- Vana'diel hour from now.
        xi.test.world:skipTime(vanaMinutesInSeconds(60) + 5)
        xi.test.world:tick(xi.tick.ZONE)

        assert(conflict:getState() == xi.conflictState.SIGN_UP, 'sign-ups should have opened')
    end)

    it('leaves an ad-hoc match alone', function()
        local zone = player:getZone()

        zone:initializeConflict({
            team1  = xi.allegiance.SAN_DORIA,
            team2  = xi.allegiance.BASTOK,
            length = 60 * 24,
        })

        local conflict = zone:getConflict()

        xi.test.world:skipTime(vanaMinutesInSeconds(60) + 5)
        xi.test.world:tick(xi.tick.ZONE)

        -- No sign-up timeline was scheduled, so nothing moved the state on its own.
        assert(conflict:getState() == xi.conflictState.SETUP, 'an ad-hoc match should not run the sign-up flow')
    end)
end)
