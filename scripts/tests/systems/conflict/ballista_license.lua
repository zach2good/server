-----------------------------------
-- Conflict (Ballista): the licence quest.
--
-- The Herald and the Pursuivants refuse anyone without a Ballista Licence, so this is the only
-- way into a scheduled match. The director of your own nation sends you to the other two nations'
-- leaders carrying a letter each, and issues the licence once both are delivered and your own
-- leader has received you.
-----------------------------------

describe('Ballista License', function()
    ---@type CClientEntityPair
    local player

    local function spawnCitizenOf(nation)
        local p = xi.test.world:spawnPlayer()

        p:setNation(nation)
        p:setRank(3)

        -- A fresh character starts on the first SoA mission, whose zone-in cutscene fires in
        -- Northern San d'Oria and would intercept the quest NPC.
        p:addMission(xi.mission.log_id.SOA, xi.mission.id.soa.RUMORS_FROM_THE_WEST)

        local missionStatus = p:getMissionStatus(xi.mission.log_id.SOA)
        missionStatus = utils.mask.setBit(missionStatus, 0, true)
        missionStatus = utils.mask.setBit(missionStatus, 1, true)
        p:setMissionStatus(xi.mission.log_id.SOA, missionStatus)
        p:completeMission(xi.mission.log_id.SOA, xi.mission.id.soa.RUMORS_FROM_THE_WEST)

        return p
    end

    -- Heaven's Tower carries a cutscene-only duplicate of its NPCs at a lower id than the real
    -- one, and a name lookup finds the duplicate first. The second result is the one that talks.
    local function realEntityId(zone, name)
        local found = zone:queryEntitiesByName(name)

        return found[#found]:getID()
    end

    before_each(function()
        player = spawnCitizenOf(xi.nation.SANDORIA)
    end)

    it('refuses anyone below rank 3', function()
        player:setRank(2)

        player:gotoZone(xi.zone.NORTHERN_SAN_DORIA)
        player.entities:gotoAndTrigger('Excenmille', { eventId = 29 })

        player.assert.no:hasKI(xi.ki.BALLISTA_LICENSE)
    end)

    it('hands over both letters when the offer is accepted', function()
        player:gotoZone(xi.zone.NORTHERN_SAN_DORIA)
        player.entities:gotoAndTrigger('Excenmille', { eventId = 36, finishOption = 1 })

        player.assert:hasKI(xi.ki.LETTER_TO_THE_BAS_CONFLICT_CMD1)
        player.assert:hasKI(xi.ki.LETTER_TO_THE_WIN_CONFLICT_CMD1)
    end)

    it('keeps the letters when the offer is declined', function()
        player:gotoZone(xi.zone.NORTHERN_SAN_DORIA)
        player.entities:gotoAndTrigger('Excenmille', { eventId = 36, finishOption = 0 })

        player.assert.no:hasKI(xi.ki.LETTER_TO_THE_BAS_CONFLICT_CMD1)

        -- Declining is remembered, so the second conversation is the shorter one.
        player.entities:gotoAndTrigger('Excenmille', { eventId = 31 })
    end)

    -- The San d'Orian leader has one cutscene for his own citizens and one for everyone else, and
    -- the quest previously sent Bastokans to an event that does not exist in the zone at all.
    it('receives a citizen of another nation at the San dOrian leader', function()
        local bastokan = spawnCitizenOf(xi.nation.BASTOK)

        bastokan:gotoZone(xi.zone.METALWORKS)
        bastokan.entities:gotoAndTrigger('Invincible_Shield', { eventId = 813, finishOption = 1 })

        bastokan.assert:hasKI(xi.ki.LETTER_TO_THE_SAN_CONFLICT_CMD1)

        -- gotoAndTrigger asserts which event came back, so this is the whole point. A capture of a
        -- Bastokan run has this door open 71, one per nation, not the shared 72 the local event
        -- dump implies by listing only 70 and 72 for this actor.
        bastokan:gotoZone(xi.zone.CHATEAU_DORAGUILLE)
        bastokan.entities:gotoAndTrigger('_6h4', { eventId = 71 })
    end)

    it('walks a San d\'Orian through to the licence', function()
        player:gotoZone(xi.zone.NORTHERN_SAN_DORIA)
        player.entities:gotoAndTrigger('Excenmille', { eventId = 36, finishOption = 1 })

        -- Bastok: the leader receives them, then the director takes the letter.
        player:gotoZone(xi.zone.METALWORKS)
        player.entities:gotoAndTrigger('_6ld', { eventId = 828 })
        player.entities:gotoAndTrigger('Invincible_Shield', { eventId = 821 })

        player.assert.no:hasKI(xi.ki.LETTER_TO_THE_BAS_CONFLICT_CMD1)

        -- Windurst, where both NPCs have a cutscene-only duplicate.
        player:gotoZone(xi.zone.HEAVENS_TOWER)

        local zone = player:getZone()
        player.entities:gotoAndTrigger(realEntityId(zone, 'Kupipi'), { eventId = 427 })
        player.entities:gotoAndTrigger(realEntityId(zone, 'Mhabi_Molkot'), { eventId = 421 })

        player.assert.no:hasKI(xi.ki.LETTER_TO_THE_WIN_CONFLICT_CMD1)

        -- Report back, then be received by their own leader.
        player:gotoZone(xi.zone.NORTHERN_SAN_DORIA)
        player.entities:gotoAndTrigger('Excenmille', { eventId = 33 })

        player:gotoZone(xi.zone.CHATEAU_DORAGUILLE)
        player.entities:gotoAndTrigger('_6h4', { eventId = 70 })

        -- The licence is issued on the third option.
        player:gotoZone(xi.zone.NORTHERN_SAN_DORIA)
        player.entities:gotoAndTrigger('Excenmille', { eventId = 32, finishOption = 3 })

        player.assert:hasKI(xi.ki.BALLISTA_LICENSE)
    end)
end)
