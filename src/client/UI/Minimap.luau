--!strict
-- North-up minimap (top-right) drawn from MapConfig: forest, water, city
-- grid, park, lake, river, highway and the map border. The local player is
-- an arrow at the centre (rotates with the camera); other players are dots.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local MapConfig = require(ReplicatedStorage:WaitForChild("ApexCity").Config.MapConfig)

local Ui = require(script.Parent.Ui)

local player = Players.LocalPlayer

local SIZE = 190
local SCALE = 0.055 -- pixels per stud
local DOT_RANGE = 1400

local Minimap = {}

local canvas: Frame
local arrow: TextLabel
local dots: { [Player]: Frame } = {}

local function rect(parent: Instance, minX: number, maxX: number, minZ: number, maxZ: number, color: Color3, transparency: number?, z: number?)
	return Ui.new("Frame", {
		Position = UDim2.fromOffset(minX * SCALE, minZ * SCALE),
		Size = UDim2.fromOffset((maxX - minX) * SCALE, (maxZ - minZ) * SCALE),
		BackgroundColor3 = color,
		BackgroundTransparency = transparency or 0,
		BorderSizePixel = 0,
		ZIndex = z or 2,
		Parent = parent,
	})
end

local function line(parent: Instance, a: Vector3, b: Vector3, width: number, color: Color3, z: number?)
	local mid = (a + b) / 2
	local length = (Vector3.new(b.X, 0, b.Z) - Vector3.new(a.X, 0, a.Z)).Magnitude
	local angle = math.deg(math.atan2(b.Z - a.Z, b.X - a.X))
	Ui.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(mid.X * SCALE, mid.Z * SCALE),
		Size = UDim2.fromOffset(length * SCALE, width),
		Rotation = angle,
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		ZIndex = z or 3,
		Parent = parent,
	})
end

local function drawWorld(parent: Instance)
	local border = MapConfig.Border.Radius
	-- Forest disc + border ring
	local disc = rect(parent, -border, border, -border, border, Color3.fromRGB(40, 70, 44), 0, 1)
	Ui.corner(1000).Parent = disc
	Ui.stroke(Color3.fromRGB(140, 200, 255), 2, 0.2).Parent = disc
	-- Harbour water
	local h = MapConfig.Harbor
	rect(parent, h.WaterMinX, h.WaterMaxX, h.WaterMinZ, h.WaterMaxZ, Color3.fromRGB(40, 90, 130), 0, 2)
	-- City
	local half = MapConfig.City.HalfSize
	rect(parent, -half, h.WaterfrontX + 20, -half, half, Color3.fromRGB(70, 72, 78), 0, 2)
	for k = 0, 10 do
		local x = -half + k * MapConfig.City.AvenueSpacing
		if x <= h.WaterfrontX then
			rect(parent, x - 18, x + 18, -half, half, Color3.fromRGB(40, 42, 46), 0, 3)
		end
	end
	for j = 0, 20 do
		local z = -half + j * MapConfig.City.StreetSpacing
		rect(parent, -half, h.WaterfrontX, z - 13, z + 13, Color3.fromRGB(40, 42, 46), 0, 3)
	end
	local park = MapConfig.Park
	rect(parent, park.MinX, park.MaxX, park.MinZ, park.MaxZ, Color3.fromRGB(70, 120, 60), 0, 4)
	-- Lake + river + roads
	local lake = MapConfig.Forest.Lake
	local lakeFrame = rect(parent, lake.X - lake.Radius, lake.X + lake.Radius, lake.Z - lake.Radius, lake.Z + lake.Radius, Color3.fromRGB(40, 90, 130), 0, 2)
	Ui.corner(1000).Parent = lakeFrame
	local river = MapConfig.Forest.River
	for i = 1, #river - 1 do
		line(parent, river[i], river[i + 1], 3, Color3.fromRGB(40, 90, 130), 2)
	end
	local highway = MapConfig.Highway.Points
	for i = 1, #highway - 1 do
		line(parent, highway[i], highway[i + 1], 2, Color3.fromRGB(150, 150, 150), 3)
	end
	for _, connector in MapConfig.ConnectorRoads do
		line(parent, connector.From, connector.To, 1.5, Color3.fromRGB(130, 130, 130), 3)
	end
	line(parent, Vector3.new(MapConfig.Bridge.StartX, 0, MapConfig.Bridge.Z), Vector3.new(MapConfig.Bridge.EndX, 0, MapConfig.Bridge.Z), 3, Color3.fromRGB(170, 90, 60), 4)
