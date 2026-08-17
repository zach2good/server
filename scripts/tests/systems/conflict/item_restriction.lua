-----------------------------------
-- Conflict (Ballista): the ban on a player's own items.
--
-- The Pashhow match bars a player's own items, which is why it hands out fifteen temporary slots
-- instead of ten. String 7258 offers three match styles and none of them is a restricted Best of
-- Three, and the 2005/02/24 update names Pashhow alone for the increase.
--
-- This drives the real 0x037 packet rather than the useItem binding, because the binding goes
-- straight to the AI container and never passes the handler that enforces this.
-----------------------------------

local ffi = require('ffi')

ffi.cdef [[
    typedef struct {
        uint16_t id : 9;
        uint16_t size : 7;
        uint16_t sync;
    } GP_CLI_HEADER_ITEM_USE;

    // 0x037 - Item use
    typedef struct {
        GP_CLI_HEADER_ITEM_USE header;
        uint32_t UniqueNo;
        uint32_t ItemNum;
        uint16_t ActIndex;
        uint8_t  PropertyItemIndex;
        uint8_t  padding00;
        uint32_t Category;
    } GP_CLI_COMMAND_ITEM_USE_TEST;
]]

describe('Conflict (Ballista) item restriction', function()
    ---@type CClientEntityPair
    local player

    -- A stack of potions, so there is something real to try to drink.
    local potion = 4148

    local function startMatch(restrictItems)
        local zone = player:getZone()

        zone:initializeConflict({
            team1        = xi.allegiance.SAN_DORIA,
            team2        = xi.allegiance.BASTOK,
            restrictItems = restrictItems,
            length       = 60 * 24,
        })

        local conflict = zone:getConflict()

        conflict:addPlayer(player, 0)
        conflict:setState(xi.conflictState.PREPARING)
        conflict:setState(xi.conflictState.ACTIVE)

        return conflict
    end

    local function tryUsingPotion()
        local item = player:findItem(potion, xi.inv.INVENTORY)
        assert(item ~= nil, 'setup: the potion was not in inventory')

        local slot = item:getSlotID()

        local p = ffi.new('GP_CLI_COMMAND_ITEM_USE_TEST')

        p.UniqueNo          = player:getID()
        p.ItemNum           = 0
        p.ActIndex          = player:getTargID()
        p.PropertyItemIndex = slot
        p.Category          = xi.inv.INVENTORY

        player.packets:send(0x037, p, ffi.sizeof(p))
    end

    -- The refusal is a battle message, so that is the only thing that separates a use that was
    -- turned away from one that was passed on. MessageNum sits at 0x18 of the 0x029 packet.
    local function wasRefused()
        for _, packet in ipairs(player.packets:getIncoming()) do
            if packet.type == 0x029 then
                local messageId = packet.data[0x18] + packet.data[0x19] * 256
                if messageId == 40 then -- MsgBasic::CannotInThisArea
                    return true
                end
            end
        end

        return false
    end

    before_each(function()
        player = xi.test.world:spawnPlayer({ zone = xi.zone.JUGNER_FOREST, job = xi.job.WAR, level = 75 })
        player:addItem(potion, 4)
    end)

    it('refuses a normal item during a restricted match', function()
        startMatch(true)

        player.packets:clear()
        tryUsingPotion()

        assert(wasRefused(), 'a restricted match should have turned the potion away')
        assert(player:hasItem(potion, xi.inv.INVENTORY), 'the potion should not have been consumed')
    end)

    it('allows a normal item when the match does not restrict them', function()
        startMatch(false)

        player.packets:clear()
        tryUsingPotion()

        assert(not wasRefused(), 'an unrestricted match should not turn the potion away')
    end)

    it('allows a temporary item even in a restricted match', function()
        startMatch(true)

        player:addTempItem(potion)

        local item = player:findItem(potion, xi.inv.TEMPITEMS)
        assert(item ~= nil, 'setup: the temporary potion was not stored')

        local p = ffi.new('GP_CLI_COMMAND_ITEM_USE_TEST')

        p.UniqueNo          = player:getID()
        p.ActIndex          = player:getTargID()
        p.PropertyItemIndex = item:getSlotID()
        p.Category          = xi.inv.TEMPITEMS

        player.packets:clear()
        player.packets:send(0x037, p, ffi.sizeof(p))

        assert(not wasRefused(), 'the restriction is on a player\'s own items, not the match\'s')
    end)

    it('gives fifteen temporary slots to a match that bars normal items', function()
        startMatch(true)

        assert(player:getFreeSlotsCount(xi.inv.TEMPITEMS) == 15, 'a restricted match carries fifteen temporary slots')
    end)

    -- A container refuses to shrink below what it holds, so arriving with a full temporary bag
    -- used to leave the match's allowance unapplied for the whole match.
    it('applies its allowance to a player arriving with temporary items', function()
        -- Distinct ids, because temporary storage holds only one of each type.
        local carried =
        {
            xi.item.HI_POTION, xi.item.X_POTION, xi.item.MAX_POTION, xi.item.HI_ETHER,
            xi.item.SUPER_ETHER, xi.item.PRO_ETHER, xi.item.HI_ELIXIR, xi.item.ELIXIR,
            xi.item.REMEDY, xi.item.PETRA_EATER, xi.item.BOTTLE_OF_CATHOLICON, xi.item.MEGALIXIR,
        }

        for _, itemId in ipairs(carried) do
            player:addTempItem(itemId)
        end

        local before = 50 - player:getFreeSlotsCount(xi.inv.TEMPITEMS)
        assert(before > 10, 'setup: the player should be carrying more than the match allows, got ' .. before)

        startMatch(false)

        -- The allowance cannot apply while the container still holds more than it, so the match
        -- empties it first. Ten free slots means both happened.
        assert(player:getFreeSlotsCount(xi.inv.TEMPITEMS) == 10, 'the match allowance should have taken effect')
    end)

    it('gives ten temporary slots to a match that allows them', function()
        startMatch(false)

        assert(player:getFreeSlotsCount(xi.inv.TEMPITEMS) == 10, 'an unrestricted match carries ten temporary slots')
    end)
end)
