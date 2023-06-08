-----------------------------------------------------------------
-- File     : /lua/defaultprojectiles.lua
-- Author(s): John Comes, Gordon Duclos
-- Summary  : Script for default projectiles
-- Copyright © 2005 Gas Powered Games, Inc.  All rights reserved.
-----------------------------------------------------------------

local Projectile = import('/lua/sim/Projectile.lua').Projectile
local DummyProjectile = import('/lua/sim/Projectile.lua').DummyProjectile
local UnitsInSphere = import('/lua/utilities.lua').GetTrueEnemyUnitsInSphere
local GetDistanceBetweenTwoEntities = import('/lua/utilities.lua').GetDistanceBetweenTwoEntities
local OCProjectiles = {}

-- shared between sim and ui
local OverchargeShared = import('/lua/shared/overcharge.lua')

-- upvalue globals for performance
local Random = Random
local CreateTrail = CreateTrail
local CreateEmitterOnEntity = CreateEmitterOnEntity
local CreateBeamEmitterOnEntity = CreateBeamEmitterOnEntity

local TableGetn = table.getn

local MathFloor = math.floor 

-- upvalue moho functions for performance
local IEffectScaleEmitter = _G.moho.IEffect.ScaleEmitter
local IEffectOffsetEmitter = _G.moho.IEffect.OffsetEmitter

-----------------------------------------------------------------
-- Null Shell
-----------------------------------------------------------------
---@class NullShell : Projectile
NullShell = Class(Projectile) {}

-----------------------------------------------------------------
-- PROJECTILE WITH ATTACHED EFFECT EMITTERS
-----------------------------------------------------------------
---@class EmitterProjectile : Projectile
EmitterProjectile = Class(Projectile) {
    FxTrails = {'/effects/emitters/missile_munition_trail_01_emit.bp',},
    FxTrailScale = 1,
    FxTrailOffset = 0,

    OnCreate = function(self)
        Projectile.OnCreate(self)

        local effect
        for i in self.FxTrails do
            effect = CreateEmitterOnEntity(self, self.Army, self.FxTrails[i])
            
            -- only do these engine calls when they matter
            if self.FxTrailScale ~= 1 then 
                IEffectScaleEmitter(effect, self.FxTrailScale)
            end
            
            if self.FxTrailOffset ~= 1 then 
                IEffectOffsetEmitter(effect, 0, 0, self.FxTrailOffset)
            end
        end
    end,
}

-----------------------------------------------------------------
-- BEAM PROJECTILES
-----------------------------------------------------------------
---@class SingleBeamProjectile : EmitterProjectile
SingleBeamProjectile = Class(EmitterProjectile) {

    BeamName = '/effects/emitters/default_beam_01_emit.bp',
    FxTrails = {},

    OnCreate = function(self)
        EmitterProjectile.OnCreate(self)

        if self.BeamName then
            CreateBeamEmitterOnEntity(self, -1, self.Army, self.BeamName)
        end
    end,
}

---@class MultiBeamProjectile : EmitterProjectile
MultiBeamProjectile = Class(EmitterProjectile) {

    Beams = {'/effects/emitters/default_beam_01_emit.bp',},
    FxTrails = {},

    OnCreate = function(self)
        EmitterProjectile.OnCreate(self)

        local beam = nil
        for k, v in self.Beams do
            CreateBeamEmitterOnEntity(self, -1, self.Army, v)
        end
    end,
}

