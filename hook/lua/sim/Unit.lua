local oldUnit = Unit
--This is responsible for the extra hitboxes that units can have now.
HitBoxExtender = Class(import('/lua/sim/Entity.lua').Entity) {
	Create = function(self, Owner, Bone, IsSphere, Size, Offsets)
		self.Owner = Owner
		self.HitBox = true
		self:AttachBoneTo(-1, self.Owner, Bone)
		if IsSphere then
			self:SetCollisionShape('Sphere', Offsets[1], Offsets[2], Offsets[3], Size)
		else
			self:SetCollisionShape('Box', Offsets[1], Offsets[2], Offsets[3], Size[1], Size[2], Size[3])
		end
	end,

	--Just passes off the damage info to the owner, aka the unit it's attached to, via a table of the values.
	OnDamage = function(self, instigator, amount, vector, damageType)
		self.Owner:AddDamage(instigator, amount, vector, damageType)
	end,
	
	--Handles regular collisions
    OnCollisionCheck = function(self, other, firingWeapon)
		return self.Owner:OnCollisionCheck(other, firingWeapon)
    end,--Just simplified both of these to just call the owning unit's functions.
	
	--Handles Beam collisions
    OnCollisionCheckWeapon = function(self, firingWeapon)
        return self.Owner:OnCollisionCheckWeapon(firingWeapon)
    end,
}

