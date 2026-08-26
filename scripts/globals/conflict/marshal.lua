-----------------------------------
-- Conflict (Ballista): the Marshal.
--
-- The Marshal takes Ballista Points for vouchers. A voucher is a key item that is spent
-- automatically at the start of the next match, turning into one temporary item.
--
-- Every cost below is read out of the client: Marshal event 26 carries the exchange table as
-- twenty-three rows of item, voucher key item and price. Ffxiclopedia lists two further rows,
-- Max-Potion and Hi-Elixir, which the client's table does not have.
--
-- The Marshal also runs the previous match MVP board and Ballista Point Ranking. Neither is
-- implemented: both need match history this server does not keep, and the option values that
-- drive them are not confirmed.
-----------------------------------

require('scripts/globals/conflict/ranking')
require('scripts/globals/conflict/zoneinfo')

xi = xi or {}
xi.conflict = xi.conflict or {}

xi.conflict.marshal = xi.conflict.marshal or {}

-- The client refuses to bank more than this, and says so itself in message 7523.
xi.conflict.marshal.maxPoints = 2000

-- Marshal event 26 loads 10 into the voucher-count parameter for both message 7525 and the
-- refusal at 7535, so this is a hard ceiling on top of the one-of-each-type rule.
xi.conflict.marshal.maxVouchers = 10

-- levelCap is the lowest match cap that will hand this voucher over. Ffxiclopedia annotates two
-- restoratives that way, and redemption is where it belongs: Marshal event 26 has no cap check at
-- all when buying. What it does have is one entitlement, on the Catholicon, gated on wearing a
-- chevron: "I see that you are wearing $6. Ballista point exchange authorization has been
-- granted", against "You have not earned the right to exchange your points for that item".
xi.conflict.marshal.shop =
{
    { keyItem = xi.keyItem.POTION_VOUCHER,               item = xi.item.POTION,                        cost = 15 },
    { keyItem = xi.keyItem.HI_POTION_VOUCHER,            item = xi.item.HI_POTION,                     cost = 45 },
    { keyItem = xi.keyItem.X_POTION_VOUCHER,             item = xi.item.X_POTION,                      cost = 90 },
    { keyItem = xi.keyItem.ETHER_VOUCHER,                item = xi.item.ETHER,                         cost = 20 },
    { keyItem = xi.keyItem.HI_ETHER_VOUCHER,             item = xi.item.HI_ETHER,                      cost = 60 },
    { keyItem = xi.keyItem.SUPER_ETHER_VOUCHER,          item = xi.item.SUPER_ETHER,                   cost = 120 },
    { keyItem = xi.keyItem.ELIXIR_VOUCHER,               item = xi.item.ELIXIR,                        cost = 200, levelCap = 50 },
    { keyItem = xi.keyItem.REVITALIZER_VOUCHER,          item = xi.item.REVITALIZER,                   cost = 700, levelCap = 60 },
    { keyItem = xi.keyItem.BODY_BOOST_VOUCHER,           item = xi.item.BOTTLE_OF_BODY_BOOST,          cost = 300 },
    { keyItem = xi.keyItem.MANA_BOOST_VOUCHER,           item = xi.item.BOTTLE_OF_MANA_BOOST,          cost = 300 },
    { keyItem = xi.keyItem.DRACHENESSENCE_VOUCHER,       item = xi.item.VIAL_OF_DRACHENESSENCE,        cost = 30 },
    { keyItem = xi.keyItem.BARFIRE_OINTMENT_VOUCHER,     item = xi.item.DOSE_OF_BARFIRE_OINTMENT,      cost = 50 },
    { keyItem = xi.keyItem.BARBLIZZARD_OINTMENT_VOUCHER, item = xi.item.DOSE_OF_BARBLIZZARD_OINTMENT,  cost = 50 },
    { keyItem = xi.keyItem.BARAERO_OINTMENT_VOUCHER,     item = xi.item.DOSE_OF_BARAERO_OINTMENT,      cost = 50 },
    { keyItem = xi.keyItem.BARSTONE_OINTMENT_VOUCHER,    item = xi.item.DOSE_OF_BARSTONE_OINTMENT,     cost = 50 },
    { keyItem = xi.keyItem.BARTHUNDER_OINTMENT_VOUCHER,  item = xi.item.DOSE_OF_BARTHUNDER_OINTMENT,   cost = 50 },
    { keyItem = xi.keyItem.BARWATER_OINTMENT_VOUCHER,    item = xi.item.DOSE_OF_BARWATER_OINTMENT,     cost = 50 },
    { keyItem = xi.keyItem.PETRA_EATER_VOUCHER,          item = xi.item.PETRA_EATER,                   cost = 30 },
    { keyItem = xi.keyItem.REMEDY_VOUCHER,               item = xi.item.REMEDY,                        cost = 100 },
    { keyItem = xi.keyItem.PANACEA_VOUCHER,              item = xi.item.FLASK_OF_PANACEA,              cost = 200 },
    { keyItem = xi.keyItem.SMELLING_SALTS_VOUCHER,       item = xi.item.CHUNK_OF_SMELLING_SALTS,       cost = 75 },
    { keyItem = xi.keyItem.HEALING_POWDER_VOUCHER,       item = xi.item.FLASK_OF_HEALING_POWDER,       cost = 100 },

    -- Last in the client's own table, which pages this list fifteen at a time.
    { keyItem = xi.keyItem.CATHOLICON_VOUCHER,           item = xi.item.BOTTLE_OF_CATHOLICON,          cost = 100 },
}