-- Nukes
---@class NukeProjectile : NullShell
NukeProjectile = Class(NullShell) {
    MovementThread = function(self)
		self.Nuke = true
        self.CreateEffects(self, self.InitialEffects, self.Army, 1)
        self:TrackTarget(false)
        WaitSeconds(2) -- Height
        self:SetCollision(true)
        self.CreateEffects(self, self.LaunchEffects, self.Army, 1)
        WaitSeconds(1)
        self.CreateEffects(self, self.ThrustEffects, self.Army, 3)
        WaitSeconds(1)
        self:TrackTarget(true) -- Turn ~90 degrees towards target
        self:SetDestroyOnWater(true)
        self:SetTurnRate(30)
        WaitSeconds(3) -- Now set turn rate to zero so nuke flies straight
        self:SetTurnRate(0)
        self:SetAcceleration(0.2)
        self.WaitTime = 0.3
        while not self:BeenDestroyed() do
            self:SetTurnRateByDist()
            WaitSeconds(self.WaitTime)
        end
    end,

    SetTurnRateByDist = function(self)
        local dist = self:GetDistanceToTarget()
        -- Get the nuke as close to 90 deg as possible
        if dist > 250 then
            -- Freeze the turn rate as to prevent steep angles at long distance targets
            self:SetTurnRate(0)
        elseif dist > 150 then
            -- Increase check intervals
            self.WaitTime = 0.2
        elseif dist > 75 then
            -- Further increase check intervals
            self.WaitTime = 0.1
        elseif dist < 75 then
            -- Turn the missile down
            self:SetTurnRate(30)
        end
    end,

    GetDistanceToTarget = function(self)
        local tpos = self:GetCurrentTargetPosition()
        local mpos = self:GetPosition()
        local dist = VDist2(mpos[1], mpos[3], tpos[1], tpos[3])
        return dist
    end,

    CreateEffects = function(self, EffectTable, army, scale)
        if not EffectTable then return end
        for k, v in EffectTable do
            self.Trash:Add(CreateAttachedEmitter(self, -1, army, v):ScaleEmitter(scale))
        end
    end,

    ForceThread = function(self)
        -- Knockdown force rings
        local position = self:GetPosition()
        DamageRing(self, position, 0, 200, 40, 'Force', true)
        WaitSeconds(0.1)
        DamageRing(self, position, 0, 160, 100, 'Force', true)
    end,

    OnImpact = function(self, TargetType, TargetEntity)
        if not TargetEntity or not EntityCategoryContains(categories.PROJECTILE * categories.ANTIMISSILE * categories.TECH3, TargetEntity) then
            -- Play the explosion sound
            local myBlueprint = self:GetBlueprint()
            if myBlueprint.Audio.NukeExplosion then
                self:PlaySound(myBlueprint.Audio.NukeExplosion)
            end

            self.effectEntity = self:CreateProjectile(self.effectEntityPath, 0, 0, 0, nil, nil, nil):SetCollision(false)
            self.effectEntity:ForkThread(self.effectEntity.EffectThread)
            self.Trash:Add(ForkThread(self.ForceThread, self) )
        end
        NullShell.OnImpact(self, TargetType, TargetEntity)
    end,

    LauncherCallbacks = function(self)
        local launcher = self:GetLauncher()
        if launcher and not launcher.Dead and launcher.EventCallbacks.ProjectileDamaged then
            self.ProjectileDamaged = {}
            for k,v in launcher.EventCallbacks.ProjectileDamaged do
                table.insert(self.ProjectileDamaged, v)
            end
        end
        self:SetCollisionShape('Sphere', 0, 0, 0, 1)
        self.Trash:Add(ForkThread(self.MovementThread, self) )
    end,

    DoTakeDamage = function(self, instigator, amount, vector, damageType)
        if self.ProjectileDamaged then
            for k,v in self.ProjectileDamaged do
                v(self)
            end
        end
        NullShell.DoTakeDamage(self, instigator, amount, vector, damageType)
    end,

    OnDamage = function(self, instigator, amount, vector, damageType)
		local bp = self:GetBlueprint().Defense.MaxHealth
			if bp then
			self:DoTakeDamage(instigator, amount, vector, damageType)
		else
			self:OnKilled(instigator, damageType)
		end
    end,
}

