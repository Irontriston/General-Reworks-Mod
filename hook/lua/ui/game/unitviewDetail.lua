function FormatTime(seconds)
    return string.format("%02d:%02d", math.floor(seconds / 60), math.mod(seconds, 60))
end

function ShowEnhancement(bp, bpID, iconID, iconPrefix, userUnit)
    if not CheckFormat() then
        View:Hide()
        return
    end

    -- Name / Description
    View.UnitImg:SetTexture(UIUtil.UIFile(iconPrefix..'_btn_up.dds'))

    LayoutHelpers.AtTopIn(View.UnitShortDesc, View, 10)
    View.UnitShortDesc:SetFont(UIUtil.bodyFont, 14)

    local slotName = enhancementSlotNames[string.lower(bp.Slot)]
    slotName = slotName or bp.Slot

    if bp.Name ~= nil then
        View.UnitShortDesc:SetText(LOCF("%s: %s", bp.Name, slotName))
    else
        View.UnitShortDesc:SetText(LOC(slotName))
    end
    if View.UnitShortDesc:GetStringAdvance(View.UnitShortDesc:GetText()) > View.UnitShortDesc.Width() then
        LayoutHelpers.AtTopIn(View.UnitShortDesc, View, 14)
        View.UnitShortDesc:SetFont(UIUtil.bodyFont, 10)
    end

    local showecon = true
    local showAbilities = false
    local showUpKeep = false
    local time, energy, mass
    if bp.Icon ~= nil and not string.find(bp.Name, 'Remove') then
        time, energy, mass = import("/lua/game.lua").GetConstructEconomyModel(userUnit, bp)
        time = math.max(time, 0.01)
        showUpKeep = DisplayResources(bp, time, energy, mass)
        View.TimeStat.Value:SetFont(UIUtil.bodyFont, 14)
        View.TimeStat.Value:SetText(string.format("%s", FormatTime(time)))
        if string.len(View.TimeStat.Value:GetText()) > 5 then
            View.TimeStat.Value:SetFont(UIUtil.bodyFont, 10)
        end
    else
        showecon = false
        if View.Description then
            View.Description:Hide()
            for i, v in View.Description.Value do
                v:SetText("")
            end
        end
    end

    if View.Description then
        -- If enhancement of preset, then remove extension. (ual0301_Engineer -> ual0301)
        if string.find(bpID, '_') then
            bpID = string.sub(bpID, 1, string.find(bpID, "_[^_]*$")-1)
        end
        WrapAndPlaceText(nil, nil, bpID.."-"..iconID, View.Description)
    end

    local showShield = false
    if bp.ShieldMaxHealth then
        showShield = true
        View.ShieldStat.Value:SetText(bp.ShieldMaxHealth)
    end

    ShowView(showUpKeep, true, showecon, showShield)
    if time == 0 and energy == 0 and mass == 0 then
        View.BuildCostGroup:Hide()
        View.TimeStat:Hide()
    end
end

function CreateLines(control, blocks)
    local i = 0
    local prevText = control.Value[1]
    for _, block in blocks do
        for _, line in block.lines do
            i = i + 1
            local text = control.Value[i]
            if text then
                text:SetText(line)
            else
                text = UIUtil.CreateText(control, line, 12, UIUtil.bodyFont)
                LayoutHelpers.Below(text, prevText)
                text.Width:Set(prevText.Width)
                text:DisableHitTest()
                control.Value[i] = text
            end
            text:SetColor(block.color)
            prevText = text
        end
    end
    if i > 0 then
        control.Height:Set(prevText.Bottom() - control.Value[1].Top() + LayoutHelpers.ScaleNumber(30))
    else
        control.Height:Set(LayoutHelpers.ScaleNumber(30))
    end
    for i = i + 1, table.getsize(control.Value) do
        control.Value[i]:SetText('')
    end
end

