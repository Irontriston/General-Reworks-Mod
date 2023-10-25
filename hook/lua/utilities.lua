function GetStandAloneEntitiesInRect(x1, z1, x2, z2)
	local AllEntities = GetEntitiesInRect(x1, z1, x2, z2)
	if not AllEntities then
		return nil
	end
	local SortedEntities = {}
	local HitBoxExtras = {}
	for _, Ent in AllEntities do
		if not Ent.HitBox then
			table.insert(SortedEntities, Ent)
		end
		if Ent.Hitbox then
			table.insert(HitBoxExtras, Ent)
		end
	end
	--These wait to be called after so that no doubles accidentally make it into the final result.
	for _, Box in HitBoxExtras do
		if not table.find(SortedEntities, Box.Owner) then
			table.insert(SortedEntities, Box.Owner)
		end
	end
	LOG('Sorted Entities: ')
	LOG(reprsl(SortedEntities))
	return SortedEntities
end

--[[ Note: Includes allied units in selection!!
function GetEnemyUnitsInSphere(unit, position, radius)
    local x1 = position.x - radius
    local y1 = position.y - radius
    local z1 = position.z - radius
    local x2 = position.x + radius
    local y2 = position.y + radius
    local z2 = position.z + radius
    local UnitsinRec = GetUnitsInRect(x1, z1, x2, z2)

    -- Check for empty rectangle
    if not UnitsinRec then
        return UnitsinRec
    end

    local RadEntities = {}
    for _, v in UnitsinRec do
        local dist = VDist3(position, v:GetPosition())
        if v.UnitID and unit.Army ~= v.Army and dist <= radius then
            table.insert(RadEntities, v)
        end
    end

    return RadEntities
end]]

-- This function has been simplified bc it basically just modifies GetEnemyUnitsInSphere().
function GetTrueEnemyUnitsInSphere(unit, position, radius, categoriesX)
    local UnitsinRec = GetEnemyUnitsInSphere(unit, position, radius)--This gets all entities in the sphere not under the control of the projectile's army.
    if not UnitsinRec then
        return UnitsinRec
    end
    local RadEntities = {}
    for _, v in UnitsinRec do--This just weeds out allies and categorically nonabiding units.
        if not IsAlly(unit.Army, v.Army) and EntityCategoryContains(categoriesX or categories.ALLUNITS, v) then
            table.insert(RadEntities, v)
        end
    end
    return RadEntities
end