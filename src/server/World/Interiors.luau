--!strict
-- The eight enterable locations. Each builder takes a lot (ground centre,
-- width along the street, depth, facing yaw). Walls and furniture are
-- destructible chunks where it makes sense.

local Builder = require(script.Parent.Builder)
local BuildingKit = require(script.Parent.BuildingKit)
local Props = require(script.Parent.Props)

export type Lot = { Center: Vector3, Width: number, Depth: number, Facing: number }

local Interiors = {}

local DARK = Color3.fromRGB(35, 36, 40)

local function frame(lot: Lot): CFrame
	return CFrame.new(lot.Center) * CFrame.Angles(0, lot.Facing, 0)
end

-- Simple room: floor, walls with a door gap in the front, flat roof.
local function room(model: Model, id: string, base: CFrame, width: number, depth: number, height: number, wallColor: Color3, wallMaterial: Enum.Material, kind: Builder.ChunkMaterial, doorWidth: number, glassFront: boolean?)
	Builder.chunk(model, Vector3.new(width, 1, depth), base * CFrame.new(0, 0.5, 0), Color3.fromRGB(150, 146, 140), Enum.Material.Concrete, "Concrete", id, true)
	local t = 1.2
	-- back and sides
	Builder.chunk(model, Vector3.new(width, height, t), base * CFrame.new(0, height / 2 + 1, depth / 2 - t / 2), wallColor, wallMaterial, kind, id, true)
	Builder.chunk(model, Vector3.new(t, height, depth), base * CFrame.new(-width / 2 + t / 2, height / 2 + 1, 0), wallColor, wallMaterial, kind, id, true)
	Builder.chunk(model, Vector3.new(t, height, depth), base * CFrame.new(width / 2 - t / 2, height / 2 + 1, 0), wallColor, wallMaterial, kind, id, true)
	-- front with door gap
	local side = (width - doorWidth) / 2
	for _, sx in { -1, 1 } do
		local panel = Builder.chunk(model, Vector3.new(side, height, t), base * CFrame.new(sx * (doorWidth / 2 + side / 2), height / 2 + 1, -depth / 2 + t / 2), if glassFront then Color3.fromRGB(120, 150, 160) else wallColor, if glassFront then Enum.Material.Glass else wallMaterial, if glassFront then "Glass" else kind, id, true)
		if glassFront then
			panel.Transparency = 0.5
			panel.Reflectance = 0.15
		end
	end
	Builder.chunk(model, Vector3.new(doorWidth, height - 9, t), base * CFrame.new(0, 9 + (height - 9) / 2 + 1, -depth / 2 + t / 2), wallColor, wallMaterial, kind, id, false)
	Builder.chunk(model, Vector3.new(width, 1, depth), base * CFrame.new(0, height + 1.5, 0), Color3.fromRGB(110, 108, 104), Enum.Material.Concrete, "Concrete", id, false)
end

local function ceilingLight(parent: Instance, cframe: CFrame, length: number, color: Color3?)
	local strip = Builder.decor(parent, "LightStrip", Vector3.new(length, 0.3, 1), cframe, color or Color3.fromRGB(245, 245, 240), Enum.Material.Neon)
	Builder.pointLight(strip, color or Color3.fromRGB(255, 250, 240), 26, 1.2, "ApexInteriorLight")
end

--------------------------------------------------------------------------------
-- 1. Subway station (entrance kiosk on the lot, hall + tunnels underground)
--------------------------------------------------------------------------------
Interiors.SubwayHole = { Width = 12, Length = 34 } -- hole left in the block ground