GetAbilityDesc = {
    ability_radar = function(bp)
        return LOCF('<LOC uvd_Radius>', bp.Intel.RadarRadius)
    end,
    ability_sonar = function(bp)
        return LOCF('<LOC uvd_Radius>', bp.Intel.SonarRadius)
    end,
    ability_omni = function(bp)
        return LOCF('<LOC uvd_Radius>', bp.Intel.OmniRadius)
    end,
    ability_flying = function(bp)
        return LOCF("<LOC uvd_0011>Speed: %0.2f, Turning: %0.2f", bp.Air.MaxAirspeed, bp.Air.TurnSpeed)
    end,
    ability_carrier = function(bp)
        return LOCF('<LOC uvd_StorageSlots>', bp.Transport.StorageSlots)
    end,
    ability_factory = function(bp)
        return LOCF('<LOC uvd_BuildRate>', bp.Economy.BuildRate)
    end,
    ability_upgradable = function(bp)
        return GetShortDesc(__blueprints[bp.General.UpgradesTo])
    end,
    ability_tacticalmissledeflect = function(bp)
        return LOCF('<LOC uvd_Radius>', bp.Defense.AntiMissile.Radius)..', '
             ..LOCF('<LOC uvd_FireRate>', 1 / bp.Defense.AntiMissile.RedirectRateOfFire)
    end,
    ability_transportable = function(bp)
        return LOCF('<LOC uvd_UnitSize>', bp.Transport.TransportClass)
    end,
    ability_transport = function(bp)
        local text = LOC('<LOC uvd_Capacity>')
        return bp.Transport and bp.Transport.Class1Capacity and text..bp.Transport.Class1Capacity
            or bp.CategoriesHash.TECH1 and text..'≈6'
            or bp.CategoriesHash.TECH2 and text..'≈12'
            or bp.CategoriesHash.TECH3 and text..'≈28'
            or ''
    end,
    ability_airstaging = function(bp)
        return LOCF('<LOC uvd_RepairRate>', bp.Transport.RepairRate)..', '
             ..LOCF('<LOC uvd_DockingSlots>', bp.Transport.DockingSlots)
    end,
    ability_jamming = function(bp)
        return LOCF('<LOC uvd_Radius>', bp.Intel.JamRadius.Max)..', '
             ..LOCF('<LOC uvd_Blips>', bp.Intel.JammerBlips)
    end,
    ability_personalshield = function(bp)
        return LOCF('<LOC uvd_RegenRate>', bp.Defense.Shield.ShieldRegenRate)
    end,
    ability_shielddome = function(bp)
        return LOCF('<LOC uvd_Radius>', bp.Defense.Shield.ShieldSize)..', '
             ..LOCF('<LOC uvd_RegenRate>', bp.Defense.Shield.ShieldRegenRate)
    end,
    ability_stealthfield = function(bp)
        return LOCF('<LOC uvd_Radius>', bp.Intel.RadarStealthFieldRadius)
    end,
    ability_stealth_sonarfield = function(bp)
        return LOCF('<LOC uvd_Radius>', bp.Intel.SonarStealthFieldRadius)
    end,
    ability_customizable = function(bp)
        local cnt = 0
        for _, v in bp.Enhancements do
            if v.RemoveEnhancements or (not v.Slot) then continue end
            cnt = cnt + 1
        end
        return cnt
    end,
    ability_massive = function(bp)
        return string.format(LOC('<LOC uvd_0010>Damage: %.2f, Splash: %.2f'),
            bp.Display.MovementEffects.Land.Footfall.Damage.Amount,
            bp.Display.MovementEffects.Land.Footfall.Damage.Radius)
    end,
    ability_personal_teleporter = function(bp)
        if not bp.General.TeleportDelay then return '' end
        return LOCF('<LOC uvd_Delay>', bp.General.TeleportDelay)
    end
}