-----------------------------------------------------------------
-- POLY-TRAIL PROJECTILES
-----------------------------------------------------------------
---@class SinglePolyTrailProjectile : EmitterProjectile
SinglePolyTrailProjectile = Class(EmitterProjectile) {

    PolyTrail = '/effects/emitters/test_missile_trail_emit.bp',
    PolyTrailOffset = 0,
    FxTrails = {},

    OnCreate = function(self)
        EmitterProjectile.OnCreate(self)

        if self.PolyTrail ~= '' then
            local effect = CreateTrail(self, -1, self.Army, self.PolyTrail)
            
            -- only do these engine calls when they matter
            if self.PolyTrailOffset ~= 0 then 
                IEffectOffsetEmitter(effect, 0, 0, self.PolyTrailOffset)
            end
        end
    end,
}

-- upvalue for performance


---@class MultiPolyTrailProjectile : EmitterProjectile
MultiPolyTrailProjectile = Class(EmitterProjectile) {

    PolyTrails = {'/effects/emitters/test_missile_trail_emit.bp'},
    PolyTrailOffset = {0},
    FxTrails = {},
    RandomPolyTrails = 0,   -- Count of how many are selected randomly for PolyTrail table

    OnCreate = function(self)
        EmitterProjectile.OnCreate(self)

        if self.PolyTrails then
            local effect
            local army = self.Army 
            local NumPolyTrails = TableGetn(self.PolyTrails)

            if self.RandomPolyTrails ~= 0 then
                local index
                for i = 1, self.RandomPolyTrails do
                    index = Random(1, NumPolyTrails)
                    effect = CreateTrail(self, -1, army, self.PolyTrails[index])

                    -- only do these engine calls when they matter
                    if self.PolyTrailOffset[index] ~= 0 then 
                        IEffectOffsetEmitter(effect, 0, 0, self.PolyTrailOffset[index])
                    end
                end
            else
                for i = 1, NumPolyTrails do
                    effect = CreateTrail(self, -1, army, self.PolyTrails[i])

                    -- only do these engine calls when they matter
                    if self.PolyTrailOffset[i] ~= 0 then 
                        IEffectOffsetEmitter(effect, 0, 0, self.PolyTrailOffset[i])
                    end
                end
            end
        end
    end,
}


-----------------------------------------------------------------
-- COMPOSITE EMITTER PROJECTILES - MULTIPURPOSE PROJECTILES
-- - THAT COMBINES BEAMS, POLYTRAILS, AND NORMAL EMITTERS
-----------------------------------------------------------------

-- LIGHTWEIGHT VERSION THAT LIMITS USE TO 1 BEAM, 1 POLYTRAIL, AND STANDARD EMITTERS
---@class SingleCompositeEmitterProjectile : SinglePolyTrailProjectile
SingleCompositeEmitterProjectile = Class(SinglePolyTrailProjectile) {

    BeamName = '/effects/emitters/default_beam_01_emit.bp',
    FxTrails = {},

    OnCreate = function(self)
        SinglePolyTrailProjectile.OnCreate(self)

        if self.BeamName ~= '' then
            CreateBeamEmitterOnEntity(self, -1, self.Army, self.BeamName)
        end
    end,
}

-- HEAVYWEIGHT VERSION, ALLOWS FOR MULTIPLE BEAMS, POLYTRAILS, AND STANDARD EMITTERS
---@class MultiCompositeEmitterProjectile : MultiPolyTrailProjectile
MultiCompositeEmitterProjectile = Class(MultiPolyTrailProjectile) {

    Beams = {'/effects/emitters/default_beam_01_emit.bp',},
    PolyTrails = {'/effects/emitters/test_missile_trail_emit.bp'},
    PolyTrailOffset = {0},
    RandomPolyTrails = 0,   -- Count of how many are selected randomly for PolyTrail table
    FxTrails = {},

    OnCreate = function(self)
        MultiPolyTrailProjectile.OnCreate(self)

        local beam = nil
        for k, v in self.Beams do
            CreateBeamEmitterOnEntity(self, -1, self.Army, v)
        end
    end,
}

