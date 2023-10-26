--****************************************************************************
--**
--**  File     :  /data/projectiles/BrackmanQAIHackCircuitryEffect01/BrackmanQAIHackCircuitryEffect01_script.lua
--**
--**  Author(s):  Greg Kohne
--**
--**  Summary  :  BrackmanQAIHackCircuitryEffect01, non-damaging
--**
--**  Copyright © 2007 Gas Powered Games, Inc.  All rights reserved.
--****************************************************************************
local EffectTemplate = import("/lua/effecttemplates.lua")
local EmitterProjectile = import("/lua/sim/defaultprojectiles.lua").EmitterProjectile
local ProjCode = import('/mods/GeneralReworks/new lua/ProjCaptureCode.lua')

BrackmanQAIHackCircuitryEffect01 = Class(EmitterProjectile) {
	FxImpactTrajectoryAligned = true,
	FxTrajectoryAligned= true,
	FxTrails = EffectTemplate.CBrackmanQAIHackCircuitryEffectFxtrailsALL[1],
	OnImpact = function(self, TargetType, TargetEntity)
		EmitterProjectile.OnImpact(self, TargetType, TargetEntity)
		--ProjCode.CaptureThread(self, TargetEntity)
	end,
}
TypeClass = BrackmanQAIHackCircuitryEffect01