xi.conflict.marshal.shopByKeyItem = {}
for _, entry in ipairs(xi.conflict.marshal.shop) do
    xi.conflict.marshal.shopByKeyItem[entry.keyItem] = entry
end

-- An uncapped match admits every voucher, so it sorts above every numbered cap.
local function meetsLevelCap(entry, levelCap)
    if entry.levelCap == nil then
        return true
    end

    if levelCap == 0 then
        return true
    end

    return levelCap >= entry.levelCap
end

xi.conflict.marshal.meetsLevelCap = meetsLevelCap

function xi.conflict.marshal.heldVoucherCount(player)
    local count = 0

    for _, entry in ipairs(xi.conflict.marshal.shop) do
        if player:hasKeyItem(entry.keyItem) then
            count = count + 1
        end
    end

    return count
end

-- Reasons a purchase can be refused, so the caller can pick the right line to say.
xi.conflict.marshal.refusal =
{
    UNKNOWN_ITEM  = 1,
    NOT_ENTITLED  = 2, -- 7529, you have not earned the right to that item
    NOT_ENOUGH    = 3,
    ALREADY_HELD  = 4,
    TOO_MANY      = 5,
}

-- The one item the Marshal will not sell to just anyone.
xi.conflict.marshal.entitledByChevron = { [xi.item.BOTTLE_OF_CATHOLICON] = true }

-- Returns true on success, or false and a refusal reason. The match's level cap does not come
-- into it: that decides what a match will hand over, which is redeemVouchers' business.
function xi.conflict.marshal.purchase(player, keyItem)
    local entry = xi.conflict.marshal.shopByKeyItem[keyItem]
    if entry == nil then
        return false, xi.conflict.marshal.refusal.UNKNOWN_ITEM
    end

    if xi.conflict.marshal.entitledByChevron[entry.item] then
        -- Holding the key item is not the same as being entitled: an expired chevron is one the
        -- Herald already wants back before the wearer enters another match.
        if
            xi.conflict.ranking.heldChevron(player) == nil or
            xi.conflict.ranking.hasExpiredChevron(player)
        then
            return false, xi.conflict.marshal.refusal.NOT_ENTITLED
        end
    end

    -- One of each type, on top of the total below.
    if player:hasKeyItem(entry.keyItem) then
        return false, xi.conflict.marshal.refusal.ALREADY_HELD
    end

    if xi.conflict.marshal.heldVoucherCount(player) >= xi.conflict.marshal.maxVouchers then
        return false, xi.conflict.marshal.refusal.TOO_MANY
    end

    if player:getCurrency('ballista_point') < entry.cost then
        return false, xi.conflict.marshal.refusal.NOT_ENOUGH
    end

    player:delCurrency('ballista_point', entry.cost)
    player:addKeyItem(entry.keyItem)

    return true
end

-- Spends every voucher the player holds, one temporary item each, at the start of a match. A
-- voucher whose item the match's level cap does not admit stays unspent for a later match.
function xi.conflict.marshal.redeemVouchers(player, levelCap)
    local redeemed = 0

    for _, entry in ipairs(xi.conflict.marshal.shop) do
        if player:hasKeyItem(entry.keyItem) and meetsLevelCap(entry, levelCap or 0) then
            if player:getFreeSlotsCount(xi.inv.TEMPITEMS) == 0 then
                break
            end

            -- The voucher is worth up to 700 Ballista Points, so it is only spent once the item
            -- it pays for is actually held. The one-of-each rule applies here as it does to a
            -- quarried item.
            if not player:hasItem(entry.item, xi.inv.TEMPITEMS) then
                player:addTempItem(entry.item)

                if player:hasItem(entry.item, xi.inv.TEMPITEMS) then
                    player:delKeyItem(entry.keyItem)

                    redeemed = redeemed + 1
                end
            end
        end
    end

    return redeemed
end
