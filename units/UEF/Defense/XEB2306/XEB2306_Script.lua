--#The UEF Heavy Point Defense.
local TStructureUnit = import('/lua/terranunits.lua').TStructureUnit
local TDFHeavyPlasmaCannonWeapon = import('/lua/terranweapons.lua').TDFHeavyPlasmaGatlingCannonWeapon

local EffectUtils = import('/lua/effectutilities.lua')
local Effects = import('/lua/effecttemplates.lua')

XEB2306 = Class(TStructureUnit) {
    Weapons = {
        MainGun = Class(TDFHeavyPlasmaCannonWeapon) 
        {
            PlayFxWeaponPackSequence = function(self)
                if self.SpinManip then
                    self.SpinManip:SetTargetSpeed(0)
                end
                self.ExhaustEffects = EffectUtils.CreateBoneEffects(self.unit, 'Exhaust', self.unit.Army, Effects.WeaponSteam01)
                TDFHeavyPlasmaCannonWeapon.PlayFxWeaponPackSequence(self)
            end,

            PlayFxRackSalvoChargeSequence = function(self)
                if not self.SpinManip then 
                    self.SpinManip = CreateRotator(self.unit, 'Gun_Barrel', 'z', nil, 270, 300, 1200)
                    self.unit.Trash:Add(self.SpinManip)
                end
                
                if self.SpinManip then
                    self.SpinManip:SetTargetSpeed(1200)
                end
                TDFHeavyPlasmaCannonWeapon.PlayFxRackSalvoChargeSequence(self)
            end,

            PlayFxRackSalvoReloadSequence = function(self)
                if self.SpinManip then
                    self.SpinManip:SetTargetSpeed(500)
                end
                self.ExhaustEffects = EffectUtils.CreateBoneEffects(self.unit, 'Exhaust', self.unit.Army, Effects.WeaponSteam01)
                TDFHeavyPlasmaCannonWeapon.PlayFxRackSalvoChargeSequence(self)
            end,    
        }
    },
}

TypeClass = XEB2306
