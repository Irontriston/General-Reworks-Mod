local oldProj = Projectile
local Utils = import('/lua/utilities.lua')
local CatUtils = import('/lua/sim/CategoryUtils.lua')

Projectile = ClassProjectile(oldProj) {--[[
	OnCreate = function(self, inWater)
		oldProj.OnCreate(self, inWater)
		if self.Blueprint.Physics.Lifetime then--Hopefully allows projectiles with long lifetime values to live to that values.
			self:SetLifetime(self.Blueprint.Physics.Lifetime)
		end
	end,--]]
	--Completely overriden bc integrating extra hitbox collisions is not possible through simple amendment.
    OnImpact = function(self, targetType, targetEntity)

        -- localize information for performance
        local position = self:GetPosition()
        local damageData = self.DamageData
        local radius = damageData.DamageRadius or 0

        local launcher = self.Launcher

        local blueprint = self.Blueprint
        local blueprintAudio = blueprint.Audio
        local blueprintDisplay = blueprint.Display
        local blueprintCategoriesHash = blueprint.CategoriesHash

        -- callbacks for launcher to have an idea what is going on for AIs
        if blueprintCategoriesHash['TACTICAL'] or blueprintCategoriesHash['STRATEGIC'] then

            -- we have a target, but got caught by terrain
            if targetType == 'Terrain' then
                if not IsDestroyed(launcher) then
                    launcher:OnMissileImpactTerrain(self:GetCurrentTargetPosition(), position)
                end

                -- we have a target, but got caught by an (unexpected) shield
            elseif targetType == 'Shield' then
                if not IsDestroyed(launcher) then
                    launcher:OnMissileImpactShield(self:GetCurrentTargetPosition(), targetEntity.Owner, position)
                end
            end
        end
		
		-- Changes the targettype to reflect a unit hit if an extra hitbox was hit.
		if targetEntity and targetEntity.HitBox and targetType ~= 'Shield' then
			targetEntity = targetEntity.Owner
			local layer = targetEntity:GetCurrentLayer()
			if layer == 'Air' or layer == 'Orbit' then
				targetType = 'UnitAir'
			elseif layer == 'Land' or layer == 'Water' then
				targetType = 'Unit'
			elseif layer == 'Seabed' or layer == 'Sub' then
				targetType = 'UnitUnderwater'
			end
		end
		
        -- Try to use the launcher as instigator first. If its been deleted, use ourselves (this projectile is still associated with an army)
        local instigator = launcher or self

        -- localize information for performance
        local vc = VectorCached
        vc[1], vc[2], vc[3] = EntityGetPositionXYZ(self)

        -- adjust the impact location based on the velocity of the thing we're hitting, this fixes a bug with damage being applied the tick after the collision
        -- is registered. As a result, the unit has moved one step ahead already, allowing it to 'miss' the area damage that we're trying to apply. Usually
        -- air units are affected by this, see also the pull request for a visual aid on this issue on Github
        if radius > 0 and targetEntity then
            if targetType == 'Unit' or targetType == 'UnitAir' then
                local vx, vy, vz = targetEntity:GetVelocity()
                vc[1] = vc[1] + vx
                vc[2] = vc[2] + vy
                vc[3] = vc[3] + vz
            elseif targetType == 'Shield' then
                local vx, vy, vz = targetEntity.Owner:GetVelocity()
                vc[1] = vc[1] + vx
                vc[2] = vc[2] + vy
                vc[3] = vc[3] + vz
            end
        end

        -- do the projectile damage
        self:DoDamage(instigator, damageData, targetEntity, vc)

        -- compute whether we should spawn additional effects for this
        -- projectile, there's always a 10% chance or if we're far away from
        -- the previous impact
        local dx = OnImpactPreviousX - vc[1]
        local dz = OnImpactPreviousZ - vc[3]
        local dsqrt = dx * dx + dz * dz
        local doEffects = Random() < 0.1 or dsqrt > radius

        -- do splat logic and knock over trees
        if radius > 0 and doEffects then

            -- update last position of known effects
            OnImpactPreviousX = vc[1]
            OnImpactPreviousZ = vc[3]

            -- knock over trees
            DamageArea(
                self, -- instigator
                vc, -- position
                0.75 * radius, -- radius
                1, -- damage amount
                'TreeForce', -- damage type
                false-- damage friendly flag
            )

            -- try and spawn in a splat
            if -- if we flat out hit the terrain
            targetType == "Terrain" or

                -- if we hit a unit that is on land
                (targetEntity and targetEntity.Layer == "Land")
            then
                -- choose a splat to spawn
                local splat = blueprintDisplay.ScorchSplat
                if not splat then
                    splat = ScorchSplatTextures[ ScorchSplatTexturesLookup[ScorchSplatTexturesLookupIndex] ]
                    ScorchSplatTexturesLookupIndex = ScorchSplatTexturesLookupIndex + 1
                    if ScorchSplatTexturesLookupIndex > ScorchSplatTexturesLookupCount then
                        ScorchSplatTexturesLookupIndex = 1
                    end
                end

                -- choose our radius to use
                local altRadius = blueprintDisplay.ScorchSplatSize
                if not altRadius then
                    local damageMultiplier = (0.01 * damageData.DamageAmount)
                    if damageMultiplier > 1 then
                        damageMultiplier = 1
                    end
                    altRadius = damageMultiplier * radius
                end

                -- radius, lod and lifetime share the same rng adjustment
                local rngRadius = altRadius * Random()

                CreateSplat(
                -- position, orientation and the splat
                    vc, -- position
                    6.28 * Random(), -- heading
                    splat, -- splat

                    -- scale the splat, lod and duration randomly
                    0.75 * altRadius + 0.2 * rngRadius, -- size x
                    0.75 * altRadius + 0.2 * rngRadius, -- size z
                    10 + 30 * altRadius + 30 * rngRadius, -- lod
                    8 + 8 * altRadius + 8 * rngRadius, -- duration
                    self.Army-- owner of splat
                )
            end
        end

        -- Buffs (Stun, etc)
        self:DoUnitImpactBuffs(targetEntity)

        -- Sounds for all other impacts, ie: Impact<TargetTypeName>
        local snd = blueprintAudio['Impact' .. targetType]
        if snd then
            self:PlaySound(snd)
        elseif blueprintAudio.Impact then
            self:PlaySound(blueprintAudio.Impact)
        end

        -- Possible 'target' values are:
        --  'Unit'
        --  'Terrain'
        --  'Water'
        --  'Air'
        --  'Prop'
        --  'Shield'
        --  'UnitAir'
        --  'UnderWater'
        --  'UnitUnderwater'
        --  'Projectile'
        --  'ProjectileUnderWater
        local impactEffects
        local impactEffectsScale = 1

        if targetType == 'Terrain' then
            impactEffects = self.FxImpactLand
            impactEffectsScale = self.FxLandHitScale
        elseif targetType == 'Water' then
            impactEffects = self.FxImpactWater
            impactEffectsScale = self.FxWaterHitScale
        elseif targetType == 'Unit' then
            impactEffects = self.FxImpactUnit
            impactEffectsScale = self.FxUnitHitScale
        elseif targetType == 'UnitAir' then
            impactEffects = self.FxImpactAirUnit
            impactEffectsScale = self.FxAirUnitHitScale
        elseif targetType == 'Shield' then
            impactEffects = self.FxImpactShield
            impactEffectsScale = self.FxShieldHitScale
        elseif targetType == 'Air' then
            impactEffects = self.FxImpactNone
            impactEffectsScale = self.FxNoneHitScale
        elseif targetType == 'Projectile' then
            impactEffects = self.FxImpactProjectile
            impactEffectsScale = self.FxProjectileHitScale
        elseif targetType == 'ProjectileUnderwater' then
            impactEffects = self.FxImpactProjectileUnderWater
            impactEffectsScale = self.FxProjectileUnderWaterHitScale
        elseif targetType == 'Underwater' or targetType == 'UnitUnderwater' then
            impactEffects = self.FxImpactUnderWater
            impactEffectsScale = self.FxUnderWaterHitScale
        elseif targetType == 'Prop' then
            impactEffects = self.FxImpactProp
            impactEffectsScale = self.FxPropHitScale
        else
            LOG('*ERROR: Projectile:OnImpact(): UNKNOWN TARGET TYPE ', repr(targetType))
        end

        if impactEffects then
            -- impact effects, always make these
            self:CreateImpactEffects(self.Army, impactEffects, impactEffectsScale)
        end

        -- terrain effects, only make these when they're relatively unique
        if doEffects then
            -- do the terrain effects
            local blueprintDislayImpactEffects = blueprintDisplay.ImpactEffects
            local terrainEffects = self:GetTerrainEffects(targetType, blueprintDislayImpactEffects.Type, vc)
            if terrainEffects then
                self:CreateTerrainEffects(self.Army, terrainEffects, blueprintDislayImpactEffects.Scale or 1)
            end
        end

        self:OnImpactDestroy(targetType, targetEntity)
    end,
	
	OnLostTarget = function(self)
		local bp = self.Blueprint.Physics
		oldProj.OnLostTarget(self)
		if bp.SearchRadius and bp.SearchCategories then
			self:ForkThread(self.GetNewTarget)
		end
	end,
	
	GetNewTarget = function(self)
		local bp = self.Blueprint.Physics
		local SearchCats = CatUtils.ParseEntityCategoryProperly(bp.SearchCategories)
		while not self:GetTrackingTarget() do
			local Position = self:GetPosition()
			local entities = Utils.GetTrueEnemyUnitsInSphere(self.Launcher, Position, bp.SearchRadius,  SearchCats)
			local FinalTarget = nil
			if entities then
				local Distance = 1000000 --Gaurantees that unless you decide to some batshit insane stuff, the proj will always find a target if one exists in it's sphere.
				local newEnts = {}
				if bp.SearchLayers then
					for _, entity in entities do
						if table.find(bp.SearchLayers, entity:GetCurrentLayer() ) then
							table.insert(newEnts, entity)
						end
					end
				else
					newEnts = entities
				end
				if newEnts ~= {} then
					for _, entity in newEnts do
						local Length = VDist3(Position, entity:GetPosition() )
						if Length < Distance then
							Distance = Length
							FinalTarget = entity
						end
					end
				end
			end
			if FinalTarget then
				self:SetNewTarget(FinalTarget)
				self:TrackTarget(true)
				self:SetLifetime(bp.Lifetime)
				break
			end
			WaitSeconds(0.1)
		end
	end,
}