function WrapAndPlaceText(bp, builder, descID, control)
    local lines = {}
    local blocks = {}
    --Unit description
    local text = LOC(UnitDescriptions[descID])
    if text and text ~='' then
        table.insert(blocks, {color = UIUtil.fontColor,
            lines = WrapText(text, control.Value[1].Width(), function(text)
                return control.Value[1]:GetStringAdvance(text)
            end)})
        table.insert(blocks, {color = UIUtil.bodyColor, lines = {''}})
    end

    if builder and bp.EnhancementPresetAssigned then
        table.insert(lines, LOC('<LOC uvd_upgrades>')..':')
        for _, v in bp.EnhancementPresetAssigned.Enhancements do
            table.insert(lines, '    '..LOC(bp.Enhancements[v].Name))
        end
        table.insert(blocks, {color = 'FFB0FFB0', lines = lines})
    elseif bp then
        --Get not autodetected abilities
        if bp.Display.Abilities then
            for _, id in bp.Display.Abilities do
                local ability = ExtractAbilityFromString(id)
                if not IsAbilityExist[ability] then
                    table.insert(lines, LOC(id))
                end
            end
        end
        --Autodetect abilities exclude engineering
        for id, func in IsAbilityExist do
            if (id ~= 'ability_engineeringsuite') and (id ~= 'ability_building') and
               (id ~= 'ability_repairs') and (id ~= 'ability_reclaim') and (id ~= 'ability_capture') and func(bp) then
                local ability = LOC('<LOC '..id..'>')
                if GetAbilityDesc[id] then
                    local desc = GetAbilityDesc[id](bp)
                    if desc ~= '' then
                        ability = ability..' - '..desc
                    end
                end
                table.insert(lines, ability)
            end
        end
        if not table.empty(lines) then
            table.insert(lines, '')
        end
        table.insert(blocks, {color = 'FF7FCFCF', lines = lines})
        --Autodetect engineering abilities
        if IsAbilityExist.ability_engineeringsuite(bp) then
            lines = {}
            table.insert(lines, LOC('<LOC '..'ability_engineeringsuite'..'>')
                ..' - '..LOCF('<LOC uvd_BuildRate>', bp.Economy.BuildRate)
                ..', '..LOCF('<LOC uvd_Radius>', bp.Economy.MaxBuildDistance))
            local orders = LOC('<LOC order_0011>')
            if IsAbilityExist.ability_building(bp) then
                orders = orders..', '..LOC('<LOC order_0001>')
            end
            if IsAbilityExist.ability_repairs(bp) then
                orders = orders..', '..LOC('<LOC order_0005>')
            end
            if IsAbilityExist.ability_reclaim(bp) then
                orders = orders..', '..LOC('<LOC order_0006>')
            end
            if IsAbilityExist.ability_capture(bp) then
                orders = orders..', '..LOC('<LOC order_0007>')
            end
            table.insert(lines, orders)
            table.insert(lines, '')
            table.insert(blocks, {color = 'FFFFFFB0', lines = lines})
        end

        if options.gui_render_armament_detail == 1 then
            --Armor values
            lines = {}
            local armorType = bp.Defense.ArmorType
            if armorType and armorType ~= '' then
                local spaceWidth = control.Value[1]:GetStringAdvance(' ')
                local str = LOC('<LOC uvd_ArmorType>')..LOC('<LOC at_'..armorType..'>')
                local spaceCount = (195 - control.Value[1]:GetStringAdvance(str)) / spaceWidth
                str = str..string.rep(' ', spaceCount)..LOC('<LOC uvd_DamageTaken>')
                table.insert(lines, str)
                for _, armor in armorDefinition do
                    if armor[1] == armorType then
                        local row = 0
                        local armorDetails = ''
                        local elemCount = table.getsize(armor)
                        for i = 2, elemCount do
                            --if string.find(armor[i], '1.0') > 0 then continue end
                            local armorName = armor[i]
                            armorName = string.sub(armorName, 1, string.find(armorName, ' ') - 1)
                            armorName = LOC('<LOC an_'..armorName..'>')..' - '..string.format('%0.2f', tonumber(armor[i]:sub(armorName:len() + 2, armor[i]:len())) * 100)
                            if row < 1 then
                                armorDetails = armorName
                                row = 1
                            else
                                local spaceCount = (195 - control.Value[1]:GetStringAdvance(armorDetails)) / spaceWidth
                                armorDetails = armorDetails..string.rep(' ', spaceCount)..armorName
                                table.insert(lines, armorDetails)
                                armorDetails = ''
                                row = 0
                            end
                        end
                        if armorDetails ~= '' then
                            table.insert(lines, armorDetails)
                        end
                    end
                end
                table.insert(lines, '')
                table.insert(blocks, {color = 'FF7FCFCF', lines = lines})
            end
            --Weapons
            if not table.empty(bp.Weapon) then
                local weapons = {upgrades = {normal = {}, death = {}},
                                    basic = {normal = {}, death = {}}}
                for _, weapon in bp.Weapon do
                    if not weapon.WeaponCategory then continue end
                    local dest = weapons.basic
                    if weapon.EnabledByEnhancement then
                        dest = weapons.upgrades
                    end
                    if (weapon.FireOnDeath) or (weapon.WeaponCategory == 'Death') then
                        dest = dest.death
                    else
                        dest = dest.normal
                    end
                    if dest[weapon.DisplayName] then
                        dest[weapon.DisplayName].count = dest[weapon.DisplayName].count + 1
                    else
                        dest[weapon.DisplayName] = {info = weapon, count = 1}
                    end
                end
                for k, v in weapons do
                    if not table.empty(v.normal) or not table.empty(v.death) then
                        table.insert(blocks, {color = UIUtil.fontColor, lines = {LOC('<LOC uvd_'..k..'>')..':'}})
                    end
                    for name, weapon in v.normal do
                        local info = weapon.info
                        local weaponDetails1 = LOCStr(name)..' ('..LOCStr(info.WeaponCategory)..') '
                        if info.ManualFire then
                            weaponDetails1 = weaponDetails1..LOC('<LOC uvd_ManualFire>')
                        end
                        local weaponDetails2
                        if info.NukeInnerRingDamage then
                            weaponDetails2 = string.format(LOC('<LOC uvd_0014>Damage: %.2f - %.2f, Splash: %.2f - %.2f')..', '..LOC('<LOC uvd_Range>'),
                                info.NukeInnerRingDamage + info.NukeOuterRingDamage, info.NukeOuterRingDamage,
                                info.NukeInnerRingRadius, info.NukeOuterRingRadius, info.MinRadius, info.MaxRadius)
                        else
                            local MuzzleBones = 0
                            if info.MuzzleSalvoDelay > 0 then
                                MuzzleBones = info.MuzzleSalvoSize
                            elseif info.RackBones then
                                for _, v in info.RackBones do
                                    MuzzleBones = MuzzleBones + table.getsize(v.MuzzleBones)
                                end
                                if not info.RackFireTogether then
                                    MuzzleBones = MuzzleBones / table.getsize(info.RackBones)
                                end
                            else
                                MuzzleBones = 1
                            end

                            local Damage = info.Damage
                            if info.DamageToShields then
                                Damage = math.max(Damage, info.DamageToShields)
                            end
                            Damage = Damage * (info.DoTPulses or 1)
                            local ProjectilePhysics = __blueprints[info.ProjectileId].Physics
                            while ProjectilePhysics do
                                Damage = Damage * (ProjectilePhysics.Fragments or 1)
                                ProjectilePhysics = __blueprints[string.lower(ProjectilePhysics.FragmentId or '')].Physics
                            end

                            local ReloadTime = math.max((info.RackSalvoChargeTime or 0) + (info.RackSalvoReloadTime or 0) +
                                (info.MuzzleSalvoDelay or 0) * (info.MuzzleSalvoSize or 1), 1 / info.RateOfFire)

                            if not info.ManualFire and info.WeaponCategory ~= 'Kamikaze' then
                                local DPS = Damage * MuzzleBones
                                if info.BeamLifetime > 0 then
                                    DPS = DPS * info.BeamLifetime * 10
                                end
                                DPS = DPS / ReloadTime + (info.InitialDamage or 0)
                                weaponDetails1 = weaponDetails1..LOCF('<LOC uvd_DPS>', DPS)
                            end

                            weaponDetails2 = string.format(LOC('<LOC uvd_0010>Damage: %.2f, Splash: %.2f')..', '..LOC('<LOC uvd_Range>')..', '..LOC('<LOC uvd_Reload>'),
                                Damage, info.DamageRadius, info.MinRadius, info.MaxRadius, ReloadTime)
                        end
                        if weapon.count > 1 then
                            weaponDetails1 = weaponDetails1..' x'..weapon.count
                        end
                        table.insert(blocks, {color = UIUtil.fontColor, lines = {weaponDetails1}})
                        table.insert(blocks, {color = 'FFFFB0B0', lines = {weaponDetails2}})
                    end
                    lines = {}
                    for name, weapon in v.death do
                        local info = weapon.info
                        local weaponDetails = LOCStr(name)..' ('..LOCStr(info.WeaponCategory)..') '
                        if info.NukeInnerRingDamage then
                            weaponDetails = weaponDetails..LOCF('<LOC uvd_0014>Damage: %.2f - %.2f, Splash: %.2f - %.2f',
                                info.NukeInnerRingDamage + info.NukeOuterRingDamage, info.NukeOuterRingDamage,
                                info.NukeInnerRingRadius, info.NukeOuterRingRadius)
                        else
                            weaponDetails = weaponDetails..LOCF('<LOC uvd_0010>Damage: %.2f, Splash: %.2f',
                                info.Damage, info.DamageRadius)
                        end
                        if weapon.count > 1 then
                            weaponDetails = weaponDetails..' x'..weapon.count
                        end
                        table.insert(lines, weaponDetails)
                    end
                    if not table.empty(v.normal) or not table.empty(v.death) then
                        table.insert(lines, '')
                    end
                    table.insert(blocks, {color = 'FFFF0000', lines = lines})
                end
            end
        end
        --Other parameters
        lines = {}
        table.insert(lines, LOCF("<LOC uvd_0013>Vision: %0.2, Underwater Vision: %0.2, Regen: %0.2f, Cap Cost: %0.2f",
            bp.Intel.VisionRadius, bp.Intel.WaterVisionRadius, bp.Defense.RegenRate, bp.General.CapCost))

        if (bp.Physics.MotionType ~= 'RULEUMT_Air' and bp.Physics.MotionType ~= 'RULEUMT_None')
        or (bp.Physics.AltMotionType ~= 'RULEUMT_Air' and bp.Physics.AltMotionType ~= 'RULEUMT_None') then
            table.insert(lines, LOCF("<LOC uvd_0012>Speed: %0.2f, Reverse: %0.2f, Acceleration: %0.2f, Turning: %0.2f",
                bp.Physics.MaxSpeed, bp.Physics.MaxSpeedReverse, bp.Physics.MaxAcceleration, bp.Physics.TurnRate))
        end

        table.insert(blocks, {color = 'FFB0FFB0', lines = lines})
    end
    CreateLines(control, blocks)
