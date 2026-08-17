-----------------------------------
-- Conflict (Ballista): the Marshal's Ballista Point Ranking.
--
-- Ranks, key items and titles come from the Ffxiclopedia Ballista article. First, second and third
-- take their own chevron; fourth through tenth share bronze; past tenth takes nothing. Separately,
-- the best of each job takes that job's chevron.
-----------------------------------

describe('Conflict (Ballista) ranking', function()
    ---@type CClientEntityPair
    local player

    before_each(function()
        player = xi.test.world:spawnPlayer({ zone = xi.zone.JUGNER_FOREST, job = xi.job.WAR, level = 75 })
    end)

    it('gives the top three their own chevrons', function()
        assert(xi.conflict.ranking.overallChevronFor(1).keyItem == xi.keyItem.GOLD_BALLISTA_CHEVRON, 'first takes gold')
        assert(xi.conflict.ranking.overallChevronFor(2).keyItem == xi.keyItem.MYTHRIL_BALLISTA_CHEVRON, 'second takes mythril')
        assert(xi.conflict.ranking.overallChevronFor(3).keyItem == xi.keyItem.SILVER_BALLISTA_CHEVRON, 'third takes silver')
    end)

    it('shares bronze from fourth to tenth', function()
        for place = 4, 10 do
            local chevron = xi.conflict.ranking.overallChevronFor(place)

            assert(chevron ~= nil, 'place ' .. place .. ' should take a chevron')
            assert(chevron.keyItem == xi.keyItem.BRONZE_BALLISTA_CHEVRON, 'place ' .. place .. ' should take bronze')
        end
    end)

    it('gives nothing past tenth', function()
        assert(xi.conflict.ranking.overallChevronFor(11) == nil, 'eleventh should take nothing')
        assert(xi.conflict.ranking.overallChevronFor(50) == nil, 'fiftieth should take nothing')
    end)

    it('carries a chevron and a title for every job', function()
        for _, job in pairs(xi.job) do
            if type(job) == 'number' and job >= xi.job.WAR and job <= xi.job.SCH then
                local chevron = xi.conflict.ranking.jobChevronFor(job)

                assert(chevron ~= nil, 'job ' .. job .. ' has no chevron')
                assert(chevron.keyItem ~= nil, 'job ' .. job .. ' has no key item')
                assert(chevron.title ~= nil, 'job ' .. job .. ' has no title')
            end
        end
    end)

    -- Registration opens when a match ends and runs four Vana'diel hours; the board is unreadable
    -- until it closes, then readable for four Vana'diel days. Rather than move the clock, each
    -- match is given a start time that puts its end the required distance in the past.
    local function matchEndedMinutesAgo(minutes)
        local now = VanadielUniqueDay() * 1440 + VanadielHour() * 60 + VanadielMinute()
        local length = 60

        local zone = player:getZone()

        zone:initializeConflict({
            team1     = xi.allegiance.SAN_DORIA,
            team2     = xi.allegiance.BASTOK,
            startTime = now - minutes - length,
            length    = length,
        })

        return zone:getConflict()
    end

    it('refuses registration while the match is still running', function()
        local conflict = matchEndedMinutesAgo(-30)

        assert(not xi.conflict.ranking.registrationIsOpen(conflict), 'a running match cannot be registered')
        assert(not xi.conflict.ranking.boardIsReadable(conflict), 'nor can its board be read')
    end)

    it('opens registration for four Vana hours after the match', function()
        local conflict = matchEndedMinutesAgo(60)

        assert(xi.conflict.ranking.registrationIsOpen(conflict), 'registration should be open')
        assert(not xi.conflict.ranking.boardIsReadable(conflict), 'the board stays shut while registering')
    end)

    it('opens the board once registration closes', function()
        local conflict = matchEndedMinutesAgo(xi.conflict.ranking.registerWindow + 60)

        assert(not xi.conflict.ranking.registrationIsOpen(conflict), 'registration should have closed')
        assert(xi.conflict.ranking.boardIsReadable(conflict), 'the board should now be readable')
    end)

    it('closes the board after four Vana days', function()
        local expired = xi.conflict.ranking.registerWindow + xi.conflict.ranking.viewWindow + 60
        local conflict = matchEndedMinutesAgo(expired)

        assert(not xi.conflict.ranking.boardIsReadable(conflict), 'the board should have expired')
    end)

    -- End to end: a finished match is registered, the board reads it back, and the placing
    -- decides the chevron.
    it('registers a match and reads it back off the board', function()
        local conflict = matchEndedMinutesAgo(60)

        conflict:addPlayer(player, 0)

        local entry = player:getConflictEntry()
        entry:addPetras(3)
        entry:scorePetras()

        assert(entry:getPoints() > 0, 'setup: the player should have earned points')

        local registered = xi.conflict.ranking.register(player, conflict)
        assert(registered, 'the registration was refused')

        local assessment = xi.conflict.ranking.assess(player, xi.zone.JUGNER_FOREST)

        assert(assessment ~= nil, 'the board did not carry the registered match')
        assert(assessment.place == 1, 'the only registrant should be first')
        assert(assessment.overall.keyItem == xi.keyItem.GOLD_BALLISTA_CHEVRON, 'first takes gold')
        assert(assessment.jobChevron.keyItem == xi.keyItem.BLOODY_BALLISTA_CHEVRON, 'and the Warrior chevron')
    end)

    it('refuses a match with no points earned', function()
        local conflict = matchEndedMinutesAgo(60)

        conflict:addPlayer(player, 0)

        local ok, reason = xi.conflict.ranking.register(player, conflict)

        assert(not ok, 'a match with no points should not register')
        assert(reason == xi.conflict.ranking.refusal.NO_POINTS, 'the wrong refusal was given')
    end)

    it('takes back the chevron a player already holds', function()
        player:addKeyItem(xi.keyItem.BRONZE_BALLISTA_CHEVRON)

        local gold = xi.conflict.ranking.overallChevronFor(1)
        assert(xi.conflict.ranking.awardChevron(player, gold), 'the award was refused')

        assert(player:hasKeyItem(xi.keyItem.GOLD_BALLISTA_CHEVRON), 'the new chevron was not handed over')
        assert(not player:hasKeyItem(xi.keyItem.BRONZE_BALLISTA_CHEVRON), 'only one chevron may be held')
        assert(player:hasTitle(xi.title.GOLD_BALLI_STAR), 'the title should come with it')
    end)

    -- A chevron is good for one Earth week; after that the Herald wants it back before the wearer
    -- enters another match.
    it('treats a chevron as current for its first week', function()
        assert(xi.conflict.ranking.awardChevron(player, xi.conflict.ranking.overallChevronFor(1)), 'setup: award failed')

        assert(not xi.conflict.ranking.hasExpiredChevron(player), 'a fresh chevron has not expired')
    end)

    it('expires a chevron after a week', function()
        assert(xi.conflict.ranking.awardChevron(player, xi.conflict.ranking.overallChevronFor(1)), 'setup: award failed')

        -- Backdate the award past its lifetime.
        player:setCharVar('[Conflict]ChevronAwarded', GetSystemTime() - xi.conflict.ranking.chevronLifetime - 1)

        assert(xi.conflict.ranking.hasExpiredChevron(player), 'the chevron should have expired')
    end)

    it('clears the expiry when the chevron goes back', function()
        assert(xi.conflict.ranking.awardChevron(player, xi.conflict.ranking.overallChevronFor(1)), 'setup: award failed')
        player:setCharVar('[Conflict]ChevronAwarded', GetSystemTime() - xi.conflict.ranking.chevronLifetime - 1)

        assert(xi.conflict.ranking.returnChevron(player), 'the return was refused')

        assert(not player:hasKeyItem(xi.keyItem.GOLD_BALLISTA_CHEVRON), 'the chevron should have gone back')
        assert(not xi.conflict.ranking.hasExpiredChevron(player), 'nothing is held, so nothing has expired')
    end)

    it('holds nothing against a player wearing no chevron', function()
        assert(not xi.conflict.ranking.hasExpiredChevron(player), 'no chevron cannot be expired')
        assert(not xi.conflict.ranking.returnChevron(player), 'there is nothing to hand back')
    end)

    it('finds the chevron a player is already holding', function()
        assert(xi.conflict.ranking.heldChevron(player) == nil, 'a fresh character holds none')

        player:addKeyItem(xi.keyItem.SILVER_BALLISTA_CHEVRON)

        local held = xi.conflict.ranking.heldChevron(player)

        assert(held ~= nil, 'the held chevron was not found')
        assert(held.title == xi.title.SILVER_BALLI_STAR, 'the wrong chevron was reported')
    end)
end)
