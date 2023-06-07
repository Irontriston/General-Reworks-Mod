--
-- AA Missile for Cybrans
--
local CAAMissileNaniteProjectile = import('/lua/cybranprojectiles.lua').CAAMissileNaniteProjectile03
CAAMissileNanite03 = Class(CAAMissileNaniteProjectile) {

    OnCreate = function(self)
        CAAMissileNaniteProjectile.OnCreate(self)
        self:ForkThread(self.UpdateThread)
    end,

    UpdateThread = function(self)
        WaitSeconds(1.5)
        self:SetAcceleration(13 + Random() * 7)
        self:ChangeMaxZigZag(0.5)
        self:ChangeZigZagFrequency(2)
    end,

    OnImpact = function(self, TargetType, TargetEntity)
        CAAMissileNaniteProjectile.OnImpact(self, TargetType, TargetEntity)
    end,
}

TypeClass = CAAMissileNanite03

