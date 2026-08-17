-----------------------------------
-- Conflict (Ballista) quarry: petra / temporary-item digging.
--
-- Ported from Eden. The item tables and weighted determination are the bulk and
-- are zone-independent; xi.conflict.quarry itself needs the zone's zoneinfo and
-- live Rooks (for closestRookDistance), so it is exercised once a match is set
-- up in a Ballista zone.
-----------------------------------
require('scripts/globals/conflict/zoneinfo')

xi = xi or {}
xi.conflict = xi.conflict or {}

xi.conflict.tempItemToIndex =
{
    [xi.item.HI_POTION]  = 0,
    [xi.item.X_POTION]   = 1,
    [xi.item.MAX_POTION] = 2,

    [xi.item.HI_ETHER]    = 3,
    [xi.item.SUPER_ETHER] = 4,
    [xi.item.PRO_ETHER]   = 5,

    [xi.item.HI_ELIXIR] = 6,
    [xi.item.ELIXIR]    = 7,

    [xi.item.FLASK_OF_EYE_DROPS]       = 8,
    [xi.item.FLASK_OF_ECHO_DROPS]      = 9,
    [xi.item.REMEDY]                   = 10,
    [xi.item.FLASK_OF_POISON_POTION]   = 11,
    [xi.item.FLASK_OF_SLEEPING_POTION] = 12,

    [xi.item.PINCH_OF_PRISM_POWDER] = 13,
    [xi.item.POT_OF_SILENT_OIL]     = 14,

    [xi.item.REVITALIZER]          = 15,
    [xi.item.BOTTLE_OF_BODY_BOOST] = 16,
    [xi.item.BOTTLE_OF_MANA_BOOST] = 17,
    [xi.item.DAEDALUS_WING]        = 18,

    [xi.item.VIAL_OF_DRACHENESSENCE]     = 19,
    [xi.item.DOSE_OF_BARFIRE_OINTMENT]   = 20,
    [xi.item.DOSE_OF_BARBLIZZARD_OINTMENT] = 21,
    [xi.item.DOSE_OF_BARAERO_OINTMENT]   = 22,
    [xi.item.DOSE_OF_BARSTONE_OINTMENT]  = 23,
    [xi.item.DOSE_OF_BARTHUNDER_OINTMENT] = 24,
    [xi.item.DOSE_OF_BARWATER_OINTMENT]  = 25,

    [xi.item.FLASK_OF_PEAR_AU_LAIT]   = 26,
    [xi.item.FLASK_OF_PAMAMA_AU_LAIT] = 27,
    [xi.item.BOTTLE_OF_MELON_JUICE]   = 28,
    [xi.item.BOTTLE_OF_TOMATO_JUICE]  = 29,

    [xi.item.BOTTLE_OF_GIANTS_DRINK]  = 30,
    [xi.item.BOTTLE_OF_WIZARDS_DRINK] = 31,

    [xi.item.CONTAINER_OF_CARNAL_INCENSE]    = 32,
    [xi.item.CONTAINER_OF_SPIRITUAL_INCENSE] = 33,
    [xi.item.CONTAINER_OF_CELESTIAL_INCENSE] = 34,

    [xi.item.PETRA_EATER] = 35,

    [xi.item.BOTTLE_OF_CATHOLICON]   = 36,
    [xi.item.BOTTLE_OF_CATHOLICON_1] = 37,
    [xi.item.BOTTLE_OF_LETHE_WATER]   = 38,
    [xi.item.BOTTLE_OF_LETHE_WATER_1] = 39,

    [xi.item.DEMORALIZER]   = 40,
    [xi.item.DEMORALIZER_1] = 41,

    [xi.item.FLASK_OF_PANACEA]        = 42,
    [xi.item.MEGALIXIR]               = 43,
    [xi.item.PINCH_OF_MANA_POWDER]    = 44,
    [xi.item.CHUNK_OF_SMELLING_SALTS] = 45,
    [xi.item.FLASK_OF_HEALING_POWDER] = 46,
}

xi.conflict.tempItemByIndex = {}
for itemId, index in pairs(xi.conflict.tempItemToIndex) do
    xi.conflict.tempItemByIndex[index] = itemId
end

-- Whether a job has MP (affects which recovery items are weighted in).
local jobsWithMp =
{
    [xi.job.WHM] = true,
    [xi.job.BLM] = true,
    [xi.job.RDM] = true,
    [xi.job.PLD] = true,
    [xi.job.DRK] = true,
    [xi.job.SMN] = true,
    [xi.job.BLU] = true,
    [xi.job.SCH] = true,
    [xi.job.GEO] = true,
    [xi.job.RUN] = true,
}