end

local function build(parent: Instance)
	local frame = Ui.new("Frame", {
		Name = "Minimap",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 16),
		Size = UDim2.fromOffset(SIZE, SIZE),
		BackgroundColor3 = Ui.Colors.Panel,
		BackgroundTransparency = 0.1,
		ClipsDescendants = true,
		Parent = parent,
	}, { Ui.corner(10), Ui.stroke(Color3.new(1, 1, 1), 1.5, 0.7) }) :: Frame
	canvas = Ui.new("Frame", {
		Size = UDim2.fromOffset(0, 0),
		BackgroundTransparency = 1,
		Parent = frame,
	}) :: Frame
	drawWorld(canvas)
	arrow = Ui.label("▲", 18, Color3.fromRGB(255, 220, 90)) :: TextLabel
	arrow.AnchorPoint = Vector2.new(0.5, 0.5)
	arrow.Position = UDim2.fromScale(0.5, 0.5)
	arrow.Size = UDim2.fromOffset(20, 20)
	arrow.TextXAlignment = Enum.TextXAlignment.Center
	arrow.TextStrokeTransparency = 0.2
	arrow.ZIndex = 20
	arrow.Parent = frame
	local north = Ui.label("N", 12, Ui.Colors.Text) :: TextLabel
	north.AnchorPoint = Vector2.new(0.5, 0)
	north.Position = UDim2.new(0.5, 0, 0, 2)
	north.Size = UDim2.fromOffset(12, 12)
	north.TextXAlignment = Enum.TextXAlignment.Center
	north.ZIndex = 20
	north.Parent = frame
end

local function update()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return
	end
	local position = root.Position
	canvas.Position = UDim2.fromOffset(SIZE / 2 - position.X * SCALE, SIZE / 2 - position.Z * SCALE)
	local camera = workspace.CurrentCamera
	if camera then
		local look = camera.CFrame.LookVector
		arrow.Rotation = math.deg(math.atan2(look.X, -look.Z))
	end
	-- Other players
	for _, other in Players:GetPlayers() do
		if other == player then
			continue
		end
		local otherRoot = other.Character and other.Character:FindFirstChild("HumanoidRootPart")
		local dot = dots[other]
		local visible = otherRoot ~= nil and otherRoot:IsA("BasePart") and (otherRoot.Position - position).Magnitude < DOT_RANGE
			and other.Character:GetAttribute("ApexInvisible") ~= true
		if visible and otherRoot and otherRoot:IsA("BasePart") then
			if not dot then
				dot = Ui.new("Frame", {
					AnchorPoint = Vector2.new(0.5, 0.5),
					Size = UDim2.fromOffset(7, 7),
					BackgroundColor3 = Color3.fromRGB(255, 80, 80),
					ZIndex = 15,
					Parent = canvas,
				}, { Ui.corner(10) }) :: Frame
				dots[other] = dot
			end
			local d = dot :: Frame
			d.Visible = true
			d.Position = UDim2.fromOffset(otherRoot.Position.X * SCALE, otherRoot.Position.Z * SCALE)
		elseif dot then
			dot.Visible = false
		end
	end
end

function Minimap.init(parent: Instance)
	build(parent)
	Players.PlayerRemoving:Connect(function(other)
		local dot = dots[other]
		if dot then
			dot:Destroy()
			dots[other] = nil
		end
	end)
	local accumulator = 0
	RunService.RenderStepped:Connect(function(dt)
		accumulator += dt
		if accumulator >= 1 / 20 then
			accumulator = 0
			update()
		end
	end)
end

return Minimap
