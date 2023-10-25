-- upvalued to hook onto.
local OldDamage = Damage
local OldDamageArea = DamageArea
local OldDamageRing = DamageRing
local Utils = import('/lua/utilities.lua')
do --These hooked functions will hopefully help resolve issues with 'instigator'
	function _G.Damage(instigator, location, target, amount, damageType)
		local vect = Utils.GetDirectionVector(target:GetPosition(), location )
		if target then
			if target.UnitId or target.Hitbox then
				if type(instigator) ~= 'table' then
					instigator = {Unit = instigator, Proj = 'DiscardedOrNone'}
				end
				if target.Hitbox then target = target.Owner end
				target:AddDamage(instigator, amount, vect, damageType)
			else
				OldDamage(instigator.Unit or instigator, location, target, amount, damageType)
			end
		end
	end
end
Damage = _G.Damage
do
	function _G.DamageArea(instigator, location, radius, damage, damageType, damageFriendly, damageSelf)-- Since DamageArea and DamageRing can't take a table (an obvious limitation of C++), These two will have to remain as they are until I can develop an entirely new collision detection system.
		OldDamageArea(instigator.Unit or instigator, location, radius, damage, damageType, damageFriendly, damageSelf)--Projectiles that don't do AoE however, work perfectly as intended. : )
		--[[radius = radius*1.2
		local AttackArmy = instigator.Unit.Army or instigator.Proj.Army
		local Entities = Utils.GetEntitiesInRect( location[1]-radius, location[3]-radius, location[1]+radius, location[3]+radius)
		if Entities then
			for _, ent in Entities do
				local EntPos = ent:GetPosition()
				if VDist3(EntPos, location) <= radius then--Here primarily bc I'm lazy, but it also deals with possible issues with extreme elevation differences.
					local unit = nil
					if ent.IsUnit or ent.Owner then
						unit = ent.Owner or ent
					end
					if unit and (damageFriendly or (not damageFriendly and unit.Army ~=AttackArmy and not IsAlly(unit.Army, AttackArmy) ) ) then
						Damage(instigator, location, unit, damage, damageType)
					end
					if IsProp(ent) then
						Damage(instigator, location, ent, damage, damageType)
					end
				end
			end
		end]]
	end
	
	function _G.DamageRing(instigator, location, minRadius, maxRadius, damage, damageType, damageFriendly, damageSelf)
		OldDamageRing(instigator.Unit or instigator, location, minRadius, maxRadius, damage, damageType, damageFriendly, damageSelf)
		--[[minRadius = minRadius*0.84
		maxRadius = maxRadius*1.2
		local AttackArmy = instigator.Unit.Army or instigator.Proj.Army
		local Entities = Utils.GetEntitiesInRect( location[1]-maxRadius, location[3]-maxRadius, location[1]+maxRadius, location[3]+maxRadius)
		if Entities then
			for _, ent in Entities do
				local EntPos = ent:GetPosition()
				if VDist3(EntPos, location) <= maxRadius and VDist3(EntPos, location) >= minRadius then--Same explanation as in DamageArea.
					local unit = nil
					if ent.IsUnit or ent.Owner then
						unit = ent.Owner or ent
					end
					if unit and (damageFriendly or (not damageFriendly and unit.Army ~=AttackArmy and not IsAlly(unit.Army, AttackArmy) ) ) then
						Damage(instigator, location, unit, damage, damageType)
					end
					if IsProp(ent) then
						Damage(instigator, location, ent, damage, damageType )
					end
				end
			end
		end]]
	end
end
DamageArea = _G.DamageArea
--- Performs damage over time on a unit.
---@param instigator Unit
---@param unit Unit
---@param pulses any
---@param pulseTime integer
---@param damage number
---@param damType DamageType
---@param friendly boolean
function UnitDoTThread (instigator, unit, pulses, pulseTime, damage, damType, friendly)

    -- localize for performance
    local position = VectorCache
    local DamageArea = DamageArea
    local CoroutineYield = CoroutineYield

    -- convert time to ticks
    pulseTime = 10 * pulseTime + 1

    for i = 1, pulses do
        if unit and not EntityBeenDestroyed(unit) then
            position[1], position[2], position[3] = EntityGetPositionXYZ(unit)
            Damage(instigator, position, unit, damage, damType )
        else
            break
        end
        CoroutineYield(pulseTime)
    end
end

--- Performs damage over time in a given area.
---@param instigator Unit
---@param position number
---@param pulses any
---@param pulseTime integer
---@param radius number
---@param damage number
---@param damType DamageType
---@param friendly boolean
function AreaDoTThread (instigator, position, pulses, pulseTime, radius, damage, damType, friendly)

    -- localize for performance
    local DamageArea = DamageArea
    local CoroutineYield = CoroutineYield

    -- compute ticks between pulses
    pulseTime = 10 * pulseTime + 1

    for i = 1, pulses do
        DamageArea(instigator, position, radius, damage, damType, friendly)
        CoroutineYield(pulseTime)
    end
end

-- Basically a scalable DamageArea.
function ScalableRadiusAreaDoT(entity)
    local spec = entity.Spec.Data
    -- local position = entity:GetPosition()
    local position = entity.Spec.Position
    local radius = spec.StartRadius or 0
    local freq = spec.Frequency or 1
    local dur = spec.Duration or 1
    if dur != freq then
        local reductionScalar = (radius - (spec.EndRadius or 1) ) * freq / (dur - freq)
        local duration = math.floor(dur / freq)

        for i = 1, duration do
            DamageArea(entity, position, radius, spec.Damage, spec.Type, spec.DamageFriendly)
            radius = radius - reductionScalar
            WaitSeconds(freq)
        end
    end
    entity:Destroy()
end