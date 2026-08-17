-----------------------------------
--
--     Functions for Conflict system
--
-----------------------------------
require('scripts/globals/conflict/core')
require('scripts/globals/conflict/constants')
require('scripts/globals/conflict/pursuivant')
require('scripts/globals/conflict/utils')
require('scripts/globals/conflict/zoneinfo')

xi = xi or {}
xi.conflict = xi.conflict or {}

-- Vana'diel timestamp (minutes since year 886) -> in-game epoch seconds, used by
-- the client to render match start/end times. (Eden provided this as a binding.)
if VanadielTimestampToGameEpoch == nil then
    function VanadielTimestampToGameEpoch(vanaTimestamp)
        return math.floor(vanaTimestamp * 60 / 25)
    end
end

function xi.conflict.startSignup(conflict)
    local zoneInfo = xi.conflict.getZoneInfoForConflict(conflict)
    local herald = xi.conflict.getHeraldEntity(conflict:getZone())
    local heraldPos = zoneInfo.herald.pos
    herald:setPos(heraldPos.x, heraldPos.y, heraldPos.z, heraldPos.rot)
    herald:setStatus(xi.status.NORMAL)
    conflict:setState(xi.conflictState.SIGN_UP)
end

local function getHeraldMessages(conflict, zoneInfo)
    local signupState = conflict:getSignupState()

    if signupState == xi.conflictSignupState.TEMPORARY then
        return {
            zoneInfo.text.NOW_ACCEPTING_TEMP,
        }

    else
        local messages = {}

        local nations = {}
        nations[0], nations[1] = conflict:getTeamNations()
        local allowances = xi.conflict.getTeamEntryAllowances(conflict)
        for i = 0, 1 do
            if
                allowances[i] == xi.conflict.entryAllowance.RESTRICTED_START or
                allowances[i] == xi.conflict.entryAllowance.RESTRICTED_DIFF
            then
                messages[#messages + 1] = zoneInfo.text.ENTRY_INFLUX_OFFSET + nations[i]
            elseif allowances[i] == xi.conflict.entryAllowance.FULL then
                messages[#messages + 1] = zoneInfo.text.MAX_ENTRIES_OFFSET + nations[i]
            else
                messages[#messages + 1] = zoneInfo.text.NOW_ACCEPTING_OFFSET + nations[i]
            end
        end

        if signupState == xi.conflictSignupState.GUEST then
            local lastTeamNation = 3 - nations[0] - nations[1]
            messages[#messages + 1] = zoneInfo.text.NOW_ACCEPTING_GUEST_OFFSET + lastTeamNation
        end

        return messages
    end
end

function xi.conflict.setupBallistaSignupTimeline(conflict, isScheduled)
    local zone = conflict:getZone()
    local zoneInfo = xi.conflict.getZoneInfoForConflict(conflict)
    if zone == nil or zoneInfo == nil then
        printf('[Conflict] Undefined zone for conflict: %d', conflict:getZoneID())
        return
    end

    local timeline = conflict:getTimelineAt(conflict:getStartTime())

    -- Sign-up starts 12 hours before start
    timeline:addVanaTime(-12, 0)
    timeline:addImportantEvent(function()
        xi.conflict.startSignup(conflict)
        conflict:setSignupState(xi.conflictSignupState.NATIONS)
    end)

    local herald = xi.conflict.getHeraldEntity(conflict:getZone())
    local nation1, nation2 = conflict:getTeamNations()

    -- Every 2 vana hours should be a zone-wide announcement from the Herald
    local teamsOffset = xi.conflict.teamsOffsetLookup[nation1 + nation2]
    timeline:addRepeatingEvent({ vanaHours = 2 }, function()
        if conflict:getState() >= xi.conflictState.PREPARING then
            return true -- Stop when next state occurs
        end

        -- Show zone-wide Herald announcements about the match
        xi.conflict.zoneFn(zone, function(player)
            player:messageText(herald, zoneInfo.text.BALLISTA_ANNOUNCEMENT, { showName = false, mode = 1 })
            player:messageText(herald, zoneInfo.text.BALLISTA_ANNOUNCEMENT + teamsOffset, { showName = false, mode = 1 })
        end)
    end)

    -- Every 30 vana minutes should be announcements about the match and entry from the Herald
    timeline:addRepeatingEvent({ vanaMinutes = 30 }, function()
        if conflict:getState() >= xi.conflictState.PREPARING then
            return true -- Stop when next state occurs
        end

        local messages = getHeraldMessages(conflict, zoneInfo)
        if not messages then
            printf('[Conflict] No Herald messages to show.')
            return false
        end

        -- Show local Herald messages about current entry state
        for i = 1, #messages do
            herald:messageText(herald, messages[i])
        end
    end)

    -- Guests can enter at 16:00 in-game time
    timeline:addVanaTime(4, 0):addImportantEvent(function()
        conflict:setSignupState(xi.conflictSignupState.GUEST)
    end)

    -- Temporary entry starts at 18:00 in-game time
    timeline:addVanaTime(2, 0):addImportantEvent(function()
        conflict:setSignupState(xi.conflictSignupState.TEMPORARY)
    end)

    -- Line-up starts at 22:00 in-game time
    timeline:addVanaTime(4, 0)

    -- Start warnings about entry closing 60 seconds before, and repeat ever 15 seconds
    timeline:offsetSeconds(-60):addRepeatingEvent({ seconds = 15, times = 4 }, function()
        herald:messageText(herald, zoneInfo.text.ENTRY_PERIOD_ENDS_SOON)
    end)

    -- Perform checks if match can be started just before line-up and act appropriately
    timeline:resetOffset()
    local lineupTime = timeline:getTimestamp()
    timeline:addImportantEvent(function()
        if xi.conflict.tryConfiguringMatch(conflict) then
            xi.conflict.setupActiveBallistaTimeline(conflict, isScheduled and lineupTime or nil)
        else
            xi.conflict.zoneMessageText(zone, herald, zoneInfo.text.MINIMUM_NOT_MET, { showName = false, mode = 1 })
            xi.conflict.messageText(conflict, herald, zoneInfo.text.PARTING_GIFT_CANCELLED, { showName = true })
        end
    end)
end

function xi.conflict.setupActiveBallistaTimeline(conflict, lineupTimestamp)
    conflict:setSignupState(xi.conflictSignupState.FILL)
    conflict:cleanTimeline()

    if lineupTimestamp ~= nil then
        xi.conflict.setupLineupTimeline(conflict, lineupTimestamp)
    else
        local zoneInfo = xi.conflict.getZoneInfoForConflict(conflict)
        local herald = xi.conflict.getHeraldEntity(conflict:getZone())
        local heraldPos = zoneInfo.herald.pos
        herald:setPos(heraldPos.x, heraldPos.y, heraldPos.z, heraldPos.rot)
        herald:setStatus(xi.status.NORMAL)

        conflict:setLevelRestrictionEnabled(true)
    end

    xi.conflict.setupBallistaMatchTimeline(conflict)
    xi.conflict.rook.setup(conflict)
    xi.conflict.pursuivant.field.setup(conflict)
end

function xi.conflict.setupLineupTimeline(conflict, timestamp)
    local zone = GetZone(conflict:getZoneID())
    local zoneInfo = xi.conflict.getZoneInfoForConflict(conflict)
    if zone == nil or zoneInfo == nil then
        printf('[Conflict] Undefined zone for conflict: %d', conflict:getZoneID())
        return
    end

    local timeline = conflict:getTimelineAt(timestamp)
    local herald = xi.conflict.getHeraldEntity(conflict:getZone())
    local heraldPos = zoneInfo.herald.pos
    local speechPos = xi.conflict.offsetPos(heraldPos, 3, heraldPos.rot)

    -- Start line-up speech
    timeline:addImportantEvent(function()
        herald:setLocalVar('GivingSpeech', 1)

        -- Walk to speech position
        herald:initNpcAi()
        herald:setBaseSpeed(13)
        herald:pathTo(speechPos.x, speechPos.y, speechPos.z, 0x18)
    end)

    -- Make players line up
    timeline:offsetSeconds(4):addEvent(function()
        xi.conflict.entityMessageSpecial(conflict, herald, zoneInfo.text.LINE_UP)
    end)

    timeline:offsetSeconds(1):addEvent(function()
        local players1, players2 = conflict:getTeamPlayers()
        for idx, player in pairs(players1) do
            xi.conflict.lineupPlayer(player, zoneInfo, 0, idx)
        end

        for idx, player in pairs(players2) do
            xi.conflict.lineupPlayer(player, zoneInfo, 1, idx)
        end
    end)

    -- Give speech
    timeline:offsetSeconds(5):addEvent(function()
        xi.conflict.entityMessageSpecial(conflict, herald, zoneInfo.text.I_WILL_BE_SERVING)
    end)

    timeline:offsetSeconds(5):addEvent(function()
        herald:setRotation(heraldPos.rot - 48)
        xi.conflict.entityMessageSpecial(conflict, herald, zoneInfo.text.LEVEL_RESTRICTION, conflict:getLevelCap() / 10)
    end)

    timeline:offsetSeconds(5):addEvent(function()
        xi.conflict.entityMessageSpecial(conflict, herald, zoneInfo.text.ALL_LINKSHELLS_UNEQUIPPED)
    end)

    local nation1, nation2 = conflict:getTeamNations()
    timeline:offsetSeconds(5):addEvent(function()
        herald:setRotation(heraldPos.rot + 48)
        local m1, m2 = conflict:getTeamCounts()
        xi.conflict.entityMessageSpecial(conflict, herald, zoneInfo.text.TODAYS_MATCH_WILL_PIT, nation1, nation2, m1, m2)
        local w1, w2 = conflict:getTeamWinnings()
        xi.conflict.entityMessageSpecial(conflict, herald, zoneInfo.text.IF_IS_VICTORIOUS, nation1, nation2, w1, w2)
    end)

    timeline:offsetSeconds(5):addEvent(function()
        xi.conflict.entityMessageSpecial(conflict, herald, zoneInfo.text.RULES_OF_BALLISTA)
    end)

    timeline:offsetSeconds(5):addEvent(function()
        xi.conflict.entityMessageSpecial(conflict, herald, zoneInfo.text.DO_NOT_FORGET, conflict:getRookCount())
    end)

    timeline:offsetSeconds(5):addEvent(function()
        herald:setRotation(heraldPos.rot - 64)
        xi.conflict.entityMessageSpecial(conflict, herald, zoneInfo.text.OATH_OF_FAIR_PLAY, nation1)
    end)

    timeline:offsetSeconds(20):addEvent(function()
        herald:setRotation(heraldPos.rot + 64)
        xi.conflict.entityMessageSpecial(conflict, herald, zoneInfo.text.READ_NATION_OATH, nation2)
    end)

    -- Path back to normal position
    timeline:offsetSeconds(20):addEvent(function()
        herald:setBaseSpeed(13)
        herald:pathTo(heraldPos.x, heraldPos.y, heraldPos.z, 0x18)
    end)

    timeline:offsetSeconds(5):addEvent(function()
        herald:setPos(heraldPos.x, heraldPos.y, heraldPos.z, heraldPos.rot)
        xi.conflict.entityMessageSpecial(conflict, herald, zoneInfo.text.REMEMBER_BALLISTA_EXERCISE)
    end)

    timeline:offsetSeconds(15):addEvent(function()
        xi.conflict.entityMessageSpecial(conflict, herald, zoneInfo.text.MAY_THE_BEST_SIDE_WIN)
    end)

    timeline:offsetSeconds(10):addEvent(function()
        xi.conflict.entityMessageSpecial(conflict, herald, zoneInfo.text.WE_HAVE_GATHERED)
    end)

    timeline:offsetSeconds(5):addEvent(function()
        herald:setLocalVar('GivingSpeech', 0)
        local players = conflict:getPlayers()
        for _, player in pairs(players) do
            if player:getLocalVar('[Conflict]InEvent') == 1 then
                player:release()
                player:setLocalVar('[Conflict]InEvent', 0)
            end
        end

        conflict:setLevelRestrictionEnabled(true)
    end)
end

function xi.conflict.setupBallistaMatchTimeline(conflict)
    local zoneInfo = xi.conflict.getZoneInfoForConflict(conflict)
    if zoneInfo == nil then
        return
    end

    local timeline = conflict:getTimelineAt(conflict:getStartTime())

    -- Add start time warning messages
    timeline:offsetSeconds(-240):addSkippableEvent(function()
        xi.conflict.messageSpecial(conflict, zoneInfo.text.SECONDS_UNTIL_START, 240)
    end)

    timeline:offsetSeconds(60):addSkippableEvent(function()
        xi.conflict.messageSpecial(conflict, zoneInfo.text.SECONDS_UNTIL_START, 180)
    end)

    timeline:offsetSeconds(60):addSkippableEvent(function()
        xi.conflict.messageSpecial(conflict, zoneInfo.text.SECONDS_UNTIL_START, 120)
    end)

    timeline:offsetSeconds(60):addSkippableEvent(function()
        xi.conflict.messageSpecial(conflict, zoneInfo.text.SECONDS_UNTIL_START, 60)
    end)

    timeline:offsetSeconds(30):addSkippableEvent(function()
        xi.conflict.messageSpecial(conflict, zoneInfo.text.SECONDS_UNTIL_START, 30)
    end)

    timeline:offsetSeconds(15):addSkippableEvent(function()
        xi.conflict.messageSpecial(conflict, zoneInfo.text.SECONDS_UNTIL_START, 15)
    end)

    -- Setup sneak and invisible
    timeline:resetOffset()
    timeline:addVanaMinutes(-45):addSkippableEvent(function()
        xi.conflict.messageSpecial(conflict, zoneInfo.text.PLAYER_INVISIBLE_SNEAK)
    end)

    timeline:offsetSeconds(10):addEvent(function()
        xi.conflict.giveInvisibleSneak(conflict)
    end)

    -- Setup game timeline
    if conflict:getType() == 1 then -- Best of Three
        xi.conflict.setupBestOfThreeTimeline(conflict)

    else -- All or nothing
        xi.conflict.setupAllOrNothingTimeline(conflict)
    end
end

function xi.conflict.setupAllOrNothingTimeline(conflict)
    local zoneInfo = xi.conflict.getZoneInfoForConflict(conflict)
    if zoneInfo == nil then
        return
    end

    -- The announcements pass showName = false, so the Herald simply carries them.
    local herald   = xi.conflict.getHeraldEntity(conflict:getZone())
    local timeline = conflict:getTimelineAt(conflict:getStartTime())

    timeline:addImportantEvent(function()
        conflict:setState(xi.conflictState.ACTIVE)
        xi.conflict.zoneMessageText(conflict:getZone(), herald, zoneInfo.text.LET_THE_GAMES_BEGIN, { showName = false, mode = 1 })
        xi.conflict.animation(conflict, 315, 0)
        conflict:setCombatEnabled(true)
        xi.conflict.removeInvisibleSneak(conflict)
    end)

    local endTime = conflict:getEndTime()
    local endTimeEpoch = VanadielTimestampToGameEpoch(endTime)

    -- Show players when the current match ends and high scorer every 2 ingame hours
    timeline:addRepeatingEvent({ vanaHours = 2 }, function()
        if conflict:getState() > xi.conflictState.ACTIVE then
            -- Stop when the game is no longer active.
            return true
        end

        xi.conflict.messageSpecial(conflict, zoneInfo.text.MATCH_ENDS_AT, endTimeEpoch)
        local highScorer = conflict:getHighScorer()
        if highScorer then
            xi.conflict.messageSpecial(conflict, zoneInfo.text.HIGHSCORER, highScorer:getTeamNation(), highScorer:getScoredPetras())
        end
    end)

    -- Setup match ending
    timeline:setTimestamp(endTime):addEvent(function()
        local s1, s2 = conflict:getTeamScores()
        if s1 ~= s2 then
            conflict:addTeamRoundWon((s1 - s2 > 0) and 0 or 1)
        end

        conflict:setCombatEnabled(false)
        xi.conflict.setRookVisibility(conflict, false)
        xi.conflict.setupConclusionTimeline(conflict)
    end)
end

function xi.conflict.setupBestOfThreeTimeline(conflict)
    local zoneInfo = xi.conflict.getZoneInfoForConflict(conflict)
    if zoneInfo == nil then
        return
    end

    -- The announcements pass showName = false, so the Herald simply carries them.
    local herald   = xi.conflict.getHeraldEntity(conflict:getZone())
    local timeline = conflict:getTimelineAt(conflict:getStartTime())

    timeline:addImportantEvent(function()
        conflict:setState(xi.conflictState.ACTIVE)
        xi.conflict.zoneMessageText(conflict:getZone(), herald, zoneInfo.text.LET_THE_GAMES_BEGIN, { showName = false, mode = 1 })
    end)

    -- Calculate match lengths based on start and end times with added intermissions between matchs
    local pauseMinutes = 40
    local gameLength = conflict:getEndTime() - conflict:getStartTime()
    local matchLength = (gameLength - 2 * pauseMinutes) / 3

    -- Setup each of the three matches
    for currentMatch = 1, 3 do

        -- Calculate start and end of each match
        local currentMatchStart = conflict:getEndTime() - matchLength * (3 - currentMatch) - pauseMinutes * (3 - currentMatch) - matchLength
        local currentMatchEnd = conflict:getEndTime() - matchLength * (3 - currentMatch) - pauseMinutes * (3 - currentMatch)
        local currentMatchEndEpoch = VanadielTimestampToGameEpoch(currentMatchEnd)

        timeline:setTimestamp(currentMatchStart)

        -- Inform about upcoming match if this is a break between matches
        if currentMatch > 1 then
            local startEpoch = VanadielTimestampToGameEpoch(currentMatchStart)
            for _ = 1, 2 do
                timeline:offsetSeconds(-16)
                timeline:addSkippableEvent(function()
                    xi.conflict.messageSpecial(conflict, zoneInfo.text.MATCH_X_BEGINS_AT, currentMatch, startEpoch)
                end)
            end

            timeline:resetOffset()
        end

        -- Add match starts
        timeline:addEvent(function()
            xi.conflict.messageSpecial(conflict, zoneInfo.text.LET_GAME_X_BEGIN, currentMatch)
            xi.conflict.messageSpecial(conflict, zoneInfo.text.MATCH_X_ENDS_AT, currentMatch, currentMatchEndEpoch)
            xi.conflict.animation(conflict, 315, 0)
            conflict:setPhase(currentMatch * 2 - 1)
            conflict:setCombatEnabled(true)
            xi.conflict.setRookVisibility(conflict, true)
            xi.conflict.removeInvisibleSneak(conflict)
        end)

        -- Show players when the current match ends and high scorer every 30 ingame minutes
        timeline:addRepeatingEvent({ vanaMinutes = 30, times = 1 + math.floor((currentMatchEnd - currentMatchStart) / 30) }, function()
            xi.conflict.messageSpecial(conflict, zoneInfo.text.MATCH_X_ENDS_AT, currentMatch, currentMatchEndEpoch)
            local highScorer = conflict:getHighScorer()
            if highScorer then
                xi.conflict.messageSpecial(conflict, zoneInfo.text.HIGHSCORER, highScorer:getTeamNation(), highScorer:getScoredPetras())
            end
        end)

        -- Handle match endings
        timeline:setTimestamp(currentMatchEnd)
        timeline:addImportantEvent(function()
            conflict:setCombatEnabled(false)
            xi.conflict.setRookVisibility(conflict, false)
        end)

        if currentMatch < 3 then -- Not last match
            timeline:addEvent(function()
                local n1, n2 = conflict:getTeamNations()
                local s1, s2 = conflict:getTeamScores()

                -- Award match point
                local diff = s1 - s2
                if diff == 0 then
                    xi.conflict.messageSpecial(conflict, zoneInfo.text.END_MATCH_SCORE_0P, currentMatch, s1, s2)
                else
                    local winningNation = diff > 0 and n1 or n2
                    xi.conflict.messageSpecial(conflict, zoneInfo.text.END_MATCH_SCORE_1P, currentMatch, s1, s2, winningNation)
                    conflict:addTeamRoundWon(diff > 0 and 0 or 1)
                end

                conflict:setPhase(currentMatch * 2)

                -- Show current match point totals
                local r1, r2 = conflict:getTeamRounds()
                xi.conflict.messageSpecial(conflict, zoneInfo.text.MATCH_TOTAL, n1, n2, r1, r2)
                xi.conflict.giveInvisibleSneak(conflict)
            end)

        else
            -- Last match
            timeline:addEvent(function()
                local n1, n2 = conflict:getTeamNations()
                local s1, s2 = conflict:getTeamScores()
                local highScorer = conflict:getHighScorer()
                local highScorerNation = highScorer and highScorer:getTeamNation() or -1

                -- Award match points
                local diff = s1 - s2
                if diff == 0 then
                    xi.conflict.messageSpecial(conflict, zoneInfo.text.END_MATCH_SCORE_0P, currentMatch, s1, s2)
                else
                    local winningNation = diff > 0 and n1 or n2
                    if winningNation == highScorerNation then
                        xi.conflict.messageSpecial(conflict, zoneInfo.text.END_MATCH_SCORE_2P, currentMatch, s1, s2, winningNation)
                        conflict:addTeamRoundWon(diff > 0 and 0 or 1, 2)
                    else
                        xi.conflict.messageSpecial(conflict, zoneInfo.text.END_MATCH_SCORE_1P, currentMatch, s1, s2, winningNation)
                        conflict:addTeamRoundWon(diff > 0 and 0 or 1)
                    end
                end

                xi.conflict.setupConclusionTimeline(conflict)
            end)
        end
    end
end

function xi.conflict.setupConclusionTimeline(conflict)
    local zoneInfo = xi.conflict.getZoneInfoForConflict(conflict)
    if zoneInfo == nil then
        return
    end

    local zone = conflict:getZone()
    local herald = xi.conflict.getHeraldEntity(conflict:getZone())
    local heraldPos = zoneInfo.herald.pos
    local speechPos = xi.conflict.offsetPos(heraldPos, 3, heraldPos.rot)

    local timeline = conflict:getTimelineAt(conflict:getEndTime())

    local isBestOfThree = conflict:getType() == 1
    local n1, n2 = conflict:getTeamNations()

    local winningNation = -1
    local losingNation = -1
    local partingGiftMessage = zoneInfo.text.PARTING_GIFT_WIN

    timeline:addImportantEvent(function()
        local s1, s2 = conflict:getTeamScores()
        if isBestOfThree then
            s1, s2 = conflict:getTeamRounds()
        end

        local players1, players2 = conflict:getTeamPlayers()

        local winners = {}
        local losers = {}
        if s1 > s2 then
            winningNation = n1
            losingNation = n2
            winners = players1
            losers = players2
        elseif s2 > s1 then
            winningNation = n2
            losingNation = n1
            winners = players2
            losers = players1
        end

        for _, player in pairs(winners) do
            player:messageSpecial(zoneInfo.text.FINAL_SCORE_WIN, winningNation, losingNation, s1, s2)
            player:independentAnimation(player, 316, 0)
        end

        for _, player in pairs(losers) do
            player:messageSpecial(zoneInfo.text.FINAL_SCORE_LOSE, winningNation, losingNation, s1, s2)
            player:independentAnimation(player, 317, 0)
        end

        xi.conflict.zoneMessageText(zone, herald, zoneInfo.text.TIME_HAS_EXPIRED, { showName = false, mode = 1 })
        if winningNation ~= -1 then
            xi.conflict.zoneMessageText(zone, herald, zoneInfo.text.IS_VICTORIOUS_OFFSET + winningNation, { showName = false, mode = 1 })
        else
            partingGiftMessage = zoneInfo.text.PARTING_GIFT_DRAW
            xi.conflict.zoneMessageText(zone, herald, zoneInfo.text.FINAL_SCORE_DRAW, { showName = false, mode = 1 })
        end

        -- Update state and start Herald ending sequence
        conflict:setState(xi.conflictState.POST_GAME)

        -- Walk to speech position
        herald:setLocalVar('GivingSpeech', 1)
        herald:initNpcAi()
        herald:setBaseSpeed(13)
        herald:pathTo(speechPos.x, speechPos.y, speechPos.z, 0x18)
    end)

    -- Make players line up
    timeline:offsetSeconds(5):addEvent(function()
        local players1, players2 = conflict:getTeamPlayers()
        local highScorer = conflict:getHighScorer()
        for idx, player in pairs(players1) do
            xi.conflict.lineupPlayer(player, zoneInfo, 0, idx, true, highScorer)
        end

        for idx, player in pairs(players2) do
            xi.conflict.lineupPlayer(player, zoneInfo, 1, idx, true, highScorer)
        end
    end)

    -- Give speech
    timeline:offsetSeconds(4):addEvent(function()
        xi.conflict.entityMessageSpecial(conflict, herald, zoneInfo.text.MEMBERS_LINE_UP)
    end)

    timeline:offsetSeconds(10):addEvent(function()
        xi.conflict.entityMessageSpecial(conflict, herald, zoneInfo.text.SALUTE)
    end)

    timeline:offsetSeconds(5):addEvent(function()
        herald:sendEmote(herald, xi.emote.BOW, xi.emoteMode.MOTION)
    end)

    timeline:offsetSeconds(5):addEvent(function()
        local rotationSign = winningNation == n2 and 1 or -1
        herald:setRotation(heraldPos.rot + 48 * rotationSign)
        if winningNation ~= -1 then
            xi.conflict.entityMessageSpecial(conflict, herald, zoneInfo.text.VICTORY_CRY, winningNation)
        else
            xi.conflict.entityMessageSpecial(conflict, herald, zoneInfo.text.NO_VICTOR)
        end
    end)

    timeline:offsetSeconds(10):addEvent(function()
        local rotationSign = losingNation == n1 and -1 or 1
        herald:setRotation(heraldPos.rot + 48 * rotationSign)
        if losingNation ~= -1 then
            xi.conflict.entityMessageSpecial(conflict, herald, zoneInfo.text.PONDER_DEFEAT, losingNation)
        else
            xi.conflict.entityMessageSpecial(conflict, herald, zoneInfo.text.REFLECT_STRATEGY)
        end
    end)

    timeline:offsetSeconds(10):addEvent(function()
        herald:setRotation(heraldPos.rot)
        xi.conflict.entityMessageSpecial(conflict, herald, zoneInfo.text.BRING_US_TOGETHER)
    end)

    timeline:offsetSeconds(5):addEvent(function()
        herald:sendEmote(herald, xi.emote.CLAP, xi.emoteMode.MOTION)
    end)

    -- Path back to normal position
    timeline:offsetSeconds(5):addEvent(function()
        herald:setBaseSpeed(13)
        herald:pathTo(heraldPos.x, heraldPos.y, heraldPos.z, 0x18)
    end)

    -- Release players
    timeline:offsetSeconds(5):addEvent(function()
        herald:setPos(heraldPos.x, heraldPos.y, heraldPos.z, heraldPos.rot)
        xi.conflict.entityMessageSpecial(conflict, herald, zoneInfo.text.DISMISSED)
        xi.conflict.messageText(conflict, herald, partingGiftMessage, { showName = true })

        herald:setLocalVar('GivingSpeech', 0)
        local players = conflict:getPlayers()
        for _, player in pairs(players) do
            if player:getLocalVar('[Conflict]InEvent') == 1 then
                player:release()
                player:setLocalVar('[Conflict]InEvent', 0)
            end
        end
    end)

    -- Setup reminders for getting reward
    timeline:resetOffset():offsetSeconds(2 * 60)
    timeline:addRepeatingEvent({ minutes = 2 }, function()
        -- Stop messaging when all player entries are finalized.
        local entries = conflict:getEntries()
        if #entries == 0 then
            return true
        end

        xi.conflict.messageText(conflict, herald, partingGiftMessage, { showName = true, alwaysShow = false })
    end)
end
