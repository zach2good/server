require('scripts/globals/conflict/zoneinfo')

xi = xi or {}
xi.conflict = xi.conflict or {}

xi.conflict.herald = xi.conflict.herald or {}

-- Warping from the Herald costs either the key item or this many Ballista Points.
local teleportCost = 100

-- The lowest level admitted to each capped bracket. The level 30 match takes anyone, and the
-- uncapped match starts at 61 rather than the 66 a flat cap-minus-nine would give.
local minimumEntryLevel =
{
    [30] = 1,
    [40] = 31,
    [50] = 41,
    [60] = 51,
    [0]  = 61, -- Uncapped
}

function xi.conflict.herald.onTrigger(player, npc)
    if npc:getLocalVar('GivingSpeech') ~= 0 then
        return
    end

    local conflict = npc:getZone():getConflict()
    local zoneInfo = xi.conflict.getZoneInfoForEntity(player)
    if conflict == nil then
        player:startEvent(zoneInfo.events.HERALD)
        return
    end

    local params = {}

    local nation1, nation2 = conflict:getTeamNations()
    local members1, members2 = conflict:getTeamCounts()
    local maxTeamSize = conflict:getMaxTeamSize()
    local playerNation = player:getNation()

    --[[ Param 0: Signup status

    1: [Sign up for own nation]
    2: [Sign up for guest entry. Automatically added to lowest member count]
    3: [Sign up for temporary entry. Auto-balance based on main job]
    4: [Sign up to fill empty slots while match is going on]
    5: There is little or no difference in the number of participants for each nation's forces. We are not accepting guest entries at this time.
    6: Due to the lack of participants for the opposing nation, we are unable to accept your entry at this time.
    7: No openings remain in the requested nation's forces. You cannot participate in this match unless someone requests a discharge.
    8: No openings remain in either nation's forces. You cannot participate in this match unless someone requests a discharge.
    9: I apologize, but your re-entry into the coming match has been restricted until 00:00 Vana'diel time.
    10: In accordance with the rules for the next match, we are only allowed to accept applications that have reached at least level XX.
    11: Your temporary entry application is currently being processed.
    12: I am sorry. Only adventurers who possess a Ballista License can participate in Ballista.
    -- ]]

    local entry = player:getConflictEntry()
    local signupState = conflict:getSignupState()
    local allowances = xi.conflict.getTeamEntryAllowances(conflict)

    local minimumLevel = minimumEntryLevel[conflict:getLevelCap()] or 1

    if entry ~= nil then
        params[0] = 11

    elseif player:getMainLvl() < minimumLevel then
        params[0] = 10

    elseif not player:hasKeyItem(xi.keyItem.BALLISTA_LICENSE) then
        params[0] = 12

    elseif conflict:hasPlayerLeft(player) then
        params[0] = 9

    elseif
        allowances[0] == xi.conflict.entryAllowance.FULL and
        allowances[1] == xi.conflict.entryAllowance.FULL
    then
        params[0] = 8

    elseif
        signupState == xi.conflictSignupState.FILL and
        (members1 < maxTeamSize or members2 < maxTeamSize)
    then
        params[0] = 4

    elseif signupState == xi.conflictSignupState.NATIONS then

        local teamIdx = nil
        if playerNation == nation1 then
            teamIdx = 0
        elseif playerNation == nation2 then
            teamIdx = 1
        end

        if
            teamIdx == nil or
            allowances[teamIdx] == xi.conflict.entryAllowance.RESTRICTED_DIFF
        then
            -- Guest entry not open yet, and own nation not participating or too little difference in nation members
            params[0] = 5
        elseif allowances[teamIdx] == xi.conflict.entryAllowance.FULL then
            -- Own nation is full
            params[0] = 7
        elseif allowances[teamIdx] == xi.conflict.entryAllowance.RESTRICTED_START then
            -- Don't allow entry if other team is lacking members
            params[0] = 6
        else
            -- Success
            params[0] = 1
        end

    elseif signupState == xi.conflictSignupState.GUEST then
        params[0] = 2

    elseif signupState == xi.conflictSignupState.TEMPORARY then
        params[0] = 3

    else
        params[0] = 0
    end

    -- ## Param 1: misc flags
    local state = conflict:getState()
    params[1] = state -- The state numbers match what is sent in the first few bites in this event

    params[1] = params[1] + 0x800 -- Unknown. Seemingly always set and required for 'Best of Three' flag to work properly

    if conflict:getType() == 1 then -- Best of Three
        params[1] = params[1] + 0x1000
    end

    if conflict:hasItemRestriction() then
        params[1] = params[1] + 0x2000
    end

    params[1] = params[1] + bit.lshift(conflict:getLevelCap(), 4)

    -- ## Param 2: misc. flags and allegiances
    params[2] = playerNation

    -- Bits for participating nations
    params[2] = params[2] + bit.lshift(nation1, 2) + bit.lshift(nation2, 4)

    -- First talk is different, all following have this bit set
    if player:getLocalVar('[Conflict]HeraldChat') == 1 or state == xi.conflictState.POST_GAME then
        params[2] = params[2] + 0x40
    else
        player:setLocalVar('[Conflict]HeraldChat', 1)
    end

    -- If player can afford to join
    if player:getGil() >= conflict:getSignupFee() then
        params[2] = params[2] + 0x80
    end

    -- Refund available
    if state == xi.conflictState.CANCELLED and entry ~= nil then
        params[2] = params[2] + 0x400
    end

    -- TODO: participated in previous Ballista
    if signupState == xi.conflictSignupState.NATIONS and false then
        params[2] = params[2] + 0x1000
    end

    -- Sign-up status
    if entry ~= nil then
        if entry:getTeamIndex() == 1 then
            params[2] = params[2] + 0x4000 -- Has an application for second team, leave empty for first team
        end

        if entry:isTempEntry() then
            params[2] = params[2] + 0x1000000 -- Has a temporary application
        end
    end

    -- Teleports and warps
    if entry == nil or state ~= xi.conflictState.SIGN_UP then
        -- Can warp to HP with ballista points
        if player:getCurrency('ballista_point') >= teleportCost then
            params[2] = params[2] + 0x2000
        end

        if player:hasKeyItem(xi.keyItem.BALLISTA_INSTAWARP) then
            -- Can warp to HP with key item
            params[2] = params[2] + 0x8000
        end

        if player:hasKeyItem(xi.keyItem.BALLISTA_INSTAPORT) then
            -- Can teleport to other Ballista area
            params[2] = params[2] + 0x10000
        end

        -- Reminder of temporary entries open at 18:00, if player currently isn't allowed yet
        if params[0] >= 5 and params[0] <= 7 then
            params[2] = params[2] + 0x80000
        end
    end

    -- Game ended or got cancelled and reward/refund is given out
    if entry ~= nil and state > xi.conflictState.ACTIVE then
        --[[ Reward numbers:
            1: Congratulations! Here is your reward. Use it wisely!
            2: I wish you better luck during the next match. Here is your parting gift.
            3: Both nations fought well. Let me return your participation fee.
            4: Let me return your participation fee.

            If exp should be rewarded as well, add 0x200000 to param
        ]]
        local reward = 4 -- Cancelled

        local playerTeam = entry:getTeamIndex()
        local winningNation = conflict:getWinningTeam()
        if winningNation == playerTeam then -- Won
            reward = 1
        elseif winningNation == nil then -- Draw
            reward = 3
        elseif winningNation ~= nil then -- Lost
            reward = 2
        end

        player:setLocalVar('[Conflict]Reward', reward)
        if reward ~= 4 then
            params[2] = params[2] + bit.lshift(reward, 8)
            if winningNation ~= nil then
                params[2] = params[2] + 0x200000
            end
        end
    end

    -- ## Param 3; Team member counts
    -- Member counts repeats. Maybe one is amount signed up, and second is how many are logged in?
    params[3] = members1 + bit.lshift(members2, 8) + bit.lshift(members1, 16) + bit.lshift(members2, 24)

    -- ## Param 4: Unknown
    -- Is consistent across characters and worlds, but changes sometimes. Same number is also given by Pursuivants. Possible 'seasons'?
    -- Seen values: 0x120100, 0x10020100, 0x300201C0, 0x201201C0
    params[4] = 0

    -- ## Params 6 and 7 are points/rounds won
    if conflict:getType() == 1 and state == xi.conflictState.POST_GAME then -- Best of Three
        params[6], params[7] = conflict:getTeamRounds()
    else
        params[6], params[7] = conflict:getTeamScores()
    end

    player:startEvent(zoneInfo.events.HERALD, params)
