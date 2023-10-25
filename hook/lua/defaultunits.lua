local OldStruct = StructureUnit

StructureUnit = ClassUnit(OldStruct) {
    ---@param self StructureUnit
    OnCreate = function(self)--Bc this makes changes to terrain already, I can't just hook the old one, I have to override it completely with my own version.
        Unit.OnCreate(self)
        self:HideLandBones()
        self.FxBlinkingLightsBag = { }

        local layer = self.Layer
        local blueprint = self.Blueprint
        local physicsBlueprint = blueprint.Physics
        local flatten = physicsBlueprint.FlattenSkirt
        local horizontalSkirt = physicsBlueprint.HorizontalSkirt
        if flatten then
            if horizontalSkirt then
                self:FlattenSkirtHorizontally()
            else
                self:FlattenSkirt()
            end
        end
		--and (flatten or physicsBlueprint.AlwaysAlignToTerrain) This is removed to let t1 pd/aa tilt, as well as any other small structure.
            
        -- check for terrain orientation  physicsBlueprint.AltitudeToTerrain or
        if not (physicsBlueprint.StandUpright or horizontalSkirt) and (layer == 'Land' or layer == 'Seabed') then
            -- rotate structure to match terrain gradient
            local a1, a2 = TerrainUtils.GetTerrainSlopeAnglesDegrees(
                self:GetPosition(),
                blueprint.Footprint.SizeX or physicsBlueprint.SkirtSizeX,
                blueprint.Footprint.SizeZ or physicsBlueprint.SkirtSizeZ
            )

            -- do not orientate structures that are on flat ground
            if a1 != 0 or a2 != 0 then
                -- quaternion magic incoming, be prepared! Note that the yaw axis is inverted, but then
                -- re-inverted again by multiplying it with the original orientation
                local quatSlope = Quaternion.fromAngle(0, 0 - a2,-1 * a1)
                local quatOrient = setmetatable(self:GetOrientation(), Quaternion)
                local quat = quatOrient * quatSlope
                self:SetOrientation(quat, true)

                -- technically obsolete, but as this is part of an integration we don't want to break
                -- the mod package that it originates from. Originates from the BrewLan mod suite
                self.TerrainSlope = {}
            end
        end

        -- create decal below structure
        if --[[flatten and]] not self:HasTarmac() and blueprint.General.FactionName ~= "Seraphim" then
            if self.TarmacBag then
                self:CreateTarmac(true, true, true, self.TarmacBag.Orientation, self.TarmacBag.CurrentBP)
            else
                self:CreateTarmac(true, true, true, false, false)
            end
        end
    end,
}
-- Concrete Structures| Unsure of what these were supposed to be for, But I might look into this.
---@class ConcreteStructureUnit : StructureUnit
ConcreteStructureUnit = ClassUnit(StructureUnit) {
    ---@param self ConcreteStructureUnit
    OnCreate = function(self)
        StructureUnit.OnCreate(self)
    end
}
--- Base class for command units.
---@class CommandUnit : WalkingLandUnit
CommandUnit = Class(WalkingLandUnit) {
    DeathThreadDestructionWaitTime = 2,

    ---@param self CommandUnit
    ---@param HeadName string
    __init = function(self, HeadName)
        self.HeadLabel = HeadName
    end,

    ---@param self CommandUnit
    OnCreate = function(self)
        WalkingLandUnit.OnCreate(self)
		-- Save build effect bones for faster access when creating build effects
        self.BuildEffectBones = self.Blueprint.General.BuildBones.BuildEffectBones
		self:BuildManipulatorSetEnabled(true) --Here to let the ACU build with ResetArm and PrepareArm changed.
    end,

    ---@param self CommandUnit
    ResetRightArm = function(self)
        --self:BuildManipulatorSetEnabled(false)
        self.BuildArmManipulator:SetPrecedence(0)
        self:SetWeaponEnabledByLabel(self.HeadLabel, true)
        self:GetWeaponManipulatorByLabel(self.HeadLabel):SetHeadingPitch(self.BuildArmManipulator:GetHeadingPitch())
        self:SetImmobile(false)
    end,

    ---@param self CommandUnit
    OnFailedToBuild = function(self)
        WalkingLandUnit.OnFailedToBuild(self)
        if self:BeenDestroyed() then return end
        self:ResetRightArm()
    end,

    ---@param self CommandUnit
    ---@param target Unit
    OnStopCapture = function(self, target)
        WalkingLandUnit.OnStopCapture(self, target)
        if self:BeenDestroyed() then return end
        self:ResetRightArm()
    end,

    ---@param self CommandUnit
    ---@param target Unit
    OnFailedCapture = function(self, target)
        WalkingLandUnit.OnFailedCapture(self, target)
        if self:BeenDestroyed() then return end
        self:ResetRightArm()
    end,

    ---@param self CommandUnit
    ---@param target Unit
    OnStopReclaim = function(self, target)
        WalkingLandUnit.OnStopReclaim(self, target)
        if self:BeenDestroyed() then return end
        self:ResetRightArm()
    end,
	
    ---@param self CommandUnit
    OnPrepareArmToBuild = function(self)
        WalkingLandUnit.OnPrepareArmToBuild(self)
        if self:BeenDestroyed() then return end

        self:BuildManipulatorSetEnabled(true)
        self.BuildArmManipulator:SetPrecedence(13)
        self:SetWeaponEnabledByLabel(self.HeadLabel, false)
        self.BuildArmManipulator:SetHeadingPitch(self:GetWeaponManipulatorByLabel(self.HeadLabel):GetHeadingPitch())

        -- This is an extremely ugly hack to get around an engine bug. If you have used a command such as OC or repair on an illegal
        -- target (An allied unit, or something at full HP, for example) while moving, the engine is tricked into a state where
        -- the unit is still moving, but unaware of it (It thinks it stopped to do the command). This allows it to build on the move,
        -- as it doesn't know it's doing something bad. To fix it, we temporarily make the unit immobile when it starts construction.
        if self:IsMoving() then
            self:SetImmobile(true)
            self:ForkThread(function() WaitTicks(1) if not self:BeenDestroyed() then self:SetImmobile(false) end end)
        end
    end,

    ---@param self CommandUnit
    ---@param unitBeingBuilt Unit
    ---@param order string
    OnStartBuild = function(self, unitBeingBuilt, order)
        WalkingLandUnit.OnStartBuild(self, unitBeingBuilt, order)
        self.UnitBeingBuilt = unitBeingBuilt

        if order ~= 'Upgrade' then
            self.BuildingUnit = true
        end

        -- Check if we're about to try and build something we shouldn't. This can only happen due to
        -- a native code bug in the SCU REBUILDER behaviour.
        -- FractionComplete is zero only if we're the initiating builder. Clearly, we want to allow
        -- assisting builds of other races, just not *starting* them.
        -- We skip the check if we're assisting another builder: it's up to them to have the ability
        -- to start this build, not us.
        if not self:GetGuardedUnit() and unitBeingBuilt:GetFractionComplete() == 0 and not self:CanBuild(unitBeingBuilt.Blueprint.BlueprintId) then
            IssueStop({self})
            IssueClearCommands({self})
            unitBeingBuilt:Destroy()
        end
    end,

    ---@param self CommandUnit
    ---@param unitBeingBuilt Unit
    OnStopBuild = function(self, unitBeingBuilt)
        WalkingLandUnit.OnStopBuild(self, unitBeingBuilt)
        if self:BeenDestroyed() then return end
        self:ResetRightArm()

        self.UnitBeingBuilt = nil
        self.UnitBuildOrder = nil
        self.BuildingUnit = false
    end,

    ---@param self CommandUnit
    OnPaused = function(self)
        WalkingLandUnit.OnPaused(self)
        if self.BuildingUnit then
            WalkingLandUnit.StopBuildingEffects(self, self.UnitBeingBuilt)
        end
    end,

    ---@param self CommandUnit
    OnUnpaused = function(self)
        if self.BuildingUnit then
            WalkingLandUnit.StartBuildingEffects(self, self.UnitBeingBuilt, self.UnitBuildOrder)
        end
        WalkingLandUnit.OnUnpaused(self)
    end,

    ---@param self CommandUnit
    ---@param auto boolean
    SetAutoOvercharge = function(self, auto)
        local wep = self:GetWeaponByLabel('AutoOverCharge')
        if wep.NeedsUpgrade then return end

        wep:SetAutoOvercharge(auto)
        self.Sync.AutoOvercharge = auto
    end,

    ---@param self CommandUnit
    ---@param bones string
    PlayCommanderWarpInEffect = function(self, bones)
        self:HideBone(0, true)
        self:SetUnSelectable(true)
        self:SetBusy(true)
        self:ForkThread(self.WarpInEffectThread, bones)
    end,

    ---@param self CommandUnit
    ---@param bones string
    WarpInEffectThread = function(self, bones)
        self:PlayUnitSound('CommanderArrival')
        self:CreateProjectile('/effects/entities/UnitTeleport01/UnitTeleport01_proj.bp', 0, 1.35, 0, nil, nil, nil):SetCollision(false)
        WaitSeconds(2.1)

        local bp = self.Blueprint
        local psm = bp.Display.WarpInEffect.PhaseShieldMesh
        if psm then
            self:SetMesh(psm, true)
        end

        self:ShowBone(0, true)
        self:SetUnSelectable(false)
        self:SetBusy(false)
        self:SetBlockCommandQueue(false)

        for _, v in bones or bp.Display.WarpInEffect.HideBones do
            self:HideBone(v, true)
        end

        local totalBones = self:GetBoneCount() - 1
        for k, v in EffectTemplate.UnitTeleportSteam01 do
            for bone = 1, totalBones do
                CreateAttachedEmitter(self, bone, self.Army, v)
            end
        end

        if psm then
            WaitSeconds(6)
            self:SetMesh(bp.Display.MeshBlueprint, true)
        end
    end,

    -------------------------------------------------------------------------------------------
    -- TELEPORTING WITH DELAY
    -------------------------------------------------------------------------------------------

    ---@param self CommandUnit
    ---@param teleporter any
    ---@param location number
    ---@param orientation number
    InitiateTeleportThread = function(self, teleporter, location, orientation)
        self.UnitBeingTeleported = self
        self:SetImmobile(true)
        self:PlayUnitSound('TeleportStart')
        self:PlayUnitAmbientSound('TeleportLoop')

        local bp = self.Blueprint
        local bpEco = bp.Economy
        local teleDelay = bp.General.TeleportDelay
        local energyCost, time

        if bpEco then
            local mass = (bpEco.TeleportMassCost or bpEco.BuildCostMass or 1) * (bpEco.TeleportMassMod or 0.01)
            local energy = (bpEco.TeleportEnergyCost or bpEco.BuildCostEnergy or 1) * (bpEco.TeleportEnergyMod or 0.01)
            energyCost = mass + energy
            time = energyCost * (bpEco.TeleportTimeMod or 0.01)
        end

        if teleDelay then
            energyCostMod = (time + teleDelay) / time
            time = time + teleDelay
            energyCost = energyCost * energyCostMod

            self.TeleportDestChargeBag = nil
            self.TeleportCybranSphere = nil  -- this fixes some "...Game object has been destroyed" bugs in EffectUtilities.lua:TeleportChargingProgress

            self.TeleportDrain = CreateEconomyEvent(self, energyCost or 100, 0, time or 5, self.UpdateTeleportProgress)

            -- Create teleport charge effect + exit animation delay
            self:PlayTeleportChargeEffects(location, orientation, teleDelay)
            WaitFor(self.TeleportDrain)
        else
            self.TeleportDrain = CreateEconomyEvent(self, energyCost or 100, 0, time or 5, self.UpdateTeleportProgress)

            -- Create teleport charge effect
            self:PlayTeleportChargeEffects(location, orientation)
            WaitFor(self.TeleportDrain)
        end

        if self.TeleportDrain then
            RemoveEconomyEvent(self, self.TeleportDrain)
            self.TeleportDrain = nil
        end

        self:PlayTeleportOutEffects()
        self:CleanupTeleportChargeEffects()
        WaitSeconds(0.1)
        self:SetWorkProgress(0.0)
        Warp(self, location, orientation)
        self:PlayTeleportInEffects()
        self:CleanupRemainingTeleportChargeEffects()

        WaitSeconds(0.1) -- Perform cooldown Teleportation FX here

        -- Landing Sound
        self:StopUnitAmbientSound('TeleportLoop')
        self:PlayUnitSound('TeleportEnd')
        self:SetImmobile(false)
        self.UnitBeingTeleported = nil
        self.TeleportThread = nil
    end,

    ---@param self CommandUnit
    ---@param work any
    ---@return boolean
    OnWorkBegin = function(self, work)
        if WalkingLandUnit.OnWorkBegin(self, work) then 

            -- Prevent consumption bug where two enhancements in a row prevents assisting units from
            -- updating their consumption costs based on the new build rate values.
            self:UpdateAssistersConsumption()

            -- Inform EnhanceTask that enhancement is not restricted
            return true
        end
    end,
}