function Interiors.subway(parent: Instance, lot: Lot)
	local model = Builder.model(parent, "SubwayStation")
	local id = "SubwayStation"
	local base = frame(lot)
	local hallDepth = 32
	local hallTop = -3
	local hallBottom = hallTop - hallDepth
	local hallLength = 160
	local hallWidth = 46
	local hallCenter = base * CFrame.new(0, 0, 0)
	local tile = Color3.fromRGB(200, 196, 186)

	-- Entrance: stairs descending from the hole (hole runs along local Z)
	local hole = Interiors.SubwayHole
	local steps = 26
	local run = hole.Length / steps
	local rise = (0.1 - (hallBottom + 1)) / steps
	for i = 0, steps - 1 do
		Builder.part(model, "Step", Vector3.new(hole.Width, 1, run + 0.2), base * CFrame.new(0, 0.1 - rise * (i + 1) + 0.5 - 1, -hole.Length / 2 + run * (i + 0.5)), Color3.fromRGB(120, 118, 115), Enum.Material.Concrete)
	end
	-- stair continues as a sloped corridor into the hall: side walls of the shaft
	for _, sx in { -1, 1 } do
		Builder.part(model, "ShaftWall", Vector3.new(1, hallDepth + 4, hole.Length), base * CFrame.new(sx * (hole.Width / 2 + 0.5), hallBottom + hallDepth / 2, 0), tile, Enum.Material.Marble)
	end
	-- Railings + entrance sign at street level
	for _, sx in { -1, 1 } do
		Builder.part(model, "Railing", Vector3.new(0.4, 3.5, hole.Length), base * CFrame.new(sx * (hole.Width / 2 + 0.3), 1.85, 0), Color3.fromRGB(40, 70, 50), Enum.Material.Metal)
	end
	local post = Builder.part(model, "SignPost", Vector3.new(0.6, 9, 0.6), base * CFrame.new(hole.Width / 2 + 1.5, 4.6, -hole.Length / 2), Color3.fromRGB(40, 70, 50), Enum.Material.Metal)
	local globe = Builder.decor(post, "Globe", Vector3.new(1.8, 1.8, 1.8), post.CFrame * CFrame.new(0, 5, 0), Color3.fromRGB(120, 255, 140), Enum.Material.Neon)
	globe.Shape = Enum.PartType.Ball
	Builder.pointLight(globe, Color3.fromRGB(140, 255, 150), 14, 1, "ApexStreetLight")
	local sign = Builder.part(model, "Sign", Vector3.new(10, 2, 0.4), base * CFrame.new(0, 4, -hole.Length / 2 - 0.5), DARK, Enum.Material.SmoothPlastic)
	Builder.sign(sign, Enum.NormalId.Front, "HARBOR ST STATION", Color3.new(1, 1, 1))

	-- Hall (the stairs land at its north end)
	local hallFrame = hallCenter * CFrame.new(0, 0, hole.Length / 2 + hallLength / 2 - 10)
	Builder.part(model, "HallFloor", Vector3.new(hallWidth, 1, hallLength), hallFrame * CFrame.new(0, hallBottom + 0.5, 0), Color3.fromRGB(150, 146, 140), Enum.Material.Concrete)
	Builder.part(model, "HallCeiling", Vector3.new(hallWidth, 1, hallLength), hallFrame * CFrame.new(0, hallTop - 0.5, 0), Color3.fromRGB(90, 92, 96), Enum.Material.Concrete)
	for _, sx in { -1, 1 } do
		Builder.part(model, "HallWall", Vector3.new(1, hallDepth, hallLength), hallFrame * CFrame.new(sx * (hallWidth / 2 + 0.5), hallBottom + hallDepth / 2, 0), tile, Enum.Material.Marble)
	end
	-- End wall behind the stairs (with the stair opening)
	Builder.part(model, "EndWall", Vector3.new((hallWidth - hole.Width) / 2, hallDepth, 1), hallFrame * CFrame.new(-(hallWidth + hole.Width) / 4, hallBottom + hallDepth / 2, -hallLength / 2), tile, Enum.Material.Marble)
	Builder.part(model, "EndWall", Vector3.new((hallWidth - hole.Width) / 2, hallDepth, 1), hallFrame * CFrame.new((hallWidth + hole.Width) / 4, hallBottom + hallDepth / 2, -hallLength / 2), tile, Enum.Material.Marble)
	-- Platform in the middle, tracks either side
	Builder.part(model, "Platform", Vector3.new(14, 4, hallLength - 20), hallFrame * CFrame.new(0, hallBottom + 3, 10), Color3.fromRGB(175, 170, 160), Enum.Material.Concrete)
	Builder.decor(model, "SafetyLine", Vector3.new(1, 0.1, hallLength - 20), hallFrame * CFrame.new(-6.2, hallBottom + 5.05, 10), Color3.fromRGB(255, 210, 40), Enum.Material.SmoothPlastic)
	Builder.decor(model, "SafetyLine", Vector3.new(1, 0.1, hallLength - 20), hallFrame * CFrame.new(6.2, hallBottom + 5.05, 10), Color3.fromRGB(255, 210, 40), Enum.Material.SmoothPlastic)
	for _, sx in { -1, 1 } do
		for _, rail in { -2.4, 2.4 } do
			Builder.decor(model, "Rail", Vector3.new(0.4, 0.4, hallLength + 300), hallFrame * CFrame.new(sx * 15 + rail, hallBottom + 1.2, 0), Color3.fromRGB(120, 110, 100), Enum.Material.Metal)
		end
	end
	-- Pillars with light strips
	for z = -60, 60, 30 do
		for _, sx in { -1, 1 } do
			Builder.chunk(model, Vector3.new(2, hallDepth - 1, 2), hallFrame * CFrame.new(sx * 6, hallBottom + hallDepth / 2, z), Color3.fromRGB(80, 90, 110), Enum.Material.Metal, "Steel", id, true)
		end
		ceilingLight(model, hallFrame * CFrame.new(0, hallTop - 1.2, z) * CFrame.Angles(0, math.rad(90), 0), 20)
	end
	-- Tunnels beyond both ends
	for _, sz in { -1, 1 } do
		local tunnelFrame = hallFrame * CFrame.new(0, 0, sz * (hallLength / 2 + 75))
		if sz == 1 then
			Builder.part(model, "TunnelFloor", Vector3.new(hallWidth, 1, 150), tunnelFrame * CFrame.new(0, hallBottom + 0.5, 0), Color3.fromRGB(60, 58, 55), Enum.Material.Concrete)
			Builder.part(model, "TunnelRoof", Vector3.new(hallWidth, 1, 150), tunnelFrame * CFrame.new(0, hallBottom + 16, 0), Color3.fromRGB(50, 50, 52), Enum.Material.Concrete)
			for _, sx in { -1, 1 } do
				Builder.part(model, "TunnelWall", Vector3.new(1, 16, 150), tunnelFrame * CFrame.new(sx * (hallWidth / 2 + 0.5), hallBottom + 8, 0), Color3.fromRGB(70, 68, 64), Enum.Material.Concrete)
			end
			Builder.part(model, "TunnelEnd", Vector3.new(hallWidth, 16, 1), tunnelFrame * CFrame.new(0, hallBottom + 8, 75), Color3.fromRGB(30, 30, 32), Enum.Material.Concrete)
			for z = -60, 60, 40 do
				local lamp = Builder.decor(model, "TunnelLamp", Vector3.new(0.6, 0.6, 0.6), tunnelFrame * CFrame.new(-hallWidth / 2 + 1, hallBottom + 10, z), Color3.fromRGB(255, 200, 120), Enum.Material.Neon)
				Builder.pointLight(lamp, Color3.fromRGB(255, 190, 110), 18, 0.8, "ApexInteriorLight")
			end
		end
	end
	-- A parked train on the east track
	for i = 0, 2 do
		local car = Builder.part(model, "TrainCar", Vector3.new(10, 11, 40), hallFrame * CFrame.new(15, hallBottom + 7, -40 + i * 42), Color3.fromRGB(170, 175, 182), Enum.Material.Metal)
		for w = -1, 1 do
			Builder.decor(car, "Window", Vector3.new(0.2, 3, 8), car.CFrame * CFrame.new(-5.05, 1.5, w * 12), Color3.fromRGB(30, 40, 50), Enum.Material.Glass)
		end
		Builder.decor(car, "Stripe", Vector3.new(10.1, 0.8, 40), car.CFrame * CFrame.new(0, -2, 0), Color3.fromRGB(200, 40, 40), Enum.Material.SmoothPlastic)
	end
	-- Station name board
	local board = Builder.part(model, "NameBoard", Vector3.new(0.4, 3, 18), hallFrame * CFrame.new(-hallWidth / 2 + 0.3, hallBottom + 12, 0), DARK, Enum.Material.SmoothPlastic)
	Builder.sign(board, Enum.NormalId.Right, "HARBOR ST", Color3.new(1, 1, 1))
	Builder.tag(model, "ApexSubway")
	return model
