--!strict
-- The forest ring around New Harbor: terrain ground with hills, the harbour
-- water, a lake and a river, a winding highway plus roads linking the city
-- to the forest, ~1500 trees and a ranger cabin.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MapConfig = require(ReplicatedStorage:WaitForChild("ApexCity").Config.MapConfig)

local Builder = require(script.Parent.Builder)
local Props = require(script.Parent.Props)

local ForestGenerator = {}

local terrain = workspace.Terrain
local Forest = MapConfig.Forest
local CITY_EDGE = MapConfig.City.HalfSize + 10

--------------------------------------------------------------------------------
-- Terrain
--------------------------------------------------------------------------------
local function fillRect(minX: number, maxX: number, minZ: number, maxZ: number, material: Enum.Material)
	local tile = Forest.TerrainTile
	local depth = Forest.TerrainDepth
	local x = minX
	while x < maxX do
		local w = math.min(tile, maxX - x)
		local z = minZ
		while z < maxZ do
			local d = math.min(tile, maxZ - z)
			terrain:FillBlock(CFrame.new(x + w / 2, -depth / 2, z + d / 2), Vector3.new(w, depth, d), material)
			z += d
			task.wait()
		end
		x += w
	end
end

local function groundRing()
	local r = Forest.OuterRadius
	fillRect(-r, r, -r, -CITY_EDGE, Enum.Material.Grass)
	fillRect(-r, r, CITY_EDGE, r, Enum.Material.Grass)
	fillRect(-r, -CITY_EDGE, -CITY_EDGE, CITY_EDGE, Enum.Material.Grass)
	fillRect(CITY_EDGE, r, -CITY_EDGE, CITY_EDGE, Enum.Material.Grass)
end

local function inForest(x: number, z: number, margin: number): boolean
	return (math.abs(x) > CITY_EDGE + margin or math.abs(z) > CITY_EDGE + margin) and math.sqrt(x * x + z * z) < MapConfig.Border.Radius - 40
end

local function inHarborWater(x: number, z: number, margin: number): boolean
	local h = MapConfig.Harbor
	return x > h.WaterMinX - margin and x < h.WaterMaxX + margin and z > h.WaterMinZ - margin and z < h.WaterMaxZ + margin
end

local function distanceToPolyline(p: Vector3, points: { Vector3 }): number
	local best = math.huge
	local flat = Vector3.new(p.X, 0, p.Z)
	for i = 1, #points - 1 do
		local a = Vector3.new(points[i].X, 0, points[i].Z)
		local b = Vector3.new(points[i + 1].X, 0, points[i + 1].Z)
		local ab = b - a
		local t = if ab.Magnitude > 0 then math.clamp((flat - a):Dot(ab) / ab:Dot(ab), 0, 1) else 0
		best = math.min(best, (flat - (a + ab * t)).Magnitude)
	end
	return best
end

local RIVER = {
	Vector3.new(Forest.Lake.X + 150, 0, Forest.Lake.Z + 60), Vector3.new(-1700, 0, -2000),
	Vector3.new(-900, 0, -2150), Vector3.new(200, 0, -2000), Vector3.new(1000, 0, -1750),
	Vector3.new(1400, 0, -1520),
}

local function hills(rng: Random)
	local placed = 0
	local attempts = 0
	while placed < Forest.HillCount and attempts < 500 do
		attempts += 1
		local angle = rng:NextNumber(0, math.pi * 2)
		local distance = rng:NextNumber(CITY_EDGE + 350, MapConfig.Border.Radius - 150)
		local x, z = math.cos(angle) * distance, math.sin(angle) * distance
		local lake = Vector3.new(Forest.Lake.X, 0, Forest.Lake.Z)
		if not inForest(x, z, 250) or inHarborWater(x, z, 200) or (Vector3.new(x, 0, z) - lake).Magnitude < Forest.Lake.Radius + 250 then
			continue
		end
		if distanceToPolyline(Vector3.new(x, 0, z), RIVER) < 220 or distanceToPolyline(Vector3.new(x, 0, z), MapConfig.Highway.Points) < 200 then
			continue
		end
		local radius = rng:NextNumber(70, 190)
		local material = if rng:NextNumber() < 0.25 then Enum.Material.Rock else Enum.Material.Grass
		terrain:FillBall(Vector3.new(x, -radius * 0.62, z), radius, material)
		placed += 1
		if placed % 5 == 0 then
			task.wait()
		end
	end