end

-- requestedTeamIdx is set when the player picked a specific nation's forces off the menu rather
-- than letting the Herald place them.
local function handleSignupRequest(player, conflict, isTempEntry, requestedTeamIdx)
    --[[ Responses based on p0:
    0:  The entry period has come to a close. Your application was not accepted.
    3:  I'm sorry. We are unable to accept your entry.
        Currently we are only accept temporary entries. Before the match begins, adventurers will automatically be divided into two forces based on their main jobs. Do you wish to proceed?
    5:  There is little or no difference in the number of participants for each nation's forces. We are not guest entries at this time.
        We are now accepting applications for the Ballista match between <n1> and <n2>.
        Currently, the <n1> forces number <p4> adventurers. The <n2> forces number <p5>.
        Do you wish to apply once more?
    6:  Due to the lack of participants for the opposing nation, we are unable to accept your entry at this time.
        We are now accepting applications for the Ballista match between <n1> and <n2>.
        Currently, the <n1> forces number <p4> adventurers. The <n2> forces number <p5>.
        Do you wish to apply once more?
    7:  No openings remain in the requested nation's forces. You cannot participate in this match unless someone requests a discharge.
    8:  No openings remain for either nation's forces. You cannot participate in this match unless someone requests a discharge.
    11: Your application has been accepted. You are now a member of the <??> forces.
        As to avoid any problems with crowding, I ask that you wait for the start of the match at a distance.
    Optional for 11:
        * p7: bits 20+ is cost
        * p7: bits 1-2 is nation
        * p7: bit 3 'act as a representative for nation' (seems overriden by bit 4)
        * p7: bit 4 'temporary entry'

        Team counts after joining:
        * p4: team1 count
        * p5: team2 count
    --]]

    local params = {}

    local signupState = conflict:getSignupState()
    if signupState == xi.conflictSignupState.TEMPORARY and not isTempEntry then
        params[0] = 3
        return params
    end

    local members1, members2 = conflict:getTeamCounts()
    params[4] = members1
    params[5] = members2

    if signupState == xi.conflictSignupState.FILL then
        local maxTeamSize = conflict:getMaxTeamSize()
        -- Can only fill teams up to the maximum team size allowed in the match
        if members1 >= maxTeamSize and members2 >= maxTeamSize then
            params[0] = 8
            return params
        end
    end

    if members1 >= 72 and members2 >= 72 then
        params[0] = 8
        return params
    end

    local allowances = xi.conflict.getTeamEntryAllowances(conflict)

    local teamIdx = 0
    if requestedTeamIdx ~= nil then
        teamIdx = requestedTeamIdx

        -- The same openings that gate a nation entry gate a request for that nation by name.
        if allowances[teamIdx] == xi.conflict.entryAllowance.RESTRICTED_START then
            params[0] = 6
            return params

        elseif allowances[teamIdx] == xi.conflict.entryAllowance.RESTRICTED_DIFF then
            params[0] = 5
            return params
        end

    elseif signupState == xi.conflictSignupState.NATIONS then
        -- Join own nation team if possible
        local nation1, nation2 = conflict:getTeamNations()
        if nation1 == player:getNation() then
            teamIdx = 0
        elseif nation2 == player:getNation() then
            teamIdx = 1
        else
            -- Can't join as a non-participating nation at the moment
            params[0] = 0
            return params
        end

        -- Check entry application against requested nation members
        if allowances[teamIdx] == xi.conflict.entryAllowance.RESTRICTED_START then
            -- Not enough entries on other team to start the match yet, so can't join.
            params[0] = 6
            return params

        elseif allowances[teamIdx] == xi.conflict.entryAllowance.RESTRICTED_DIFF then
            -- Too little of a difference to join own nation team at the moment.
            params[0] = 5
            return params
        end

    else
        -- Join team with fewest members
        teamIdx = members1 > members2 and 1 or 0
    end

    -- Can't join team if it has equal or more than 72 members
    if allowances[teamIdx] == xi.conflict.entryAllowance.FULL then
        params[0] = 7
        return params
    end

    -- Attempt to join
    local signupFee = conflict:getSignupFee()
    if player:getGil() >= signupFee and conflict:addPlayer(player, teamIdx) then
        params[0] = 11

        local entry = player:getConflictEntry()
        local teamNation = entry:getTeamNation()
        params[7] = teamNation + bit.lshift(signupFee, 16)
        if teamNation ~= player:getNation() then
            params[7] = params[7] + 0x4
        end

        if entry:isTempEntry() then
            params[7] = params[7] + 0x8
        end

        params[4], params[5] = conflict:getTeamCounts()

        if signupState == xi.conflictSignupState.FILL then
            local zoneInfo = xi.conflict.getZoneInfoForConflict(conflict)
            local herald = xi.conflict.getHeraldEntity(player:getZone())
            xi.conflict.entityMessageSpecial(conflict, herald, zoneInfo.text.A_NEW_PARTICIPANT, entry:getTeamNation())
        end

        return params
    else
        -- Failed to join
        if signupState == xi.conflictSignupState.NATIONS then
            params[0] = 5
            return params

        elseif signupState == xi.conflictSignupState.TEMPORARY then
            params[0] = 3
            return params

        else
            params[0] = 0
            return params
        end
    end
