-----------------------------------
--  Plague Breath
--  Description: Deals water damage to enemies within a fan-shaped area originating from the caster. Additional effect: Poison.
--  Type: Magical Water (Element)
-----------------------------------
---@type TMobSkill
local mobskillObject = {}

mobskillObject.onMobSkillCheck = function(target, mob, skill)
    return 0
end

mobskillObject.onMobWeaponSkill = function(target, mob, skill)
    local power = mob:getMainLvl() / 4 + 1

    xi.mobskills.mobStatusEffectMove(mob, target, xi.effect.POISON, power, 3, 60)

    local dmgmod = xi.mobskills.mobBreathMove(mob, target, skill, 0.1, 2, xi.element.WATER, 250)

    local dmg = xi.mobskills.mobFinalAdjustments(dmgmod, mob, skill, target, xi.attackType.BREATH, xi.damageType.WATER, xi.mobskills.shadowBehavior.IGNORE_SHADOWS)
    target:takeDamage(dmg, mob, xi.attackType.BREATH, xi.damageType.WATER)
    return dmg
end

return mobskillObject