local jobsWithPets =
{
    [xi.job.DRG] = true,
    [xi.job.PUP] = true,
    [xi.job.SMN] = true,
}

local function isJobWithMp(job)
    return jobsWithMp[job] and true or false
end

local function isJobWithSpells(job)
    return job == xi.job.NIN or isJobWithMp(job)
end

local checkers =
{
    mp = function(mJob, sJob)
        return isJobWithMp(mJob) or isJobWithMp(sJob)
    end,

    spell = function(mJob, sJob)
        return isJobWithSpells(mJob) or isJobWithSpells(sJob)
    end,
}

local staticPercentages =
{
    [xi.item.MAX_POTION]        = { pct = 3 },
    [xi.item.PRO_ETHER]         = { check = checkers.mp, pct = 2.5 },
    [xi.item.FLASK_OF_ECHO_DROPS] = { check = checkers.spell, pct = 4 },
    [xi.item.ELIXIR]            = { pct = 3 },
    [xi.item.HI_ELIXIR]         = { pct = 3 },
    [xi.item.DEMORALIZER]       = { pct = 3 },
    [xi.item.DEMORALIZER_1]     = { pct = 1.7 },
}

local scalars =
{
    recoveryHp = function(player, mJob, sJob)
        return checkers.mp(mJob, sJob) and 0.6 or 1
    end,

    recoveryMp = function(player, mJob, sJob)
        return checkers.mp(mJob, sJob) and 0.6 or 0
    end,

    regenHp = function(player, mJob, sJob)
        return checkers.mp(mJob, sJob) and 0.5 or 1
    end,

    regenMp = function(player, mJob, sJob)
        return checkers.mp(mJob, sJob) and 0.5 or 0
    end,

    wyvern = function(player, mJob, sJob)
        return mJob == xi.job.DRG and 1 or 0
    end,

    pet = function(player, mJob, sJob)
        return (jobsWithPets[mJob] or jobsWithPets[sJob]) and 1 or 0
    end,
}

local itemWeights =
{
    -- HP recovery
    [xi.item.HI_POTION] = { base = 100, scale = scalars.recoveryHp },
    [xi.item.X_POTION]  = { base = 70, scale = scalars.recoveryHp },

    -- MP recovery
    [xi.item.HI_ETHER]    = { base = 100, scale = scalars.recoveryMp },
    [xi.item.SUPER_ETHER] = { base = 70, scale = scalars.recoveryMp },

    -- Misc
    [xi.item.FLASK_OF_EYE_DROPS]    = { base = 50 },
    [xi.item.REMEDY]                = { base = 70 },
    [xi.item.PINCH_OF_PRISM_POWDER] = { base = 40 },
    [xi.item.DAEDALUS_WING]         = { base = 40 },

    -- Catholicons
    [xi.item.BOTTLE_OF_CATHOLICON]   = { base = 50 },
    [xi.item.BOTTLE_OF_CATHOLICON_1] = { base = 30 },

    -- Ointments
    [xi.item.DOSE_OF_BARFIRE_OINTMENT]    = { base = 32 },
    [xi.item.DOSE_OF_BARBLIZZARD_OINTMENT] = { base = 32 },
    [xi.item.DOSE_OF_BARAERO_OINTMENT]    = { base = 32 },
    [xi.item.DOSE_OF_BARSTONE_OINTMENT]   = { base = 32 },
    [xi.item.DOSE_OF_BARTHUNDER_OINTMENT] = { base = 32 },
    [xi.item.DOSE_OF_BARWATER_OINTMENT]   = { base = 32 },

    -- HP Regen
    [xi.item.FLASK_OF_PEAR_AU_LAIT]   = { base = 60, scale = scalars.regenHp },
    [xi.item.FLASK_OF_PAMAMA_AU_LAIT] = { base = 60, scale = scalars.regenHp },

    -- MP Regen
    [xi.item.BOTTLE_OF_MELON_JUICE]  = { base = 60, scale = scalars.regenMp },
    [xi.item.BOTTLE_OF_TOMATO_JUICE] = { base = 60, scale = scalars.regenMp },

    -- Incenses
    [xi.item.CONTAINER_OF_CARNAL_INCENSE]    = { base = 30 },
    [xi.item.CONTAINER_OF_SPIRITUAL_INCENSE] = { base = 30 },
    [xi.item.CONTAINER_OF_CELESTIAL_INCENSE] = { base = 30 },

    -- Offensive items
    [xi.item.BOTTLE_OF_LETHE_WATER]   = { base = 45 },
    [xi.item.BOTTLE_OF_LETHE_WATER_1] = { base = 25 },

    -- AoE recovery
    [xi.item.FLASK_OF_HEALING_POWDER] = { base = 20 },
    [xi.item.PINCH_OF_MANA_POWDER]    = { base = 15, scale = scalars.recoveryMp },

    -- Pet items
    [xi.item.CHUNK_OF_SMELLING_SALTS] = { base = 40, scale = scalars.pet },
    [xi.item.VIAL_OF_DRACHENESSENCE]  = { base = 80, scale = scalars.wyvern },

    -- Small chance of getting some pre-checked items
    [xi.item.FLASK_OF_POISON_POTION] = { base = 5 },
    [xi.item.PETRA_EATER]            = { base = 5 },

    -- TODO: special catch-up mechanic items
    [xi.item.REVITALIZER]           = { base = 0 },
    [xi.item.BOTTLE_OF_BODY_BOOST]  = { base = 0 },
    [xi.item.BOTTLE_OF_MANA_BOOST]  = { base = 0 },
    [xi.item.BOTTLE_OF_GIANTS_DRINK]  = { base = 0 },
    [xi.item.BOTTLE_OF_WIZARDS_DRINK] = { base = 0 },
    [xi.item.MEGALIXIR]             = { base = 0 },
}