end

--------------------------------------------------------------------------------
-- 2. Office tower with lobby and an outside glass lift to the roof
--------------------------------------------------------------------------------
function Interiors.officeTower(parent: Instance, lot: Lot)
	local height = 204
	local width = math.min(lot.Width, 90)
	local depth = math.min(lot.Depth, 70)
	local tower = BuildingKit.build(parent, {
		Id = "OfficeTower",
		Kind = "Skyscraper",
		Center = lot.Center,
		Width = width,
		Depth = depth,
		Height = height,
		Facing = lot.Facing,
		OpenFront = true,
		Seed = 77,
	})
	local base = frame(lot)
	-- Lobby furniture
	local desk = Builder.part(tower, "ReceptionDesk", Vector3.new(16, 4, 4), base * CFrame.new(0, 3, 6), Color3.fromRGB(70, 60, 55), Enum.Material.Marble)
	local deskSign = Builder.decor(desk, "Logo", Vector3.new(10, 1.6, 0.2), desk.CFrame * CFrame.new(0, 0.6, -2.1), Color3.fromRGB(230, 200, 120), Enum.Material.Metal)
	Builder.sign(deskSign, Enum.NormalId.Front, "APEX TOWER", Color3.fromRGB(40, 30, 20))
	for _, sx in { -1, 1 } do
		Props.deciduousTree(tower, (base * CFrame.new(sx * (width / 2 - 8), 1, -depth / 2 + 8)).Position, Random.new(5), 0.35)
		Props.bench(tower, base * CFrame.new(sx * 14, 1, -8))
	end
	ceilingLight(tower, base * CFrame.new(0, 34, 0), width - 10)
	-- External glass lift on the right side
	local shaftCenter = base * CFrame.new(width / 2 + 6, 0, -depth / 2 + 10)
	for _, corner in { Vector3.new(-4.5, 0, -4.5), Vector3.new(4.5, 0, -4.5), Vector3.new(-4.5, 0, 4.5), Vector3.new(4.5, 0, 4.5) } do
		Builder.part(tower, "LiftRail", Vector3.new(0.8, height + 6, 0.8), shaftCenter * CFrame.new(corner.X, (height + 6) / 2, corner.Z), Color3.fromRGB(180, 182, 186), Enum.Material.Metal)
	end
	local platform = Instance.new("Part")
	platform.Name = "LiftPlatform"
	platform.Size = Vector3.new(8, 1, 8)
	platform.CFrame = shaftCenter * CFrame.new(0, 1, 0)
	platform.Color = Color3.fromRGB(200, 205, 210)
	platform.Material = Enum.Material.DiamondPlate
	platform.Anchored = false
	platform.Parent = tower
	for _, wall in { CFrame.new(0, 4, 3.9), CFrame.new(3.9, 4, 0) * CFrame.Angles(0, math.rad(90), 0) } do
		local glass = Instance.new("Part")
		glass.Name = "LiftGlass"
		glass.Size = Vector3.new(8, 7, 0.2)
		glass.CFrame = platform.CFrame * wall
		glass.Material = Enum.Material.Glass
		glass.Transparency = 0.6
		glass.Color = Color3.fromRGB(180, 220, 230)
		glass.Anchored = false
		glass.Massless = true
		glass.Parent = platform
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = platform
		weld.Part1 = glass
		weld.Parent = glass
	end
	local anchor = Instance.new("Attachment")
	anchor.Parent = platform
	local align = Instance.new("AlignPosition")
	align.Mode = Enum.PositionAlignmentMode.OneAttachment
	align.Attachment0 = anchor
	align.MaxForce = 1e7
	align.MaxVelocity = 28
	align.Responsiveness = 20
	align.Position = platform.Position
	align.Parent = platform
	local orient = Instance.new("AlignOrientation")
	orient.Mode = Enum.OrientationAlignmentMode.OneAttachment
	orient.Attachment0 = anchor
	orient.RigidityEnabled = true
	orient.CFrame = platform.CFrame
	orient.Parent = platform
	platform:SetAttribute("ApexLiftBottom", platform.Position)
	platform:SetAttribute("ApexLiftTop", platform.Position + Vector3.new(0, height + 1, 0))
	Builder.tag(platform, "ApexLift")
	-- Rooftop landing bridge from the lift to the roof
	Builder.part(tower, "RoofBridge", Vector3.new(8, 1, 10), shaftCenter * CFrame.new(-6, height + 2.2, 0), Color3.fromRGB(120, 122, 124), Enum.Material.DiamondPlate)
	pcall(function()
		platform:SetNetworkOwner(nil)
	end)
	return tower
