local LandUnit = import('/lua/DefaultUnits.lua').LandUnit
local TauCannon = import('/lua/seraphimweapons.lua').SDFThauCannon
local RiotGun = import('/lua/terranweapons.lua').TDFRiotWeapon

UTL0303 = Class(LandUnit) {
	Weapons = {
		Railgun = Class(TauCannon) {},
		LeftKAMGun = Class(RiotGun) {},
		RightKAMGun = Class(RiotGun) {},
	},
}
TypeClass = UTL0303