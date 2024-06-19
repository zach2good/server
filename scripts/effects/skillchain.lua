-----------------------------------
-- xi.effect.SKILLCHAIN
-----------------------------------
---@type TEffect
local effectObject = {}

effectObject.onEffectGain = function(target, effect)
end

effectObject.onEffectTick = function(target, effect)
end

effectObject.onEffectLose = function(target, effect)
    target:setMod(xi.mod.SENGIKORI_DEBUFF, 0)
end

return effectObject
