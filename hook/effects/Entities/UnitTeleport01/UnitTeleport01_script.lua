local Old = UnitTeleportEffect01
UnitTeleportEffect01 = Class(Old) {

    TeleportEffectThread = function(self)
        local army = self.Army
        local pos = self:GetPosition()
        pos[2] = GetSurfaceHeight(pos[1], pos[3]) - 2
		local instigatorPack = { Unit = self.Launcher, Proj = self }
        -- initial effect
        for k, v in EffectTemplate.CSGTestEffect2 do
            CreateEmitterOnEntity(self, army, v)
        end

        -- initial light flash
        CreateLightParticleIntel(self, -1, army, 22, 4, 'flare_lens_add_02', 'ramp_blue_13')
        DamageRing(instigatorPack, pos, 0.1, 4, 1, 'Fire', false, false)
        DamageRing(instigatorPack, pos, 2, 6, 1, 'Fire', false, false)
        DamageRing(instigatorPack, pos, 0.1, 1, 1, 'Force', false, false)

        WaitTicks(2)
        DamageRing(instigatorPack, pos, 2, 4, 1, 'Force', false, false)
        WaitTicks(2)
        DamageRing(instigatorPack, pos, 4, 6, 1, 'Force', false, false)
        WaitTicks(2)

        CreateLightParticleIntel(self, -1, army, 38, 10, 'flare_lens_add_02', 'ramp_blue_13')
        self:CreateQuantumEnergy(army)

        -- knockdown trees
        for k = 1, 4 do
            DamageRing(instigatorPack, pos, 0.1, 1 + k * 1, 1, 'Force', false, false)
            WaitTicks(2)
        end

        DamageRing(instigatorPack, pos, 2, 7, 1, 'Fire', false, false)

        -- Wait till we want the commander to appear visibily
        WaitTicks(15)

        CreateLightParticleIntel(self, -1, army, 35, 10, 'glow_02', 'ramp_blue_13')
        DamageRing(instigatorPack, pos, .1, 11, 100, 'Disintegrate', false, false)

        for k, v in EffectTemplate.CommanderTeleport01 do
            CreateEmitterOnEntity(self, army, v):ScaleEmitter(1.20)
        end

        WaitTicks(2)

        local decalOrient = RandomFloat(0, 2 * math.pi)
        CreateDecal(pos, decalOrient, 'nuke_scorch_002_albedo', '', 'Albedo', 28, 28, 500, 600, army)
        CreateDecal(pos, decalOrient, 'Crater05_normals', '', 'Normals', 28, 28, 500, 600, army)
        CreateDecal(pos, decalOrient, 'Crater05_normals', '', 'Normals', 12, 12, 500, 600, army)

        DamageRing(instigatorPack, pos, .1, 11, 100, 'Disintegrate', false, false)
        WaitTicks(3)

        -- light some trees on fire
        DamageRing(instigatorPack, pos, 1, 16, 1, 'TreeFire', false, false)

        -- knockdown trees
        for k = 1, 2 do
            DamageRing(instigatorPack, pos, 11, 11 + k, 1, 'TreeForce', false, false)
            WaitTicks(2)
        end

        -- light some trees on fire
        DamageRing(instigatorPack, pos, 13, 21, 1, 'TreeFire', false, false)

        -- knockdown trees
        for k = 1, 4 do
            DamageRing(instigatorPack, pos, 11, 13 + k * 2, 1, 'TreeForce', false, false)
            WaitTicks(2)
        end

        -- light some trees on fire
        DamageRing(instigatorPack, pos, 12, 22, 1, 'TreeFire', false, false)
    end,
}
TypeClass = UnitTeleportEffect01
