-----------------------------------
-- Conflict (Ballista): the Marshal's Ballista Point Ranking.
--
-- The board ranks the last ten matches held at a location on the points a character earned in a
-- single match, so it is per location and a good match does not carry to the next one.
--
-- A character registers a finished match with the Marshal within four Vana'diel hours of it
-- ending. The board cannot be read during that window; once it closes there are four Vana'diel
-- days to read the assessment and take the chevron it awards.
--
-- Chevrons go to the overall top ten and to the best of each job. They last one Earth week and
-- have to be handed back before entering another match. Only one may be worn, so a character who
-- earns both picks. Ranks, key items and titles come from the Ffxiclopedia Ballista article.
-----------------------------------

require('scripts/globals/conflict/zoneinfo')

xi = xi or {}
xi.conflict = xi.conflict or {}

xi.conflict.ranking = xi.conflict.ranking or {}

-- Vana'diel minutes.
xi.conflict.ranking.registerWindow = 4 * 60
xi.conflict.ranking.viewWindow     = 4 * 60 * 24

-- A chevron lasts half a Vana'diel year, after which the Herald wants it back before the wearer
-- enters another match. The Marshal adds 622080 to the expiry stamp, which is 180 Vana'diel days
-- and 7.2 Earth days; the update note's "one week Earth time" is SE rounding that off. Earth
-- seconds, because that is what GetSystemTime counts.
xi.conflict.ranking.chevronLifetime = 622080

local chevronAwardedVar = '[Conflict]ChevronAwarded'

-- Awarded on overall placing. Anything past tenth takes nothing.
xi.conflict.ranking.overallChevrons =
{
    { place = 1,  keyItem = xi.keyItem.GOLD_BALLISTA_CHEVRON,    title = xi.title.GOLD_BALLI_STAR },
    { place = 2,  keyItem = xi.keyItem.MYTHRIL_BALLISTA_CHEVRON, title = xi.title.MYTHRIL_BALLI_STAR },
    { place = 3,  keyItem = xi.keyItem.SILVER_BALLISTA_CHEVRON,  title = xi.title.SILVER_BALLI_STAR },
    { place = 10, keyItem = xi.keyItem.BRONZE_BALLISTA_CHEVRON,  title = xi.title.BRONZE_BALLI_STAR },
}

