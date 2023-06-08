--------------------------------------------------------------------------
--  CYBRAN BRACKMAN "HACK PEG-POD" PROJECTILE
--------------------------------------------------------------------------
---@class CDFBrackmanHackPegProjectile01 : MultiPolyTrailProjectile
CDFBrackmanHackPegProjectile01 = Class(MultiPolyTrailProjectile) {
    FxImpactTrajectoryAligned = false,
    PolyTrails = EffectTemplate.CBrackmanCrabPegPodTrails,
    PolyTrailOffset = {0,0},

    FxTrails = {},
    FxImpactUnit = {},
    FxImpactProp = {},
    FxImpactLand = {},
    FxTrailOffset = 0,
    FxImpactUnderWater = {},
}

--------------------------------------------------------------------------
--  CYBRAN BRACKMAN "HACK PEG" PROJECTILES
--------------------------------------------------------------------------
---@class CDFBrackmanHackPegProjectile02 : MultiPolyTrailProjectile
CDFBrackmanHackPegProjectile02 = Class(MultiPolyTrailProjectile) {
    FxImpactTrajectoryAligned = false,
    PolyTrails = EffectTemplate.CBrackmanCrabPegTrails,
    PolyTrailOffset = {0,0},

    FxTrails = {},
    FxImpactUnit = {},
    FxImpactProp = {},
    FxImpactLand = EffectTemplate.CBrackmanCrabPegHit01,
    FxTrailOffset = 0,
    FxImpactUnderWater = {},
}

---  CYBRAN MOLECULAR CANNON PROJECTILE
--- ACU
---@class CMolecularCannonProjectile : SinglePolyTrailProjectile
CMolecularCannonProjectile = ClassProjectile(SinglePolyTrailProjectile) {
    FxImpactTrajectoryAligned = false,
    PolyTrail = '/mods/GeneralReworks/effects/emitters/cybran_commander_cannon_polytrail.bp',
    FxTrails = EffectTemplate.CMolecularCannon01,
    FxImpactUnit = EffectTemplate.CMolecularRipperHit01,
    FxImpactProp = EffectTemplate.CMolecularRipperHit01,
    FxImpactLand = EffectTemplate.CMolecularRipperHit01,
}