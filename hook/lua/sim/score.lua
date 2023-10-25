historyInterval = 10
scoreInterval = 1
alliesScore = true

---@param brain AIBrain
---@return number
function CalculateBrainScore(brain)
    local commanderKills = brain:GetArmyStat("Enemies_Commanders_Destroyed", 0).Value
    local massSpent = brain:GetArmyStat("Economy_TotalConsumed_Mass", 0).Value
    local energySpent = brain:GetArmyStat("Economy_TotalConsumed_Energy", 0).Value
    local massValueDestroyed = brain:GetArmyStat("Enemies_MassValue_Destroyed", 0).Value
    local massValueLost = brain:GetArmyStat("Units_MassValue_Lost", 0).Value
    local energyValueDestroyed = brain:GetArmyStat("Enemies_EnergyValue_Destroyed", 0).Value
    local energyValueLost = brain:GetArmyStat("Units_EnergyValue_Lost", 0).Value

    -- helper variables to make equation more clear
    local energyValueCoefficient = 20

    -- score components calculated, command is very different bc of the changes to the comms themselves.
    local resourceProduction = (massSpent + (energySpent / energyValueCoefficient)) / 2
    local battleResults = math.max(0, ((massValueDestroyed - massValueLost - (commanderKills * 11200)) +
        ((energyValueDestroyed - energyValueLost - (commanderKills * 106000)) / energyValueCoefficient)) / 2)

    -- score calculated
    return math.floor(resourceProduction + battleResults + (commanderKills * 2000))
end
