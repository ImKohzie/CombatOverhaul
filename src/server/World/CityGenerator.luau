--!strict
-- New Harbor: a Manhattan-style grid city (original). Avenues run
-- north-south every 250 studs, streets east-west every 125. Districts:
-- glass downtown around Central Park, a ring of brownstones, mid-rises at
-- the edges, a warehouse district by the harbour. Plus: park, waterfront
-- with piers, a bridge out of the city, an elevated train line with a
-- running train, street props, and the eight enterable locations.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local MapConfig = require(ReplicatedStorage:WaitForChild("ApexCity").Config.MapConfig)

local Builder = require(script.Parent.Builder)
local BuildingKit = require(script.Parent.BuildingKit)
local Interiors = require(script.Parent.Interiors)
local Props = require(script.Parent.Props)

type BuildingSpec = BuildingKit.BuildingSpec

local CityGenerator = {}

local City = MapConfig.City
local GROUND = MapConfig.GroundY
local BLOCK_TOP = GROUND + City.CurbHeight
local ASPHALT = Color3.fromRGB(52, 54, 58)
local SIDEWALK = Color3.fromRGB(168, 164, 156)

local AVENUES = math.floor(City.HalfSize * 2 / City.AvenueSpacing) -- 10 blocks across
local STREETS = math.floor(City.HalfSize * 2 / City.StreetSpacing) -- 20 blocks down

local function avenueX(k: number): number
	return -City.HalfSize + k * City.AvenueSpacing
end

local function streetZ(j: number): number
	return -City.HalfSize + j * City.StreetSpacing
end

local function inPark(x: number, z: number): boolean
	local park = MapConfig.Park
	return x > park.MinX + 1 and x < park.MaxX - 1 and z > park.MinZ + 1 and z < park.MaxZ - 1
end

local function isHarborColumn(i: number): boolean
	return avenueX(i) >= MapConfig.Harbor.WaterfrontX
end

-- Special blocks (block column i, row j) -> builder
local SPECIALS: { [string]: { builder: (Instance, Interiors.Lot) -> Instance, facing: number } } = {
	["6,9"] = { builder = Interiors.subway, facing = 0 },
	["3,9"] = { builder = Interiors.officeTower, facing = 0 },
	["6,13"] = { builder = Interiors.diner, facing = 0 },
	["3,13"] = { builder = Interiors.garage, facing = 0 },
	["8,6"] = { builder = Interiors.warehouse, facing = 0 },
	["6,6"] = { builder = Interiors.openPlanTower, facing = math.pi },
	["4,6"] = { builder = Interiors.museum, facing = math.pi },
	["5,13"] = { builder = Interiors.rooftopBar, facing = 0 },
}

local SHOP_NAMES = { "DELI", "PIZZA", "BODEGA", "LAUNDRY", "BOOKS", "NOODLES", "PHARMACY", "BAGELS", "TATTOO", "ARCADE" }

