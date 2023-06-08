-- Layer caps
LAND = 0x01
SEABED = 0x02
SUB = 0x04
WATER = 0x08
AIR = 0x10
ORBIT = 0x20

-- Flags
IgnoreStructures = 0x01

-- Each footprint spec causes pathfinding structures to be created over the entire map for units
-- with that footprint, so keep the number of entries here down to the bare minimum we actually
-- need.
--
-- The script "data/lua/tests/dump_footprints.lua" can be used to figure out what footprint shapes
-- the blueprints are currently expecting.

SpecFootprints {

    { Name = 'Vehicle1x1', SizeX=1, SizeZ=1, Caps=LAND, MaxWaterDepth=0.1 , MaxSlope=0.75, Flags=0 },
    { Name = 'Vehicle2x2', SizeX=2, SizeZ=2, Caps=LAND, MaxWaterDepth=0.1 , MaxSlope=0.75, Flags=0 },
    { Name = 'Vehicle5x5', SizeX=5, SizeZ=5, Caps=LAND, MaxWaterDepth=0.13, MaxSlope=0.75, Flags=IgnoreStructures },

    { Name = 'Amphibious1x1', SizeX=1, SizeZ=1, Caps=LAND|SEABED, MaxWaterDepth=25, MaxSlope=0.75, Flags=0 },
    { Name = 'Amphibious3x3', SizeX=3, SizeZ=3, Caps=LAND|SEABED, MaxWaterDepth=25, MaxSlope=0.75, Flags=IgnoreStructures },
    { Name = 'Amphibious6x6', SizeX=6, SizeZ=6, Caps=LAND|SEABED, MaxWaterDepth=25, MaxSlope=0.75, Flags=IgnoreStructures },

    { Name = 'WaterLand1x1', SizeX=1, SizeZ=1, Caps=LAND|WATER, MaxWaterDepth=2, MinWaterDepth=0, MaxSlope=0.75, Flags=0 },
    { Name = 'WaterLand2x2', SizeX=2, SizeZ=2, Caps=LAND|WATER, MaxWaterDepth=2, MinWaterDepth=0, MaxSlope=0.75, Flags=0 },
    { Name = 'WaterLand2x6', SizeX=2, SizeZ=6, Caps=LAND|WATER, MaxWaterDepth=5, MinWaterDepth=0, MaxSlope=0.75, Flags=0 },
    { Name = 'WaterLand5x5', SizeX=5, SizeZ=5, Caps=LAND|WATER, MaxWaterDepth=5, MinWaterDepth=0, MaxSlope=0.75, Flags=0 },

    { Name = 'SurfacingSub1x3',   SizeX=1,  SizeZ=3,  Caps=SUB|WATER, MinWaterDepth=0.5, Flags=0 },
    { Name = 'SurfacingSub2x5',   SizeX=2,  SizeZ=5,  Caps=SUB|WATER, MinWaterDepth=0.6, Flags=0 },
    { Name = 'SurfacingSub2x6',   SizeX=2,  SizeZ=6,  Caps=SUB|WATER, MinWaterDepth=0.5, Flags=0 },
    { Name = 'SurfacingSub4x22',  SizeX=4,  SizeZ=22, Caps=SUB|WATER, MinWaterDepth=1.5, Flags=0 },
    { Name = 'SurfacingSub16x16', SizeX=16, SizeZ=16, Caps=SUB|WATER, MinWaterDepth=2,   Flags=0 },

    { Name = 'Water1x2',   SizeX=1, SizeZ=2,  Caps=WATER, MinWaterDepth=0.1,  Flags=0 },
    { Name = 'Water2x6',   SizeX=2, SizeZ=6,  Caps=WATER, MinWaterDepth=0.1,  Flags=0 },
    { Name = 'Water2x7',   SizeX=2, SizeZ=7,  Caps=WATER, MinWaterDepth=0.15, Flags=0 },
    { Name = 'Water3x7',   SizeX=3, SizeZ=7,  Caps=WATER, MinWaterDepth=0.15, Flags=0 },
    { Name = 'Water3x12',  SizeX=3, SizeZ=12, Caps=WATER, MinWaterDepth=0.25, Flags=0 },
    { Name = 'Water4x14',  SizeX=4, SizeZ=14, Caps=WATER, MinWaterDepth=0.3, Flags=0 },
    { Name = 'Water5x17',  SizeX=5, SizeZ=17, Caps=WATER, MinWaterDepth=0.3,  Flags=0 },
    { Name = 'Water7x19',  SizeX=7, SizeZ=19, Caps=WATER, MinWaterDepth=0.4, Flags=0 },
}