---@class ACUUnit : CommandUnit
ACUUnit = Class(CommandUnit) {
    -- The "commander under attack" warnings.
    ---@param self ACUUnit
    ---@param bpShield any
    CreateShield = function(self, bpShield)
        CommandUnit.CreateShield(self, bpShield)

        local aiBrain = self:GetAIBrain()

        -- Mutate the OnDamage function for this one very special shield.
        local oldApplyDamage = self.MyShield.ApplyDamage
        self.MyShield.ApplyDamage = function(...)
            oldApplyDamage(unpack(arg))
            aiBrain:OnPlayCommanderUnderAttackVO()
        end
    end,

    ---@param self ACUUnit
    ---@param enh string
    CreateEnhancement = function(self, enh)
        CommandUnit.CreateEnhancement(self, enh)

        self:SendNotifyMessage('completed', enh)
        self:SetImmobile(false)
    end,

    ---@param self ACUUnit
    ---@param work string
    ---@return boolean
    OnWorkBegin = function(self, work)
        local legalWork = CommandUnit.OnWorkBegin(self, work)
        if not legalWork then return end

        self:SendNotifyMessage('started', work)

        -- No need to do it for AI
        if self:GetAIBrain().BrainType == 'Human' then
            self:SetImmobile(true)
        end

        return true
    end,

    ---@param self ACUUnit
    ---@param work string
    OnWorkFail = function(self, work)
        self:SendNotifyMessage('cancelled', work)
        self:SetImmobile(false)

        CommandUnit.OnWorkFail(self, work)
    end,

    ---@param self ACUUnit
    ---@param builder Unit
    ---@param layer string
    OnStopBeingBuilt = function(self, builder, layer)
        CommandUnit.OnStopBeingBuilt(self, builder, layer)
        ArmyBrains[self.Army]:SetUnitStat(self.UnitId, "lowest_health", self:GetHealth())
        self.WeaponEnabled = {}
    end,

    ---@param instigator Can be a Unit or table, purely to support the advanced hitboxes.
    DoTakeDamage = function(self, instigator, amount, vector, damageType)
        -- Handle incoming OC damage
        if damageType == 'Overcharge' then
            local wep = (instigator.Unit or instigator):GetWeaponByLabel('OverCharge')
            amount = wep.Blueprint.Overcharge.commandDamage
        end

        WalkingLandUnit.DoTakeDamage(self, instigator, amount, vector, damageType)
        local aiBrain = self:GetAIBrain()
        if aiBrain then
            aiBrain:OnPlayCommanderUnderAttackVO()
        end

        if self:GetHealth() < ArmyBrains[self.Army]:GetUnitStat(self.UnitId, "lowest_health") then
            ArmyBrains[self.Army]:SetUnitStat(self.UnitId, "lowest_health", self:GetHealth())
        end
    end,

    ---@param instigator Can be a Unit or table, purely to support the advanced hitboxes.
    OnKilled = function(self, instigator, type, overkillRatio)
        CommandUnit.OnKilled(self, instigator, type, overkillRatio)
		--[[LOG('{ Instigator unit field:')
		LOG(instigator.Unit)
		LOG('}')]]
		LOG('{ Death Call instigator:')
		LOG(reprsl(instigator))
		LOG('}')
		local instie = instigator.Unit or instigator
        -- If there is a killer, and it's not me
        if instie.Army ~= self.Army then
            local instigatorBrain = ArmyBrains[instie.Army]

            Sync.EnforceRating = true
            WARN('ACU kill detected. Rating for ranked games is now enforced.')

            -- If we are teamkilled, filter out death explostions of allied units that were not coused by player's self destruct order
            -- Damage types:
            --     'DeathExplosion' - when normal unit is killed
            --     'Nuke' - when Paragon is killed
            --     'Deathnuke' - when ACU is killed
            if IsAlly(self.Army, instie.Army) and not (type == 'DeathExplosion' or type == 'Nuke' or type == 'Deathnuke') and not instie.SelfDestructed then
                WARN('Teamkill detected')
                Sync.Teamkill = {killTime = GetGameTimeSeconds(), instigator = instie.Army, victim = self.Army}
            end
        end
        ArmyBrains[self.Army].CommanderKilledBy = (instie or self).Army
    end,

    ---@param self ACUUnit
    ResetRightArm = function(self)
        CommandUnit.ResetRightArm(self)
        -- Ugly hack to re-initialise auto-OC once a task finishes
        local wep = self:GetWeaponByLabel('AutoOverCharge')
        --wep:SetAutoOvercharge(wep.AutoMode)
    end,

    ---@param self ACUUnit
    OnPrepareArmToBuild = function(self)
        CommandUnit.OnPrepareArmToBuild(self)
        --self:SetWeaponEnabledByLabel('OverCharge', false)
        --self:SetWeaponEnabledByLabel('AutoOverCharge', false)
    end,

    ---@param self ACUUnit
    GiveInitialResources = function(self)
        WaitTicks(1)
        local bp = self.Blueprint
        local aiBrain = self:GetAIBrain()
        aiBrain:GiveResource('Energy', bp.Economy.StorageEnergy)
        aiBrain:GiveResource('Mass', bp.Economy.StorageMass)
    end,

    ---@param self ACUUnit
    BuildDisable = function(self)
        --[[while self:IsUnitState('Building') or self:IsUnitState('Enhancing') or self:IsUnitState('Upgrading') or
                self:IsUnitState('Repairing') or self:IsUnitState('Reclaiming') do
            WaitSeconds(0.5)
        end
		
        for label, enabled in self.WeaponEnabled do
            if enabled then
                self:SetWeaponEnabledByLabel(label, true, true)
            end
        end]]
    end,

    -- Store weapon status on upgrade. Ignore default and OC, which are dealt with elsewhere
    ---@param self ACUUnit
    ---@param label string
    ---@param enable boolean
    ---@param lockOut boolean
    SetWeaponEnabledByLabel = function(self, label, enable, lockOut)
        CommandUnit.SetWeaponEnabledByLabel(self, label, enable)

        -- Unless lockOut specified, updates the 'Permanent record' of whether a weapon is enabled. With it specified,
        -- the changing of the weapon on/off state is more... temporary. For example, when building something.
        if --[[label ~= self.HeadLabel and--]] label ~= 'OverCharge' and label ~= 'AutoOverCharge' and not lockOut then
            self.WeaponEnabled[label] = enable
        end
    end,

    ---@param self ACUUnit
    ---@param unitBeingBuilt Unit
    ---@param order string
    OnStartBuild = function(self, unitBeingBuilt, order)
        CommandUnit.OnStartBuild(self, unitBeingBuilt, order)

        --Disable any active upgrade weapons
        --[[ local fork = false
        for label, enabled in self.WeaponEnabled do
            if enabled then
                self:SetWeaponEnabledByLabel(label, false, true)
                fork = true
            end
        end,
		
        if fork then
            self:ForkThread(self.BuildDisable)
        end]]
    end
}