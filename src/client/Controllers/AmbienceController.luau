--!strict
-- Ambient audio. Two zone beds (city / forest) crossfade by position, with
-- day/night variants in the forest, plus 3D positional emitters: subway
-- rumble at the station, crowds at the park and diner, river flow along the
-- river and lake, and random one-shots (horns, sirens, pigeons). Sounds
-- whose AssetRegistry entry has no ID stay silent (listed as placeholders).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local Shared = ReplicatedStorage:WaitForChild("ApexCity")
local MapConfig = require(Shared.Config.MapConfig)

local EnvironmentController = require(script.Parent.EnvironmentController)
local SoundLibrary = require(script.Parent.SoundLibrary)

local player = Players.LocalPlayer

local AmbienceController = {}

type Bed = { sound: Sound?, base: number }
local beds: { [string]: Bed } = {}
local cityWeight = 1

local function bed(key: string, volume: number, pitch: number): Bed
	local sound = SoundLibrary.play(key, { Looped = true, Volume = 0, Pitch = pitch, Parent = SoundService :: Instance })
	return { sound = sound, base = volume }
end

local function emitter(key: string, position: Vector3, volume: number, pitch: number, maxDistance: number)
	local attachment = Instance.new("Attachment")
	attachment.Name = "ApexAmbience"
	attachment.WorldPosition = position
	attachment.Parent = workspace.Terrain
	local sound = SoundLibrary.play(key, { Looped = true, Volume = volume, Pitch = pitch, Parent = attachment :: Instance, MaxDistance = maxDistance })
	if not sound then
		attachment:Destroy()
	end
end

local function placeEmitters()
	-- River + lake
	local river = MapConfig.Forest.River
	for i = 1, #river - 1 do
		emitter("Ambience.River", river[i]:Lerp(river[i + 1], 0.5) + Vector3.new(0, 2, 0), 0.8, 0.5, 180)
	end
	local lake = MapConfig.Forest.Lake
	emitter("Ambience.River", Vector3.new(lake.X, 1, lake.Z), 0.5, 0.4, 260)
	-- Tagged places (streamed in)
	local function attachTo(tag: string, key: string, volume: number, pitch: number, distance: number)
		local function add(instance: Instance)
			local position: Vector3? = nil
			if instance:IsA("BasePart") then
				position = instance.Position
			elseif instance:IsA("Model") then
				position = instance:GetPivot().Position
			end
			if position then
				emitter(key, position, volume, pitch, distance)
			end
		end
		for _, instance in CollectionService:GetTagged(tag) do
			add(instance)
		end
		CollectionService:GetInstanceAddedSignal(tag):Connect(add)
	end
	attachTo("ApexSubway", "Ambience.Subway.Rumble", 1, 0.25, 120)
	attachTo("ApexDiner", "Ambience.City.Crowd", 0.6, 1, 90)
	attachTo("ApexPark", "Ambience.City.Crowd", 0.4, 1, 260)
	attachTo("ApexPark", "Ambience.City.Pigeons", 0.5, 1, 200)
end

local ONE_SHOTS = { "Ambience.City.Horns", "Ambience.City.Sirens" }

local function oneShots()
	task.spawn(function()
		while true do
			task.wait(8 + math.random() * 14)
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if root and root:IsA("BasePart") and cityWeight > 0.5 then
				local key = ONE_SHOTS[math.random(1, #ONE_SHOTS)]
				local angle = math.random() * math.pi * 2
				local position = root.Position + Vector3.new(math.cos(angle) * 150, 10, math.sin(angle) * 150)
				SoundLibrary.play(key, { Position = position, Volume = 0.5, MaxDistance = 400 })
			end
		end
	end)
end

local function step(dt: number)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return
	end
	local half = MapConfig.City.HalfSize
	local edge = math.max(math.abs(root.Position.X), math.abs(root.Position.Z))
	local targetCity = math.clamp(1 - (edge - half) / 300, 0, 1)
	cityWeight += (targetCity - cityWeight) * math.min(1, dt * 0.8)
	local night = workspace:GetAttribute("ApexNight") == true
	local function set(name: string, weight: number)
		local b = beds[name]
		if b and b.sound then
			b.sound.Volume = b.base * weight
		end
	end
	set("traffic", cityWeight)
	set("forestWind", 1 - cityWeight)
	set("birds", (1 - cityWeight) * (if night then 0 else 1))
	set("night", (1 - cityWeight) * (if night then 1 else 0))
end

function AmbienceController.init()
	-- Wait until the character exists so built-in fallback sounds resolve
	local character = player.Character or player.CharacterAdded:Wait()
	character:WaitForChild("HumanoidRootPart", 10)
	task.wait(1)
	beds.traffic = bed("Ambience.City.Traffic", 0.25, 0.3)
	beds.forestWind = bed("Ambience.Forest.Wind", 0.35, 0.6)
	beds.birds = bed("Ambience.Forest.Birds", 0.5, 1)
	beds.night = bed("Ambience.Forest.Night", 0.5, 1)
	local rain = SoundLibrary.play("Ambience.Rain", { Looped = true, Volume = 0, Pitch = 1.6, Parent = SoundService :: Instance })
	EnvironmentController.setRainSound(rain)
	placeEmitters()
	oneShots()
	RunService.Heartbeat:Connect(step)
end

return AmbienceController
