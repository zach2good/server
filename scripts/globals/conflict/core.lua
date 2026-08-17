-----------------------------------
-- Conflict (Ballista) core: the match helper logic (team balancing, match
-- configuration, line-up, gate breach, quarry-event handling) plus the gameplay
-- implementations the engine bridge delegates to (cleanup, onGateBreach, gameHint).
--
-- The engine -> Lua bridge entry points themselves live in bindings.lua. Ported
-- from Eden. Enum keys adapted to this codebase's UPPERCASE generated Lua enums
-- (e.g. xi.conflictState.PREPARING). The signup/match timeline lives in
-- timeline.lua; quarry item logic in quarry.lua.
-----------------------------------
require('scripts/globals/conflict/zoneinfo')

xi = xi or {}
xi.conflict = xi.conflict or {}

-----------------------------------
-- Match helpers.
-----------------------------------

function xi.conflict.onGateBreach(entry, timeline, shortGateBreach, alreadyHadGateBreach)
    local zoneInfo = xi.conflict.getZoneInfoForEntity(entry:getPlayer())
    if zoneInfo == nil then
        return
    end

    if not alreadyHadGateBreach then
        local player = entry:getPlayer()
        if player then
            player:messageSpecial(zoneInfo.text.GATE_BREACH_WILL_LAST, shortGateBreach and 3 or 7)
            xi.conflict.gameHint(player)
        end
    end

    timeline:addVanaMinutes((shortGateBreach and 1 or 2) * 90)
    timeline:addEvent(function()
        entry:removeGateBreach()
        local player = entry:getPlayer()
        if player then
            xi.conflict.gameHint(player)
        end
    end)

    timeline:offsetSeconds(-10):addEvent(function()
        local player = entry:getPlayer()
        if player then
            player:messageSpecial(zoneInfo.text.DISENGAGE_GATE_BREACH_IN_X, 10)
        end
    end)

    timeline:offsetSeconds(-20):addEvent(function()
        local player = entry:getPlayer()
        if player then
            player:messageSpecial(zoneInfo.text.DISENGAGE_GATE_BREACH_IN_X, 30)
        end
    end)
end

function xi.conflict.onEventFinish(player, csid, option, npc, cancel)
    local zoneInfo = xi.conflict.getZoneInfoForEntity(player)
    local entry    = player:getConflictEntry()
    if zoneInfo == nil or entry == nil then
        return
    end

    if csid == zoneInfo.events.KEEP_TEMP_ITEM then -- Quarry: temp item
        local itemId = player:getLocalVar('[Conflict]QuarryItemId')
        player:setLocalVar('[Conflict]QuarryItemId', 0)

        if option == 0 then -- accept
            if player:getFreeSlotsCount(xi.inv.TEMPITEMS) == 0 then
                player:messageSpecial(cancel and zoneInfo.text.THROW_AWAY_ITEM or zoneInfo.text.FIND_BUT_THROW, itemId, 1)
            elseif player:hasItem(itemId, xi.inv.TEMPITEMS) then
                player:messageSpecial(zoneInfo.text.FIND_BUT_THROW, itemId, 2)
            else
                player:messageSpecial(zoneInfo.text.OBTAIN_TEMP_ITEM, itemId)
                player:addTempItem(itemId)
            end
        elseif option == 2 then -- use item
            -- Used where it was dug up rather than carried, so it has to be held briefly first.
            -- useItem only reaches temporary storage, so a full one leaves nothing to use.
            if player:getFreeSlotsCount(xi.inv.TEMPITEMS) > 0 then
                player:addTempItem(itemId)
                player:messageSpecial(zoneInfo.text.FIND_AND_USE, itemId)
                player:useItem(itemId)
            else
                player:messageSpecial(zoneInfo.text.FIND_BUT_THROW, itemId, 1)
            end
        elseif option >= 1000 and option < (0xFFFF + 1000) then -- exchange
            local removedItemId = xi.conflict.tempItemByIndex[option - 1000]
            if removedItemId and player:delItem(removedItemId, 1, xi.inv.TEMPITEMS) then
                player:addTempItem(itemId)
                player:messageSpecial(zoneInfo.text.REPLACE_ITEM, removedItemId, itemId)
            else
                player:messageSpecial(zoneInfo.text.FIND_BUT_THROW, itemId, 1)
            end
        else -- throw away
            player:messageSpecial(zoneInfo.text.THROW_AWAY_ITEM, itemId)
        end
    elseif csid == zoneInfo.events.KEEP_FIRST_PETRA then -- Quarry: petra
        if option == 1 then -- accept
            player:messageSpecial(zoneInfo.text.OBTAIN_PETRA, 1, entry:addPetras(1))
        else -- decline
            player:messageSpecial(zoneInfo.text.THROW_AWAY_PETRA)
        end
    end
