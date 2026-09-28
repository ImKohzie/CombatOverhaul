--!strict
-- Client atmosphere:
--   * city lights: street lamps, neon signs, billboards and lit windows
--     switch on at dusk / off at dawn (tags from the map generator; works
--     with streaming because newly streamed parts adopt the current state)
--   * rain around the camera with wet, reflective roads and sidewalks
--     (and frozen raindrops while a Velocity Rift is active)
--   * thicker mist in the forest than over the city

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("ApexCity")
local GameConfig = require(Shared.Config.GameConfig)
local MapConfig = require(Shared.Config.MapConfig)

local player = Players.LocalPlayer

local WINDOW_COLORS = {
	Color3.fromRGB(255, 214, 150), Color3.fromRGB(255, 236, 190), Color3.fromRGB(220, 235, 255), Color3.fromRGB(255, 200, 130),
}

local EnvironmentController = {}

local night = false
local wetness = 0
local originals: { [Instance]: { [string]: any } } = {}

--------------------------------------------------------------------------------
-- Lights
--------------------------------------------------------------------------------
local function remember(instance: Instance, props: { [string]: any })
	if not originals[instance] then
		local saved = {}
		for key in props do
			saved[key] = (instance :: any)[key]
		end
		originals[instance] = saved
		instance.Destroying:Connect(function()
			originals[instance] = nil
		end)
	end
end

local function applyLight(instance: Instance)
	if instance:IsA("Light") then
		if CollectionService:HasTag(instance, "ApexInteriorLight") then
			instance.Brightness = if night then 1.6 else 1
		else
			instance.Brightness = if night then (if instance:IsA("SpotLight") then 2.2 else 1.2) else 0
		end
	end
end

local function applyWindow(part: Instance)
	if not part:IsA("BasePart") then
		return
	end
	remember(part, { Material = true, Color = true })
	local saved = originals[part]
	if night then
		part.Material = Enum.Material.Neon
		local seed = (math.floor(part.Position.X * 7 + part.Position.Y * 13 + part.Position.Z * 3)) % #WINDOW_COLORS + 1
		part.Color = WINDOW_COLORS[seed]:Lerp(Color3.new(0, 0, 0), 0.35)
	elseif saved then
		part.Material = saved.Material
		part.Color = saved.Color
	end
end

local function applyLampHead(part: Instance)
	if part:IsA("BasePart") then
		part.Material = if night then Enum.Material.Neon else Enum.Material.Glass
	end
end

local function applyAll()
	task.spawn(function()
		local count = 0
		local function step()
			count += 1
			if count % 400 == 0 then
				task.wait()
			end
		end
		for _, tag in { "ApexStreetLight", "ApexNeonLight", "ApexInteriorLight" } do
			for _, light in CollectionService:GetTagged(tag) do
				applyLight(light)
				step()
			end
		end
		for _, head in CollectionService:GetTagged("ApexLampHead") do
			applyLampHead(head)
			step()
		end
		for _, window in CollectionService:GetTagged("ApexWindowLight") do
			applyWindow(window)
			step()
		end
	end)
end

--------------------------------------------------------------------------------
-- Rain + wet surfaces
--------------------------------------------------------------------------------
local rainPart: Part
local rainEmitter: ParticleEmitter
local splashEmitter: ParticleEmitter
local rainSound: Sound? = nil

local function buildRain()
	rainPart = Instance.new("Part")
	rainPart.Name = "ApexRain"
	rainPart.Anchored = true
	rainPart.CanCollide = false
	rainPart.CanQuery = false
	rainPart.CanTouch = false
	rainPart.Transparency = 1
	rainPart.Size = Vector3.new(160, 1, 160)
	rainPart.Parent = workspace.CurrentCamera
	rainEmitter = Instance.new("ParticleEmitter")
	rainEmitter.Color = ColorSequence.new(Color3.fromRGB(190, 200, 215))
	rainEmitter.Transparency = NumberSequence.new(0.55)
	rainEmitter.Size = NumberSequence.new(0.08)
	rainEmitter.Lifetime = NumberRange.new(0.9, 1.1)
	rainEmitter.Speed = NumberRange.new(90, 110)
	rainEmitter.EmissionDirection = Enum.NormalId.Bottom
	rainEmitter.Orientation = Enum.ParticleOrientation.FacingCameraWorldUp
	rainEmitter.Squash = NumberSequence.new(-4) -- stretched streaks
	rainEmitter.Rate = 0
	rainEmitter.Parent = rainPart
	splashEmitter = Instance.new("ParticleEmitter")
	splashEmitter.Color = ColorSequence.new(Color3.fromRGB(210, 220, 230))
	splashEmitter.Transparency = NumberSequence.new(0.6, 1)
	splashEmitter.Size = NumberSequence.new(0.2, 0.6)
	splashEmitter.Lifetime = NumberRange.new(0.15, 0.25)
	splashEmitter.Speed = NumberRange.new(2, 4)
	splashEmitter.SpreadAngle = Vector2.new(60, 60)
	splashEmitter.Rate = 0
	splashEmitter.Parent = rainPart
