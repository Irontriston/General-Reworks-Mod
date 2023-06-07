#
# Terran Torpedo Bomb
#
local TTorpedoShipProjectile = import('/lua/terranprojectiles.lua').TTorpedoShipProjectile

TANAnglerTorpedo01 = Class(TTorpedoShipProjectile) 
{
	--[[
    OnEnterWater = function(self)
        TTorpedoShipProjectile.OnEnterWater(self)
        --self:SetCollisionShape('Box', 0, 0, 0.15, 0.027, 0.027, 0.19)
        local army = self:GetArmy()

        for k, v in self.FxEnterWater do #splash
            CreateEmitterAtEntity(self,army,v)
        end
        self:TrackTarget(true)
        self:StayUnderwater(true)
        self:SetTurnRate(240)
        self:SetMaxSpeed(24)
        --self:SetVelocity(0)
        self:ForkThread(self.MovementThread)
    end,
	--]]
}

TypeClass = TANAnglerTorpedo01
