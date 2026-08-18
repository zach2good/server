-----------------------------------
-- func: ballista <subcommand> [args]
-- desc: GM helper for testing Conflict (Ballista). Drives an ad-hoc match in the
--       current zone without waiting on the scheduled-match calendar or the Herald.
--
-- Subcommands:
--   start [aon|bo3]  - create an ad-hoc match here, add you to team 0 (and your
--                      targeted player, if any, to team 1), and enable combat.
--   join [0|1]       - add yourself (or your targeted player) to the given team.
--   combat [on|off]  - toggle combat (PVP) for the current match.
--   petra [n]        - grant yourself n petras (default 1).
--   score            - score the petras you are holding at your team's tally.
--   round [teamIdx]  - award a round win to a team (default your team).
--   fastquarry [0|1] - toggle the quarry cooldown bypass (default 1/on).
--   info             - print the next scheduled match + the current match state.
--   end              - force the current match into the finished state.
-----------------------------------
---@type TCommand
local commandObj = {}

commandObj.cmdprops =
{
    permission = 4,
    parameters = 'ss',
}

local function usage(player, msg)
    if msg then
        player:printToPlayer(msg)
    end

    player:printToPlayer('!ballista <start|join|combat|petra|score|round|fastquarry|info|end> [arg]')
end

-- The player this command should act on for entry-scoped actions: the targeted
-- player if one is selected, otherwise the caster.
local function actor(player)
    local target = player:getCursorTarget()
    if target and target:isPC() and target:getID() ~= player:getID() then
        return target
    end

    return player
end

commandObj.onTrigger = function(player, sub, arg)
    if sub == nil then
        usage(player)
        return
    end

    sub = string.lower(sub)
    local zone = player:getZone()

    if sub == 'start' then
        -- A match is only functional where there is zone data (rooks, camps, Herald, text/event
        -- ids). Outside the three Conflict zones the engine would still attach an instance, but
        -- quarry/rooks/scoreboard all no-op, so refuse rather than create a broken match.
        if xi.conflict.getZoneInfo(zone:getID()) == nil then
            player:printToPlayer('Ballista: this is not a Conflict zone. Use Jugner Forest, Pashhow Marshlands, or Meriphataud Mountains.')
            return
        end

        local ttype = (arg == 'bo3') and xi.conflictType.BEST_OF_THREE or xi.conflictType.ALL_OR_NOTHING

        zone:initializeConflict({
            team1  = xi.allegiance.SAN_DORIA,
            team2  = xi.allegiance.BASTOK,
            type   = ttype,
            length = 60 * 24,
        })

        local conflict = zone:getConflict()
        if conflict == nil then
            player:printToPlayer('Ballista: failed to create a match in this zone.')
            return
        end

        conflict:addPlayer(player, 0)

        local target = player:getCursorTarget()
        if target and target:isPC() and target:getID() ~= player:getID() then
            conflict:addPlayer(target, 1)
            player:printToPlayer(string.format('Ballista: added %s to team 1.', target:getName()))
        end

        -- An ad-hoc match has no timeline to drive its state, so put it straight into ACTIVE.
        -- Anything that asks the match what it is doing, the reward branches especially, reads
        -- the state rather than the combat flag.
        conflict:setState(xi.conflictState.ACTIVE)
        conflict:setCombatEnabled(true)
        player:printToPlayer(string.format('Ballista: %s match started in this zone, combat enabled.',
            (ttype == xi.conflictType.BEST_OF_THREE) and 'best-of-three' or 'all-or-nothing'))

        return
    end

    -- Everything below operates on the match already running in this zone.
    local conflict = zone:getConflict()
    if conflict == nil then
        usage(player, 'Ballista: no active match in this zone. Use "!ballista start" first.')
        return
    end

    if sub == 'join' then
        local teamIdx = tonumber(arg) or 0
        local who     = actor(player)
        conflict:addPlayer(who, teamIdx)
        player:printToPlayer(string.format('Ballista: %s joined team %d.', who:getName(), teamIdx))

    elseif sub == 'combat' then
        local on = (arg ~= 'off')
        conflict:setCombatEnabled(on)
        player:printToPlayer('Ballista: combat ' .. (on and 'enabled.' or 'disabled.'))

    elseif sub == 'petra' then
        local entry = actor(player):getConflictEntry()
        if entry == nil then
            player:printToPlayer('Ballista: that player is not in the match.')
            return
        end

        local n = tonumber(arg) or 1
        entry:addPetras(n)
        player:printToPlayer(string.format('Ballista: granted %d petra(s); now holding %d.', n, entry:getHeldPetras()))

    elseif sub == 'score' then
        local entry = actor(player):getConflictEntry()
        if entry == nil then
            player:printToPlayer('Ballista: that player is not in the match.')
            return
        end

        entry:scorePetras()
        local s0, s1 = conflict:getTeamScores()
        player:printToPlayer(string.format('Ballista: scored petras. Team scores: %d / %d.', s0, s1))

    elseif sub == 'round' then
        local entry   = actor(player):getConflictEntry()
        local teamIdx = tonumber(arg) or (entry and entry:getTeamIndex()) or 0
        conflict:addTeamRoundWon(teamIdx, 1)
        local r0, r1 = conflict:getTeamRounds()
        player:printToPlayer(string.format('Ballista: awarded a round to team %d. Rounds: %d / %d.', teamIdx, r0, r1))

    elseif sub == 'fastquarry' then
        local on = (arg == nil or arg == '1' or arg == 'on')
        player:setLocalVar('FastQuarry', on and 1 or 0)
        player:printToPlayer('Ballista: FastQuarry ' .. (on and 'on (quarry cooldown bypassed).' or 'off.'))

    elseif sub == 'info' then
        local i = GetNextBallistaInfo()
        player:printToPlayer(string.format('Next scheduled: zone %d, nations %d vs %d, cap %d, fee %d, start %d.',
            i.zoneId, i.nation1, i.nation2, i.levelCap, i.signupFee, i.startTime))

        local s0, s1 = conflict:getTeamScores()
        local c0, c1 = conflict:getTeamCounts()
        local r0, r1 = conflict:getTeamRounds()
        player:printToPlayer(string.format('This zone: state %d, scores %d/%d, counts %d/%d, rounds %d/%d.',
            conflict:getState(), s0, s1, c0, c1, r0, r1))

    elseif sub == 'end' then
        -- Disable combat first: this reverts every participant's allegiance to PLAYER, refreshes
        -- their look/name, and clears the Ballista scoreboard.
        conflict:setCombatEnabled(false)

        -- Through the post-game rather than straight to finished. Lifting the level restriction
        -- and collecting the temporary items only happen on that transition, so skipping it leaves
        -- every participant capped with a match's items still in hand.
        conflict:setState(xi.conflictState.POST_GAME)
        conflict:setState(xi.conflictState.FINISHED)
        player:printToPlayer('Ballista: match ended (combat disabled, players reverted, scoreboard cleared).')

    else
        usage(player, 'Ballista: unknown subcommand "' .. sub .. '".')
    end
end

return commandObj
