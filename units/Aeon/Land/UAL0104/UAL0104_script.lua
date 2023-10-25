#****************************************************************************
#**  File     :  /cdimage/units/UAL0104/UAL0104_script.lua
#**  Author(s):  John Comes, David Tomandl, Jessica St. Croix
#**  Summary  :  Aeon Mobile Anti-Air Script
#**  Copyright © 2005 Gas Powered Games, Inc.  All rights reserved.
#****************************************************************************

local AHoverLandUnit = import('/lua/aeonunits.lua').AHoverLandUnit
local AAASonicPulseBatteryWeapon = import('/lua/aeonweapons.lua').AAASonicPulseBatteryWeapon
local TargetingLaser = import('/lua/kirvesweapons.lua').TargetingLaserInvisible


UAL0104 = Class(AHoverLandUnit) {
    Weapons = {
        TargetPainter = Class(TargetingLaser) { --Adapted from cybran mobile aa.
            -- Unit in range. Cease ground fire and turn on AA
            OnWeaponFired = function(self)
                if not self.AA then
                    self.unit:SetWeaponEnabledByLabel('GroundGun', false)
                    self.unit:SetWeaponEnabledByLabel('AAGun', true)
                    self.unit:GetWeaponManipulatorByLabel('AAGun'):SetHeadingPitch(self.unit:GetWeaponManipulatorByLabel('GroundGun'):GetHeadingPitch())
                    self.AA = true
                end
                TargetingLaser.OnWeaponFired(self)
            end,

            IdleState = State(TargetingLaser.IdleState) {
                -- Start with the AA gun off to reduce twitching of ground fire
                Main = function(self)
                    self.unit:SetWeaponEnabledByLabel('GroundGun', true)
                    self.unit:SetWeaponEnabledByLabel('AAGun', false)
                    self.unit:GetWeaponManipulatorByLabel('GroundGun'):SetHeadingPitch(self.unit:GetWeaponManipulatorByLabel('AAGun'):GetHeadingPitch())
                    self.AA = false
                    TargetingLaser.IdleState.Main(self)
                end,
            },
        },
        AAGun = Class(AAASonicPulseBatteryWeapon) {},
		GroundGun = Class(AAASonicPulseBatteryWeapon) {},
    },
}

TypeClass = UAL0104