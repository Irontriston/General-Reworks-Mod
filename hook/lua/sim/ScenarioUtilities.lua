
#--[  CreateResources: Modified to use the new splats.   ]--
function CreateResources()
    local markers = GetMarkers()
    for i, tblData in pairs(markers) do
        if tblData.resource then
            CreateResourceDeposit(
                tblData.type,
                tblData.position[1], tblData.position[2], tblData.position[3],
                tblData.size
            )

            # fixme: texture names should come from editor
            local albedo, sx, sz, lod
            if tblData.type == "Mass" then
                albedo = "/mods/GeneralReworks/hook/env/common/splats/mass_marker.dds"
                sx = 2.3
                sz = 2.3
                lod = 300
                CreatePropHPR(
                    '/env/common/props/massDeposit01_prop.bp',
                    tblData.position[1], tblData.position[2], tblData.position[3],
                    Random(0,360), 0, 0
                )
            else
                albedo = "/mods/GeneralReworks/hook/env/common/splats/hydrocarbon_marker.dds"
                sx = 7.2
                sz = 7.2
                lod = 650
                CreatePropHPR(
                    '/env/common/props/hydrocarbonDeposit01_prop.bp',
                    tblData.position[1], tblData.position[2], tblData.position[3],
                    Random(0,360), 0, 0
                )
            end
            # Decal - (position, heading, textureName1, textureName2, type, sizeX, sizeZ, lodParam, duration, army)
            # Splat - (position, heading, textureName1, textureName2, type, sizeX, sizeZ, lodParam, duration, army)
#            if not ScenarioInfo.MapData.Decals then
#                ScenarioInfo.MapData.Decals = {}
#            end
#            table.insert( ScenarioInfo.MapData.Decals, CreateDecal(
#                tblData.position, # position
#                0, # heading
#                albedo, "", # TEX1, TEX2
#                "Albedo", # TYPE
#                sx, sz, # SIZE
#                lod, # LOD
#                0, # DURATION
#                -1 # ARMY
#            ) )
            CreateSplat(
                tblData.position,  # Position on the map
                0,                 # Heading, or rotation
                albedo,            # Texture path and name for albedo
                sx, sz,            # Sizes x & z in o-grids
                lod,               # LOD
                0,                 # Duration (0 for no expiration)
                -1 ,               # army (-1 for unowned)
                0
            )
        end
    end
end