-----------------------------------------------------------------
-- TRAIL ON ENTERING WATER PROJECTILE
-----------------------------------------------------------------
---@class OnWaterEntryEmitterProjectile : Projectile
OnWaterEntryEmitterProjectile = Class(Projectile) {
    FxTrails = {'/effects/emitters/torpedo_munition_trail_01_emit.bp',},
    FxTrailScale = 1,
    FxTrailOffset = 0,
    PolyTrail = '',
    PolyTrailOffset = 0,
    TrailDelay = 5,
    EnterWaterSound = 'Torpedo_Enter_Water_01',

    OnCreate = function(self, inWater)
        Projectile.OnCreate(self, inWater)

        if inWater then

            local effect 
            local army = self.Army 

            for i in self.FxTrails do
                effect = CreateEmitterOnEntity(self, army, self.FxTrails[i])
            
                -- only do these engine calls when they matter
                if self.FxTrailScale ~= 1 then 
                    IEffectScaleEmitter(effect, self.FxTrailScale)
                end
                
                if self.FxTrailOffset ~= 1 then 
                    IEffectOffsetEmitter(effect, 0, 0, self.FxTrailOffset)
                end
            end

            if self.PolyTrail ~= '' then
                effect = CreateTrail(self, -1, army, self.PolyTrail)
            
                -- only do these engine calls when they matter
                if self.PolyTrailOffset ~= 0 then 
                    IEffectOffsetEmitter(effect, 0, 0, self.PolyTrailOffset)
                end
            end
        end
    end,

    EnterWaterThread = function(self)
        WaitTicks(self.TrailDelay)

        local effect 
        local army = self.Army 

        for i in self.FxTrails do
            effect = CreateEmitterOnEntity(self, army, self.FxTrails[i])
        
            -- only do these engine calls when they matter
            if self.FxTrailScale ~= 1 then 
                IEffectScaleEmitter(effect, self.FxTrailScale)
            end
            
            if self.FxTrailOffset ~= 1 then 
                IEffectOffsetEmitter(effect, 0, 0, self.FxTrailOffset)
            end
        end
        if self.PolyTrail ~= '' then
            local effect = CreateTrail(self, -1, army, self.PolyTrail)
            
            -- only do these engine calls when they matter
            if self.PolyTrailOffset ~= 0 then 
                IEffectOffsetEmitter(effect, 0, 0, self.PolyTrailOffset)
            end
        end
    end,

    OnEnterWater = function(self)
        Projectile.OnEnterWater(self)
        self:TrackTarget(true)
        self:StayUnderwater(true)
        self.TTT1 = self:ForkThread(self.EnterWaterThread)
    end,

    OnImpact = function(self, TargetType, TargetEntity)
        Projectile.OnImpact(self, TargetType, TargetEntity)
        KillThread(self.TTT1)
    end,
}

-----------------------------------------------------------------
-- GENERIC DEBRIS PROJECTILE
-----------------------------------------------------------------

-- upvalued for performance
local CreateEmitterAtBone = CreateEmitterAtBone
local CreateEmitterAtEntity = CreateEmitterAtEntity
local GetTerrainType = GetTerrainType

-- upvalued read-only values
local DefaultTerrainTypeFxImpact = GetTerrainType(-1, -1).FXImpact

-- moho functions for performance
local EntityMethods = _G.moho.entity_methods
local EntityDestroy = EntityMethods.Destroy
local EntityPlaySound = EntityMethods.PlaySound
local EntityGetBlueprint = EntityMethods.GetBlueprint
local EntityGetPositionXYZ = EntityMethods.GetPositionXYZ

local EmitterMethods = _G.moho.IEffect
local EmitterScaleEmitter = EmitterMethods.ScaleEmitter