end

function xi.conflict.onZoneIn(player)
    local zoneInfo = xi.conflict.getZoneInfoForEntity(player)
    if zoneInfo == nil then
        return
    end

    local conflictInfo = player:getConflictEntry()
    if conflictInfo == nil then
        return
    end

    local herald = xi.conflict.getHeraldEntity(player:getZone())
    -- getIndex is the zero-based place in the team, and answers 0xFF for an entry the team does
    -- not hold. The timeline lines everyone else up from a one-based loop, so this has to match or
    -- a player arriving during the speech stands somewhere nobody else does.
    local teamIndex = conflictInfo:getIndex()

    if
        herald and
        herald:getLocalVar('GivingSpeech') == 1 and
        teamIndex ~= 0xFF
    then
        xi.conflict.lineupPlayer(player, zoneInfo, conflictInfo:getTeamIndex(), teamIndex + 1)
    end
end

function xi.conflict.teamSizeBalance(entries)
    local teamCounts = { [0] = 0, [1] = 0 }
    local tempEntries = { [0] = {}, [1] = {} }
    for _, entry in ipairs(entries) do
        teamCounts[entry:getTeamIndex()] = teamCounts[entry:getTeamIndex()] + 1
        if entry:isTempEntry() then
            table.insert(tempEntries[entry:getTeamIndex()], entry)
        end
    end

    local teamSizeDiff = math.abs(teamCounts[0] - teamCounts[1])
    if teamSizeDiff > 1 then
        local biggestTeamIdx = teamCounts[0] > teamCounts[1] and 0 or 1
        local biggestTeamTemps = tempEntries[biggestTeamIdx]
        for i = 1, teamSizeDiff / 2 do
            local idx = #biggestTeamTemps - i + 1
            if idx < 1 then
                break
            end

            biggestTeamTemps[idx]:changeTeam()
        end
    end
end

-- Secondary auto-balance metric: balance teams around similar jobs/roles.
local jobCategories =
{
    { xi.job.WAR, xi.job.MNK, xi.job.DRK, xi.job.BST, xi.job.RNG, xi.job.SAM, xi.job.DRG }, -- Main damage dealers
    { xi.job.THF, xi.job.PLD, xi.job.NIN, xi.job.PUP, xi.job.RUN },                         -- Secondary damage dealers
    { xi.job.RDM, xi.job.SCH, xi.job.BLM, xi.job.BLU },                                     -- Mages
    { xi.job.WHM, xi.job.BRD, xi.job.SMN, xi.job.COR, xi.job.DNC, xi.job.GEO },             -- Support
}

local jobCategoryByJob = {}
for categoryId, jobs in ipairs(jobCategories) do
    for _, job in ipairs(jobs) do
        jobCategoryByJob[job] = categoryId
    end
end