-- Awarded to the best of each job over the same ten matches.
xi.conflict.ranking.jobChevrons =
{
    [xi.job.WAR] = { keyItem = xi.keyItem.BLOODY_BALLISTA_CHEVRON,      title = xi.title.SEARING_STAR },
    [xi.job.MNK] = { keyItem = xi.keyItem.ORANGE_BALLISTA_CHEVRON,      title = xi.title.STRIKING_STAR },
    [xi.job.WHM] = { keyItem = xi.keyItem.WHITE_BALLISTA_CHEVRON,       title = xi.title.SOOTHING_STAR },
    [xi.job.BLM] = { keyItem = xi.keyItem.BLACK_BALLISTA_CHEVRON,       title = xi.title.SABLE_STAR },
    [xi.job.RDM] = { keyItem = xi.keyItem.RED_BALLISTA_CHEVRON,         title = xi.title.SCARLET_STAR },
    [xi.job.THF] = { keyItem = xi.keyItem.GREEN_BALLISTA_CHEVRON,       title = xi.title.SONIC_STAR },
    [xi.job.PLD] = { keyItem = xi.keyItem.SPARKING_BALLISTA_CHEVRON,    title = xi.title.SAINTLY_STAR },
    [xi.job.DRK] = { keyItem = xi.keyItem.EBON_BALLISTA_CHEVRON,        title = xi.title.SHADOWY_STAR },
    [xi.job.BST] = { keyItem = xi.keyItem.FURRY_BALLISTA_CHEVRON,       title = xi.title.SAVAGE_STAR },
    [xi.job.BRD] = { keyItem = xi.keyItem.BROWN_BALLISTA_CHEVRON,       title = xi.title.SINGING_STAR },
    [xi.job.RNG] = { keyItem = xi.keyItem.OCHRE_BALLISTA_CHEVRON,       title = xi.title.SNIPING_STAR },
    [xi.job.SAM] = { keyItem = xi.keyItem.JADE_BALLISTA_CHEVRON,        title = xi.title.SLICING_STAR },
    [xi.job.NIN] = { keyItem = xi.keyItem.TRANSPARENT_BALLISTA_CHEVRON, title = xi.title.SNEAKING_STAR },
    [xi.job.DRG] = { keyItem = xi.keyItem.PURPLE_BALLISTA_CHEVRON,      title = xi.title.SPEARING_STAR },
    [xi.job.SMN] = { keyItem = xi.keyItem.RAINBOW_BALLISTA_CHEVRON,     title = xi.title.SUMMONING_STAR },
    [xi.job.PUP] = { keyItem = xi.keyItem.SILK_BALLISTA_CHEVRON,        title = xi.title.SWAYING_STAR },
    [xi.job.COR] = { keyItem = xi.keyItem.CORAL_BALLISTA_CHEVRON,       title = xi.title.SURGING_STAR },
    [xi.job.BLU] = { keyItem = xi.keyItem.SAPPHIRE_BALLISTA_CHEVRON,    title = xi.title.SAPPHIRE_STAR },
    [xi.job.DNC] = { keyItem = xi.keyItem.SEQUINED_BALLISTA_CHEVRON,    title = xi.title.SPRIGHTLY_STAR },
    [xi.job.SCH] = { keyItem = xi.keyItem.VELVET_BALLISTA_CHEVRON,      title = xi.title.SAGACIOUS_STAR },
    [xi.job.GEO] = { keyItem = xi.keyItem.GOSSAMER_BALLISTA_CHEVRON,    title = xi.title.SPIRITUAL_STAR },
    [xi.job.RUN] = { keyItem = xi.keyItem.STEEL_BALLISTA_CHEVRON,       title = xi.title.STIPPLING_STAR },
}

xi.conflict.ranking.allChevrons = {}
for _, entry in ipairs(xi.conflict.ranking.overallChevrons) do
    table.insert(xi.conflict.ranking.allChevrons, entry)
end

for _, entry in pairs(xi.conflict.ranking.jobChevrons) do
    table.insert(xi.conflict.ranking.allChevrons, entry)
end

-- The chevron an overall placing earns, or nil past tenth. First to tenth are not four separate
-- prizes: first, second and third take their own, and fourth through tenth share bronze.
function xi.conflict.ranking.overallChevronFor(place)
    for _, entry in ipairs(xi.conflict.ranking.overallChevrons) do
        if place <= entry.place then
            return entry
        end
    end

    return nil
end

function xi.conflict.ranking.jobChevronFor(job)
    return xi.conflict.ranking.jobChevrons[job]
end

-- One chevron at a time, so anyone still holding last week's has to hand it back.
function xi.conflict.ranking.heldChevron(player)
    for _, entry in ipairs(xi.conflict.ranking.allChevrons) do
        if player:hasKeyItem(entry.keyItem) then
            return entry
        end
    end

    return nil
end

-- The client sends these back as negative numbers, which arrive unsigned. Marshal event 26:
-- registering is -5, asking for the board is -3, asking for the assessment is -7.
xi.conflict.ranking.option =
{
    REGISTER   = 0xFFFFFFFB,
    VIEW_BOARD = 0xFFFFFFFD,
    ASSESSMENT = 0xFFFFFFF9,
}

-- Registration is open for four Vana'diel hours after a match ends, and the board cannot be read
-- until that closes. Reading it is then possible for four Vana'diel days.
local function minutesSinceMatchEnd(conflict)
    local now = VanadielUniqueDay() * 1440 + VanadielHour() * 60 + VanadielMinute()

    return now - conflict:getEndTime()
end

function xi.conflict.ranking.registrationIsOpen(conflict)
    local since = minutesSinceMatchEnd(conflict)

    return since >= 0 and since < xi.conflict.ranking.registerWindow
end