end

--------------------------------------------------------------------------------
-- 3. Diner
--------------------------------------------------------------------------------
function Interiors.diner(parent: Instance, lot: Lot)
	local model = Builder.model(parent, "HarborDiner")
	local id = "HarborDiner"
	local base = frame(lot) * CFrame.new(0, 0, -lot.Depth / 2 + 22)
	local width, depth, height = 64, 36, 14
	room(model, id, base, width, depth, height, Color3.fromRGB(190, 60, 55), Enum.Material.Metal, "Steel", 8, true)
	-- Chrome trim + neon sign
	Builder.decor(model, "Trim", Vector3.new(width + 0.4, 1, 0.4), base * CFrame.new(0, height - 1, -depth / 2 - 0.2), Color3.fromRGB(220, 222, 226), Enum.Material.Metal)
	Props.neonSign(model, base * CFrame.new(0, height + 3.5, -depth / 2), "HARBOR DINER", Color3.fromRGB(255, 80, 120))
	-- Counter + stools
	Builder.chunk(model, Vector3.new(34, 4, 3), base * CFrame.new(0, 3, 8), Color3.fromRGB(220, 220, 225), Enum.Material.Marble, "Concrete", id, false)
	for x = -15, 15, 5 do
		local stool = Builder.chunk(model, Vector3.new(2, 3, 2), base * CFrame.new(x, 2.5, 4.5), Color3.fromRGB(200, 40, 40), Enum.Material.Leather, "Wood", id, false)
		stool.Shape = Enum.PartType.Cylinder
		stool.CFrame = base * CFrame.new(x, 2.5, 4.5) * CFrame.Angles(0, 0, math.rad(90))
	end
	-- Booths along the front windows
	for x = -24, 24, 12 do
		if math.abs(x) > 6 then
			Builder.chunk(model, Vector3.new(6, 3.4, 3), base * CFrame.new(x, 2.7, -12), Color3.fromRGB(240, 238, 230), Enum.Material.Marble, "Wood", id, false)
			Builder.chunk(model, Vector3.new(6, 3, 2), base * CFrame.new(x, 2.5, -15), Color3.fromRGB(180, 30, 40), Enum.Material.Leather, "Wood", id, false)
			Builder.chunk(model, Vector3.new(6, 3, 2), base * CFrame.new(x, 2.5, -9), Color3.fromRGB(180, 30, 40), Enum.Material.Leather, "Wood", id, false)
		end
	end
	-- Checkered floor strip + lights
	for i = -3, 3 do
		Builder.decor(model, "Tile", Vector3.new(width - 4, 0.05, 2), base * CFrame.new(0, 1.03, i * 4), if i % 2 == 0 then Color3.new(1, 1, 1) else Color3.fromRGB(20, 20, 20), Enum.Material.SmoothPlastic)
	end
	ceilingLight(model, base * CFrame.new(0, height - 0.5, 0), width - 8, Color3.fromRGB(255, 235, 200))
	Builder.tag(model, "ApexDiner")
	return model