function xi.conflict.autoBalance(entries)
    local jobDiffs = {}
    local categoryDiffs = {}
    for _, entry in ipairs(entries) do
        local change = entry:getTeamIndex() == 0 and -1 or 1
        jobDiffs[entry:getJob()] = (jobDiffs[entry:getJob()] or 0) + change

        local category = jobCategoryByJob[entry:getJob()]
        categoryDiffs[category] = (categoryDiffs[category] or 0) + change
    end

    local movablePlayers = {}
    for _, entry in ipairs(entries) do
        if entry:isTempEntry() then
            movablePlayers[entry] =
            {
                team   = entry:getTeamIndex() + 1,
                job    = entry:getJob(),
                player = entry,
            }
        end
    end

    while true do
        local bestSwaps = { { score = -100 }, { score = -100 } }

        for _, info in pairs(movablePlayers) do
            local scoreSign     = info.team == 1 and -1 or 1
            local jobScore      = math.abs(jobDiffs[info.job]) > 1 and math.floor(scoreSign * jobDiffs[info.job] / 2) * 100 or 0
            local categoryScore = scoreSign * categoryDiffs[jobCategoryByJob[info.job]]
            local score         = jobScore + categoryScore

            if score > bestSwaps[info.team].score then
                bestSwaps[info.team].score = score
                bestSwaps[info.team].info  = info
            end
        end

        if
            bestSwaps[1].score <= 0 or
            bestSwaps[2].score <= 0 or
            (bestSwaps[1].score <= 1 and bestSwaps[2].score <= 1)
        then
            break
        end

        for _, bestSwap in ipairs(bestSwaps) do
            bestSwap.info.player:changeTeam()
            bestSwap.info.team = 2 - (bestSwap.info.team - 1)

            local change = bestSwap.info.team == 1 and -2 or 2
            jobDiffs[bestSwap.info.job] = jobDiffs[bestSwap.info.job] + change

            local category = jobCategoryByJob[bestSwap.info.job]
            categoryDiffs[category] = categoryDiffs[category] + change

            movablePlayers[bestSwap.info.player] = nil
        end
    end
end

-- How lopsided the sides must be before a second rook appears. Retail calls the trigger a
-- "significant difference" without giving a number, so this is a guess.
local unevenSidesForSecondRook = 3

function xi.conflict.tryConfiguringMatch(conflict, options)
    if conflict:getMaxTeamSize() ~= 0 then
        return true
    end

    options = options or {}
    local rookCount = options.rookCount or conflict:getRookCount()

    if not options.skipAutoBalance then
        local entries = conflict:getEntries()
        xi.conflict.teamSizeBalance(entries)
        xi.conflict.autoBalance(entries)
    end

    local teamSize1, teamSize2 = conflict:getTeamCounts()

    local minTeamSize = options.minTeamSize or (IsTestServer() and 1 or 3)
    if teamSize1 < minTeamSize or teamSize2 < minTeamSize then
        conflict:setState(xi.conflictState.CANCELLED)
        return false
    end

    if rookCount == 0 then
        rookCount = 1

        -- Any difference at all would put two rooks in nearly every match, removing the single
        -- contested rook the mode is built around.
        if math.abs(teamSize1 - teamSize2) >= unevenSidesForSecondRook then
            rookCount = rookCount + 1
        end
    end

    local maxTeamSize = math.max(teamSize1, teamSize2)
    conflict:configureGameSetup(maxTeamSize, rookCount)

    conflict:setState(xi.conflictState.PREPARING)
    return true
end

function xi.conflict.cleanup(conflict)
    local zoneInfo = xi.conflict.getZoneInfoForConflict(conflict)
    if zoneInfo == nil then
        return
    end

    conflict:setCombatEnabled(false)

    local zone = conflict:getZone()

    local herald = xi.conflict.getHeraldEntity(zone)
    if herald then
        herald:setStatus(xi.status.DISAPPEAR)
        herald:resetLocalVars()
    end

    for _, rook in ipairs(xi.conflict.getRookEntities(zone)) do
        if rook:getStatus() ~= xi.status.DISAPPEAR then
            rook:setStatus(xi.status.DISAPPEAR)
        end
    end
end