function xi.conflict.ranking.boardIsReadable(conflict)
    local since = minutesSinceMatchEnd(conflict)
    local closes = xi.conflict.ranking.registerWindow + xi.conflict.ranking.viewWindow

    return since >= xi.conflict.ranking.registerWindow and since < closes
end

-- Reasons the Marshal turns a registration away, each matching a line it has for the purpose.
xi.conflict.ranking.refusal =
{
    WINDOW_CLOSED = 1, -- 7544, registration has concluded
    NO_POINTS     = 2, -- 7545, you did not obtain any points
    WRONG_JOB     = 3, -- 7547, your job does not match the record
}

-- Returns true on success, or false and a refusal reason.
function xi.conflict.ranking.register(player, conflict)
    -- Left inert on purpose. conflict_rankings is keyed on (instanceid, charid), and instanceid is
    -- an AUTO_INCREMENT that restarts from MAX(id) + 1 once the startup cleanup has deleted
    -- finished matches. When ids come round again a registration silently REPLACEs an unrelated
    -- older row and the board mixes two matches together. The key wants to be
    -- (zoneid, matchstart, charid), which is what the board actually reads on. Nothing in game
    -- reaches this yet, because there is no Marshal NPC, so refusing costs nothing today.
    if true then
        return false, xi.conflict.ranking.refusal.WINDOW_CLOSED
    end

    if not xi.conflict.ranking.registrationIsOpen(conflict) then
        return false, xi.conflict.ranking.refusal.WINDOW_CLOSED
    end

    local entry = player:getConflictEntry()
    if entry == nil or entry:getPoints() == 0 then
        return false, xi.conflict.ranking.refusal.NO_POINTS
    end

    -- The board records the job that earned the points, so a character who has since changed
    -- cannot register the match under the new one.
    if entry:getJob() ~= player:getMainJob() then
        return false, xi.conflict.ranking.refusal.WRONG_JOB
    end

    return entry:registerForRanking()
end

-- What the board says about one character: their best placing over the ranked matches, and
-- whether they were the best of their job. Both can be true, and retail lets them pick.
function xi.conflict.ranking.assess(player, zoneId)
    local board = GetBallistaRanking(zoneId)
    local charId = player:getID()

    local placing = nil
    local jobPlacing = nil
    local jobSeen = {}

    for _, row in ipairs(board) do
        local bestOfJob = jobSeen[row.job] == nil
        jobSeen[row.job] = true

        if row.charid == charId then
            -- Rows are best first, so the first match is the best one.
            if placing == nil then
                placing = row.place
            end

            if bestOfJob and jobPlacing == nil then
                jobPlacing = row.job
            end
        end
    end

    if placing == nil then
        return nil
    end

    return {
        place        = placing,
        overall      = xi.conflict.ranking.overallChevronFor(placing),
        jobChevron   = jobPlacing and xi.conflict.ranking.jobChevronFor(jobPlacing) or nil,
    }
end

-- Hands over one chevron and the title that goes with it. Only one may be held, so anything the
-- character is still carrying has to go back first.
function xi.conflict.ranking.awardChevron(player, chevron)
    if chevron == nil then
        return false
    end

    local held = xi.conflict.ranking.heldChevron(player)
    if held ~= nil then
        if held.keyItem == chevron.keyItem then
            return false
        end

        player:delKeyItem(held.keyItem)
    end

    player:addKeyItem(chevron.keyItem)
    player:addTitle(chevron.title)
    player:setCharVar(chevronAwardedVar, GetSystemTime())

    return true
end

-- The Herald refuses a wearer whose week is up until the chevron goes back.
function xi.conflict.ranking.hasExpiredChevron(player)
    if xi.conflict.ranking.heldChevron(player) == nil then
        return false
    end

    local awarded = player:getCharVar(chevronAwardedVar)
    if awarded == 0 then
        return false
    end

    return GetSystemTime() - awarded >= xi.conflict.ranking.chevronLifetime
end

function xi.conflict.ranking.returnChevron(player)
    local held = xi.conflict.ranking.heldChevron(player)
    if held == nil then
        return false
    end

    player:delKeyItem(held.keyItem)
    player:setCharVar(chevronAwardedVar, 0)

    return true
end