--------------------------------------------------------------------------------
-- Roads
--------------------------------------------------------------------------------
local function buildRoads(parent: Instance, rng: Random, props: Instance)
	local roads = Builder.folder(parent, "Roads")
	local y = GROUND - 1
	-- Avenues (north-south), split between intersections
	for k = 0, AVENUES do
		local x = avenueX(k)
		if x > MapConfig.Harbor.WaterfrontX then
			continue
		end
		for j = 0, STREETS - 1 do
			local z0, z1 = streetZ(j) + City.StreetWidth / 2, streetZ(j + 1) - City.StreetWidth / 2
			local zc = (z0 + z1) / 2
			if inPark(x, zc) then
				continue
			end
			local road = Builder.part(roads, "Avenue", Vector3.new(City.AvenueWidth, 2, z1 - z0), CFrame.new(x, y, zc), ASPHALT, Enum.Material.Asphalt)
			Builder.tag(road, "ApexRoad")
			Builder.decor(road, "CenterLine", Vector3.new(0.9, 0.05, z1 - z0), CFrame.new(x, GROUND + 0.03, zc), Color3.fromRGB(230, 190, 40), Enum.Material.SmoothPlastic)
			-- Street lamps along both sidewalks
			for lampZ = z0 + 20, z1 - 10, 90 do
				Props.streetLamp(props, Vector3.new(x - City.AvenueWidth / 2 - 2, BLOCK_TOP, lampZ), Vector3.new(1, 0, 0))
				Props.streetLamp(props, Vector3.new(x + City.AvenueWidth / 2 + 2, BLOCK_TOP, lampZ), Vector3.new(-1, 0, 0))
			end
			if rng:NextNumber() < 0.12 then
				Props.steamVent(props, Vector3.new(x + rng:NextNumber(-8, 8), GROUND, zc + rng:NextNumber(-30, 30)))
			end
		end
	end
	-- Streets (east-west), split between avenues
	for j = 0, STREETS do
		local z = streetZ(j)
		for i = 0, AVENUES - 1 do
			if isHarborColumn(i) then
				continue
			end
			local x0, x1 = avenueX(i) + City.AvenueWidth / 2, avenueX(i + 1) - City.AvenueWidth / 2
			local xc = (x0 + x1) / 2
			if inPark(xc, z) then
				continue
			end
			local road = Builder.part(roads, "Street", Vector3.new(x1 - x0, 2, City.StreetWidth), CFrame.new(xc, y, z), ASPHALT, Enum.Material.Asphalt)
			Builder.tag(road, "ApexRoad")
			Builder.decor(road, "LaneLine", Vector3.new(x1 - x0, 0.05, 0.5), CFrame.new(xc, GROUND + 0.03, z), Color3.fromRGB(235, 235, 230), Enum.Material.SmoothPlastic)
			-- Parked cars / taxis along the curbs
			if rng:NextNumber() < 0.35 then
				for c = 1, rng:NextInteger(1, 3) do
					local side = if rng:NextNumber() < 0.5 then -1 else 1
					local cx = x0 + 20 + (c - 1) * 18 + rng:NextNumber(0, 40)
					if cx < x1 - 10 then
						local facing = if side > 0 then -math.pi / 2 else math.pi / 2
						Props.car(props, CFrame.new(cx, GROUND, z + side * (City.StreetWidth / 2 - 4)) * CFrame.Angles(0, facing, 0), rng, rng:NextNumber() < 0.3)
					end
				end
			end
		end
	end
	-- Intersections + traffic lights
	for k = 0, AVENUES do
		local x = avenueX(k)
		if x > MapConfig.Harbor.WaterfrontX then
			continue
		end
		for j = 0, STREETS do
			local z = streetZ(j)
			if inPark(x, z) then
				continue
			end
			local square = Builder.part(roads, "Intersection", Vector3.new(City.AvenueWidth, 2, City.StreetWidth), CFrame.new(x, y, z), ASPHALT, Enum.Material.Asphalt)
			Builder.tag(square, "ApexRoad")
			if (k + j) % 2 == 0 and math.abs(x) < City.HalfSize and math.abs(z) < City.HalfSize then
				Props.trafficLight(props, Vector3.new(x + City.AvenueWidth / 2 + 1.5, BLOCK_TOP, z - City.StreetWidth / 2 - 1.5), Vector3.new(-1, 0, 0))
			end
		end
	end
end

--------------------------------------------------------------------------------
-- Blocks & buildings
--------------------------------------------------------------------------------
local function blockSlab(parent: Instance, x0: number, x1: number, z0: number, z1: number, hole: Vector2?)
	local height = 2.6
	local cy = BLOCK_TOP - height / 2
	if not hole then
		local slab = Builder.part(parent, "Block", Vector3.new(x1 - x0, height, z1 - z0), CFrame.new((x0 + x1) / 2, cy, (z0 + z1) / 2), SIDEWALK, Enum.Material.Concrete)
		Builder.tag(slab, "ApexSidewalk")
		return
	end
	-- Slab with a rectangular hole in the middle (subway entrance)
	local cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
	local hx, hz = hole.X / 2, hole.Y / 2
	Builder.part(parent, "Block", Vector3.new(x1 - x0, height, (cz - hz) - z0), CFrame.new(cx, cy, (z0 + cz - hz) / 2), SIDEWALK, Enum.Material.Concrete)
	Builder.part(parent, "Block", Vector3.new(x1 - x0, height, z1 - (cz + hz)), CFrame.new(cx, cy, (cz + hz + z1) / 2), SIDEWALK, Enum.Material.Concrete)
	Builder.part(parent, "Block", Vector3.new((cx - hx) - x0, height, hole.Y), CFrame.new((x0 + cx - hx) / 2, cy, cz), SIDEWALK, Enum.Material.Concrete)
	Builder.part(parent, "Block", Vector3.new(x1 - (cx + hx), height, hole.Y), CFrame.new((cx + hx + x1) / 2, cy, cz), SIDEWALK, Enum.Material.Concrete)
