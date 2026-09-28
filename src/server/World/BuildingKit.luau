--!strict
-- Procedural buildings made of destructible chunks: wall panels (per band of
-- floors), floor slabs and corner pillars. Every chunk carries its material
-- kind (Glass / Concrete / Steel / Wood / Brick) for the destruction system.
-- Decorative details (window frames, cornices, fire escapes, water towers)
-- are parented to the chunk they sit on so they go down with it.

local Builder = require(script.Parent.Builder)

type ChunkMaterial = Builder.ChunkMaterial

export type BuildingKind = "Skyscraper" | "Midrise" | "Brownstone" | "Warehouse" | "Garage" | "Plain"

export type BuildingSpec = {
	Id: string,
	Kind: BuildingKind,
	Center: Vector3, -- ground-level centre of the footprint
	Width: number, -- along the front (local X)
	Depth: number, -- local Z (front faces -Z)
	Height: number,
	Facing: number, -- yaw in radians; front of the building faces the street
	OpenFront: boolean?, -- leave a ground-floor opening (enterable / lobby)
	Seed: number,
}

type ShellStyle = {
	floorHeight: number,
	floorsPerBand: number,
	panelWidth: number,
	wallThickness: number,
	wallColor: Color3,
	wallMaterial: Enum.Material,
	wallKind: ChunkMaterial,
	transparency: number,
	reflectance: number,
	pillarKind: ChunkMaterial,
	pillarColor: Color3,
	slabColor: Color3,
	windowStyle: "None" | "Grid" | "Bands",
	lightChance: number,
	pillars: boolean, -- corner pillars per band (false = load-bearing walls)
	sideWindows: boolean, -- windows on the side walls too (row houses: no)
}

local BuildingKit = {}

local GLASS_TINTS = {
	Color3.fromRGB(58, 78, 92), Color3.fromRGB(70, 88, 84), Color3.fromRGB(96, 84, 66),
	Color3.fromRGB(64, 70, 82), Color3.fromRGB(84, 96, 108),
}
local CONCRETE_TONES = {
	Color3.fromRGB(176, 168, 152), Color3.fromRGB(150, 146, 140), Color3.fromRGB(196, 186, 168),
	Color3.fromRGB(128, 124, 120), Color3.fromRGB(170, 150, 128),
}
local BRICK_TONES = {
	Color3.fromRGB(128, 68, 52), Color3.fromRGB(110, 62, 48), Color3.fromRGB(142, 88, 64),
	Color3.fromRGB(96, 58, 50), Color3.fromRGB(150, 104, 78),
}

