--This is being replaced entirely bc I want to remove the bits regarding
--hitbox v. speed comparisons and air unit footprint expansions.
--Unfortunately, this doesn't seem to be called at all.
local function PostProcessUnit(unit)
    if table.find(unit.Categories, "SUBCOMMANDER") then
        table.insert(unit.Categories, "SACU_BEHAVIOR")
    end

    -- # create hash tables for quick lookup
    unit.CategoriesCount = 0
    unit.CategoriesHash = { }
    if unit.Categories then 
        unit.CategoriesCount = table.getn(unit.Categories)
        for k, category in unit.Categories do 
            unit.CategoriesHash[category] = true 
        end
    end
	unit.CategoriesHash[unit.BlueprintId] = true--This dipshit is holding the entire mod together now.
--[[
    -- # create hash tables for quick lookup
    unit.DoNotCollideListCount = 0 
    unit.DoNotCollideListHash = { }
    if unit.DoNotCollideList then 
        unit.DoNotCollideListCount = table.getn(unit.DoNotCollideList)
        for k, category in unit.DoNotCollideList do 
            unit.DoNotCollideListHash[category] = true 
        end
    end]]

    local isEngineer = unit.CategoriesHash['ENGINEER']
    local isStructure = unit.CategoriesHash['STRUCTURE']
    local isDummy = unit.CategoriesHash['DUMMYUNIT']
    local isLand = unit.CategoriesHash['LAND']
    local isAir = unit.CategoriesHash['AIR']
    local isBomber = unit.CategoriesHash['BOMBER']
    local isGunship = unit.CategoriesHash['GUNSHIP']
    local isTransport = unit.CategoriesHash['TRANSPORTATION']
    local isTech1 = unit.CategoriesHash['TECH1']
    local isTech2 = unit.CategoriesHash['TECH2']
    local isTech3 = unit.CategoriesHash['TECH3']
    local isExperimental = unit.CategoriesHash['EXPERIMENTAL']

    -- do not touch guard scan radius values of engineer-like units, as it is the reason we have
    -- the factory-reclaim-bug that we're keen in keeping that at this point
    if not isEngineer then 
        -- guarantee that the table exists
        unit.AI = unit.AI or { }

        -- if it is set then we use that - allows us to make adjustments as we see fit
        if unit.AI.GuardScanRadius == nil then 
            -- structures don't need this value set
            if isStructure or isDummy then 
                unit.AI.GuardScanRadius = 0
            -- engineers need their factory reclaim bug
            elseif isEngineer then 
                unit.AI.GuardScanRadius = 26 -- allows for factory reclaim bug 
            else -- mobile units do need this value set
                -- check if we have a primary weapon that is actually a weapon
                local primaryWeapon = unit.Weapon[1]
                if primaryWeapon and not (primaryWeapon.DummyWeapon or primaryWeapon.WeaponCategory == 'Death' or primaryWeapon.Label == 'DeathImpact' or primaryWeapon.DisplayName == 'Air Crash' ) then 
                    local isAntiAir = primaryWeapon.RangeCategory == 'UWRC_AntiAir'
                    local maxRadius = primaryWeapon.MaxRadius or 0
                    -- land to air units shouldn't get triggered too fast
                    if isLand and isAntiAir then 
                        unit.AI.GuardScanRadius = 0.80 * maxRadius
                    else	-- all other units will have the default value of 10% on top of their maximum attack radius
                        unit.AI.GuardScanRadius = 1.10 * maxRadius
                    end
                -- units with no weaponry don't need this value set
                else 
                    unit.AI.GuardScanRadius = 0
                end
                -- cap it, some units have extreme values based on their attack radius
                if isTech1 and unit.AI.GuardScanRadius > 40 then 
                    unit.AI.GuardScanRadius = 40 
                elseif isTech2 and unit.AI.GuardScanRadius > 80 then 
                    unit.AI.GuardScanRadius = 80
                elseif isTech3 and unit.AI.GuardScanRadius > 120 then 
                    unit.AI.GuardScanRadius = 120
                elseif isExperimental and unit.AI.GuardScanRadius > 160 then 
                    unit.AI.GuardScanRadius = 160
                end
                -- sanitize it
                unit.AI.GuardScanRadius = math.floor(unit.AI.GuardScanRadius)
            end
        end
    end
	--------------------------------------------------------------------------------------
	--This is where the air footprint sanitizing would be, but I'm not about that.
	--------------------------------------------------------------------------------------
    -- # Allow naval factories to correct their roll off points, as they are critical for ships not being stuck
    if unit.CategoriesHash['FACTORY'] and unit.CategoriesHash['NAVAL'] then 
        unit.Physics.CorrectNavalRollOffPoints = true
    end
	--This is where the unit's speed v. hitbox size correction would be, but it prevents me from setting realistic hitboxes on stuff.
    -- # Fix being able to check for command caps
    local unitGeneral = unit.General
    if unitGeneral then
        local commandCaps = unitGeneral.CommandCaps
        if commandCaps then
            unitGeneral.CommandCapsHash = table.deepcopy(commandCaps)
        else
            unitGeneral.CommandCapsHash = {}
        end
    else
        unit.General = {CommandCapsHash = {}}
    end
    -- Pre-compute various elements
    unit.SizeVolume = (unit.SizeX or 1) * (unit.SizeY or 1) * (unit.SizeZ or 1)
    unit.SizeDamageEffects = 1
    unit.SizeDamageEffectsScale = 1
    if unit.SizeVolume > 10 then
        unit.SizeDamageEffects = 2
        unit.SizeDamageEffectsScale = 1.5
        if unit.SizeVolume > 20 then
            unit.SizeDamageEffects = 3
            unit.SizeDamageEffectsScale = 2.0
        end
    end
    unit.Footprint = unit.Footprint or {}
    unit.Footprint.SizeMax = math.max(unit.Footprint.SizeX or 1, unit.Footprint.SizeZ or 1)
    -- Pre-compute intel state
    -- gather data
    local economyBlueprint = unit.Economy
    local intelBlueprint = unit.Intel
    local enhancementBlueprints = unit.Enhancements
    if intelBlueprint or enhancementBlueprints then
        ---@type UnitIntelStatus
        local status = {}
        -- life is good, intel is funded by the government
        local allIntelIsFree = false
        if intelBlueprint.FreeIntel or (
            not enhancementBlueprints and
                (
                (not economyBlueprint) or
                    (not economyBlueprint.MaintenanceConsumptionPerSecondEnergy) or
                    economyBlueprint.MaintenanceConsumptionPerSecondEnergy == 0
                )
            ) then
            allIntelIsFree = true
            status.AllIntelMaintenanceFree = {}
        end
        -- special case: unit has intel that is considered free
        if intelBlueprint.ActiveIntel then
            status.AllIntelMaintenanceFree = status.AllIntelMaintenanceFree or {}
            for intel, _ in intelBlueprint.ActiveIntel do
                status.AllIntelMaintenanceFree[intel] = true
            end
        end
        -- special case: unit has enhancements and therefore can have any intel type
        if enhancementBlueprints then
            status.AllIntelFromEnhancements = {}
        end
        -- usual case: find all remaining intel
        status.AllIntel = {}
        for name, value in intelBlueprint do
            if value == true or value > 0 then
                local intel = BlueprintNameToIntel[name]
                if intel then
                    if allIntelIsFree then
                        status.AllIntelMaintenanceFree[intel] = true
                    else
                        status.AllIntel[intel] = true
                    end
                end
            end
        end
        -- check if we have any intel
        if not (table.empty(status.AllIntel) and table.empty(status.AllIntelMaintenanceFree) and not enhancementBlueprints) then
            -- cache it
            status.AllIntelDisabledByEvent = {}
            status.AllIntelRecharging = {}
            unit.Intel = unit.Intel or {}
            unit.Intel.State = status
        end
    end
    -- Pre-compute use of veterancy
    if (not unit.Weapon[1]) or unit.General.ExcludeFromVeterancy then
        unit.VetEnabled = false
    else
        for index, wep in unit.Weapon do
            if not LabelToVeterancyUse[wep.Label] then
                unit.VetEnabled = true
            end
        end
    end
    unit.VetThresholds = { 0, 0, 0, 0, 0 }
    if unit.VeteranMass then
        unit.VetThresholds[1] = unit.VeteranMass[1]
        unit.VetThresholds[2] = unit.VeteranMass[2] + unit.VetThresholds[1]
        unit.VetThresholds[3] = unit.VeteranMass[3] + unit.VetThresholds[2]
        unit.VetThresholds[4] = unit.VeteranMass[4] + unit.VetThresholds[3]
        unit.VetThresholds[5] = unit.VeteranMass[5] + unit.VetThresholds[4]
    else
        local multiplier = unit.VeteranMassMult or TechToVetMultipliers[unit.TechCategory] or 2
        unit.VetThresholds[1] = 1 * multiplier * (unit.Economy.BuildCostMass or 1)
        unit.VetThresholds[2] = 2 * multiplier * (unit.Economy.BuildCostMass or 1)
        unit.VetThresholds[3] = 3 * multiplier * (unit.Economy.BuildCostMass or 1)
        unit.VetThresholds[4] = 4 * multiplier * (unit.Economy.BuildCostMass or 1)
        unit.VetThresholds[5] = 5 * multiplier * (unit.Economy.BuildCostMass or 1)
    end
    -- Pre-compute weak secondary weapons and weapon overlays
    local weapons = unit.Weapon
    if weapons then
        -- determine total dps per category
        local damagePerRangeCategory = {
            DIRECTFIRE = 0,
            INDIRECTFIRE = 0,
            ANTIAIR = 0,
            ANTINAVY = 0,
            COUNTERMEASURE = 0,
        }
        for k, weapon in weapons do
            local dps = DetermineWeaponDPS(weapon)
            local category = DetermineWeaponCategory(weapon)
            if category then
                damagePerRangeCategory[category] = damagePerRangeCategory[category] + dps
            else
                if weapon.WeaponCategory != 'Death' then
                    -- WARN("Invalid weapon on " .. unit.BlueprintId)
                end
            end
        end
        local array = {
            {
                RangeCategory = "DIRECTFIRE",
                Damage = damagePerRangeCategory["DIRECTFIRE"]
            },
            {
                RangeCategory = "INDIRECTFIRE",
                Damage = damagePerRangeCategory["INDIRECTFIRE"]
            },
            {
                RangeCategory = "ANTIAIR",
                Damage = damagePerRangeCategory["ANTIAIR"]
            },
            {
                RangeCategory = "ANTINAVY",
                Damage = damagePerRangeCategory["ANTINAVY"]
            },
            {
                RangeCategory = "COUNTERMEASURE",
                Damage = damagePerRangeCategory["COUNTERMEASURE"]
            }
        }
        table.sort(array, function(e1, e2) return e1.Damage > e2.Damage end)
        local factor = array[1].Damage
        for category, damage in damagePerRangeCategory do
            if damage > 0 then
                local cat = "OVERLAY" .. category
                if not unit.CategoriesHash[cat] then
                    table.insert(unit.Categories, cat)
                    unit.CategoriesHash[cat] = true
                    unit.CategoriesCount = unit.CategoriesCount + 1
                end

                local cat = "WEAK" .. category
                if not (
                        category == 'COUNTERMEASURE' or
                        unit.CategoriesHash['COMMAND'] or
                        unit.CategoriesHash['STRATEGIC'] or
                        unit.CategoriesHash[cat]
                    ) and damage < 0.2 * factor
                then
                    table.insert(unit.Categories, cat)
                    unit.CategoriesHash[cat] = true
                    unit.CategoriesCount = unit.CategoriesCount + 1
                end
            end
        end
    end
    -- add the defense overlay to shields
    if unit.Defense.Shield and unit.Defense.Shield.ShieldSize > 0 then
        local cat = "OVERLAYDEFENSE"
        if not unit.CategoriesHash[cat] then
            table.insert(unit.Categories, cat)
            unit.CategoriesHash[cat] = true
            unit.CategoriesCount = unit.CategoriesCount + 1
        end
    end
    -- Populate help text field when applicable
    if not (unit.Interface and unit.Interface.HelpText) then
        unit.Interface = unit.Interface or { }
        unit.Interface.HelpText = unit.Description or "" --[[@as string]]
    end
    ---------------------------------------------------------------------------
    --#region (Re) apply the ability to land on water
    -- there was a bug with Rover drones (from the kennel) when they interact
    -- with naval factories. They would first move towards a 'free build 
    -- location' when assisting a naval factory. As they can't land on water, 
    -- that build location could be far away at the shore.
    -- this doesn't fix the problem itself, but it does alleviate it. At least
    -- the drones do not need to go to the shore anymore, they now look for
    -- a 'free build location' near the naval factory on water
    if isAir and (isTransport or isGunship or isPod) and (not isExperimental) then
        table.insert(unit.Categories, "CANLANDONWATER")
        unit.CategoriesHash["CANLANDONWATER"] = true
    end
    --#endregion
end