function xi.conflict.determineQuarryItem(player, entry)
    -- Prioritise a Poison Potion if the player isn't already holding/poisoned.
    if
        math.randomInt(1, 1000) <= 480 and
        not player:hasItem(xi.item.FLASK_OF_POISON_POTION, xi.inv.TEMPITEMS) and
        not player:hasStatusEffect(xi.effect.POISON)
    then
        return xi.item.FLASK_OF_POISON_POTION
    end

    -- Prioritise a Petra Eater if the player has petras and isn't already holding one.
    local heldPetras = entry:getHeldPetras()
    if
        heldPetras > 0 and
        not player:hasItem(xi.item.PETRA_EATER, xi.inv.TEMPITEMS)
    then
        local chance = math.min(heldPetras * 3, 15)
        if math.randomInt(1, 100) <= chance then
            return xi.item.PETRA_EATER
        end
    end

    local mJob = player:getMainJob()
    local sJob = player:getSubJob()

    -- Static-percentage items first.
    local pctRoll = math.randomFloat(0, 100)
    local pctCumulative = 0
    for itemId, info in pairs(staticPercentages) do
        if not info.check or info.check(mJob, sJob) then
            pctCumulative = pctCumulative + info.pct
            if pctRoll <= pctCumulative then
                return itemId
            end
        end
    end

    -- Otherwise pick from the weighted distribution.
    local weightTotal = 0
    local distribution = {}
    for itemId, info in pairs(itemWeights) do
        local weight = info.base * (info.scale and info.scale(player, mJob, sJob) or 1)
        if weight > 0 then
            weightTotal = weightTotal + weight
            distribution[itemId] = weight
        end
    end

    local weightRoll = math.randomInt(1, weightTotal)
    local weightCumulative = 0
    for itemId, weight in pairs(distribution) do
        weightCumulative = weightCumulative + weight
        if weightRoll <= weightCumulative then
            return itemId
        end
    end

    return nil
end

-- Returns the result of a quarry for the given player:
--   0  = nothing, -1 = a petra, >0 = the temp item id to award.
local function getQuarryResult(player)
    local entry = player:getConflictEntry()
    if entry == nil then
        return 0
    end

    local roll = math.randomInt(1, 1000)
    -- closestRookDistance is nil if no rooks are active yet; treat that as far away.
    local rookDist = entry:closestRookDistance() or 999

    -- Chance of nothing, increasing slightly the closer you are to a Rook.
    local missChance = math.min(8.5 + 1000 / (rookDist * rookDist), 18)
    if roll <= missChance * 10 then
        return 0
    end

    roll = roll - missChance * 10

    -- Petra chance: very low near a Rook, rising with distance, capped at ~1/3.
    local petraChance = 1.5
    if rookDist > 15 then
        petraChance = math.min(33.3, petraChance + (rookDist - 15) * 2)
    end

    -- Petras are harder to turn up while already ahead, and easier while behind: this is the
    -- catch-up that lets a losing side back into a match. Holding a gate breach counts as being
    -- ahead, since the throw is already open. The sizes of both adjustments are a guess; only the
    -- direction is documented.
    local conflict = entry:getConflict()
    if conflict ~= nil then
        local ownScore, otherScore = conflict:getTeamScores()
        if entry:getTeamIndex() == 1 then
            ownScore, otherScore = otherScore, ownScore
        end

        if ownScore > otherScore then
            petraChance = petraChance * 0.75
        elseif ownScore < otherScore then
            petraChance = math.min(33.3, petraChance * 1.25)
        end

        if entry:hasGateBreach() then
            petraChance = petraChance * 0.75
        end
    end

    if roll <= petraChance * 10 then
        return -1
    end

    return xi.conflict.determineQuarryItem(player, entry)