function xi.conflict.gameHint(player)
    local zoneInfo = xi.conflict.getZoneInfoForEntity(player)
    local entry    = player:getConflictEntry()
    if zoneInfo == nil or entry == nil then
        return
    end

    local msgId = zoneInfo.text.USE_QUARRY_FOR_PETRA
    if entry:getHeldPetras() > 0 then
        if entry:hasGateBreach() then
            msgId = zoneInfo.text.THROW_PETRAS_INTO_ROOK
        else
            msgId = zoneInfo.text.GET_GATE_BREACH
        end
    end

    player:messageSpecial(msgId)
end

function xi.conflict.offsetPos(pos, distance, direction)
    local radians = direction * math.pi / 128
    return
    {
        x = pos.x + distance * math.cos(radians),
        y = pos.y,
        z = pos.z - distance * math.sin(radians),
    }
end

function xi.conflict.lineupPlayer(player, zoneInfo, teamIndex, playerIndex, showPoints, highScorer)
    if player:isInEvent() then
        return
    end

    local heraldPos = zoneInfo.herald.pos
    local teamRot   = heraldPos.rot + (teamIndex == 0 and -64 or 64)
    local teamZero  = xi.conflict.offsetPos(heraldPos, 1.5 * math.floor(playerIndex / 10 + 1), teamRot)
    local playerPos = xi.conflict.offsetPos(teamZero, 1.5 * (playerIndex % 10 + 1), heraldPos.rot)

    local petraParam  = -1
    local pointsParam = 0
    if showPoints then
        local entry = player:getConflictEntry()
        if entry then
            petraParam  = entry:getScoredPetras()
            pointsParam = entry:getPoints()
        end
    end

    local highScorerName   = '???'
    local highScorerNation = 0
    local highScorerPetra  = 0
    if highScorer then
        highScorerName   = (highScorer:getName() or '???')
        highScorerNation = highScorer:getTeamNation()
        highScorerPetra  = highScorer:getScoredPetras()
    end

    player:setLocalVar('[Conflict]InEvent', 1)
    player:startCutscene(
        zoneInfo.events.LINE_UP,
        highScorerName,
        '???',
        '???',
        '???',
        math.floor(playerPos.x * 1000),
        math.floor(playerPos.z * 1000),
        math.floor(playerPos.y * 1000),
        (128 + teamRot) * 16,
        petraParam,
        pointsParam,
        highScorerNation,
        highScorerPetra)
end

-- Sign-ups close on the fuller side once it leads by this much. The Japanese wiki gives four; a
-- 2004 announcement says one. Neither is a capture, and this follows the wiki.
local maxMemberDifference = 4

local maxMembers = 72
local minimumStartMembers = 3

xi.conflict.entryAllowance =
{
    ALLOWED          = 0,
    FULL             = 1,
    RESTRICTED_START = 2,
    RESTRICTED_DIFF  = 3,
}

function xi.conflict.getTeamEntryAllowances(conflict)
    local members = {}
    members[0], members[1] = conflict:getTeamCounts()

    local allowances =
    {
        [0] = xi.conflict.entryAllowance.ALLOWED,
        [1] = xi.conflict.entryAllowance.ALLOWED,
    }

    if members[0] < minimumStartMembers or members[1] < minimumStartMembers then
        for i = 0, 1 do
            if members[i] >= minimumStartMembers then
                allowances[i] = xi.conflict.entryAllowance.RESTRICTED_START
            end
        end

        return allowances
    end

    local oneIsFull = false
    for i = 0, 1 do
        if members[i] == maxMembers then
            allowances[i] = xi.conflict.entryAllowance.FULL
            oneIsFull = true
        end
    end

    if oneIsFull then
        return allowances
    end

    if math.abs(members[0] - members[1]) >= maxMemberDifference then
        if members[0] > members[1] then
            allowances[0] = xi.conflict.entryAllowance.RESTRICTED_DIFF
        else
            allowances[1] = xi.conflict.entryAllowance.RESTRICTED_DIFF
        end
    end

    return allowances
end
