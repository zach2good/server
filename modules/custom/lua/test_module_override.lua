-----------------------------------
-- Exercises the module system's override plumbing.
--
-- `test_npcs_in_gm_home` covers a module adding content. This one covers the
-- other half: `Module:addOverride` replacing an existing global function.
--
-- The target is deliberately a global that C++ reaches through
-- `luautils::callGlobal`, so the test covers the whole path:
--
--   1. the module system applies the override, and
--   2. callGlobal afterwards resolves to the override, not to whatever the
--      function was when the server first looked the path up.
--
-- Anything that memoises global function lookups has to drop what it holds when
-- an override is applied, or step 2 silently keeps using the original and every
-- module override on a callGlobal path stops working. That failure is invisible
-- without a test like this, because the override itself applies cleanly.
--
-- See: scripts/tests/modules/test_module_override.lua
-----------------------------------
require('modules/module_utils')
require('scripts/globals/player')
-----------------------------------
local m = Module:new('test_module_override')

-- Counters the test reads. Created at module load, before the override is applied.
xi                    = xi or {}
xi.testModuleOverride =
{
    onGameInCalls = 0,
    superCalls    = 0,
}

m:addOverride('xi.player.onGameIn', function(player, firstLogin, zoning)
    xi.testModuleOverride.onGameInCalls = xi.testModuleOverride.onGameInCalls + 1

    -- `super` is injected by applyOverride (modules/module_utils.lua). Counting
    -- after the call means a super that throws leaves the two counters unequal.
    local result = super(player, firstLogin, zoning)

    xi.testModuleOverride.superCalls = xi.testModuleOverride.superCalls + 1

    return result
end)