end

--------------------------------------------------------------------------------
-- 4. Multi-storey parking garage
--------------------------------------------------------------------------------
function Interiors.garage(parent: Instance, lot: Lot)
	local model = Builder.model(parent, "ParkingGarage")
	local id = "ParkingGarage"
	local base = frame(lot)
	local width = math.min(lot.Width - 6, 150)
	local depth = math.min(lot.Depth - 6, 80)
	local levels = 4
	local levelHeight = 11
	local rng = Random.new(12)
	for level = 0, levels do
		local y = level * levelHeight
		-- Slab with a ramp gap on alternating sides
		local gapSide = if level % 2 == 0 then 1 else -1
		if level == 0 then
			Builder.chunk(model, Vector3.new(width, 1, depth), base * CFrame.new(0, y + 0.5, 0), Color3.fromRGB(120, 118, 114), Enum.Material.Concrete, "Concrete", id, true)
		else
			Builder.chunk(model, Vector3.new(width - 30, 1, depth), base * CFrame.new(-gapSide * 15, y + 0.5, 0), Color3.fromRGB(120, 118, 114), Enum.Material.Concrete, "Concrete", id, false)
			Builder.chunk(model, Vector3.new(30, 1, depth - 24), base * CFrame.new(gapSide * (width / 2 - 15), y + 0.5, 12), Color3.fromRGB(120, 118, 114), Enum.Material.Concrete, "Concrete", id, false)
			-- Barrier walls on the open sides
			for _, sz in { -1, 1 } do
				Builder.chunk(model, Vector3.new(width, 3, 1), base * CFrame.new(0, y + 2.5, sz * (depth / 2 - 0.5)), Color3.fromRGB(150, 146, 140), Enum.Material.Concrete, "Concrete", id, false)
			end
		end
		if level < levels then
			-- Ramp up to the next level in the gap of the next slab
			local nextGap = if (level + 1) % 2 == 0 then 1 else -1
			local rampLength = 36
			local angle = math.atan2(levelHeight, rampLength)
			local rampCenter = base * CFrame.new(nextGap * (width / 2 - 15), y + 1 + levelHeight / 2, -depth / 2 + 12 + rampLength / 2 - 6)
			Builder.chunk(model, Vector3.new(26, 1, math.sqrt(rampLength ^ 2 + levelHeight ^ 2)), rampCenter * CFrame.Angles(angle, 0, 0), Color3.fromRGB(110, 108, 104), Enum.Material.Concrete, "Concrete", id, false)
			-- Pillars
			for x = -width / 2 + 6, width / 2 - 6, 24 do
				for _, sz in { -1, 0, 1 } do
					Builder.chunk(model, Vector3.new(2, levelHeight - 1, 2), base * CFrame.new(x, y + 1 + (levelHeight - 1) / 2, sz * (depth / 2 - 6)), Color3.fromRGB(160, 156, 150), Enum.Material.Concrete, "Concrete", id, level == 0)
				end
			end
			-- Parked cars
			for x = -width / 2 + 20, width / 2 - 40, 14 do
				if rng:NextNumber() < 0.5 then
					Props.car(model, base * CFrame.new(x, y + 1, depth / 2 - 14), rng)
				end
			end
			ceilingLight(model, base * CFrame.new(0, y + levelHeight - 0.6, 0), width - 20, Color3.fromRGB(230, 240, 255))
		end
	end
	local sign = Builder.part(model, "GarageSign", Vector3.new(16, 3, 0.5), base * CFrame.new(0, levelHeight * levels + 4, -depth / 2 - 1), Color3.fromRGB(20, 60, 140), Enum.Material.SmoothPlastic)
	Builder.sign(sign, Enum.NormalId.Front, "P  PARKING", Color3.new(1, 1, 1))
	return model
