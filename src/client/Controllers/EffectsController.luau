--!strict
-- Plays cosmetic effects the server broadcasts through the Effect remote.
-- Effects never change gameplay state. Other modules (CombatFx,
-- ProjectileFx, BeamController, DestructionFx...) register more handlers.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("ApexCity")
local Remotes = require(Shared.Net.Remotes)
local CharacterRegistry = require(Shared.CharacterRegistry)
local AssetRegistry = require(Shared.AssetRegistry)

local PoseController = require(script.Parent.PoseController)

type Handler = (payload: { [string]: any }) -> ()

local EffectsController = {}

local handlers: { [string]: Handler } = {}

local function glowFor(source: any): Color3
	if typeof(source) == "Instance" then
		local id = (source :: Instance):GetAttribute("ApexCharacter")
		local config = if type(id) == "string" then CharacterRegistry.get(id) else nil
		if config then
			return config.Palette.Glow
		end
	end
	return Color3.fromRGB(0, 170, 255)
end

handlers.Pulse = function(payload)
	local position = payload.Position
	local radius = payload.Radius
	if typeof(position) ~= "Vector3" or type(radius) ~= "number" then
		return
	end
	local ring = Instance.new("Part")
	ring.Name = "ApexPulse"
	ring.Shape = Enum.PartType.Cylinder
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.CastShadow = false
	ring.Material = Enum.Material.Neon
	ring.Color = glowFor(payload.Source)
	ring.Transparency = 0.2
	ring.Size = Vector3.new(0.4, 2, 2)
	ring.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
	ring.Parent = workspace

	local light = Instance.new("PointLight")
	light.Color = ring.Color
	light.Range = radius
	light.Brightness = 3
	light.Parent = ring

	local info = TweenInfo.new(0.45, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
	TweenService:Create(ring, info, { Size = Vector3.new(0.2, radius * 2, radius * 2), Transparency = 1 }):Play()
	TweenService:Create(light, info, { Brightness = 0 }):Play()
	task.delay(0.5, function()
		ring:Destroy()
	end)
end

-- Folder for client-only effect parts (never replicated, never queried).
local effectsFolder: Folder? = nil
local function getFolder(): Folder
	local folder = effectsFolder
	if not folder or folder.Parent == nil then
		local created = Instance.new("Folder")
		created.Name = "ApexClientEffects"
		created.Parent = workspace
		effectsFolder = created
		folder = created
	end
	return folder :: Folder
end

local function effectPart(): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	return part
end

local function colorFrom(payload: { [string]: any }): Color3
	local color = payload.Color
	if typeof(color) == "Color3" then
		return color
	end
	return glowFor(payload.Source)
end

local playSound: ((string, { [string]: any }) -> ())? = nil

-- Expanding ring perpendicular to the flight direction on entering boost.
handlers.SonicBoom = function(payload)
	if playSound and typeof(payload.Position) == "Vector3" then
		playSound("Sound.SonicBoom", { Position = payload.Position, Volume = 1.2, Pitch = 0.4, MaxDistance = 500 })
	end
	local position = payload.Position
	local direction = payload.Direction
	if typeof(position) ~= "Vector3" or typeof(direction) ~= "Vector3" or direction.Magnitude < 1e-3 then
		return
	end
	local color = colorFrom(payload)
	for i = 0, 1 do
		local ring = effectPart()
		ring.Shape = Enum.PartType.Cylinder
		ring.Material = Enum.Material.ForceField
		ring.Color = if i == 0 then Color3.new(1, 1, 1) else color
		ring.Transparency = 0.1
		-- Cylinder axis is X: point it along the travel direction
		ring.CFrame = CFrame.lookAt(position, position + direction.Unit) * CFrame.Angles(0, math.rad(90), 0)
		ring.Size = Vector3.new(0.6, 4, 4)
		ring.Parent = getFolder()
		local size = 26 + i * 12
		local info = TweenInfo.new(0.35 + i * 0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		TweenService:Create(ring, info, { Size = Vector3.new(0.1, size, size), Transparency = 1 }):Play()
		Debris:AddItem(ring, 0.6)
	end
end

-- Superhero landing: scorch disc, rock ring, flying debris, dust.
handlers.Crater = function(payload)
	local position = payload.Position
	local strength = payload.Strength
	if typeof(position) ~= "Vector3" or type(strength) ~= "number" then
		return
	end
	strength = math.clamp(strength, 0, 1)
	local source = payload.Source
	if typeof(source) == "Instance" and source:IsA("Model") then
		PoseController.playLanding(source)
	end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore: { Instance } = { getFolder() }
	for _, other in Players:GetPlayers() do
		if other.Character then
			table.insert(ignore, other.Character)
		end
	end
	params.FilterDescendantsInstances = ignore
	local ground = workspace:Raycast(position + Vector3.new(0, 3, 0), Vector3.new(0, -10, 0), params)
	if not ground then
		return
	end
	local groundColor = if ground.Instance:IsA("BasePart") then ground.Instance.Color else Color3.fromRGB(90, 90, 90)
	local groundMaterial = ground.Material
	local center = ground.Position
	local normal = ground.Normal
	-- Frame with +Y along the surface normal
	local tangent = normal:Cross(Vector3.zAxis)
	if tangent.Magnitude < 1e-3 then
		tangent = normal:Cross(Vector3.xAxis)
	end
	local base = CFrame.fromMatrix(center, tangent.Unit, normal)
	local radius = 4 + strength * 8
	local folder = getFolder()
	local lifetime = 20

	-- Scorch disc
	local scorch = effectPart()
	scorch.Shape = Enum.PartType.Cylinder
	scorch.Material = Enum.Material.Slate
	scorch.Color = groundColor:Lerp(Color3.new(0.05, 0.05, 0.05), 0.75)
	scorch.Size = Vector3.new(0.12, radius * 2, radius * 2)
	scorch.CFrame = base * CFrame.new(0, 0.04, 0) * CFrame.Angles(0, 0, math.rad(90))
	scorch.Parent = folder

	-- Rock ring (tilted slabs around the rim)
	local slabs = 8 + math.floor(strength * 8)
	local parts: { BasePart } = { scorch }
	for i = 1, slabs do
		local angle = (i / slabs) * math.pi * 2 + math.random() * 0.3
		local slab = effectPart()
		slab.Material = groundMaterial
		slab.Color = groundColor:Lerp(Color3.new(0, 0, 0), 0.25)
		local w = 1.5 + math.random() * 2 * (0.5 + strength)
		slab.Size = Vector3.new(w, 0.6 + math.random() * strength * 1.4, 1 + math.random() * 1.5)
		slab.CFrame = base
			* CFrame.Angles(0, angle, 0)
			* CFrame.new(0, 0.2, -radius * (0.85 + math.random() * 0.2))
			* CFrame.Angles(math.rad(25 + math.random() * 30), 0, math.rad(math.random() * 20 - 10))
		slab.Parent = folder
		table.insert(parts, slab)
	end

	-- Flying debris chunks (unanchored, short-lived)
	local chunks = 6 + math.floor(strength * 10)
	for _ = 1, chunks do
		local chunk = effectPart()
		chunk.Anchored = false
		chunk.CanCollide = true
		chunk.Material = groundMaterial
		chunk.Color = groundColor
		local s = 0.4 + math.random() * 0.9
		chunk.Size = Vector3.new(s, s * 0.7, s)
		chunk.CFrame = CFrame.new(center + Vector3.new(0, 1, 0)) * CFrame.Angles(math.random() * 6, math.random() * 6, 0)
		chunk.Parent = folder
		local outward = Vector3.new(math.random() - 0.5, 0, math.random() - 0.5)
		outward = if outward.Magnitude > 1e-3 then outward.Unit else Vector3.xAxis
		chunk.AssemblyLinearVelocity = outward * (20 + math.random() * 30 * strength) + normal * (25 + math.random() * 35 * strength)
		chunk.AssemblyAngularVelocity = Vector3.new(math.random() * 20, math.random() * 20, math.random() * 20)
		Debris:AddItem(chunk, 4 + math.random() * 2)
	end

	-- Dust burst
	local dustAnchor = effectPart()
	dustAnchor.Transparency = 1
	dustAnchor.Size = Vector3.new(1, 1, 1)
	dustAnchor.CFrame = CFrame.new(center)
	dustAnchor.Parent = folder
	local dust = Instance.new("ParticleEmitter")
	dust.Color = ColorSequence.new(groundColor:Lerp(Color3.new(0.8, 0.8, 0.8), 0.5))
	dust.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.4),
		NumberSequenceKeypoint.new(1, 1),
	})
	dust.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 2),
		NumberSequenceKeypoint.new(1, 6 + strength * 6),
	})
	dust.Lifetime = NumberRange.new(0.8, 1.6)
	dust.Speed = NumberRange.new(15, 30 + strength * 30)
	dust.SpreadAngle = Vector2.new(180, 20)
	dust.Drag = 4
	dust.EmissionDirection = Enum.NormalId.Top
	dust.Rate = 0
	dust.Parent = dustAnchor
	dust:Emit(math.floor(20 + strength * 40))
	Debris:AddItem(dustAnchor, 2)

	-- Landing thump
	local landId = AssetRegistry.contentId("Sound.Flight.Land")
	if landId then
		local sound = Instance.new("Sound")
		sound.SoundId = landId
		sound.Volume = 0.6 + strength * 0.8
		sound.PlaybackSpeed = 0.55 - strength * 0.15
		sound.RollOffMaxDistance = 250
		sound.Parent = dustAnchor
		sound:Play()
	end

	-- Fade and clean up the crater
	task.delay(lifetime, function()
		for _, part in parts do
			if part.Parent then
				TweenService:Create(part, TweenInfo.new(2), { Transparency = 1 }):Play()
				Debris:AddItem(part, 2.1)
			end
		end
	end)
end

-- Register a handler for an effect name.
function EffectsController.register(name: string, handler: Handler)
	handlers[name] = handler
end

EffectsController.folder = getFolder
EffectsController.part = effectPart
EffectsController.colorFrom = colorFrom
EffectsController.glowFor = glowFor

function EffectsController.play(name: string, payload: { [string]: any })
	local handler = handlers[name]
	if handler then
		handler(payload)
	end
end

-- SoundLibrary injects itself here (avoids a require cycle).
function EffectsController.setSoundPlayer(player: (string, { [string]: any }) -> ())
	playSound = player
end

function EffectsController.init()
	Remotes.event("Effect").OnClientEvent:Connect(function(name: any, payload: any)
		if type(name) == "string" and type(payload) == "table" then
			EffectsController.play(name, payload)
		end
	end)
end

return EffectsController
