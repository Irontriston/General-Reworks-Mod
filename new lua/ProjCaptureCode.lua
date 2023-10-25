-- Code that lets the hack circuitry capture unfortunate units in its path.
local UnitTransfer = import("/lua/SimUtils.lua").TransferUnitsOwnership

CaptureThread = function(self, targetEntity)
	LOG('CaptureThread has been called.')
	if targetEntity and IsUnit(targetEntity) --[[and targetEntity:IsCapturable() or targetEntity.Army == self.Army or IsAlly(targetEntity.Army, self.Army)]] then
		targetEntity.HackCount = (targetEntity.HackCount or 0) + 1
		local requiredHacks = 0
		local TargetBP = targetEntity:GetBlueprint()
		LOG('The unit '..targetEntity.UnitId..' has been hit. Now has a hack count of '..targetEntity.HackCount..' .')
		if EntityCategoryContains(targetEntity, 'TECH3') then
			requiredHacks = 24
		elseif EntityCategoryContains(targetEntity, 'TECH2') then
			requiredHacks = 12
		elseif EntityCategoryContains(targetEntity, 'TECH1') then
			requiredHacks = 4
		end
		if EntityCategoryContains(targetEntity, 'STRUCTURE') or EntityCategoryContains(targetEntity, 'NAVAL') then
			requiredHacks = requiredHacks + 10
		end
		if targetEntity.HackCount > requiredHacks then
			LOG(targetEntity.UnitId..' should have been captured now.')
			UnitTransfer({targetEntity}, self.Army, false)
		end
	end
end