end

local buildingCounter = 0
local function nextId(prefix: string): string
	buildingCounter += 1
	return string.format("%s_%04d", prefix, buildingCounter)
end

local function decorateFront(model: Model, spec: BuildingSpec, rng: Random)
	if rng:NextNumber() < 0.3 then
		local front = CFrame.new(spec.Center) * CFrame.Angles(0, spec.Facing, 0) * CFrame.new(rng:NextNumber(-spec.Width / 4, spec.Width / 4), 8, -spec.Depth / 2 - 0.4)
		Props.neonSign(model, front, SHOP_NAMES[rng:NextInteger(1, #SHOP_NAMES)], Color3.fromHSV(rng:NextNumber(), 0.7, 1))
	end
end

local function roofOf(model: Model): BasePart?
	local best: BasePart? = nil
	for _, child in model:GetChildren() do
		if child.Name == "Roof" and child:IsA("BasePart") then
			if not best or child.Position.Y > best.Position.Y then
				best = child
			end
		end
	end
	return best
end

local function buildRow(parent: Instance, rng: Random, x0: number, x1: number, zFront: number, depth: number, facing: number, kind: BuildingKit.BuildingKind, minWidth: number, maxWidth: number, minHeight: number, maxHeight: number, billboards: { BasePart })
	local x = x0
	while x1 - x > minWidth do
		local width = math.min(rng:NextNumber(minWidth, maxWidth), x1 - x)
		if x1 - (x + width) < minWidth then
			width = x1 - x
		end
		local zCenter = zFront + (if facing == 0 then depth / 2 else -depth / 2)
		local spec: BuildingSpec = {
			Id = nextId(kind),
			Kind = kind,
			Center = Vector3.new(x + width / 2, BLOCK_TOP, zCenter),
			Width = width - 1,
			Depth = depth,
			Height = rng:NextNumber(minHeight, maxHeight),
			Facing = facing,
			Seed = rng:NextInteger(1, 1e6),
		}
		local model = BuildingKit.build(parent, spec)
		decorateFront(model, spec, rng)
		local roof = roofOf(model)
		if roof and rng:NextNumber() < 0.12 then
			table.insert(billboards, roof)
		end
		x += width
	end
end

local function buildBlock(parent: Instance, rng: Random, i: number, j: number, billboards: { BasePart })
	local x0 = avenueX(i) + City.AvenueWidth / 2
	local x1 = avenueX(i + 1) - City.AvenueWidth / 2
	local z0 = streetZ(j) + City.StreetWidth / 2
	local z1 = streetZ(j + 1) - City.StreetWidth / 2
	local cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
	if inPark(cx, cz) then
		return
	end
	local key = `{i},{j}`
	local special = SPECIALS[key]
	local inset = City.SidewalkWidth
	local ix0, ix1, iz0, iz1 = x0 + inset, x1 - inset, z0 + inset, z1 - inset

	blockSlab(parent, x0, x1, z0, z1, if key == "6,9" then Vector2.new(Interiors.SubwayHole.Width, Interiors.SubwayHole.Length) else nil)

	if special then
		special.builder(parent, {
			Center = Vector3.new(cx, BLOCK_TOP, cz),
			Width = ix1 - ix0,
			Depth = iz1 - iz0,
			Facing = special.facing,
		})
		return
	end

	local distance = Vector2.new(cx, cz).Magnitude
	local rowDepth = (iz1 - iz0) / 2 - 2
	if isHarborColumn(i + 1) and i == AVENUES - 2 then
		-- Warehouse district by the water
		buildRow(parent, rng, ix0, ix1, iz0, iz1 - iz0, 0, "Warehouse", 60, 100, 24, 34, billboards)
	elseif distance < City.DowntownRadius then
		local t = distance / City.DowntownRadius
		local tall = 420 - t * 250
		if rng:NextNumber() < 0.75 then
			buildRow(parent, rng, ix0, ix1, iz0, iz1 - iz0, if rng:NextNumber() < 0.5 then 0 else math.pi, "Skyscraper", 60, 100, tall * 0.55, tall, billboards)
		else
			buildRow(parent, rng, ix0, ix1, iz0, rowDepth, 0, "Midrise", 50, 80, 60, 110, billboards)
			buildRow(parent, rng, ix0, ix1, iz1, rowDepth, math.pi, "Midrise", 50, 80, 60, 110, billboards)
		end
	elseif distance < 1000 then
		buildRow(parent, rng, ix0, ix1, iz0, rowDepth, 0, "Brownstone", 36, 50, 44, 56, billboards)
		buildRow(parent, rng, ix0, ix1, iz1, rowDepth, math.pi, "Brownstone", 36, 50, 44, 56, billboards)
	else
		buildRow(parent, rng, ix0, ix1, iz0, rowDepth, 0, "Midrise", 55, 80, 44, 84, billboards)
		buildRow(parent, rng, ix0, ix1, iz1, rowDepth, math.pi, "Plain", 55, 80, 30, 50, billboards)
	end
end

--------------------------------------------------------------------------------
-- Central Park
--------------------------------------------------------------------------------
local function buildPark(parent: Instance, rng: Random): ({ CFrame }, CFrame)
	local park = MapConfig.Park
	local folder = Builder.folder(parent, "CentralPark")
	local x0, x1 = park.MinX + City.AvenueWidth / 2, park.MaxX - City.AvenueWidth / 2
	local z0, z1 = park.MinZ + City.StreetWidth / 2, park.MaxZ - City.StreetWidth / 2
	local cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
	local lawn = Builder.part(folder, "Lawn", Vector3.new(x1 - x0, 2.6, z1 - z0), CFrame.new(cx, BLOCK_TOP - 1.3, cz), Color3.fromRGB(78, 118, 58), Enum.Material.Grass)
	Builder.tag(lawn, "ApexPark")
	-- Perimeter stone wall
	for _, spec in {
		{ Vector3.new(x1 - x0, 2.5, 1.5), Vector3.new(cx, BLOCK_TOP + 1.25, z0 + 0.75) },
		{ Vector3.new(x1 - x0, 2.5, 1.5), Vector3.new(cx, BLOCK_TOP + 1.25, z1 - 0.75) },
		{ Vector3.new(1.5, 2.5, z1 - z0), Vector3.new(x0 + 0.75, BLOCK_TOP + 1.25, cz) },
		{ Vector3.new(1.5, 2.5, z1 - z0), Vector3.new(x1 - 0.75, BLOCK_TOP + 1.25, cz) },
	} do
		Builder.part(folder, "ParkWall", spec[1], CFrame.new(spec[2]), Color3.fromRGB(110, 104, 96), Enum.Material.Cobblestone)
	end
	-- Paths: two crossing boulevards + a loop
	local pathColor = Color3.fromRGB(150, 140, 125)
	Builder.decor(folder, "Path", Vector3.new(14, 0.2, z1 - z0), CFrame.new(cx, BLOCK_TOP + 0.1, cz), pathColor, Enum.Material.Pavement).CanCollide = true
	Builder.decor(folder, "Path", Vector3.new(x1 - x0, 0.2, 14), CFrame.new(cx, BLOCK_TOP + 0.1, cz), pathColor, Enum.Material.Pavement).CanCollide = true
	local loopW, loopD = (x1 - x0) * 0.7, (z1 - z0) * 0.75
	for _, s in { -1, 1 } do
		Builder.decor(folder, "Path", Vector3.new(loopW, 0.2, 8), CFrame.new(cx, BLOCK_TOP + 0.1, cz + s * loopD / 2), pathColor, Enum.Material.Pavement)
		Builder.decor(folder, "Path", Vector3.new(8, 0.2, loopD), CFrame.new(cx + s * loopW / 2, BLOCK_TOP + 0.1, cz), pathColor, Enum.Material.Pavement)
	end
	-- Fountain plaza at the centre
	local plaza = Builder.part(folder, "Plaza", Vector3.new(0.4, 70, 70), CFrame.new(cx, BLOCK_TOP + 0.2, cz) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(190, 184, 172), Enum.Material.Pavement)
	plaza.Shape = Enum.PartType.Cylinder
	local basin = Builder.part(folder, "FountainBasin", Vector3.new(2.5, 26, 26), CFrame.new(cx, BLOCK_TOP + 1.2, cz) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(170, 166, 158), Enum.Material.Marble)
	basin.Shape = Enum.PartType.Cylinder
	local water = Builder.decor(folder, "FountainWater", Vector3.new(0.3, 23, 23), CFrame.new(cx, BLOCK_TOP + 2.3, cz) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(80, 140, 170), Enum.Material.Glass)
	water.Shape = Enum.PartType.Cylinder
	water.Transparency = 0.3
	water.Reflectance = 0.4
	local column = Builder.pillar(folder, "FountainColumn", Vector3.new(cx, BLOCK_TOP + 2, cz), 8, 3, Color3.fromRGB(170, 166, 158), Enum.Material.Marble)
	local spray = Instance.new("ParticleEmitter")
	spray.Color = ColorSequence.new(Color3.fromRGB(220, 240, 255))
	spray.Transparency = NumberSequence.new(0.3, 1)
	spray.Size = NumberSequence.new(0.6, 1.2)
	spray.Lifetime = NumberRange.new(1, 1.4)
	spray.Speed = NumberRange.new(18, 22)
	spray.SpreadAngle = Vector2.new(15, 15)
	spray.Acceleration = Vector3.new(0, -35, 0)
	spray.EmissionDirection = Enum.NormalId.Right
	spray.Rate = 60
	spray.Parent = column
	-- Pond
	local pondCenter = Vector3.new(cx + (x1 - x0) * 0.25, BLOCK_TOP, cz + (z1 - z0) * 0.22)
	local pond = Builder.decor(folder, "Pond", Vector3.new(0.4, 90, 90), CFrame.new(pondCenter + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(46, 90, 104), Enum.Material.Glass)
	pond.Shape = Enum.PartType.Cylinder
	pond.Reflectance = 0.45
	pond.Transparency = 0.1
	-- Trees, benches, lamps
	local avoid = function(p: Vector3): boolean
		if (p - pondCenter).Magnitude < 52 then
			return true
		end
		if math.abs(p.X - cx) < 12 or math.abs(p.Z - cz) < 12 then
			return true
		end
		return (p - Vector3.new(cx, p.Y, cz)).Magnitude < 42
	end
	local placed = 0
	local attempts = 0
	while placed < 120 and attempts < 600 do
		attempts += 1
		local p = Vector3.new(rng:NextNumber(x0 + 10, x1 - 10), BLOCK_TOP, rng:NextNumber(z0 + 10, z1 - 10))
		if not avoid(p) then
			Props.deciduousTree(folder, p, rng)
			placed += 1
		end
	end
	for z = z0 + 40, z1 - 40, 60 do
		Props.bench(folder, CFrame.new(cx - 11, BLOCK_TOP, z) * CFrame.Angles(0, math.rad(90), 0))
		Props.streetLamp(folder, Vector3.new(cx + 9, BLOCK_TOP, z + 30), Vector3.new(-1, 0, 0))
	end
	-- Spawns around the fountain + the training area to the north of it
	local spawns: { CFrame } = {}
	for a = 0, 3 do
		local angle = a * math.pi / 2 + math.pi / 4
		table.insert(spawns, CFrame.new(cx + math.cos(angle) * 44, BLOCK_TOP + 0.6, cz + math.sin(angle) * 44))
	end
	local training = CFrame.new(cx, BLOCK_TOP + 0.5, cz - 110)
	return spawns, training
end

--------------------------------------------------------------------------------
-- Harbour, bridge, elevated train
--------------------------------------------------------------------------------
local function buildHarbor(parent: Instance, rng: Random, props: Instance)
	local harbor = MapConfig.Harbor
	local folder = Builder.folder(parent, "Harbor")
	local quayX = harbor.WaterfrontX + City.AvenueWidth / 2
	local quayWidth = harbor.WaterMinX - quayX + 4
	for s = -1, 1, 2 do
		Builder.part(folder, "Quay", Vector3.new(quayWidth, 36, City.HalfSize), CFrame.new(quayX + quayWidth / 2, BLOCK_TOP - 18, s * City.HalfSize / 2), Color3.fromRGB(130, 126, 118), Enum.Material.Concrete)
		Builder.decor(folder, "QuayRail", Vector3.new(0.4, 3, City.HalfSize), CFrame.new(quayX + quayWidth - 0.5, BLOCK_TOP + 1.5, s * City.HalfSize / 2), Color3.fromRGB(40, 60, 70), Enum.Material.Metal)
	end
	local pierZs = { -1000, -700, -400, 350, 650, 950 }
	for index, z in pierZs do
		local pierLength = 230
		local startX = harbor.WaterMinX
		local deckY = BLOCK_TOP - 0.4
		local deck = Builder.part(folder, "Pier", Vector3.new(pierLength, 1.2, 30), CFrame.new(startX + pierLength / 2, deckY, z), Color3.fromRGB(120, 92, 66), Enum.Material.WoodPlanks)
		Builder.tag(deck, "ApexPier")
		for px = startX + 10, startX + pierLength - 5, 22 do
			for _, sz in { -13, 13 } do
				Builder.pillar(folder, "Piling", Vector3.new(px, harbor.WaterSurfaceY - harbor.WaterDepth, z + sz), harbor.WaterDepth + 3, 1.8, Color3.fromRGB(80, 62, 46), Enum.Material.Wood)
			end
		end
		if index == 2 or index == 5 then
			-- Shipping containers
			for c = 0, 5 do
				local stack = rng:NextInteger(1, 3)
				for level = 0, stack - 1 do
					local color = Color3.fromHSV(rng:NextNumber(), 0.6, 0.55)
					Builder.chunk(folder, Vector3.new(24, 9, 9.5), CFrame.new(startX + 30 + c * 28, deckY + 5.1 + level * 9, z + rng:NextNumber(-3, 3)), color, Enum.Material.CorrodedMetal, "Steel", "Container_" .. index .. "_" .. c, level == 0)
				end
			end
		elseif index == 3 then
			-- Dock crane
			local craneX = startX + 120
			for _, sz in { -11, 11 } do
				Builder.part(folder, "CraneLeg", Vector3.new(2, 60, 2), CFrame.new(craneX, deckY + 30, z + sz), Color3.fromRGB(200, 150, 30), Enum.Material.Metal)
			end
			Builder.part(folder, "CraneBoom", Vector3.new(90, 4, 4), CFrame.new(craneX + 25, deckY + 60, z), Color3.fromRGB(200, 150, 30), Enum.Material.Metal)
		elseif index == 6 then
			-- Lighthouse at the end of the pier
			local lx = startX + pierLength - 15
			Builder.pillar(folder, "Lighthouse", Vector3.new(lx, deckY, z), 60, 12, Color3.fromRGB(235, 235, 230), Enum.Material.Concrete)
			Builder.pillar(folder, "LighthouseBand", Vector3.new(lx, deckY + 25, z), 8, 12.2, Color3.fromRGB(180, 40, 40), Enum.Material.Concrete)
			local lamp = Builder.decor(folder, "LighthouseLamp", Vector3.new(6, 6, 6), CFrame.new(lx, deckY + 64, z), Color3.fromRGB(255, 240, 200), Enum.Material.Neon)
			lamp.Shape = Enum.PartType.Ball
			local beam = Instance.new("SpotLight")
			beam.Range = 60
			beam.Angle = 30
			beam.Brightness = 0
			beam.Color = Color3.fromRGB(255, 240, 200)
			beam.Parent = lamp
			Builder.tag(beam, "ApexStreetLight")
			Builder.tag(lamp, "ApexLighthouse")
		end
		for lx = startX + 20, startX + pierLength - 20, 70 do
			Props.streetLamp(props, Vector3.new(lx, deckY + 0.6, z + 13), Vector3.new(0, 0, -1))
		end
	end
end

local function buildBridge(parent: Instance)
	local bridge = MapConfig.Bridge
	local folder = Builder.folder(parent, "Bridge")
	local deckColor = Color3.fromRGB(70, 72, 76)
	local rampStart = MapConfig.Harbor.WaterfrontX + City.AvenueWidth / 2
	local rampLength = 140
	local deckStart = rampStart + rampLength
	local deckEnd = bridge.EndX - 110
	local function slab(from: Vector3, to: Vector3)
		local mid = (from + to) / 2
		local length = (to - from).Magnitude
		local road = Builder.part(folder, "BridgeDeck", Vector3.new(bridge.Width, 3, length), CFrame.lookAt(mid, to) * CFrame.new(0, -1.5, 0), deckColor, Enum.Material.Asphalt)
		Builder.tag(road, "ApexRoad")
		for _, sx in { -1, 1 } do
			Builder.part(folder, "BridgeRail", Vector3.new(1, 3.5, length), CFrame.lookAt(mid, to) * CFrame.new(sx * (bridge.Width / 2 - 0.5), 1.75, 0), Color3.fromRGB(140, 60, 40), Enum.Material.Metal)
		end
	end
	local z = bridge.Z
	slab(Vector3.new(rampStart, BLOCK_TOP - 0.6, z), Vector3.new(deckStart, bridge.DeckY, z))
	local segments = 3
	for s = 0, segments - 1 do
		local a = deckStart + (deckEnd - deckStart) * s / segments
		local b = deckStart + (deckEnd - deckStart) * (s + 1) / segments
		slab(Vector3.new(a, bridge.DeckY, z), Vector3.new(b, bridge.DeckY, z))
	end
	slab(Vector3.new(deckEnd, bridge.DeckY, z), Vector3.new(bridge.EndX, 2, z))
	-- Suspension towers + cables
	local towerColor = Color3.fromRGB(150, 60, 40)
	for _, tx in { deckStart + 120, deckEnd - 120 } do
		for _, sx in { -1, 1 } do
			Builder.part(folder, "BridgeTower", Vector3.new(5, 120, 5), CFrame.new(tx, bridge.DeckY + 40, z + sx * (bridge.Width / 2 + 3)), towerColor, Enum.Material.Metal)
		end
		Builder.part(folder, "TowerBeam", Vector3.new(5, 6, bridge.Width + 11), CFrame.new(tx, bridge.DeckY + 95, z), towerColor, Enum.Material.Metal)
	end
	for _, sx in { -1, 1 } do
		local cableZ = z + sx * (bridge.Width / 2 + 3)
		local points = {
			Vector3.new(deckStart, bridge.DeckY + 4, cableZ),
			Vector3.new(deckStart + 120, bridge.DeckY + 98, cableZ),
			Vector3.new((deckStart + deckEnd) / 2, bridge.DeckY + 30, cableZ),
			Vector3.new(deckEnd - 120, bridge.DeckY + 98, cableZ),
			Vector3.new(deckEnd, bridge.DeckY + 4, cableZ),
		}
		for p = 1, #points - 1 do
			local a, b = points[p], points[p + 1]
			Builder.decor(folder, "Cable", Vector3.new(0.8, 0.8, (b - a).Magnitude), CFrame.lookAt((a + b) / 2, b), Color3.fromRGB(60, 60, 64), Enum.Material.Metal)
		end
	end
	for lx = deckStart, deckEnd, 100 do
		Props.streetLamp(folder, Vector3.new(lx, bridge.DeckY, z - bridge.Width / 2 + 2), Vector3.new(0, 0, 1))
	end
end

local function buildTrain(parent: Instance)
	local train = MapConfig.Train
	local folder = Builder.folder(parent, "ElevatedTrain")
	local x = train.X
	local steel = Color3.fromRGB(60, 70, 64)
	for z = -City.HalfSize + 10, City.HalfSize - 10, train.PillarSpacing do
		for _, sx in { -1, 1 } do
			Builder.part(folder, "TrainPillar", Vector3.new(2, train.DeckY, 2), CFrame.new(x + sx * 12, GROUND + train.DeckY / 2, z), steel, Enum.Material.Metal)
		end
		Builder.part(folder, "TrainBeam", Vector3.new(26, 2, 2), CFrame.new(x, GROUND + train.DeckY - 1, z), steel, Enum.Material.Metal)
	end
	local segment = 250
	for z = -City.HalfSize, City.HalfSize - segment, segment do
		local deck = Builder.part(folder, "TrainDeck", Vector3.new(26, 1.5, segment), CFrame.new(x, GROUND + train.DeckY + 0.75, z + segment / 2), steel, Enum.Material.DiamondPlate)
		Builder.tag(deck, "ApexTrainDeck")
		for _, rail in { -2.5, 2.5 } do
			Builder.decor(folder, "Rail", Vector3.new(0.4, 0.5, segment), CFrame.new(x + rail, GROUND + train.DeckY + 1.75, z + segment / 2), Color3.fromRGB(120, 110, 100), Enum.Material.Metal)
		end
	end
	-- Station platform with a stair from the sidewalk
	local platformZ = 60
	Builder.part(folder, "TrainPlatform", Vector3.new(12, 1, 120), CFrame.new(x + 19, GROUND + train.DeckY + 1, platformZ), Color3.fromRGB(150, 146, 140), Enum.Material.Concrete)
	local steps = 40
	for s = 0, steps - 1 do
		Builder.part(folder, "TrainStair", Vector3.new(6, 1, 1.6), CFrame.new(x + 22, BLOCK_TOP + (train.DeckY + 1 - BLOCK_TOP) * (s + 1) / steps - 0.5, platformZ - 60 - 64 + s * 1.6), Color3.fromRGB(80, 80, 84), Enum.Material.DiamondPlate)
	end
	local canopy = Builder.part(folder, "Canopy", Vector3.new(12, 0.6, 80), CFrame.new(x + 19, GROUND + train.DeckY + 12, platformZ), Color3.fromRGB(40, 90, 60), Enum.Material.Metal)
	Builder.sign(canopy, Enum.NormalId.Bottom, "HARBOR LINE", Color3.new(1, 1, 1))

	-- The running train (anchored, moved by the server)
	local model = Builder.model(folder, "Train")
	for c = 0, train.Cars - 1 do
		local car = Builder.part(model, "Car", Vector3.new(10, 11, 44), CFrame.new(x, GROUND + train.DeckY + 7.5, -City.HalfSize + 40 + c * 46), Color3.fromRGB(190, 195, 200), Enum.Material.Metal)
		car.Reflectance = 0.1
		Builder.decor(car, "Windows", Vector3.new(10.1, 3, 36), car.CFrame * CFrame.new(0, 1.5, 0), Color3.fromRGB(30, 40, 50), Enum.Material.Glass)
		Builder.decor(car, "Stripe", Vector3.new(10.15, 0.8, 44), car.CFrame * CFrame.new(0, -2, 0), Color3.fromRGB(40, 150, 90), Enum.Material.SmoothPlastic)
	end
	model.PrimaryPart = model:FindFirstChild("Car") :: BasePart
	-- Simple back-and-forth run with a station stop
	task.spawn(function()
		local minZ = -City.HalfSize + 40
		local maxZ = City.HalfSize - 40 - (train.Cars - 1) * 46
		local z = minZ
		local direction = 1
		local pause = 0
		local base = model:GetPivot()
		local accumulator = 0
		while model.Parent do
			local dt = RunService.Heartbeat:Wait()
			accumulator += dt
			if accumulator < 1 / 30 then
				continue
			end
			local step = accumulator
			accumulator = 0
			if pause > 0 then
				pause -= step
				continue
			end
			local previous = z
			z += direction * train.Speed * step
			if (previous - platformZ) * (z - platformZ) <= 0 then
				pause = 5
			end
			if z >= maxZ or z <= minZ then
				z = math.clamp(z, minZ, maxZ)
				direction = -direction
				pause = 3
			end
			model:PivotTo(base + Vector3.new(0, 0, z - minZ))
		end
	end)
end

--------------------------------------------------------------------------------
function CityGenerator.generate(root: Instance): { Spawns: { CFrame }, TrainingArea: CFrame }
	local rng = Random.new(MapConfig.Seed)
	local city = Builder.folder(root, "City")
	local props = Builder.folder(city, "StreetProps")
	local blocks = Builder.folder(city, "Blocks")
	buildRoads(city, rng, props)
	local billboards: { BasePart } = {}
	for i = 0, AVENUES - 1 do
		if isHarborColumn(i) then
			continue
		end
		for j = 0, STREETS - 1 do
			buildBlock(blocks, rng, i, j, billboards)
		end
	end
	for index, roof in billboards do
		local brand = MapConfig.Brands[((index - 1) % #MapConfig.Brands) + 1]
		Props.billboard(roof.Parent or props, CFrame.new(roof.Position + Vector3.new(0, roof.Size.Y / 2, 0)) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0), brand, rng)
	end
	local spawns, training = buildPark(city, rng)
	buildHarbor(city, rng, props)
	buildBridge(city)
	buildTrain(city)
	return { Spawns = spawns, TrainingArea = training }
end

return CityGenerator