end

function Show(bp, builderUnit, bpID)
    if not CheckFormat() then
        View:Hide()
        return
    end

    -- Name / Description
    LayoutHelpers.AtTopIn(View.UnitShortDesc, View, 10)
    View.UnitShortDesc:SetFont(UIUtil.bodyFont, 14)

    View.UnitShortDesc:SetText(GetShortDesc(bp))

    local scale = View.UnitShortDesc.Width() / View.UnitShortDesc.TextAdvance()
    if scale < 1 then
        LayoutHelpers.AtTopIn(View.UnitShortDesc, View, 10 / scale)
        View.UnitShortDesc:SetFont(UIUtil.bodyFont, 14 * scale)
    end
    local showecon = true
    local showUpKeep = false
    local showAbilities = false
    if builderUnit ~= nil then
        -- Differential upgrading. Check to see if building this would be an upgrade
        local targetBp = bp
        local builderBp = builderUnit:GetBlueprint()

        local performUpgrade = false

        if targetBp.General.UpgradesFrom == builderBp.BlueprintId then
            performUpgrade = true
        elseif targetBp.General.UpgradesFrom == builderBp.General.UpgradesTo then
            performUpgrade = true
        elseif targetBp.General.UpgradesFromBase ~= "none" then
            -- try testing against the base
            if targetBp.General.UpgradesFromBase == builderBp.BlueprintId then
                performUpgrade = true
            elseif targetBp.General.UpgradesFromBase == builderBp.General.UpgradesFromBase then
                performUpgrade = true
            end
        end

        local time, energy, mass

        if performUpgrade then
            time, energy, mass = import("/lua/game.lua").GetConstructEconomyModel(builderUnit, bp.Economy, builderBp.Economy)
        else
            time, energy, mass = import("/lua/game.lua").GetConstructEconomyModel(builderUnit, bp.Economy)
        end

        time = math.max(time, 0.01)
        showUpKeep = DisplayResources(bp, time, energy, mass)
        View.TimeStat.Value:SetFont(UIUtil.bodyFont, 14)
        View.TimeStat.Value:SetText(string.format("%s", FormatTime(time)))
        if string.len(View.TimeStat.Value:GetText()) > 5 then
            View.TimeStat.Value:SetFont(UIUtil.bodyFont, 10)
        end
    else
        showecon = false
    end

    -- Health stat
    View.HealthStat.Value:SetText(string.format("%.2f", bp.Defense.MaxHealth))

    if View.Description then
        WrapAndPlaceText(bp, builderUnit, bpID, View.Description)
    end
    local showShield = false
    if bp.Defense.Shield and bp.Defense.Shield.ShieldMaxHealth then
        showShield = true
        View.ShieldStat.Value:SetText(bp.Defense.Shield.ShieldMaxHealth)
    end

    local iconName = GameCommon.GetCachedUnitIconFileNames(bp)
    View.UnitImg:SetTexture(iconName)
    LayoutHelpers.SetDimensions(View.UnitImg, 46, 46)

    ShowView(showUpKeep, false, showecon, showShield)
