-----------------------------------
-- Engine to Lua bridge for the Conflict (Ballista) system.
--
-- luautils::Conflict* resolves these by name off the xi.conflict table and calls them. Eden
-- returns a local `this` table that its engine resolves per file; our loader requires globals, so
-- the entry points are assigned onto xi.conflict directly.
--
-- Each wrapper stays thin and delegates to the gameplay implementation. A hook whose
-- implementation has not been ported yet is simply absent here, and the engine treats a missing
-- entry point as a no-op.
-----------------------------------
require('scripts/globals/conflict/core')
require('scripts/globals/conflict/marshal')
require('scripts/globals/conflict/pursuivant')
require('scripts/globals/conflict/quarry')
require('scripts/globals/conflict/rook')
require('scripts/globals/conflict/timeline')
require('scripts/globals/conflict/utils')
require('scripts/globals/conflict/zoneinfo')

xi = xi or {}
xi.conflict = xi.conflict or {}

-- The rook gate stands open while only one side has players present, so there is nobody to
-- contest a throw.
local rookOpenAnimation   = 34
local rookClosedAnimation = 0

xi.conflict.getRookIds = function(conflict, count)
    local rooks = xi.conflict.getRookEntities(conflict:getZone())

    local ids = {}
    for i = 1, math.min(count, #rooks) do
        table.insert(ids, rooks[i]:getID())
    end

    return ids
end

xi.conflict.onConflictQuarry = function(player)
    return xi.conflict.quarry(player)
end

-- A scheduled match runs the full Herald sign-up timeline. An ad-hoc match, the kind a script or
-- a GM command starts, skips straight to play and schedules nothing.
xi.conflict.setupConflict = function(conflict, isScheduled)
    if isScheduled then
        return xi.conflict.setupBallistaSignupTimeline(conflict)
    end
end

xi.conflict.cleanupConflict = function(conflict)
    return xi.conflict.cleanup(conflict)
end

xi.conflict.showGameHint = function(player)
    return xi.conflict.gameHint(player)
end

xi.conflict.onConflictGateBreach = function(entry, timeline, shortGateBreach, alreadyHadGateBreach)
    return xi.conflict.onGateBreach(entry, timeline, shortGateBreach, alreadyHadGateBreach)
end

-- The engine has already revived the player; the camp position is zone data, so the move and the
-- covering Invisible happen here.
xi.conflict.onReraise = function(player)
    return xi.conflict.reraiseAtCamp(player)
end

-- distributeInitialItems is deliberately absent: the engine resolves it on the implementation
-- name in quarry.lua, and a wrapper here would collide with it on the one xi.conflict table.

xi.conflict.marshalRedeemVouchers = function(player, levelCap)
    return xi.conflict.marshal.redeemVouchers(player, levelCap)
end

xi.conflict.updateRookState = function(conflict, shouldBeOpen)
    local rooks     = xi.conflict.getRookEntities(conflict:getZone())
    local animation = shouldBeOpen and rookOpenAnimation or rookClosedAnimation

    for i = 1, math.min(conflict:getRookCount(), #rooks) do
        rooks[i]:setAnimation(animation)
    end
end