local cUnit = moho.unit_methods
---@class Unit : moho.unit_methods, InternalObject, IntelComponent, VeterancyComponent
---@field Brain AIBrain
---@field Blueprint UnitBlueprint
---@field Trash TrashBag
---@field Layer Layer
---@field Army Army
---@field UnitId UnitId
---@field EntityId EntityId
---@field EventCallbacks table<string, function[]>
---@field Buffs {Affects: table<BuffEffectName, BlueprintBuff.Effect>, buffTable: table<string, table>}
---@field EngineFlags? table<string, any>
---@field TerrainType TerrainType
---@field EngineCommandCap? table<string, boolean>
---@field UnitBeingBuilt Unit?
---@field SoundEntity? Unit | Entity
Unit = ClassUnit(oldUnit) {
    ---@param self Unit
    OnCreate = function(self)
		oldUnit.OnCreate(self)
		self.HitBoxExts = {} -- These two deal with extra hitboxes and their collisions
		self.HitBoxColls = {} -- Moved them here to hopefully help with issues
		--Create Extra hitboxes according to the blueprint
		if self.Blueprint.HitBoxes then
			--self:SetCollisionShape('Sphere', 0, 0, 0, 0) --Having to use this bc Apparently 'None' makes units stop targetting eachother entirely.
			for ind, HitBox in self.Blueprint.HitBoxes do
				if not self:IsValidBone(HitBox.Bone) then
					LOG('Error creating HitBox #'..ind..' in '..self.UnitId..': The given bone '..HitBox.Bone..' does not exist in the model. Can\'t create hitboxes based on non-existent bones.' )
				elseif HitBox.IsSphere and type(HitBox.Size) != 'number' then
					LOG('Error creating HitBox #'..ind..' in '..self.UnitId..': The given size argument needs to be a number for a spherical hitbox.')
				elseif not HitBox.IsSphere and type(HitBox.Size) != 'table' then
					LOG('Error creating HitBox #'..ind..' in '..self.UnitId..':  The given hitbox needs to be a three-long table for a rect prism hitbox.')
				else
					local box = HitBoxExtender( {Owner = self} ):Create(self, HitBox.Bone, HitBox.IsSphere, HitBox.Size, HitBox.Offsets)
					self.Trash:Add(box)
				end
			end
		end
		self:ForkThread(self.update)
    end,

	update = function(self)
		while not self.Dead do
			WaitSeconds(0.1) --Prevents a freeze, bc that would be annoying to say the least.
			local old = self.HitBoxColls
			self.HitBoxColls = {}
			local SameInstigator = false
			for ind, val in old do --Remove duplicates so AoE doesn't screw us over.
				SameInstigator = false
				for ind2, val2 in self.HitBoxColls do
					if not (val.instigator.Proj or val2.instigator.Proj) then
						if val.instigator.Unit == val2.instigator.Unit then
							SameInstigator = true
							break
						end
					end
					if val.instigator.Proj == val2.instigator.Proj  then
						SameInstigator = true
						break
					end
				end
				if not SameInstigator then
					table.insert(self.HitBoxColls, val)
				end
			end
			for i, Hit in self.HitBoxColls do
				self:DamageReference(Hit.instigator, Hit.amount, Hit.vector, Hit.damageType)--Thanks to lua debauchery, I have to manually insert the contents in the correct order.
			end
			self.HitBoxColls = {} --Reset the list so units don't continuously take damage
		end
	end,
	
	--The two below are only hooked to change the DamageArea funcs to the new one.
    DeathWeaponDamageThread = function(self, damageRadius, damage, damageType, damageFriendly)
        WaitSeconds(0.1)
        DamageArea({Unit = self, Proj = 'Death'}, self:GetPosition(), damageRadius or 1, damage or 1, damageType or 'Normal', damageFriendly or false)
        DamageArea({Unit = self, Proj = 'Death'}, self:GetPosition(), damageRadius or 1, 1, 'TreeForce', false)
    end,
	
	OnAnimCollision = function(self, bone, x, y, z)
        local layer = self.Layer
        local blueprintMovementEffects = self.Blueprint.Display.MovementEffects
        local movementEffects = blueprintMovementEffects and blueprintMovementEffects[layer] and blueprintMovementEffects[layer].Footfall

        if movementEffects then
            local effects = {}
            local scale = 1
            local offset
            local boneTable

            if movementEffects.Damage then
                local bpDamage = movementEffects.Damage
                DamageArea({Unit = self, Proj = 'AnimCollision'}, self:GetPosition(bone), bpDamage.Radius, bpDamage.Amount, bpDamage.Type, bpDamage.DamageFriendly)
            end

            if movementEffects.CameraShake then
                local shake = movementEffects.CameraShake
                self:ShakeCamera(shake.Radius, shake.MaxShakeEpicenter, shake.MinShakeAtRadius, shake.Interval)
            end

            for _, v in movementEffects.Bones do
                if bone == v.FootBone then
                    boneTable = v
                    bone = v.FootBone
                    scale = boneTable.Scale or 1
                    offset = bone.Offset
                    if v.Type then
                        effects = self.GetTerrainTypeEffects('FXMovement', layer, self:GetPosition(v.FootBone), v.Type)
                    end

                    break
                end
            end

            if boneTable.Tread and self:GetTTTreadType(self:GetPosition(bone)) ~= 'None' then
                CreateSplatOnBone(self, boneTable.Tread.TreadOffset, 0, boneTable.Tread.TreadMarks, boneTable.Tread.TreadMarksSizeX, boneTable.Tread.TreadMarksSizeZ, 100, boneTable.Tread.TreadLifeTime or 15, self.Army)
                local treadOffsetX = boneTable.Tread.TreadOffset[1]
                if x and x > 0 then
                    if layer ~= 'Seabed' then
						self:PlayUnitSound('FootFallLeft')
                    else
                        self:PlayUnitSound('FootFallLeftSeabed')
                    end
                elseif x and x < 0 then
                    if layer ~= 'Seabed' then
						self:PlayUnitSound('FootFallRight')
                    else
                        self:PlayUnitSound('FootFallRightSeabed')
                    end
                end
            end

            for k, v in effects do
                CreateEmitterAtBone(self, bone, self.Army, v):ScaleEmitter(scale):OffsetEmitter(offset.x or 0, offset.y or 0, offset.z or 0)
            end
        end

        if layer ~= 'Seabed' then
            self:PlayUnitSound('FootFallGeneric')
        else
            self:PlayUnitSound('FootFallGenericSeabed')
        end
    end,
	
	AddDamage = function(self, Ininstigator, Inamount, Invector, IndamageType)
		table.insert(self.HitBoxColls, {instigator = Ininstigator, amount = Inamount, vector = Invector, damageType = IndamageType} )
	end,
    ---Damage has been reworked completely here so it's just this now.
    OnDamage = function(self, instigator, amount, vector, damageType)
		self:AddDamage(instigator, amount, vector, damageType)--Soon to be commented.
    end,
	--This will be the new 'Damage' function, just to help weed out doubles.
	DamageReference = function(self, instigator, amount, vector, damageType)
        if not amount then --Somewhere the damage was discarded. Not sure if I need to keep this since It's not been called at all in a good while.
			LOG('No damage here. Has damage amount been discarded somewhere?')
			return
		end
		-- only applies to trees
        if damageType == "TreeForce" or damageType == "TreeFire" then 
            return 
        end
        if self.CanTakeDamage then
            self:DoOnDamagedCallbacks(instigator.Unit)
            if self:GetShieldType() == 'Personal' and self:ShieldIsOn() and not self.MyShield.Charging then
                self.MyShield:ApplyDamage(instigator.Unit, amount, vector, damageType)
            else
                self:DoTakeDamage(instigator, amount, vector, damageType)
            end
        end
	end,
	DoTakeDamage = function(self, instigator, amount, vector, damageType)
		--[[LOG('{ DamageCall instigator')
		LOG(reprsl(instigator))
		LOG('}')]]
        VeterancyComponent.DoTakeDamage(self, instigator.Unit or instigator, amount, vector, damageType)
        local preAdjHealth = self:GetHealth()
        self:AdjustHealth(instigator.Unit or instigator, -amount)
        local health = self:GetHealth()
        if health < 1 then
            -- this if statement is an issue too
            if damageType == 'Reclaimed' then
                self:Destroy()
            else
                local excessDamageRatio = 0.0
                -- Calculate the excess damage amount
                local excess = preAdjHealth - amount
                local maxHealth = self:GetMaxHealth()
                if excess < 0 and maxHealth > 0 then
                    excessDamageRatio = -excess / maxHealth
                end

                if not EntityCategoryContains(categories.VOLATILE, self) then
                    self:SetReclaimable(false)
                end
                self:Kill(instigator.Unit or instigator, damageType, excessDamageRatio)--Will self.Kill accept a table?
            end
        end
	end,
}