end

--------------------------------------------------------------------------------
-- 5. Warehouse
--------------------------------------------------------------------------------
function Interiors.warehouse(parent: Instance, lot: Lot)
	local width = math.min(lot.Width - 8, 160)
	local depth = math.min(lot.Depth - 8, 80)
	local warehouse = BuildingKit.build(parent, {
		Id = "Warehouse",
		Kind = "Warehouse",
		Center = lot.Center,
		Width = width,
		Depth = depth,
		Height = 32,
		Facing = lot.Facing,
		OpenFront = true,
		Seed = 31,
	})
	local base = frame(lot)
	local rng = Random.new(31)
	-- Crate stacks
	for _ = 1, 26 do
		local x = rng:NextNumber(-width / 2 + 10, width / 2 - 10)
		local z = rng:NextNumber(-depth / 2 + 16, depth / 2 - 8)
		local stack = rng:NextInteger(1, 3)
		for s = 0, stack - 1 do
			Builder.chunk(warehouse, Vector3.new(6, 6, 6), base * CFrame.new(x, 1 + 3 + s * 6, z) * CFrame.Angles(0, rng:NextNumber(-0.2, 0.2), 0), Color3.fromRGB(150, 110, 70), Enum.Material.WoodPlanks, "Wood", "Warehouse", s == 0)
		end
	end
	-- Shipping container
	Builder.chunk(warehouse, Vector3.new(10, 10, 30), base * CFrame.new(-width / 2 + 12, 6, 10), Color3.fromRGB(30, 90, 140), Enum.Material.CorrodedMetal, "Steel", "Warehouse", true)
	-- Catwalk along the back wall
	Builder.chunk(warehouse, Vector3.new(width - 10, 1, 6), base * CFrame.new(0, 18, depth / 2 - 5), Color3.fromRGB(60, 62, 64), Enum.Material.DiamondPlate, "Steel", "Warehouse", false)
	Builder.decor(warehouse, "CatwalkRail", Vector3.new(width - 10, 3, 0.3), base * CFrame.new(0, 20, depth / 2 - 8), Color3.fromRGB(200, 170, 40), Enum.Material.Metal)
	for step = 0, 16 do
		Builder.part(warehouse, "Stair", Vector3.new(5, 1, 2), base * CFrame.new(width / 2 - 8, 1 + step * 1.05, depth / 2 - 10 - step * 1.3), Color3.fromRGB(60, 62, 64), Enum.Material.DiamondPlate)
	end
	for x = -width / 2 + 20, width / 2 - 20, 30 do
		ceilingLight(warehouse, base * CFrame.new(x, 30, 0), 3, Color3.fromRGB(255, 230, 190))
	end
	return warehouse
end

--------------------------------------------------------------------------------
-- 6. Skyscraper with a destructible open-plan office floor
--------------------------------------------------------------------------------
function Interiors.openPlanTower(parent: Instance, lot: Lot)
	local width = math.min(lot.Width - 10, 100)
	local depth = math.min(lot.Depth - 6, 76)
	local tower = BuildingKit.build(parent, {
		Id = "OpenPlanTower",
		Kind = "Skyscraper",
		Center = lot.Center,
		Width = width,
		Depth = depth,
		Height = 240,
		Facing = lot.Facing,
		Seed = 99,
	})
	-- The office occupies the band starting at 108 studs (floors 10-12)
	local base = frame(lot) * CFrame.new(0, 108 + 1, 0)
	local rng = Random.new(99)
	local id = "OpenPlanTower"
	for x = -width / 2 + 10, width / 2 - 10, 12 do
		for z = -depth / 2 + 10, depth / 2 - 10, 10 do
			if rng:NextNumber() < 0.75 then
				Builder.chunk(tower, Vector3.new(6, 0.5, 3), base * CFrame.new(x, 2.7, z), Color3.fromRGB(200, 196, 188), Enum.Material.Wood, "Wood", id, false)
				Builder.chunk(tower, Vector3.new(0.4, 2.5, 3), base * CFrame.new(x - 2.8, 1.25, z), Color3.fromRGB(60, 60, 62), Enum.Material.Metal, "Steel", id, false)
				Builder.chunk(tower, Vector3.new(0.4, 2.5, 3), base * CFrame.new(x + 2.8, 1.25, z), Color3.fromRGB(60, 60, 62), Enum.Material.Metal, "Steel", id, false)
				-- Cubicle partition + monitor
				Builder.chunk(tower, Vector3.new(6, 4, 0.3), base * CFrame.new(x, 2, z + 1.8), Color3.fromRGB(150, 160, 170), Enum.Material.Fabric, "Wood", id, false)
				Builder.decor(tower, "Monitor", Vector3.new(2, 1.3, 0.2), base * CFrame.new(x, 3.6, z + 1), Color3.fromRGB(20, 25, 30), Enum.Material.SmoothPlastic)
			end
		end
	end
	-- Interior columns in the open plan
	for x = -width / 4, width / 4, width / 2 do
		for z = -depth / 4, depth / 4, depth / 2 do
			Builder.chunk(tower, Vector3.new(3, 35, 3), base * CFrame.new(x, 17.5, z), Color3.fromRGB(180, 178, 172), Enum.Material.Concrete, "Concrete", id, false)
		end
	end
	for z = -depth / 2 + 12, depth / 2 - 12, 16 do
		ceilingLight(tower, base * CFrame.new(0, 34, z), width - 16)
	end
	return tower
