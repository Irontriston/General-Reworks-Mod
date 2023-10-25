-- Sets the playable area for an operation to `rect`. Can be an area name or rectangle.
---@param rect Area | Rectangle
---@param voFlag? boolean # defaults to `true`
function SetPlayableArea(rect, voFlag)--The change here is that there is no more rounding.
    if voFlag == nil then
        voFlag = true
    end

    if type(rect) == 'string' then
        rect = ScenarioUtils.AreaToRect(rect)
    end

    local x0 = rect.x0
    local y0 = rect.y0
    local x1 = rect.x1
    local y1 = rect.y1

    LOG(string.format('Debug: SetPlayableArea before round : %s, %s %s, %s', rect.x0, rect.y0, rect.x1, rect.y1))
    LOG(string.format('Debug: SetPlayableArea after round : %s, %s %s, %s', x0, y0, x1, y1))

    ScenarioInfo.MapData.PlayableRect = {x0, y0, x1, y1}
    rect.x0 = x0
    rect.x1 = x1
    rect.y0 = y0
    rect.y1 = y1

    SetPlayableRect(x0, y0, x1, y1)
    if voFlag then
        ForkThread(PlayableRectCameraThread, rect)
        SyncVoice({Cue = 'Computer_Computer_MapExpansion_01380', Bank = 'XGG'})
    end

    import("/lua/simsync.lua").SyncPlayableRect(rect)
    Sync.NewPlayableArea = {x0, y0, x1, y1}
    ForkThread(GenerateOffMapAreas)
end