---@class BaseGenericDebris : DummyProjectile
BaseGenericDebris = Class(DummyProjectile){

    OnImpact = function(self, targetType, targetEntity)

        -- cache values
        local blueprint = EntityGetBlueprint(self)
        local blueprintDisplayImpactEffects = blueprint.Display.ImpactEffects
        local impactEffectType = blueprintDisplayImpactEffects.Type or 'Default'

        -- determine sound value
        local impactSnd = "Impact"
        if targetType == 'Terrain' then
            impactSnd = "ImpactTerrain"
        elseif targetType == 'Water' then
            impactSnd = "ImpactWater"
        end
        
        -- play impact sound
        local snd = blueprint.Audio[impactSnd]
        if snd then 
            EntityPlaySound(self, snd)
        end

        -- Inlined GetTerrainEffects --

        -- get x / z position
        local x, _, z = EntityGetPositionXYZ(self)

        -- get terrain at that location and try and get some effects
        local terrainTypeFxImpact = GetTerrainType(x, z).FXImpact
        local terrainEffects = terrainTypeFxImpact[targetType][impactEffectType] or DefaultTerrainTypeFxImpact[targetType][impactEffectType] or false

        -- Inlined CreateTerrainEffects --

        -- check if table exists, can be set to false
        if terrainEffects then 

            -- store values in cache
            local emit = false
            local army = self.Army 
            local effectScale = blueprintDisplayImpactEffects.Scale or 1

            for _, v in terrainEffects do

                -- create emitter and scale accordingly
                emit = CreateEmitterAtBone(self, -2, army, v)
                if effectScale ~= 1 then
                    EmitterScaleEmitter(emit, effectScale)
                end
            end
        end

        -- destroy ourselves :(
        EntityDestroy(self)
    end,
}

-----------------------------------------------------------
-- PROJECTILE THAT ADJUSTS DAMAGE AND ENERGY COST ON IMPACT
-----------------------------------------------------------

---@class OverchargeProjectile
OverchargeProjectile = Class() {
    OnImpact = function(self, targetType, targetEntity)
        -- Stop us doing blueprint damage in the other OnImpact call if we ditch this one without resetting self.DamageData
        self.DamageData.DamageAmount = 0

        local launcher = self:GetLauncher()
        if not launcher then 
            return 
        end

        local wep = launcher:GetWeaponByLabel('OverCharge')
        if not wep then
             return 
            end

        if IsDestroyed(wep) then
            return
        end

        --  Table layout for Overcharge data section
        --  Overcharge = {
        --      energyMult = _, -- What proportion of current storage are we allowed to spend?
        --      commandDamage = _, -- Takes effect in ACUUnit DoTakeDamage()
        --      structureDamage = _, -- Takes effect in StructureUnit DoTakeDamage() & Shield  ApplyDamage()
        --      maxDamage = _,
        --      minDamage = _,
        --  },

        local data = wep:GetBlueprint().Overcharge
        if not data then return end

        -- Set the damage dealt by the projectile for hitting the floor or an ACUUnit
        -- Energy drained is calculated by the relationship equations
        local damage = data.minDamage

        local killShieldUnit = false
        if targetEntity then
            -- Handle hitting shields. We want the unit underneath, not the shield itself
            if not IsUnit(targetEntity) then
                if not targetEntity.Owner then -- We hit something odd, not a shield
                    WARN('Overcharge hit something that was not the ground, a shield, or a unit')
                    LOG(targetType)
                    return
                end

                targetEntity = targetEntity.Owner
            end

            -- Get max energy available to drain according to how much we have
            local energyAvailable = launcher:GetAIBrain():GetEconomyStored('ENERGY')
            local energyLimit = energyAvailable * data.energyMult
            if OCProjectiles[self.Army] > 1 then
                energyLimit = energyLimit / OCProjectiles[self.Army]
            end
            local energyLimitDamage = self:EnergyAsDamage(energyLimit)
            -- Find max available damage
            damage = math.min(data.maxDamage, energyLimitDamage)
            -- How much damage do we actually need to kill the unit?
            local idealDamage = targetEntity:GetHealth()
            local maxHP = self:UnitsDetection(targetType, targetEntity)
            idealDamage = maxHP or data.minDamage
            
            local targetCats = targetEntity:GetBlueprint().CategoriesHash

            -----SHIELDS------
            if targetEntity.MyShield and targetEntity.MyShield.ShieldType == 'Bubble' then
                if targetCats.DIESTOOCDEPLETINGSHIELD then
                    killShieldUnit = true
                end

                if targetCats.STRUCTURE then
                    idealDamage = data.minDamage
                else
                    idealDamage = targetEntity.MyShield:GetMaxHealth()
                end
                --MaxHealth instead of GetHealth because with getHealth OC won't kill bubble shield which is in AoE range but has more hp than targetEntity.MyShield.
                --good against group of mobile shields
            end
            ------ ACU -------
            if targetCats.COMMAND and not maxHP then -- no units around ACU - min.damage
                idealDamage = data.minDamage
            end
            damage = math.min(damage, idealDamage)
            damage = math.max(data.minDamage, damage)
            -- prevents radars blinks if there is less than 5k e in storage when OC hits the target
            if energyAvailable < 5000 then
                damage = energyLimitDamage
            end
        end

        -- Turn the final damage into energy
        local drain = self:DamageAsEnergy(damage)

        self.DamageData.DamageAmount = damage

        if drain > 0 then
            launcher.EconDrain = CreateEconomyEvent(launcher, drain, 0, 0)
            launcher:ForkThread(function()
                WaitFor(launcher.EconDrain)
                RemoveEconomyEvent(launcher, launcher.EconDrain)
                OCProjectiles[self.Army] = OCProjectiles[self.Army] - 1
                launcher.EconDrain = nil
                -- if oc depletes a mobile shield it kills the generator, vet counted, no wreck left
                if killShieldUnit and targetEntity and not IsDestroyed(targetEntity) and (IsDestroyed(targetEntity.MyShield) or (not targetEntity.MyShield:IsUp())) then
                    targetEntity:Kill(launcher, 'Overcharge', 2)
                    launcher:OnKilledUnit(targetEntity, targetEntity:GetVeterancyValue())
                end
            end)
        end
    end,

    DamageAsEnergy = function(self, damage)
        return OverchargeShared.DamageAsEnergy(damage)
    end,

    EnergyAsDamage = function(self, energy)
        return OverchargeShared.EnergyAsDamage(energy)
    end,

    UnitsDetection = function(self, targetType, targetEntity)
     -- looking for units around target which are in splash range
        local launcher = self:GetLauncher()
        local maxHP = 0

        for _, unit in UnitsInSphere(launcher, self:GetPosition(), 2.7, categories.MOBILE -categories.COMMAND) or {} do
                if unit.MyShield and unit:GetHealth() + unit.MyShield:GetHealth() > maxHP then
                    maxHP = unit:GetHealth() + unit.MyShield:GetHealth()
                elseif unit:GetHealth() > maxHP then
                    maxHP = unit:GetHealth()
                end
        end

        for _, unit in UnitsInSphere(launcher, self:GetPosition(), 13.2, categories.EXPERIMENTAL*categories.LAND*categories.MOBILE) or {} do
            -- Special for fatty's shield
            if EntityCategoryContains(categories.UEF, unit) and unit.MyShield._IsUp and unit.MyShield:GetMaxHealth() > maxHP then
                maxHP = unit.MyShield:GetMaxHealth()
            elseif unit:GetHealth() > maxHP then
                local distance = math.min(unit:GetBlueprint().SizeX, unit:GetBlueprint().SizeZ)
                if GetDistanceBetweenTwoEntities(unit, self) < distance + self.DamageData.DamageRadius then
                    maxHP = unit:GetHealth()
                end
            end
        end

        if EntityCategoryContains(categories.EXPERIMENTAL, targetEntity) and targetEntity:GetHealth() > maxHP then
            maxHP = targetEntity:GetHealth()
            --[[ we need this because if OC shell hitted top part of GC model its health won't be in our table
            Bug appeared since we use shell.pos in getUnitsInSphere instead of target.pos.
            Shell is too far from actual target.pos(target pos is somewhere near land and shell is near GC's head)
            and getUnits returns nothing. Same to GetDistance. Distance between shell and GC pos > than math.min (x,z) size]]
        end

        if maxHP ~= 0 then
            return maxHP
        end
    end,

    OnCreate = function(self)
        self.Army = self:GetArmy()

        if not OCProjectiles[self.Army] then
            OCProjectiles[self.Army] = 0
        end

        OCProjectiles[self.Army] = OCProjectiles[self.Army] + 1
    end,
}