end

function DisplayResources(bp, time, energy, mass)
    -- Cost Group
    if time > 0 then
        local consumeEnergy = -energy / time
        local consumeMass = -mass / time
        View.BuildCostGroup.EnergyValue:SetText(string.format("%.2f (%.2f)",-energy,consumeEnergy))
        View.BuildCostGroup.MassValue:SetText(string.format("%.2f (%.2f)",-mass,consumeMass))

        View.BuildCostGroup.EnergyValue:SetColor("FFF05050")
        View.BuildCostGroup.MassValue:SetColor("FFF05050")
    end

    -- Upkeep Group
    local upkeepEnergy, upkeepMass = GetUpkeep(bp)
    local showUpkeep = false
    if upkeepEnergy ~= 0 or upkeepMass ~= 0 then
        View.UpkeepGroup.Label:SetText(LOC("<LOC uvd_0002>Yield"))
        View.UpkeepGroup.EnergyValue:SetText(string.format("%.2f",upkeepEnergy))
        View.UpkeepGroup.MassValue:SetText(string.format("%.2f",upkeepMass))
        if upkeepEnergy >= 0 then
            View.UpkeepGroup.EnergyValue:SetColor("FF64ff55")
        else
            View.UpkeepGroup.EnergyValue:SetColor("FFF05050")
        end

        if upkeepMass >= 0 then
            View.UpkeepGroup.MassValue:SetColor("FF50F050")
        else
            View.UpkeepGroup.MassValue:SetColor("FFF05050")
        end
        showUpkeep = true
    elseif bp.Economy and (bp.Economy.StorageEnergy ~= 0 or bp.Economy.StorageMass ~= 0) then
        View.UpkeepGroup.Label:SetText(LOC("<LOC uvd_0006>Storage"))
        local upkeepEnergy = bp.Economy.StorageEnergy or 0
        local upkeepMass = bp.Economy.StorageMass or 0
        View.UpkeepGroup.EnergyValue:SetText(string.format("%.2f",upkeepEnergy))
        View.UpkeepGroup.MassValue:SetText(string.format("%.2f",upkeepMass))
        View.UpkeepGroup.EnergyValue:SetColor("FF50F050")
        View.UpkeepGroup.MassValue:SetColor("FF50F050")
        showUpkeep = true
    end

    return showUpkeep
end