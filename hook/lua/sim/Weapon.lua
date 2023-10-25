local OldWeapon = Weapon
-- Only hooked this to remove the reset pose time for structures, at least for aeon ones.
Weapon = Class(OldWeapon) {
    ---@param self Weapon
    ---@param bp? WeaponBlueprint
    SetupTurret = function(self, bp)
        bp = bp or self.Blueprint -- defensive programming

        local yawBone = bp.TurretBoneYaw
        local pitchBone = bp.TurretBonePitch
        local muzzleBone = bp.TurretBoneMuzzle
        local precedence = bp.AimControlPrecedence or 10
        local pitchBone2, muzzleBone2

        local boneDualPitch = bp.TurretBoneDualPitch
        if boneDualPitch and boneDualPitch ~= '' then
            pitchBone2 = boneDualPitch
        end
        local boneDualMuzzle = bp.TurretBoneDualMuzzle
        if boneDualMuzzle and boneDualMuzzle ~= '' then
            muzzleBone2 = boneDualMuzzle
        end
        local unit = self.unit
        if not (unit:ValidateBone(yawBone) and unit:ValidateBone(pitchBone) and unit:ValidateBone(muzzleBone)) then
            error('*ERROR: Bone aborting turret setup due to bone issues.', 2)
            return
        elseif pitchBone2 and muzzleBone2 then
            if not (unit:ValidateBone(pitchBone2) and unit:ValidateBone(muzzleBone2)) then
                error('*ERROR: Bone aborting turret setup due to pitch/muzzle bone2 issues.', 2)
                return
            end
        end
        local aimControl, aimRight, aimLeft
        if yawBone and pitchBone and muzzleBone then
            local trashManipulators = self.Trash
            if bp.TurretDualManipulators then
                aimControl = CreateAimController(self, 'Torso', yawBone)
                aimRight = CreateAimController(self, 'Right', pitchBone, pitchBone, muzzleBone)
                aimLeft = CreateAimController(self, 'Left', pitchBone2, pitchBone2, muzzleBone2)
                self.AimRight = aimRight
                self.AimLeft = aimLeft
                aimControl:SetPrecedence(precedence)
                aimRight:SetPrecedence(precedence)
                aimLeft:SetPrecedence(precedence)
                self:SetFireControl('Right')
                trashManipulators:Add(aimControl)
                trashManipulators:Add(aimRight)
                trashManipulators:Add(aimLeft)
            else
                aimControl = CreateAimController(self, 'Default', yawBone, pitchBone, muzzleBone)
                trashManipulators:Add(aimControl)
                aimControl:SetPrecedence(precedence)
                if bp.RackSlavedToTurret and not table.empty(bp.RackBones) then
                    for _, v in bp.RackBones do
                        local rackBone = v.RackBone
                        if rackBone ~= pitchBone then
                            local slaver = CreateSlaver(unit, rackBone, pitchBone)
                            slaver:SetPrecedence(precedence - 1)
                            trashManipulators:Add(slaver)
                        end
                    end
                end
            end
        else
            error('*ERROR: Trying to setup a turreted weapon but there are yaw bones, pitch bones or muzzle bones missing from the blueprint.', 2)
        end
        self.AimControl = aimControl

        local numbersExist = true
        local turretyawmin, turretyawmax, turretyawspeed
        local turretpitchmin, turretpitchmax, turretpitchspeed

        -- SETUP MANIPULATORS AND SET TURRET YAW, PITCH AND SPEED
        if bp.TurretYaw and bp.TurretYawRange then
            turretyawmin, turretyawmax = self:GetTurretYawMinMax(bp)
        else
            numbersExist = false
        end
        if bp.TurretYawSpeed then
            turretyawspeed = self:GetTurretYawSpeed(bp)
        else
            numbersExist = false
        end
        if bp.TurretPitch and bp.TurretPitchRange then
            turretpitchmin, turretpitchmax = self:GetTurretPitchMinMax(bp)
        else
            numbersExist = false
        end
        if bp.TurretPitchSpeed then
            turretpitchspeed = self:GetTurretPitchSpeed(bp)
        else
            numbersExist = false
        end
        if numbersExist then
            aimControl:SetFiringArc(turretyawmin, turretyawmax, turretyawspeed, turretpitchmin, turretpitchmax, turretpitchspeed)
            if aimRight and aimLeft then -- although, they should both exist if either one does
                turretyawmin = turretyawmin / 12
                turretyawmax = turretyawmax / 12
                aimRight:SetFiringArc(turretyawmin, turretyawmax, turretyawspeed, turretpitchmin, turretpitchmax, turretpitchspeed)
                aimLeft:SetFiringArc(turretyawmin, turretyawmax, turretyawspeed, turretpitchmin, turretpitchmax, turretpitchspeed)
            end
        else
            local strg = '*ERROR: TRYING TO SETUP A TURRET WITHOUT ALL TURRET NUMBERS IN BLUEPRINT, ABORTING TURRET SETUP. WEAPON: ' .. bp.Label .. ' UNIT: '.. unit.UnitId
            error(strg, 2)
        end
    end,
	
    ---@param self Weapon
    ---@param label string
    OnStopTracking = function(self, label)
        self:PlayWeaponSound('BarrelStop')
        self:StopWeaponAmbientSound('BarrelLoop')
    end,
}