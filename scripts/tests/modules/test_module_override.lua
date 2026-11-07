-----------------------------------
-- Verifies the default 'test_module_override' module (listed in modules/init.txt)
-- still overrides xi.player.onGameIn, and that C++ calling that global through
-- luautils::callGlobal reaches the override rather than the original.
--
-- This is the module system's override plumbing end to end. If a change ever
-- caches global function lookups without invalidating them when an override is
-- applied, the override still applies but callGlobal keeps using the original,
-- and this test is what notices.
--
-- See: modules/custom/lua/test_module_override.lua
-----------------------------------
describe('Module: test_module_override', function()
    it('is loaded and has applied its override', function()
        assert(xi.testModuleOverride,
            'the test_module_override module did not load; is it listed in modules/init.txt?')

        assert(xi.player.onGameIn,
            'xi.player.onGameIn is missing, so there was nothing to override')
    end)

    it('runs the override when a character logs in through callGlobal', function()
        local before = xi.testModuleOverride.onGameInCalls

        xi.test.world:spawnPlayer()

        assert(xi.testModuleOverride.onGameInCalls > before,
            string.format(
                'xi.player.onGameIn override did not run (%d calls before, %d after). ' ..
                'The override applied, so callGlobal resolved the path to the original function.',
                before, xi.testModuleOverride.onGameInCalls))
    end)

    it('still calls through to super', function()
        local calls = xi.testModuleOverride.onGameInCalls
        assert(calls > 0, 'the override never ran, so super was never reached')

        assert(xi.testModuleOverride.superCalls == calls,
            string.format(
                'super() did not complete on every call (%d overrides, %d returned from super), ' ..
                'so the override replaced the original behaviour instead of wrapping it',
                calls, xi.testModuleOverride.superCalls))
    end)
end)
