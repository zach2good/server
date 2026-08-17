-----------------------------------
-- Conflict (Ballista) Rook: scoring (throwing petras), and the 3-hour rook
-- movement timeline.
--
-- Ported from Eden; Eden's GetTimestamp() (seconds) -> GetSystemTime().
-----------------------------------
require('scripts/globals/conflict/zoneinfo')

xi = xi or {}
xi.conflict = xi.conflict or {}
xi.conflict.rook = xi.conflict.rook or {}

function xi.conflict.rook.onTrigger(player, npc)
    local zoneInfo = xi.conflict.getZoneInfoForEntity(player)
    if zoneInfo == nil then
        return
    end

    local entry = player:getConflictEntry()
    if entry == nil then
        player:messageText(npc, zoneInfo.text.ROOK_DESCRIPTION, { showName = false })
        return
    end

    if entry:getHeldPetras() < 1 then
        player:messageText(npc, zoneInfo.text.POSSESS_NO_PETRA, { showName = false })
        return
    end

    if not entry:canScore() then
        player:messageText(npc, zoneInfo.text.NEED_GATE_BREACH, { showName = false })
        return
    end

    local now = GetSystemTime()
    if player:getLocalVar('[Conflict]NextScore') > now then
        player:messageText(npc, zoneInfo.text.MUST_WAIT_SCORE, { showName = false })
        return
    end

    player:setLocalVar('[Conflict]NextScore', now + 10)
    player:startEvent(zoneInfo.events.ROOK_THROW, { [1] = 2, interrupt_text = zoneInfo.text.UNABLE_TO_COMPLETE_THROW })
end

function xi.conflict.rook.onEventFinish(player, csid, option, npc)
    local zoneInfo = xi.conflict.getZoneInfoForEntity(player)
    local entry    = player:getConflictEntry()
    if
        zoneInfo == nil or
        entry == nil
    then
        return
    end

    -- The client decides when to close the event, so everything the trigger checked has to hold
    -- again here. Otherwise a throw can be opened while it is legal and banked until it is not.
    local conflict = entry:getConflict()
    if
        conflict == nil or
        not conflict:isCombatEnabled() or
        entry:getHeldPetras() < 1 or
        not entry:canScore()
    then
        return
    end

    npc:entityAnimationPacket('clos')
    npc:entityAnimationPacket('goal')

    local petrasScored = entry:scorePetras()
    if petrasScored > 0 then
        local highScorer = entry:getConflict():getHighScorer()
        local highScore  = highScorer and highScorer:getScoredPetras() or 0
        player:showText(npc, zoneInfo.text.SCORE_PETRA, petrasScored, entry:getTeamAllegiance() - 2, entry:getScoredPetras(), highScore)
    end
end

function xi.conflict.forEachRook(conflict, rookFn)
    local zoneInfo  = xi.conflict.getZoneInfoForConflict(conflict)
    local rookCount = conflict:getRookCount()
    if
        zoneInfo == nil or
        zoneInfo.rooks == nil
    then
        return
    end

    -- The rooks are returned in spawn order, which is the order their position tables are
    -- written in, so index i is the same rook in both.
    local rooks = xi.conflict.getRookEntities(conflict:getZone())

    for i, rookInfo in ipairs(zoneInfo.rooks) do
        if i > rookCount then
            break
        end

        rookFn(rooks[i], rookInfo)
    end
end