end

local function carveWater()
	local h = MapConfig.Harbor
	local bottom = h.WaterSurfaceY - h.WaterDepth
	-- Harbour basin
	local sizeX = h.WaterMaxX - h.WaterMinX
	local z = h.WaterMinZ
	while z < h.WaterMaxZ do
		local d = math.min(480, h.WaterMaxZ - z)
		local center = Vector3.new((h.WaterMinX + h.WaterMaxX) / 2, 0, z + d / 2)
		terrain:FillBlock(CFrame.new(center + Vector3.new(0, -h.WaterDepth / 2, 0)), Vector3.new(sizeX, h.WaterDepth + 2, d), Enum.Material.Air)
		terrain:FillBlock(CFrame.new(center + Vector3.new(0, bottom - 2, 0)), Vector3.new(sizeX, 4, d), Enum.Material.Sand)
		terrain:FillBlock(CFrame.new(center + Vector3.new(0, (bottom + h.WaterSurfaceY) / 2, 0)), Vector3.new(sizeX, h.WaterSurfaceY - bottom, d), Enum.Material.Water)
		z += d
		task.wait()
	end
	-- Lake
	local lake = Forest.Lake
	local lakeCF = CFrame.new(lake.X, -7, lake.Z)
	terrain:FillCylinder(lakeCF, 16, lake.Radius, Enum.Material.Air)
	terrain:FillCylinder(lakeCF * CFrame.new(0, -9, 0), 4, lake.Radius, Enum.Material.Sand)
	terrain:FillCylinder(lakeCF * CFrame.new(0, -3, 0), 8, lake.Radius - 4, Enum.Material.Water)
	-- Sandy shore ring
	terrain:FillCylinder(CFrame.new(lake.X, -1, lake.Z), 2, lake.Radius + 14, Enum.Material.Sand)
	terrain:FillCylinder(lakeCF * CFrame.new(0, -3, 0), 8, lake.Radius - 4, Enum.Material.Water)
	-- River
	for i = 1, #RIVER - 1 do
		local a, b = RIVER[i], RIVER[i + 1]
		local length = (b - a).Magnitude
		local pieces = math.ceil(length / 120)
		for p = 0, pieces - 1 do
			local pa = a:Lerp(b, p / pieces)
			local pb = a:Lerp(b, (p + 1) / pieces)
			local mid = (pa + pb) / 2
			local cf = CFrame.lookAt(mid, pb)
			local l = (pb - pa).Magnitude + 30
			terrain:FillBlock(cf * CFrame.new(0, -4, 0), Vector3.new(56, 10, l), Enum.Material.Air)
			terrain:FillBlock(cf * CFrame.new(0, -10, 0), Vector3.new(56, 4, l), Enum.Material.Mud)
			terrain:FillBlock(cf * CFrame.new(0, -6, 0), Vector3.new(50, 6, l), Enum.Material.Water)
		end
		task.wait()
	end
end

--------------------------------------------------------------------------------
-- Roads that follow the terrain
--------------------------------------------------------------------------------
local function groundHeight(x: number, z: number): number
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { terrain }
	local hit = workspace:Raycast(Vector3.new(x, 400, z), Vector3.new(0, -800, 0), params)
	if hit then
		return hit.Position.Y
	end
	return 0
end

