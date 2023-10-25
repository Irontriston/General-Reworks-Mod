local OldCZARBeam = QuantumBeamGeneratorCollisionBeam 

QuantumBeamGeneratorCollisionBeam  = Class(OldCZARBeam) {
    TerrainImpactScale = 2.5,
    ScorchSplatDropTime = 0.2,
    ---@param self, as always. Reworked for the size modifier and a couple of other changes.
    ScorchThread = function(self)
        local army = self:GetArmy()
        local size = 4+ Random()*4
        local CurrentPosition = self:GetPosition(1)
        local LastPosition = Vector(0,0,0)
        local skipCount = 1
        -- local FriendlyFire = self.DamageData.DamageFriendly
        while true do
            if Util.GetDistanceBetweenTwoVectors(CurrentPosition, LastPosition) > 0.1 or skipCount > 100 then
                CreateSplat( CurrentPosition, Random()*2*math.pi, self.SplatTexture, size, size, 200, 150, army )
                LastPosition = CurrentPosition
                skipCount = 1
                -- commented due to hard-crash potential
                -- DamageArea(self, CurrentPosition, size, 1, 'Force', FriendlyFire)
                -- DamageArea(self, CurrentPosition, size, 1, 'Force', FriendlyFire)
            else
                skipCount = skipCount + self.ScorchSplatDropTime
            end
            WaitSeconds(self.ScorchSplatDropTime)
            size = 4+ Random()*4
            CurrentPosition = self:GetPosition(1)
        end
    end,
}