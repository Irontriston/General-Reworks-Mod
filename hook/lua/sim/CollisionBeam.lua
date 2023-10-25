local OldBeam = CollisionBeam
local DefaultDamage = import("/lua/sim/defaultdamage.lua")
local ScenarioFramework = import("/lua/scenarioframework.lua")

---@class CollisionBeam : moho.CollisionBeamEntity
CollisionBeam = Class(OldBeam) {
    -- This is called when the collision beam hits something new. Because the beam
    -- is continuously detecting collisions it only executes this function when the
    -- thing it is touching changes. Expect Impacts with non-physical things like
    -- 'Air' (hitting nothing) and 'Underwater' (hitting nothing underwater).
    ---@param self CollisionBeam
    ---@param impactType ImpactType
    ---@param targetEntity? Unit | Prop
    OnImpact = function(self, impactType, targetEntity)
		if targetEntity and targetEntity.HitBox and impactType ~= 'Shield' then--Corrects issues involving hitboxes
			targetEntity = targetEntity.Owner
			local layer = targetEntity:GetCurrentLayer()
			if layer == 'Air' or layer == 'Orbit' then
				impactType = 'UnitAir'
			elseif layer == 'Land' or layer == 'Water' then
				impactType = 'Unit'
			elseif layer == 'Seabed' or layer == 'Sub' then
				impactType = 'UnitUnderwater'
			end
		end

        if impactType == 'Unit' or impactType == 'UnitAir' or impactType == 'UnitUnderwater' then
            if not self:GetLauncher() then
                return
            end

            self:ShowBeamSource(targetEntity)
        else
            self:HideBeamSource()
        end

        if not self.DamageTable then
            self:SetDamageTable()
        end

        local damageData = self.DamageTable

        -- Buffs (Stun, etc)
        if targetEntity and IsUnit(targetEntity) then
            self:DoUnitImpactBuffs(targetEntity)
        end

        -- Do Damage
        self:DoDamage({ Unit = self:GetLauncher(), Proj = self:GetEntityId() }, damageData, targetEntity)

        local ImpactEffects = {}
        local ImpactEffectScale = 1

        if impactType == 'Water' then
            ImpactEffects = self.FxImpactWater
            ImpactEffectScale = self.FxWaterHitScale
        elseif impactType == 'Underwater' or impactType == 'UnitUnderwater' then
            ImpactEffects = self.FxImpactUnderWater
            ImpactEffectScale = self.FxUnderWaterHitScale
        elseif impactType == 'Unit' then
            ImpactEffects = self.FxImpactUnit
            ImpactEffectScale = self.FxUnitHitScale
        elseif impactType == 'UnitAir' then
            ImpactEffects = self.FxImpactAirUnit
            ImpactEffectScale = self.FxAirUnitHitScale
        elseif impactType == 'Terrain' then
            ImpactEffects = self.FxImpactLand
            ImpactEffectScale = self.FxLandHitScale
        elseif impactType == 'Air' or impactType == 'Projectile' then
            ImpactEffects = self.FxImpactNone
            ImpactEffectScale = self.FxNoneHitScale
        elseif impactType == 'Prop' then
            ImpactEffects = self.FxImpactProp
            ImpactEffectScale = self.FxPropHitScale
        elseif impactType == 'Shield' then
            ImpactEffects = self.FxImpactShield
            ImpactEffectScale = self.FxShieldHitScale
        else
            LOG('*ERROR: CollisionBeam:OnImpact(): UNKNOWN TARGET TYPE ', repr(impactType))
        end

        self:CreateImpactEffects(self.Army, ImpactEffects, ImpactEffectScale)
        self:UpdateTerrainCollisionEffects(impactType)
    end,
}