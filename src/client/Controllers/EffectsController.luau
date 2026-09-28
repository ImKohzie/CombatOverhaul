--!strict
-- Plays cosmetic effects the server broadcasts through the Effect remote.
-- Effects never change gameplay state. Phase 3 adds pooling and the full
-- VFX library; Phase 1 only has the pipeline test pulse.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("ApexCity")
local Remotes = require(Shared.Net.Remotes)
local CharacterRegistry = require(Shared.CharacterRegistry)

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

function EffectsController.play(name: string, payload: { [string]: any })
	local handler = handlers[name]
	if handler then
		handler(payload)
	end
end

function EffectsController.init()
	Remotes.event("Effect").OnClientEvent:Connect(function(name: any, payload: any)
		if type(name) == "string" and type(payload) == "table" then
			EffectsController.play(name, payload)
		end
	end)
end

return EffectsController