local function emergeRook(rook, rookInfo)
    if rook == nil or #rookInfo.pos == 0 then
        return
    end

    rook:clearActionQueue()

    local currentPosIdx = rook:getLocalVar('PositionIndex')
    local newPosIdx     = 1

    if currentPosIdx == 0 then
        newPosIdx = math.randomInt(1, #rookInfo.pos)
    elseif #rookInfo.pos > 1 then
        -- Draw from the other positions, then step over the one already in use. Most rooks have a
        -- single fixed spot, where there is nothing else to pick and this would run off the end.
        newPosIdx = math.randomInt(1, #rookInfo.pos - 1)
        if newPosIdx >= currentPosIdx then
            newPosIdx = newPosIdx + 1
        end
    else
        newPosIdx = currentPosIdx
    end

    rook:setLocalVar('PositionIndex', newPosIdx)

    local newPos = rookInfo.pos[newPosIdx]
    rook:setPos(newPos[1], newPos[2], newPos[3], newPos[4])
    rook:setUntargetable(true)
    rook:setAnimationSub(69) -- Emerge from ground
    rook:queue(8000, function(rook)
        rook:setUntargetable(false)
        rook:setAnimationSub(70) -- Stay above ground
    end)
end

local function submergeRook(rook)
    if rook == nil then
        return
    end

    rook:clearActionQueue()
    rook:setUntargetable(true)
    rook:setAnimationSub(71) -- Submerge into ground
    rook:queue(8000, function(rook)
        rook:setAnimationSub(72) -- Stay below ground
    end)
end

local rookModelMap =
{
    [5] = 323, -- SAN/BAS
    [6] = 322, -- SAN/WIN
    [7] = 324, -- BAS/WIN
}

function xi.conflict.rook.setup(conflict)
    local zoneInfo = xi.conflict.getZoneInfoForConflict(conflict)

    local a1, a2 = conflict:getTeamAllegiances()
    local modelId = rookModelMap[a1 + a2] or 325 -- 325 = blank flags

    local startTime = conflict:getStartTime()
    local endTime   = conflict:getEndTime()
    local timeline  = conflict:getTimelineAt(startTime)

    timeline:addImportantEvent(function()
        xi.conflict.forEachRook(conflict, function(rook)
            if rook ~= nil then
                rook:resetLocalVars()
                rook:setModelId(modelId)
                rook:setAnimation(conflict:areRooksOpen() and 34 or 0)
                rook:setStatus(xi.status.NORMAL)
                rook:setUntargetable(false)
            end
        end)
    end)

    timeline:addEvent(function()
        xi.conflict.forEachRook(conflict, emergeRook)
    end)

    -- Rooks move every 3 game hours, exactly at 3:00, 6:00, 9:00, etc.
    local rookMoveInterval = 180
    timeline:setTimestamp(startTime + rookMoveInterval - startTime % rookMoveInterval)

    while timeline:getTimestamp() <= endTime do
        timeline:offsetSeconds(-30):addSkippableEvent(function()
            if conflict:isCombatEnabled() then
                xi.conflict.messageSpecial(conflict, zoneInfo.text.ROOKS_MOVE_IN, 30)
            end
        end)

        timeline:offsetSeconds(15):addSkippableEvent(function()
            if conflict:isCombatEnabled() then
                xi.conflict.messageSpecial(conflict, zoneInfo.text.ROOKS_MOVE_IN, 15)
            end
        end)

        timeline:offsetSeconds(7):addEvent(function()
            if conflict:isCombatEnabled() then
                xi.conflict.forEachRook(conflict, submergeRook)
            end
        end)

        timeline:resetOffset()
        timeline:addEvent(function()
            if conflict:isCombatEnabled() then
                xi.conflict.messageSpecial(conflict, zoneInfo.text.ROOKS_MOVED)
                xi.conflict.forEachRook(conflict, emergeRook)
            end
        end)

        -- 3 hours later.
        timeline:addVanaMinutes(rookMoveInterval)
    end
end

function xi.conflict.setRookVisibility(conflict, visible)
    local statusToSet  = visible and xi.status.NORMAL or xi.status.DISAPPEAR
    local animationSub = visible and 70 or 72

    xi.conflict.forEachRook(conflict, function(rook)
        if rook ~= nil then
            rook:setStatus(statusToSet)
            rook:setUntargetable(not visible)
            rook:setAnimationSub(animationSub)
        end
    end)
end
