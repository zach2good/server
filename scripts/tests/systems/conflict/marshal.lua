-----------------------------------
-- Conflict (Ballista): the Marshal's point exchange.
--
-- Points buy a voucher, which is a key item. The voucher is spent automatically at the start of
-- the next match and becomes one temporary item.
--
-- Costs and the two level gates come from the Ffxiclopedia Ballista article. The client caps a
-- player at 2000 points and says so itself, which is why nothing here banks more than that.
-----------------------------------

describe('Conflict (Ballista) Marshal', function()
    ---@type CClientEntityPair
    local player

    local function startMatch(levelCap)
        local zone = player:getZone()

        zone:initializeConflict({
            team1    = xi.allegiance.SAN_DORIA,
            team2    = xi.allegiance.BASTOK,
            levelCap = levelCap or 0,
            length   = 60 * 24,
        })

        local conflict = zone:getConflict()

        conflict:addPlayer(player, 0)
        conflict:setState(xi.conflictState.PREPARING)
        conflict:setState(xi.conflictState.ACTIVE)

        return conflict
    end

    before_each(function()
        player = xi.test.world:spawnPlayer({ zone = xi.zone.JUGNER_FOREST, job = xi.job.WAR, level = 75 })
    end)

    it('takes the points and hands over the voucher', function()
        player:addCurrency('ballista_point', 100)

        local bought = xi.conflict.marshal.purchase(player, xi.keyItem.HI_POTION_VOUCHER)

        assert(bought, 'the purchase was refused')
        assert(player:hasKeyItem(xi.keyItem.HI_POTION_VOUCHER), 'the voucher was not handed over')
        assert(player:getCurrency('ballista_point') == 55, 'a Hi-Potion voucher costs 45 points')
    end)

    it('refuses a player who cannot afford it', function()
        player:addCurrency('ballista_point', 10)

        local bought, reason = xi.conflict.marshal.purchase(player, xi.keyItem.HI_POTION_VOUCHER)

        assert(not bought, 'a player who cannot pay was sold a voucher')
        assert(reason == xi.conflict.marshal.refusal.NOT_ENOUGH, 'the wrong refusal was given')
        assert(not player:hasKeyItem(xi.keyItem.HI_POTION_VOUCHER), 'the voucher was handed over anyway')
        assert(player:getCurrency('ballista_point') == 10, 'points were taken for a refused purchase')
    end)

    it('refuses a second voucher of the same type', function()
        player:addCurrency('ballista_point', 200)

        assert(xi.conflict.marshal.purchase(player, xi.keyItem.POTION_VOUCHER), 'setup: the first purchase failed')

        local bought, reason = xi.conflict.marshal.purchase(player, xi.keyItem.POTION_VOUCHER)

        assert(not bought, 'only one of each voucher may be held')
        assert(reason == xi.conflict.marshal.refusal.ALREADY_HELD, 'the wrong refusal was given')
        assert(player:getCurrency('ballista_point') == 185, 'the refused purchase still took points')
    end)

    -- Marshal event 26 gates exactly one item, on wearing a chevron rather than on any match cap.
    it('refuses the Catholicon to anyone without a chevron', function()
        player:addCurrency('ballista_point', 2000)

        local bought, reason = xi.conflict.marshal.purchase(player, xi.keyItem.CATHOLICON_VOUCHER)

        assert(not bought, 'the Catholicon needs a chevron')
        assert(reason == xi.conflict.marshal.refusal.NOT_ENTITLED, 'the wrong refusal was given')
    end)

    it('sells the Catholicon to a chevron wearer', function()
        player:addCurrency('ballista_point', 2000)
        player:addKeyItem(xi.keyItem.BRONZE_BALLISTA_CHEVRON)

        assert(xi.conflict.marshal.purchase(player, xi.keyItem.CATHOLICON_VOUCHER), 'a chevron wearer may buy it')
    end)

    it('asks nothing extra of the rest of the list', function()
        player:addCurrency('ballista_point', 2000)

        assert(xi.conflict.marshal.purchase(player, xi.keyItem.REVITALIZER_VOUCHER), 'a Revitalizer needs no chevron')
        assert(xi.conflict.marshal.purchase(player, xi.keyItem.ELIXIR_VOUCHER), 'nor does an Elixir')
    end)

    -- Marshal event 26 loads 10 into the voucher-count parameter of both the status line and the
    -- refusal, so the one-of-each rule is not the only ceiling.
    it('refuses an eleventh voucher', function()
        player:addCurrency('ballista_point', 2000)

        local bought = 0
        for _, entry in ipairs(xi.conflict.marshal.shop) do
            if xi.conflict.marshal.purchase(player, entry.keyItem) then
                bought = bought + 1
            end
        end

        assert(bought == xi.conflict.marshal.maxVouchers,
            'expected to stop at ' .. xi.conflict.marshal.maxVouchers .. ' vouchers, bought ' .. bought)

        assert(xi.conflict.marshal.heldVoucherCount(player) == xi.conflict.marshal.maxVouchers,
            'the player should be holding exactly the maximum')
    end)

    it('spends held vouchers into temporary items when the match starts', function()
        player:addCurrency('ballista_point', 200)

        assert(xi.conflict.marshal.purchase(player, xi.keyItem.POTION_VOUCHER), 'setup: the purchase failed')
        assert(xi.conflict.marshal.purchase(player, xi.keyItem.ETHER_VOUCHER), 'setup: the purchase failed')

        startMatch(0)

        assert(not player:hasKeyItem(xi.keyItem.POTION_VOUCHER), 'the voucher was not spent')
        assert(not player:hasKeyItem(xi.keyItem.ETHER_VOUCHER), 'the voucher was not spent')

        assert(player:hasItem(xi.item.POTION, xi.inv.TEMPITEMS), 'the Potion was not handed over')
        assert(player:hasItem(xi.item.ETHER, xi.inv.TEMPITEMS), 'the Ether was not handed over')
    end)

    it('keeps a voucher the match level cap does not admit', function()
        player:addCurrency('ballista_point', 2000)

        assert(xi.conflict.marshal.purchase(player, xi.keyItem.REVITALIZER_VOUCHER), 'setup: the purchase failed')

        startMatch(30)

        assert(player:hasKeyItem(xi.keyItem.REVITALIZER_VOUCHER), 'a voucher the match cannot admit should keep')
        assert(not player:hasItem(xi.item.REVITALIZER, xi.inv.TEMPITEMS), 'the match should not have admitted it')
    end)
end)