local function road(parent: Instance, points: { Vector3 }, width: number, lamps: boolean)
	local asphalt = Color3.fromRGB(56, 58, 62)
	local pieceLength = 60
	local lampCounter = 0
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local length = (Vector3.new(b.X, 0, b.Z) - Vector3.new(a.X, 0, a.Z)).Magnitude
		local pieces = math.max(1, math.ceil(length / pieceLength))
		for p = 0, pieces - 1 do
			local pa = a:Lerp(b, p / pieces)
			local pb = a:Lerp(b, (p + 1) / pieces)
			local inCity = math.abs(pa.X) < CITY_EDGE and math.abs(pa.Z) < CITY_EDGE and math.abs(pb.X) < CITY_EDGE and math.abs(pb.Z) < CITY_EDGE
			if inCity then
				continue
			end
			local ya = math.max(groundHeight(pa.X, pa.Z), 0) + 0.4
			local yb = math.max(groundHeight(pb.X, pb.Z), 0) + 0.4
			local from = Vector3.new(pa.X, ya, pa.Z)
			local to = Vector3.new(pb.X, yb, pb.Z)
			local mid = (from + to) / 2
			local cf = CFrame.lookAt(mid, to)
			local l = (to - from).Magnitude + 1.5
			-- Cut the terrain above the road and fill an embankment below it
			terrain:FillBlock(cf * CFrame.new(0, 14, 0), Vector3.new(width + 8, 28, l), Enum.Material.Air)
			terrain:FillBlock(cf * CFrame.new(0, -5, 0), Vector3.new(width + 14, 9, l), Enum.Material.Ground)
			local segment = Builder.part(parent, "Road", Vector3.new(width, 1.5, l), cf * CFrame.new(0, -0.35, 0), asphalt, Enum.Material.Asphalt)
			Builder.tag(segment, "ApexRoad")
			if p % 2 == 0 then
				Builder.decor(segment, "CenterLine", Vector3.new(0.8, 0.05, l * 0.6), cf * CFrame.new(0, 0.42, 0), Color3.fromRGB(230, 190, 40), Enum.Material.SmoothPlastic)
			end
			lampCounter += 1
			if lamps and lampCounter % 5 == 0 then
				Props.streetLamp(parent, (cf * CFrame.new(width / 2 + 2, 0, 0)).Position, (cf.RightVector * -1))
			end
		end
	end
end

--------------------------------------------------------------------------------
-- Trees & cabin
--------------------------------------------------------------------------------
local function trees(parent: Instance, rng: Random)
	local folder = Builder.folder(parent, "Trees")
	local lake = Vector3.new(Forest.Lake.X, 0, Forest.Lake.Z)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { terrain }
	local placed = 0
	local attempts = 0
	while placed < Forest.TreeCount and attempts < Forest.TreeCount * 5 do
		attempts += 1
		local x = rng:NextNumber(-MapConfig.Border.Radius, MapConfig.Border.Radius)
		local z = rng:NextNumber(-MapConfig.Border.Radius, MapConfig.Border.Radius)
		if not inForest(x, z, 40) or inHarborWater(x, z, 40) then
			continue
		end
		local p = Vector3.new(x, 0, z)
		if (p - lake).Magnitude < Forest.Lake.Radius + 25 or distanceToPolyline(p, RIVER) < 45 or distanceToPolyline(p, MapConfig.Highway.Points) < 35 then
			continue
		end
		local nearConnector = false
		for _, connector in MapConfig.ConnectorRoads do
			if distanceToPolyline(p, { connector.From, connector.To }) < 30 then
				nearConnector = true
				break
			end
		end
		if nearConnector or (p - Vector3.new(Forest.Cabin.X, 0, Forest.Cabin.Z)).Magnitude < 45 then
			continue
		end
		local hit = workspace:Raycast(Vector3.new(x, 400, z), Vector3.new(0, -800, 0), params)
		if not hit or hit.Material == Enum.Material.Water or hit.Material == Enum.Material.Rock then
			continue
		end
		if rng:NextNumber() < 0.6 then
			Props.conifer(folder, hit.Position, rng)
		else
			Props.deciduousTree(folder, hit.Position, rng, 1.2)
		end
		placed += 1
	end
end