end

--------------------------------------------------------------------------------
-- 7. Museum hall
--------------------------------------------------------------------------------
function Interiors.museum(parent: Instance, lot: Lot)
	local model = Builder.model(parent, "HarborMuseum")
	local id = "HarborMuseum"
	local base = frame(lot)
	local width = math.min(lot.Width - 10, 180)
	local depth = math.min(lot.Depth - 10, 80)
	local height = 34
	local marble = Color3.fromRGB(226, 220, 208)
	room(model, id, base, width, depth, height, marble, Enum.Material.Marble, "Concrete", 18, false)
	-- Classical portico: steps + columns + pediment
	for step = 0, 3 do
		Builder.part(model, "Steps", Vector3.new(60 - step * 4, 1, 4), base * CFrame.new(0, step + 0.5, -depth / 2 - 14 + step * 3), marble, Enum.Material.Marble)
	end
	for x = -24, 24, 8 do
		Builder.chunk(model, Vector3.new(2.6, height, 2.6), base * CFrame.new(x, height / 2 + 1, -depth / 2 - 6), marble, Enum.Material.Marble, "Concrete", id, true).Shape = Enum.PartType.Block
	end
	Builder.chunk(model, Vector3.new(56, 3, 12), base * CFrame.new(0, height + 2.5, -depth / 2 - 5), marble, Enum.Material.Marble, "Concrete", id, false)
	local name = Builder.part(model, "Frieze", Vector3.new(40, 3, 0.4), base * CFrame.new(0, height + 2.5, -depth / 2 - 11.2), marble, Enum.Material.Marble)
	Builder.sign(name, Enum.NormalId.Front, "HARBOR MUSEUM OF HISTORY", Color3.fromRGB(60, 50, 40), marble, Enum.Font.Garamond)
	-- Skylight
	Builder.chunk(model, Vector3.new(width * 0.5, 0.6, depth * 0.5), base * CFrame.new(0, height + 2.3, 0), Color3.fromRGB(190, 225, 240), Enum.Material.Glass, "Glass", id, false).Transparency = 0.5
	-- Interior colonnade
	for x = -width / 2 + 20, width / 2 - 20, 20 do
		for _, sz in { -1, 1 } do
			local column = Builder.chunk(model, Vector3.new(height, 3, 3), base * CFrame.new(x, height / 2 + 1, sz * depth / 4) * CFrame.Angles(0, 0, math.rad(90)), marble, Enum.Material.Marble, "Concrete", id, true)
			column.Shape = Enum.PartType.Cylinder
		end
	end
	-- Original statue: abstract heroic figure on a plinth
	local plinth = Builder.chunk(model, Vector3.new(8, 4, 8), base * CFrame.new(0, 3, 6), Color3.fromRGB(80, 80, 84), Enum.Material.Granite, "Concrete", id, true)
	local bronze = Color3.fromRGB(150, 110, 60)
	Builder.decor(plinth, "StatueBody", Vector3.new(3, 8, 2), plinth.CFrame * CFrame.new(0, 6, 0), bronze, Enum.Material.Metal)
	Builder.decor(plinth, "StatueHead", Vector3.new(2, 2, 2), plinth.CFrame * CFrame.new(0, 11, 0), bronze, Enum.Material.Metal).Shape = Enum.PartType.Ball
	Builder.decor(plinth, "StatueArm", Vector3.new(1, 6, 1), plinth.CFrame * CFrame.new(1.8, 11, 0) * CFrame.Angles(0, 0, math.rad(-20)), bronze, Enum.Material.Metal)
	-- Display cases
	for x = -width / 2 + 25, width / 2 - 25, 25 do
		for _, sz in { -1, 1 } do
			local pedestal = Builder.chunk(model, Vector3.new(5, 3.5, 3), base * CFrame.new(x, 2.75, sz * (depth / 2 - 8)), Color3.fromRGB(60, 45, 35), Enum.Material.Wood, "Wood", id, true)
			local case = Builder.chunk(model, Vector3.new(5, 3, 3), pedestal.CFrame * CFrame.new(0, 3.25, 0), Color3.fromRGB(200, 230, 240), Enum.Material.Glass, "Glass", id, false)
			case.Transparency = 0.6
			Builder.decor(case, "Artifact", Vector3.new(1.2, 1.2, 1.2), case.CFrame, Color3.fromHSV(math.random(), 0.5, 0.8), Enum.Material.Metal).Shape = Enum.PartType.Ball
		end
	end
	for x = -width / 2 + 20, width / 2 - 20, 40 do
		ceilingLight(model, base * CFrame.new(x, height - 0.2, 0), 6, Color3.fromRGB(255, 240, 215))
	end
	return model