local function pick<T>(rng: Random, list: { T }): T
	return list[rng:NextInteger(1, #list)]
end

-- Windows on a wall panel (decor children of the chunk).
local function addWindows(panel: Part, style: ShellStyle, rng: Random, floors: number, outward: Vector3)
	if style.windowStyle == "None" then
		return
	end
	local size = panel.Size
	if style.windowStyle == "Bands" then
		for f = 0, floors - 1 do
			local y = -size.Y / 2 + style.floorHeight * (f + 0.55)
			local band = Builder.decor(panel, "Window", Vector3.new(size.X - 1.2, style.floorHeight * 0.45, 0.2), panel.CFrame * CFrame.new(0, y, 0) + outward * (size.Z / 2 + 0.05), Color3.fromRGB(52, 64, 78), Enum.Material.Glass)
			band.Reflectance = 0.25
			if rng:NextNumber() < style.lightChance then
				Builder.tag(band, "ApexWindowLight")
			end
		end
	else -- Grid
		local columns = math.clamp(math.floor(size.X / 10), 1, 3)
		local spacing = size.X / columns
		for f = 0, floors - 1 do
			local y = -size.Y / 2 + style.floorHeight * (f + 0.5)
			for c = 0, columns - 1 do
				local x = -size.X / 2 + spacing * (c + 0.5)
				local window = Builder.decor(panel, "Window", Vector3.new(spacing * 0.5, style.floorHeight * 0.55, 0.2), panel.CFrame * CFrame.new(x, y, 0) + outward * (size.Z / 2 + 0.05), Color3.fromRGB(40, 48, 58), Enum.Material.Glass)
				window.Reflectance = 0.3
				if rng:NextNumber() < style.lightChance then
					Builder.tag(window, "ApexWindowLight")
				end
			end
		end
	end
end

-- Core shell: bands of wall panels, slabs, pillars. Returns the roof slab.
local function shell(model: Model, spec: BuildingSpec, style: ShellStyle, rng: Random, width: number, depth: number, height: number, baseY: number, openFront: boolean?): Part?
	local base = CFrame.new(spec.Center.X, baseY, spec.Center.Z) * CFrame.Angles(0, spec.Facing, 0)
	local floors = math.max(1, math.floor(height / style.floorHeight))
	local bandHeight = style.floorHeight * style.floorsPerBand
	local bands = math.ceil(floors / style.floorsPerBand)
	local t = style.wallThickness
	local grounded = baseY <= spec.Center.Y + 0.5
	local roof: Part? = nil

	for b = 0, bands - 1 do
		local floorsHere = math.min(style.floorsPerBand, floors - b * style.floorsPerBand)
		local h = style.floorHeight * floorsHere
		local y0 = b * bandHeight
		local isGround = b == 0 and grounded

		-- Floor slab
		local slab = Builder.chunk(model, Vector3.new(width, 1, depth), base * CFrame.new(0, y0 + 0.5, 0), style.slabColor, Enum.Material.Concrete, "Concrete", spec.Id, isGround)
		slab.Name = "Slab"

		-- Corner pillars
		for _, sx in (if style.pillars then { -1, 1 } else {}) :: { number } do
			for _, sz in { -1, 1 } do
				Builder.chunk(model, Vector3.new(2.4, h, 2.4), base * CFrame.new(sx * (width / 2 - 1.2), y0 + 1 + h / 2 - 0.5, sz * (depth / 2 - 1.2)), style.pillarColor, if style.pillarKind == "Steel" then Enum.Material.Metal else Enum.Material.Concrete, style.pillarKind, spec.Id, isGround)
			end
		end

		-- Walls: front (-Z), back (+Z), left (-X), right (+X)
		local sides = {
			{ length = width, offset = CFrame.new(0, 0, -depth / 2 + t / 2), front = true, windows = true },
			{ length = width, offset = CFrame.new(0, 0, depth / 2 - t / 2) * CFrame.Angles(0, math.pi, 0), front = false, windows = true },
			{ length = depth, offset = CFrame.new(-width / 2 + t / 2, 0, 0) * CFrame.Angles(0, math.rad(90), 0), front = false, windows = style.sideWindows },
			{ length = depth, offset = CFrame.new(width / 2 - t / 2, 0, 0) * CFrame.Angles(0, math.rad(-90), 0), front = false, windows = style.sideWindows },
		}
		for _, side in sides do
			local usable = side.length - 4.8
			local count = math.max(1, math.ceil(usable / style.panelWidth))
			local panelWidth = usable / count
			for i = 0, count - 1 do
				local x = -usable / 2 + panelWidth * (i + 0.5)
				-- Doorway: skip the middle ground-floor front panel(s)
				if side.front and b == 0 and openFront and math.abs(x) < panelWidth then
					-- lintel above the opening keeps the facade supported
					local lintelHeight = math.max(h - 12, 2)
					local lintelCF = base * side.offset * CFrame.new(x, y0 + 1 + (h - lintelHeight) + lintelHeight / 2 - 0.5, 0)
					Builder.chunk(model, Vector3.new(panelWidth - 0.1, lintelHeight, t), lintelCF, style.wallColor, style.wallMaterial, style.wallKind, spec.Id, false)
					continue
				end
				local cf = base * side.offset * CFrame.new(x, y0 + 1 + h / 2 - 0.5, 0)
				local panel = Builder.chunk(model, Vector3.new(panelWidth - 0.1, h - 1, t), cf, style.wallColor, style.wallMaterial, style.wallKind, spec.Id, isGround)
				panel.Transparency = style.transparency
				panel.Reflectance = style.reflectance
				if style.wallKind == "Glass" and rng:NextNumber() < style.lightChance then
					Builder.tag(panel, "ApexWindowLight")
				end
				if side.windows then
					addWindows(panel, style, rng, floorsHere, (base * side.offset).LookVector * -1)
				end
			end
		end

		if b == bands - 1 then
			local top = Builder.chunk(model, Vector3.new(width, 1.2, depth), base * CFrame.new(0, y0 + h + 0.6, 0), style.slabColor, Enum.Material.Concrete, "Concrete", spec.Id, false)
			top.Name = "Roof"
			roof = top
			-- Parapet
			for _, side in sides do
				Builder.decor(top, "Parapet", Vector3.new(side.length, 2.5, 0.8), base * side.offset * CFrame.new(0, y0 + h + 2.4, -t / 2 + 0.4), style.slabColor, Enum.Material.Concrete)
			end
		end
	end
	return roof
end

local function waterTower(roof: Part, rng: Random)
	local top = roof.Position + Vector3.new(rng:NextNumber(-roof.Size.X / 4, roof.Size.X / 4), roof.Size.Y / 2, rng:NextNumber(-roof.Size.Z / 4, roof.Size.Z / 4))
	for _, leg in { Vector3.new(-2.5, 0, -2.5), Vector3.new(2.5, 0, -2.5), Vector3.new(-2.5, 0, 2.5), Vector3.new(2.5, 0, 2.5) } do
		Builder.decor(roof, "TowerLeg", Vector3.new(0.6, 8, 0.6), CFrame.new(top + leg + Vector3.new(0, 4, 0)), Color3.fromRGB(60, 50, 45), Enum.Material.Metal)
	end
	local tank = Builder.cylinder(roof, "WaterTank", 10, 9, CFrame.new(top + Vector3.new(0, 13, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(120, 92, 68), Enum.Material.WoodPlanks)
	tank.CanCollide = true
	local cone = Builder.decor(roof, "TankRoof", Vector3.new(2, 10, 10), CFrame.new(top + Vector3.new(0, 19, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(70, 60, 55), Enum.Material.Metal)
	cone.Shape = Enum.PartType.Cylinder
end

local function rooftopUnits(roof: Part, rng: Random)
	for _ = 1, rng:NextInteger(1, 3) do
		local offset = Vector3.new(rng:NextNumber(-roof.Size.X / 3, roof.Size.X / 3), 0, rng:NextNumber(-roof.Size.Z / 3, roof.Size.Z / 3))
		Builder.part(roof, "ACUnit", Vector3.new(6, 3, 5), CFrame.new(roof.Position + offset + Vector3.new(0, 2.1, 0)), Color3.fromRGB(150, 152, 155), Enum.Material.DiamondPlate)
	end
end

--------------------------------------------------------------------------------
-- Building types
--------------------------------------------------------------------------------
function BuildingKit.build(parent: Instance, spec: BuildingSpec): Model
	local rng = Random.new(spec.Seed)
	local model = Builder.model(parent, spec.Id)
	model:SetAttribute("ApexBuildingKind", spec.Kind)
	local groundY = spec.Center.Y

	if spec.Kind == "Skyscraper" then
		local style: ShellStyle = {
			floorHeight = 12,
			floorsPerBand = 3,
			panelWidth = 30,
			wallThickness = 1.2,
			wallColor = pick(rng, GLASS_TINTS),
			wallMaterial = Enum.Material.Glass,
			wallKind = "Glass",
			transparency = 0.25,
			reflectance = 0.2,
			pillarKind = "Steel",
			pillarColor = Color3.fromRGB(70, 74, 80),
			slabColor = Color3.fromRGB(120, 122, 124),
			windowStyle = "None",
			lightChance = 0.45,
			pillars = true,
			sideWindows = false,
		}
		local setback = rng:NextNumber() < 0.45 and spec.Height > 180
		local lowerHeight = if setback then spec.Height * 0.65 else spec.Height
		local roof = shell(model, spec, style, rng, spec.Width, spec.Depth, lowerHeight, groundY, spec.OpenFront)
		if setback and roof then
			local upperY = roof.Position.Y + 0.6
			roof = shell(model, spec, style, rng, spec.Width * 0.68, spec.Depth * 0.68, spec.Height - lowerHeight, upperY, false)
		end
		if roof then
			rooftopUnits(roof, rng)
			if rng:NextNumber() < 0.5 then
				local antenna = Builder.decor(roof, "Antenna", Vector3.new(1, 40, 1), CFrame.new(roof.Position + Vector3.new(0, 20.6, 0)), Color3.fromRGB(180, 180, 185), Enum.Material.Metal)
				local beacon = Builder.decor(antenna, "Beacon", Vector3.new(1.4, 1.4, 1.4), CFrame.new(antenna.Position + Vector3.new(0, 20, 0)), Color3.fromRGB(255, 40, 40), Enum.Material.Neon)
				beacon.Shape = Enum.PartType.Ball
			end
		end
	elseif spec.Kind == "Midrise" then
		local style: ShellStyle = {
			floorHeight = 12,
			floorsPerBand = 2,
			panelWidth = 30,
			wallThickness = 1.5,
			wallColor = pick(rng, CONCRETE_TONES),
			wallMaterial = Enum.Material.Concrete,
			wallKind = "Concrete",
			transparency = 0,
			reflectance = 0,
			pillarKind = "Concrete",
			pillarColor = Color3.fromRGB(140, 136, 130),
			slabColor = Color3.fromRGB(130, 128, 124),
			windowStyle = "Bands",
			lightChance = 0.4,
			pillars = true,
			sideWindows = spec.Height > 70,
		}
		local roof = shell(model, spec, style, rng, spec.Width, spec.Depth, spec.Height, groundY, spec.OpenFront)
		if roof then
			if rng:NextNumber() < 0.5 then
				waterTower(roof, rng)
			else
				rooftopUnits(roof, rng)
			end
		end
	elseif spec.Kind == "Brownstone" then
		local style: ShellStyle = {
			floorHeight = 11,
			floorsPerBand = 1,
			panelWidth = 34,
			wallThickness = 1.5,
			wallColor = pick(rng, BRICK_TONES),
			wallMaterial = Enum.Material.Brick,
			wallKind = "Brick",
			transparency = 0,
			reflectance = 0,
			pillarKind = "Brick",
			pillarColor = Color3.fromRGB(90, 60, 50),
			slabColor = Color3.fromRGB(110, 104, 98),
			windowStyle = "Grid",
			lightChance = 0.35,
			pillars = false,
			sideWindows = false,
		}
		local roof = shell(model, spec, style, rng, spec.Width, spec.Depth, spec.Height, groundY, spec.OpenFront)
		local base = CFrame.new(spec.Center) * CFrame.Angles(0, spec.Facing, 0)
		-- Stoop
		for step = 0, 3 do
			Builder.part(model, "Stoop", Vector3.new(6, 1, 2), base * CFrame.new(0, step + 0.5, -spec.Depth / 2 - 7 + step * 2), Color3.fromRGB(120, 100, 88), Enum.Material.Slate)
		end
		-- Fire escape on the front: landings + ladder rails per floor
		local floors = math.floor(spec.Height / 11)
		if floors >= 3 and rng:NextNumber() < 0.7 then
			for f = 1, floors - 1 do
				local landing = Builder.decor(model, "FireEscape", Vector3.new(10, 0.3, 3.5), base * CFrame.new(spec.Width / 4, f * 11 + 0.5, -spec.Depth / 2 - 1.8), Color3.fromRGB(35, 35, 38), Enum.Material.DiamondPlate)
				landing.CanCollide = true
				Builder.decor(landing, "Rail", Vector3.new(10, 3, 0.2), landing.CFrame * CFrame.new(0, 1.6, -1.7), Color3.fromRGB(35, 35, 38), Enum.Material.Metal)
				Builder.decor(landing, "Ladder", Vector3.new(1.2, 11, 0.2), landing.CFrame * CFrame.new(3.5, -5.5, -1.2) * CFrame.Angles(math.rad(-20), 0, 0), Color3.fromRGB(35, 35, 38), Enum.Material.Metal)
			end
		end
		if roof then
			-- Cornice
			Builder.decor(roof, "Cornice", Vector3.new(spec.Width + 1.5, 1.5, 2), base * CFrame.new(0, spec.Height + 1.8, -spec.Depth / 2 - 0.4), Color3.fromRGB(80, 70, 64), Enum.Material.Concrete)
			if rng:NextNumber() < 0.35 then
				waterTower(roof, rng)
			end
		end
	elseif spec.Kind == "Warehouse" or spec.Kind == "Garage" or spec.Kind == "Plain" then
		local style: ShellStyle = {
			floorHeight = if spec.Kind == "Warehouse" then spec.Height else 12,
			floorsPerBand = 1,
			panelWidth = 20,
			wallThickness = 1.5,
			wallColor = if spec.Kind == "Warehouse" then Color3.fromRGB(110, 118, 124) else pick(rng, CONCRETE_TONES),
			wallMaterial = if spec.Kind == "Warehouse" then Enum.Material.CorrodedMetal else Enum.Material.Concrete,
			wallKind = if spec.Kind == "Warehouse" then "Steel" else "Concrete",
			transparency = 0,
			reflectance = 0,
			pillarKind = "Steel",
			pillarColor = Color3.fromRGB(80, 80, 84),
			slabColor = Color3.fromRGB(120, 118, 114),
			windowStyle = if spec.Kind == "Plain" then "Bands" else "None",
			lightChance = 0.3,
			pillars = spec.Kind ~= "Plain",
			sideWindows = false,
		}
		shell(model, spec, style, rng, spec.Width, spec.Depth, spec.Height, groundY, spec.OpenFront)
	end
	return model
end

return BuildingKit
