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
		table.insert(self.Owner.HitBoxColls, {instigator, amount, vector, damageType} )
	end,
	
	--Handles regular collisions
    OnCollisionCheck = function(self, other, firingWeapon)
			-- bail out immediately
			if self.Owner.DisallowCollisions then
				return false
			end
			-- if we're allied, check if we allow allied collisions
			if self.Owner.Army == other.Army or IsAlly(self.Owner.Army, other.Army) then
				return other.CollideFriendly
			end
			-- check for exclusions from projectile perspective
			for k = 1, other.Blueprint.DoNotCollideListCount do
				if self.Owner.Blueprint.CategoriesHash[other.Blueprint.DoNotCollideList[k] ] then
					return false 
				end
			end
			-- check for exclusions from unit perspective
			for k = 1, self.Owner.Blueprint.DoNotCollideListCount do
				if other.Blueprint.CategoriesHash[self.Owner.Blueprint.DoNotCollideList[k] ] then
					return false
				end
			end
			return true
    end,
	
	--Handles Beam collisions
    OnCollisionCheckWeapon = function(self, firingWeapon)
       -- bail out immediately
        if self.Owner.DisallowCollisions then
            return false
        end
        -- if we're allied, check if we allow allied collisions
        if self.Owner.Army == firingWeapon.Army or IsAlly(self.Owner.Army, firingWeapon.Army) then
            return firingWeapon.Blueprint.CollideFriendly
        end
        return true
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
			for ind, HitBox in self.Blueprint.HitBoxes do
				if not self:IsValidBone(HitBox.Bone) then
					LOG('Error creating HitBox #'..ind..' in '..self.UnitId..': The given bone '..HitBox.Bone..' does not exist in the model. Can\'t create hitboxes based on non-existent bones.' )
				elseif HitBox.IsSphere and type(HitBox.Size) != 'number' then
					LOG('Error creating HitBox #'..ind..' in '..self.UnitId..': The given size argument needs to be a number for a spherical hitbox.')
				elseif not HitBox.IsSphere and type(HitBox.Size) != 'table' then
					LOG('Error creating HitBox #'..ind..' in '..self.UnitId..':  The given hitbox needs to be a three-long table for a rect prism hitbox.')
				--[[
				elseif HitBox.Offsets != 'table' or (#HitBox.Offsets) != 3 then
					LOG('Error creating HitBox #'..ind..' in '..self.UnitId..': The Offset argument is not the correct size. Fix it you moron.')
				--]]
				else
					local box = HitBoxExtender( {Owner = self,} )
					box:Create(self, HitBox.Bone, HitBox.IsSphere, HitBox.Size, HitBox.Offsets)
					self.Trash:Add(box)
				end
			end
			
		end
		self:ForkThread(self.update)
    end,

	update = function(self)
		while not self.Dead do
			local old = self.HitBoxColls
			self.HitBoxColls = {}
			local SameInstigator = false
			
			for ind, val in old do --Remove duplicates so AoE doesn't screw us over.
				SameInstigator = false
				for ind2, val2 in self.HitBoxColls do
					if val[1] == val2[1]  then
						SameInstigator = true
						break
					end
				end
				if not SameInstigator then
					table.insert(self.HitBoxColls, val)
				end
			end
			
			for i, Hit in self.HitBoxColls do
				self:DamageReference(unpack(Hit) )
			end
			self.HitBoxColls = {} --Resets the count so units don't continuously take damage
			WaitSeconds(0.1) --Prevents a freeze, bc that would be annoying to say the least.
		end
	end,

    ---Damage has been reworked completely here so no oldUnit linking.
    OnDamage = function(self, instigator, amount, vector, damageType)
		table.insert(self.HitBoxColls, {instigator, amount, vector, damageType} )
    end,
	--This will be the new 'Damage' function, just to weed out doubles.
	DamageReference = function(self, instigator, amount, vector, damageType)
        if not amount then --No fucking clue if this will help with the nil errors or not
			return
		end
		-- only applies to trees
        if damageType == "TreeForce" or damageType == "TreeFire" then 
            return 
        end
        if self.CanTakeDamage then
            self:DoOnDamagedCallbacks(instigator)
            if self:GetShieldType() == 'Personal' and self:ShieldIsOn() and not self.MyShield.Charging then
                self.MyShield:ApplyDamage(instigator, amount, vector, damageType)
            else
                self:DoTakeDamage(instigator, amount, vector, damageType)
            end
        end
	end,
	
    -- On killed: amended to tell us if  something goes wrong with the hitbox addons
    OnKilled = function(self, instigator, type, overkillRatio)
		oldUnit.OnKilled(self, instigator, type, overkillRatio)
		if self:IsBeingBuilt() and type ~= 'decay' then
			local str = instigator.UnitId or instigator.ProjectileId or 'nothing at all apparently..'
			WARN('Tried to build '..self.UnitId..', but was immediately killed by '..str..'.')
		end
    end,
}