end

local function setWet(instance: Instance, amount: number)
	if not instance:IsA("BasePart") then
		return
	end
	remember(instance, { Reflectance = true, Color = true })
	local saved = originals[instance]
	if not saved then
		return
	end
	instance.Reflectance = (saved.Reflectance :: number) + 0.18 * amount
	instance.Color = (saved.Color :: Color3):Lerp(Color3.new(0.1, 0.1, 0.12), 0.3 * amount)
end

local function applyWetness(amount: number)
	task.spawn(function()
		local count = 0
		for _, tag in { "ApexRoad", "ApexSidewalk" } do
			for _, part in CollectionService:GetTagged(tag) do
				setWet(part, amount)
				count += 1
				if count % 300 == 0 then
					task.wait()
				end
			end
		end
	end)
end

--------------------------------------------------------------------------------
-- Loop
--------------------------------------------------------------------------------
local function inForest(position: Vector3): boolean
	local half = MapConfig.City.HalfSize
	return math.abs(position.X) > half + 40 or math.abs(position.Z) > half + 40
end

local lastWetStep = -1
local function step(dt: number)
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	-- Rain follows the camera
	local rain = workspace:GetAttribute("ApexRain")
	local intensity = if type(rain) == "number" then rain else 0
	local frozen = player:GetAttribute("ApexWorldFrozen") == true
	if rainPart then
		if rainPart.Parent ~= camera then
			rainPart.Parent = camera
		end
		local position = camera.CFrame.Position
		rainPart.CFrame = CFrame.new(position.X, position.Y + 60, position.Z)
		rainEmitter.Rate = intensity * 2200
		rainEmitter.TimeScale = if frozen then 0 else 1
		splashEmitter.Rate = 0
	end
	if rainSound then
		rainSound.Volume = intensity * 0.6
	end
	-- Wet surfaces follow the rain (updated in steps to limit churn)
	local target = if intensity > 0.2 then 1 else 0
	wetness += (target - wetness) * math.min(1, dt * 0.08)
	local stepped = math.floor(wetness * 4 + 0.5)
	if stepped ~= lastWetStep then
		lastWetStep = stepped
		applyWetness(stepped / 4)
	end
	-- Forest mist
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if atmosphere and root and root:IsA("BasePart") then
		local env = GameConfig.Environment
		local wanted = if inForest(root.Position) then env.ForestAtmosphereDensity else env.CityAtmosphereDensity
		wanted += intensity * 0.12
		atmosphere.Density += (wanted - atmosphere.Density) * math.min(1, dt * 0.5)
	end
end

function EnvironmentController.init()
	night = workspace:GetAttribute("ApexNight") == true
	workspace:GetAttributeChangedSignal("ApexNight"):Connect(function()
		night = workspace:GetAttribute("ApexNight") == true
		applyAll()
	end)
	-- Streamed-in instances adopt the current state
	for _, tag in { "ApexStreetLight", "ApexNeonLight", "ApexInteriorLight" } do
		CollectionService:GetInstanceAddedSignal(tag):Connect(applyLight)
	end
	CollectionService:GetInstanceAddedSignal("ApexLampHead"):Connect(applyLampHead)
	CollectionService:GetInstanceAddedSignal("ApexWindowLight"):Connect(applyWindow)
	for _, tag in { "ApexRoad", "ApexSidewalk" } do
		CollectionService:GetInstanceAddedSignal(tag):Connect(function(part)
			if wetness > 0.05 then
				setWet(part, lastWetStep / 4)
			end
		end)
	end
	applyAll()
	buildRain()
	RunService.Heartbeat:Connect(step)
end

-- The ambience controller hands over its rain loop so volume tracks the rain.
function EnvironmentController.setRainSound(sound: Sound?)
	rainSound = sound
end

return EnvironmentController