end

function xi.conflict.herald.onEventUpdate(player, csid, option)
    local zoneInfo = xi.conflict.getZoneInfoForEntity(player)
    if zoneInfo == nil then
        return
    end

    if csid == zoneInfo.events.HERALD then
        if
            option == 1 or
            option == 2 or
            option == 14 or
            option == 15 or
            option == 16
        then
            local conflict = player:getZone():getConflict()
            if conflict == nil then
                return
            end

            -- 14 and 15 are "only in the <nation>'s forces", naming the first and second team.
            local requestedTeamIdx = nil
            if option == 14 then
                requestedTeamIdx = 0
            elseif option == 15 then
                requestedTeamIdx = 1
            end

            -- Sign-up
            local params = handleSignupRequest(player, conflict, option == 1, requestedTeamIdx)
            if params then
                player:updateEvent(params)
            end

        elseif option == 9 then
            -- Instawarp
            if
                not player:hasKeyItem(xi.keyItem.BALLISTA_INSTAWARP) and
                player:getCurrency('ballista_point') < teleportCost
            then
                player:updateEvent(0)
                return
            end

            player:updateEvent(1)

        elseif option == 10 or option == 11 or option == 12 then
            -- Instaport
            if not player:hasKeyItem(xi.keyItem.BALLISTA_INSTAPORT) then
                player:updateEvent(0)
                return
            end

            player:updateEvent(1)
        end
    end
