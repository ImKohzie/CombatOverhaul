--!strict
-- Layout numbers for the generated map "New Harbor" + forest ring.
-- The world is centred on (0, 0, 0); ground level is y = GroundY.
-- Avenues run north-south (constant X), streets run east-west (constant Z).

local MapConfig = {}

MapConfig.Seed = 1947
MapConfig.Generate = true -- build the map on server start if it isn't in the place yet
MapConfig.ModelName = "NewHarbor"
MapConfig.GroundY = 0.1
MapConfig.YieldEvery = 350 -- parts created before yielding a frame during generation

MapConfig.City = {
	HalfSize = 1250,
	AvenueSpacing = 250,
	StreetSpacing = 125,
	AvenueWidth = 36,
	StreetWidth = 26,
	SidewalkWidth = 8,
	CurbHeight = 0.6,
	DowntownRadius = 700, -- skyscrapers inside, brownstones outside
}

-- Central park replaces the blocks and interior roads inside this rectangle.
MapConfig.Park = { MinX = -250, MaxX = 250, MinZ = -375, MaxZ = 375 }

-- Harbour: water east of the waterfront avenue, with piers and a bridge.
MapConfig.Harbor = {
	WaterfrontX = 1000, -- last avenue before the water
	WaterMinX = 1030,
	WaterMaxX = 1760,
	WaterMinZ = -1500,
	WaterMaxZ = 1500,
	WaterSurfaceY = -3,
	WaterDepth = 30,
	PierCount = 6,
}

MapConfig.Bridge = { Z = 0, StartX = 1000, EndX = 1850, DeckY = 26, Width = 40 }

MapConfig.Train = { X = -750, DeckY = 30, PillarSpacing = 50, Cars = 3, Speed = 40 }

MapConfig.Forest = {
	OuterRadius = 3600, -- terrain extends a little past the border
	TreeCount = 1500,
	HillCount = 60,
	Lake = { X = -2350, Z = -2250, Radius = 190 },
	Cabin = { X = -2150, Z = -1950 },
	TerrainTile = 480,
	TerrainDepth = 14,
}

-- Highway (polyline, y follows terrain) and the roads linking city and forest.
MapConfig.Highway = {
	Width = 34,
	Points = {
		Vector3.new(1850, 0, 0), Vector3.new(2300, 0, -300), Vector3.new(2650, 0, -1000),
		Vector3.new(2500, 0, -1900), Vector3.new(1700, 0, -2600), Vector3.new(500, 0, -2900),
		Vector3.new(-700, 0, -2850), Vector3.new(-1800, 0, -2600), Vector3.new(-2700, 0, -1800),
		Vector3.new(-2950, 0, -600), Vector3.new(-2850, 0, 700), Vector3.new(-2400, 0, 1800),
		Vector3.new(-1500, 0, 2600), Vector3.new(-200, 0, 2900), Vector3.new(1100, 0, 2750),
		Vector3.new(2100, 0, 2200), Vector3.new(2600, 0, 1200), Vector3.new(2300, 0, 300),
		Vector3.new(1850, 0, 0),
	},
}

MapConfig.ConnectorRoads = {
	{ From = Vector3.new(0, 0, -1250), To = Vector3.new(0, 0, -2880), Width = 26 },
	{ From = Vector3.new(0, 0, 1250), To = Vector3.new(-100, 0, 2890), Width = 26 },
	{ From = Vector3.new(-1250, 0, 0), To = Vector3.new(-2920, 0, 0), Width = 26 },
	{ From = Vector3.new(-1250, 0, -1000), To = Vector3.new(-2150, 0, -1950), Width = 18 }, -- cabin road
}

MapConfig.Border = {
	Radius = 3500,
	WarnDistance = 250,
	PushStrength = 60, -- studs/second pushback at the wall
}

-- Original brand names for billboards (no real brands).
MapConfig.Brands = {
	"NOVA COLA", "ZENITH AIR", "HARBOR TRUST", "PULSE NEWS", "OKAMI RAMEN",
	"BRIGHTLINE", "CORVID MOTORS", "LUMEN TV", "SKYLARK SHOES", "IRONLEAF COFFEE",
}

return MapConfig