end

function xi.conflict.quarry(player)
    local zoneInfo = xi.conflict.getZoneInfoForEntity(player)
    local entry    = player:getConflictEntry()
    if zoneInfo == nil or entry == nil then
        return
    end

    local itemId = getQuarryResult(player) or 0
    player:setAnimation(48)

    player:timer(3000, function(player)
        player:setAnimation(0)

        if itemId == 0 then
            player:messageSpecial(zoneInfo.text.FIND_NOTHING)
        elseif itemId > 0 then
            if player:hasKeyItem(xi.keyItem.PETRA_SHOVEL) then
                -- Automatically place the item into the temp inventory if possible.
                local freeSlots = player:getFreeSlotsCount(xi.inv.TEMPITEMS)
                if freeSlots == 0 then
                    player:messageSpecial(zoneInfo.text.CANT_CARRY_MORE_TEMP_ITEMS, itemId)
                elseif player:hasItem(itemId, xi.inv.TEMPITEMS) then
                    player:messageSpecial(zoneInfo.text.CAN_ONLY_CARRY_ONE_TEMP_ITEM, itemId)
                else
                    player:messageSpecial(zoneInfo.text.OBTAIN_TEMP_ITEM, itemId, freeSlots == 1 and 1 or 0)
                    player:addTempItem(itemId)
                end
            else
                -- Let the player decide what to do with the item.
                local params = { [1] = xi.conflict.tempItemToIndex[itemId], [2] = 0, [3] = 0, [4] = 0 }

                if player:hasItem(itemId, xi.inv.TEMPITEMS) then
                    params[7] = 2
                elseif player:getFreeSlotsCount(xi.inv.TEMPITEMS) == 0 then
                    params[7] = 1

                    -- Flag the items already held that could be exchanged.
                    local inventoryItems = player:getItems(xi.inv.TEMPITEMS)
                    for _, inventoryItemId in ipairs(inventoryItems) do
                        -- A held item the client's exchange list does not carry cannot be offered
                        -- as an exchange. The Marshal sells vouchers for two such items.
                        local leftShift = xi.conflict.tempItemToIndex[inventoryItemId]
                        if leftShift ~= nil then
                            local paramIdx = 2 + math.floor(leftShift / 32)
                            leftShift = leftShift % 32
                            params[paramIdx] = params[paramIdx] + bit.lshift(1, leftShift)
                        end
                    end
                end

                player:setLocalVar('[Conflict]QuarryItemId', itemId)

                -- Quarrying involves no NPC, so the event would otherwise be dispatched into
                -- whichever script the player last talked to.
                player:prepareEventForZone()
                player:startEvent(zoneInfo.events.KEEP_TEMP_ITEM, params)
            end
        elseif itemId < 0 then
            if
                entry:getHeldPetras() == 0 and
                player:hasKeyItem(xi.keyItem.BALLISTA_BAND)
            then
                player:prepareEventForZone()
                player:startEvent(zoneInfo.events.KEEP_FIRST_PETRA)
            else
                player:messageSpecial(zoneInfo.text.OBTAIN_PETRA, 1, entry:addPetras(1))
            end
        end
    end)
end

function xi.conflict.distributeInitialItems(player)
    local zoneInfo = xi.conflict.getZoneInfoForEntity(player)
    if zoneInfo == nil then
        return false
    end

    -- Static items for all jobs.
    player:addTempItem(xi.item.X_POTION)
    player:addTempItem(xi.item.REMEDY)
    player:addTempItem(xi.item.BOTTLE_OF_CATHOLICON)
    player:addTempItem(xi.item.PETRA_EATER)
    player:messageSpecial(zoneInfo.text.PRESENTED_WITH_TEMP_ITEMS, 5)

    -- Delay the last item; the inventory doesn't always update correctly otherwise.
    player:timer(1000, function(player)
        local mJob = player:getMainJob()
        local sJob = player:getSubJob()

        if mJob == xi.job.DRG then
            player:addTempItem(xi.item.VIAL_OF_DRACHENESSENCE)
        elseif isJobWithMp(mJob) or isJobWithMp(sJob) then
            player:addTempItem(xi.item.SUPER_ETHER)
        else
            player:addTempItem(xi.item.DOSE_OF_BARFIRE_OINTMENT + math.random(0, 5))
        end
    end)

    return true
end