end

function xi.conflict.herald.onEventFinish(player, csid, option, npc)
    local zoneInfo = xi.conflict.getZoneInfoForEntity(player)
    if zoneInfo == nil then
        return
    end

    if csid == zoneInfo.events.HERALD then

        if option == 3 or option == 4 then -- Discharge request. 3: Leave mid-game, 4: Leave before game
            local conflict = player:getConflict()
            local entry = player:getConflictEntry()
            if conflict == nil or entry == nil then
                return
            end

            if not entry:canLeave() then
                player:messageSpecial(zoneInfo.text.DISCHARGE_DENIED, entry:getTeamNation())
                return
            end

            local state = conflict:getState()
            if option == 4 and state < xi.conflictState.PREPARING then
                -- Leave before game has started, so gil is returned.
                local returnedGil = entry:leave()
                player:messageSpecial(zoneInfo.text.DISCHARGED, entry:getTeamNation(), returnedGil)

            elseif state == xi.conflictState.PREPARING or state == xi.conflictState.ACTIVE then
                -- Leave during game, no gil returned and notification is sent to other players in the conflict.
                entry:leave()
                player:messageSpecial(zoneInfo.text.NO_LONGER_MEMBER, entry:getTeamNation())
                xi.conflict.messageSpecial(conflict, zoneInfo.text.ENTRY_CANCELLATION, entry:getTeamNation())

            else
                -- Unable to be discharged at the current state
                player:messageSpecial(zoneInfo.text.DISCHARGE_DENIED, entry:getTeamNation())
            end

        elseif option == 5 or option == 6 or option == 7 or option == 8 then -- Win, lose, draw, or cancellation refund
            local conflict = player:getConflict()
            if conflict == nil then
                return
            end

            local state = conflict:getState()
            if state <= xi.conflictState.ACTIVE then
                return
            end

            local reward = player:getLocalVar('[Conflict]Reward')
            local entry = player:getConflictEntry()
            if reward ~= 0 and entry ~= nil and entry:canLeave() then
                player:setLocalVar('[Conflict]Reward', 0)
                local rewardTable = {
                    keyItem = { xi.keyItem.BALLISTA_INSTAWARP, xi.keyItem.BALLISTA_INSTAPORT },
                }

                local gilReward = entry:leave()
                if gilReward == nil then
                    return
                end

                if reward == 1 then -- Win
                    player:messageSpecial(zoneInfo.text.YOUR_NATION_REWARD, gilReward)

                elseif reward == 3 then -- Draw
                    player:messageSpecial(zoneInfo.text.DRAW_REWARD, gilReward)

                elseif reward == 4 then -- Cancellation refund
                    player:messageSpecial(zoneInfo.text.CANCELLATION_REFUND, gilReward)
                end

                -- If not refunding, reward experience points based on player level
                if reward ~= 4 then
                    local level = player:getMainLvl()
                    local expReward = nil
                    if level < 40 then
                        expReward = 300
                    elseif level < 50 then
                        expReward = 350
                    elseif level < 60 then
                        expReward = 400
                    elseif level < 75 then
                        expReward = 450
                    else
                        expReward = 500
                    end

                    rewardTable.xp = expReward
                end

                npcUtil.giveReward(player, rewardTable)
            end

        elseif option == 9 then -- Warp to HP
            if player:hasKeyItem(xi.keyItem.BALLISTA_INSTAWARP) then
                player:delKeyItem(xi.keyItem.BALLISTA_INSTAWARP)
                player:messageSpecial(zones[player:getZoneID()].text.HAND_OVER_KI, xi.keyItem.BALLISTA_INSTAWARP)

            elseif player:getCurrency('ballista_point') >= teleportCost then
                player:delCurrency('ballista_point', teleportCost)
                player:messageSpecial(zones[player:getZoneID()].text.USE_BALLISTA_POINTS, 100)
            else
                return
            end

            player:timer(500, function(player)
                player:warp()
            end)

        elseif option == 10 or option == 11 or option == 12 then -- Teleport to Ballista area
            if not player:hasKeyItem(xi.keyItem.BALLISTA_INSTAPORT) then
                return
            end

            local targetZone = 0
            if option == 10 then
                targetZone = xi.zone.JUGNER_FOREST
            elseif option == 11 then
                targetZone = xi.zone.PASHHOW_MARSHLANDS
            elseif option == 12 then
                targetZone = xi.zone.MERIPHATAUD_MOUNTAINS
            end

            xi.conflict.teleportToZone(player, targetZone)
        end
    end
end
