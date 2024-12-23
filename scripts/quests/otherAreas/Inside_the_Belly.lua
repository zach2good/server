-----------------------------------
-- Inside the Belly
-----------------------------------
-- Log ID: 4, Quest ID: 17
-- !addquest 4 26
-- Zaldon  : !pos -11.810 -7.287 -6.742 248
-----------------------------------

local quest = Quest:new(xi.questLog.OTHER_AREAS, xi.quest.id.otherAreas.INSIDE_THE_BELLY)

quest.reward = {}

quest.sections =
{
    {
        check = function(player, status, vars)
            return status == xi.questStatus.QUEST_AVAILABLE and
                player:getQuestStatus(xi.questLog.OTHER_AREAS, xi.quest.id.otherAreas.THE_REAL_GIFT) == xi.questStatus.QUEST_COMPLETED and
                xi.crafting.getTotalSkill(player, xi.skill.FISHING) >= 30 and
                xi.settings.map.FISHING_ENABLE == true
        end,

        [xi.zone.SELBINA] =
        {
            ['Zaldon'] = quest:progressEvent(161),

            onEventFinish =
            {
                [161] = function(player, csid, option, npc)
                    quest:begin(player)
                end,
            },
        },
    },

    {
        check = function(player, status, vars)
            return (status == xi.questStatus.QUEST_ACCEPTED or status == xi.questStatus.QUEST_COMPLETED) and
                player:getQuestStatus(xi.questLog.OTHER_AREAS, xi.quest.id.otherAreas.THE_REAL_GIFT) == xi.questStatus.QUEST_COMPLETED and
                xi.crafting.getTotalSkill(player, xi.skill.FISHING) >= 30 and
                xi.settings.map.FISHING_ENABLE == true
        end,

        [xi.zone.SELBINA] =
        {
            ['Zaldon'] =
            {
                onTrade = function(player, npc, trade)
                end,

                onTrigger = function(player, npc)
                    local fishingSkill = xi.crafting.getTotalSkill(player, xi.skill.FISHING)

                    local tier = 4

                    if fishingSkill < 40 then
                        tier = 1
                    elseif fishingSkill < 50 then
                        tier = 2
                    elseif fishingSkill < 75 then
                        tier = 3
                    end

                    local csTier =
                    {
                        {
                            162,
                            xi.item.GIANT_CATFISH,
                            xi.item.DARK_BASS,
                            xi.item.OGRE_EEL,
                            xi.item.ZAFMLUG_BASS,
                        },

                        {
                            163,
                            xi.item.ZAFMLUG_BASS,
                            xi.item.GIANT_DONKO,
                            xi.item.BHEFHEL_MARLIN,
                            xi.item.BLADEFISH,
                            xi.item.SILVER_SHARK,
                        },

                        {
                            164,
                            xi.item.JUNGLE_CATFISH,
                            xi.item.GAVIAL_FISH,
                            xi.item.PIRARUCU,
                            xi.item.EMPEROR_FISH,
                            xi.item.MEGALODON,
                            xi.item.MORINABALIGI,
                        },

                        {
                            165,
                            xi.item.PTERYGOTUS,
                            xi.item.KALKANBALIGI,
                            xi.item.TAKITARO,
                            xi.item.SEA_ZOMBIE,
                            xi.item.TITANICTUS,
                            xi.item.TURNABALIGI,
                            xi.item.CAVE_CHERAX,
                            xi.item.TRICORN,
                        },
                    }

                    return player:startEvent(unpack(csTier[tier]))
                end,
            },

            onEventFinish =
            {
            },
        },
    },
}

return quest