end

--------------------------------------------------------------------------------
-- 8. Rooftop bar on a mid-rise (with an outside stair tower)
--------------------------------------------------------------------------------
function Interiors.rooftopBar(parent: Instance, lot: Lot)
	local width = math.min(lot.Width - 20, 90)
	local depth = math.min(lot.Depth - 10, 70)
	local height = 48
	local building = BuildingKit.build(parent, {
		Id = "RooftopBarBuilding",
		Kind = "Midrise",
		Center = lot.Center,
		Width = width,
		Depth = depth,
		Height = height,
		Facing = lot.Facing,
		Seed = 55,
	})
	local base = frame(lot)
	local roofY = height + 1.8
	local id = "RooftopBar"
	-- Switchback stair tower on the left side
	local towerBase = base * CFrame.new(-width / 2 - 7, 0, 0)
	local flights = math.ceil(roofY / 6)
	for f = 0, flights - 1 do
		local dir = if f % 2 == 0 then 1 else -1
		for s = 0, 7 do
			local y = f * 6 + s * 0.75 + 0.5
			if y > roofY then
				break
			end
			Builder.part(building, "Stair", Vector3.new(5, 0.8, 2.2), towerBase * CFrame.new(if dir == 1 then -2.6 else 2.6, y, dir * (-8 + s * 2.2)), Color3.fromRGB(45, 45, 48), Enum.Material.DiamondPlate)
		end
		Builder.part(building, "Landing", Vector3.new(10.4, 0.8, 4), towerBase * CFrame.new(0, f * 6 + 6.5, dir * 10), Color3.fromRGB(45, 45, 48), Enum.Material.DiamondPlate)
	end
	Builder.part(building, "RoofLanding", Vector3.new(8, 0.8, 8), base * CFrame.new(-width / 2 - 2, roofY - 0.4, 0), Color3.fromRGB(45, 45, 48), Enum.Material.DiamondPlate)
	-- Bar deck
	local deck = base * CFrame.new(0, roofY, 0)
	Builder.chunk(building, Vector3.new(width - 6, 0.4, depth - 6), deck * CFrame.new(0, 0.2, 0), Color3.fromRGB(130, 96, 66), Enum.Material.WoodPlanks, "Wood", id, false)
	Builder.chunk(building, Vector3.new(24, 4, 3), deck * CFrame.new(0, 2.2, depth / 2 - 10), Color3.fromRGB(60, 40, 30), Enum.Material.Wood, "Wood", id, false)
	Props.neonSign(building, deck * CFrame.new(0, 7, depth / 2 - 8.4) * CFrame.Angles(0, math.pi, 0), "SKYLINE BAR", Color3.fromRGB(120, 220, 255))
	for x = -width / 2 + 12, width / 2 - 12, 14 do
		for z = -depth / 2 + 12, depth / 2 - 20, 14 do
			local tableTop = Builder.chunk(building, Vector3.new(0.4, 4, 4), deck * CFrame.new(x, 3.2, z) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(230, 230, 226), Enum.Material.Metal, "Steel", id, false)
			tableTop.Shape = Enum.PartType.Cylinder
			Builder.decor(tableTop, "Umbrella", Vector3.new(0.4, 9, 9), deck * CFrame.new(x, 8, z) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(200, 60, 50), Enum.Material.Fabric).Shape = Enum.PartType.Cylinder
		end
	end
	-- String lights
	for i = 0, 12 do
		local bulb = Builder.decor(building, "StringLight", Vector3.new(0.6, 0.6, 0.6), deck * CFrame.new(-width / 2 + 6 + i * (width - 12) / 12, 8 + math.sin(i / 12 * math.pi) * -1.5, 0), Color3.fromRGB(255, 220, 150), Enum.Material.Neon)
		bulb.Shape = Enum.PartType.Ball
		if i % 3 == 0 then
			Builder.pointLight(bulb, Color3.fromRGB(255, 210, 140), 16, 0.8, "ApexNeonLight")
		end
	end
	return building
end

return Interiors