local function cabin(parent: Instance)
	local model = Builder.model(parent, "RangerCabin")
	local id = "RangerCabin"
	local x, z = Forest.Cabin.X, Forest.Cabin.Z
	terrain:FillBlock(CFrame.new(x, -3, z), Vector3.new(70, 6, 60), Enum.Material.Ground)
	terrain:FillBlock(CFrame.new(x, 15, z), Vector3.new(70, 30, 60), Enum.Material.Air)
	local base = CFrame.new(x, 0.2, z)
	local log = Color3.fromRGB(110, 78, 52)
	local width, depth, height = 36, 28, 12
	Builder.chunk(model, Vector3.new(width + 10, 1, depth), base * CFrame.new(0, 0.5, 0), Color3.fromRGB(96, 70, 48), Enum.Material.WoodPlanks, "Wood", id, true)
	Builder.chunk(model, Vector3.new(width, height, 1.5), base * CFrame.new(0, height / 2 + 1, depth / 2), log, Enum.Material.Wood, "Wood", id, true)
	Builder.chunk(model, Vector3.new(1.5, height, depth), base * CFrame.new(-width / 2, height / 2 + 1, 0), log, Enum.Material.Wood, "Wood", id, true)
	Builder.chunk(model, Vector3.new(1.5, height, depth), base * CFrame.new(width / 2, height / 2 + 1, 0), log, Enum.Material.Wood, "Wood", id, true)
	for _, sx in { -1, 1 } do
		Builder.chunk(model, Vector3.new(width / 2 - 4, height, 1.5), base * CFrame.new(sx * (width / 4 + 2), height / 2 + 1, -depth / 2), log, Enum.Material.Wood, "Wood", id, true)
	end
	-- Gable roof
	for _, sx in { -1, 1 } do
		Builder.chunk(model, Vector3.new(width + 4, 1, depth / 2 + 6), base * CFrame.new(0, height + 5, sx * (depth / 4 + 0.5)) * CFrame.Angles(sx * math.rad(-35), 0, 0), Color3.fromRGB(70, 50, 40), Enum.Material.WoodPlanks, "Wood", id, false)
	end
	-- Chimney + fireplace glow + table
	Builder.chunk(model, Vector3.new(4, 20, 4), base * CFrame.new(width / 2 - 4, 11, depth / 2 - 4), Color3.fromRGB(110, 100, 94), Enum.Material.Cobblestone, "Brick", id, true)
	local fire = Builder.decor(model, "Fireplace", Vector3.new(3, 2, 1), base * CFrame.new(width / 2 - 4, 2.5, depth / 2 - 6.5), Color3.fromRGB(255, 140, 40), Enum.Material.Neon)
	Builder.pointLight(fire, Color3.fromRGB(255, 150, 60), 20, 1.5, "ApexInteriorLight")
	Builder.chunk(model, Vector3.new(8, 0.6, 4), base * CFrame.new(-6, 3.5, 2), Color3.fromRGB(130, 96, 66), Enum.Material.WoodPlanks, "Wood", id, false)
	local sign = Builder.part(model, "Sign", Vector3.new(12, 2.5, 0.4), base * CFrame.new(0, height - 1, -depth / 2 - 1), Color3.fromRGB(70, 50, 35), Enum.Material.Wood)
	Builder.sign(sign, Enum.NormalId.Front, "RANGER STATION", Color3.fromRGB(240, 220, 180), Color3.fromRGB(70, 50, 35), Enum.Font.Fantasy)
	-- Porch
	Builder.part(model, "Porch", Vector3.new(width, 0.8, 6), base * CFrame.new(0, 0.6, -depth / 2 - 3), Color3.fromRGB(96, 70, 48), Enum.Material.WoodPlanks)
end

--------------------------------------------------------------------------------
function ForestGenerator.generate(root: Instance)
	local rng = Random.new(MapConfig.Seed + 1)
	local folder = Builder.folder(root, "Forest")
	groundRing()
	hills(rng)
	carveWater()
	local roads = Builder.folder(folder, "Roads")
	road(roads, MapConfig.Highway.Points, MapConfig.Highway.Width, true)
	for _, connector in MapConfig.ConnectorRoads do
		road(roads, { connector.From, connector.To }, connector.Width, false)
	end
	cabin(folder)
	trees(folder, rng)
end

return ForestGenerator
