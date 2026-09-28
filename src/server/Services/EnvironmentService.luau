--!strict
-- Server side of the atmosphere: lighting post-processing setup, the
-- 20-minute day/night clock (ClockTime + ambient colours) and the weather
-- state (workspace attribute ApexRain = 0..1). Lights, rain visuals, wet
-- roads, forest mist and ambience are handled per client.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local GameConfig = require(ReplicatedStorage:WaitForChild("ApexCity").Config.GameConfig)

local EnvironmentService = {}

local function ensure(className: string, name: string, configure: (Instance) -> ()): Instance
	local existing = Lighting:FindFirstChildOfClass(className :: any)
	if existing then
		return existing
	end
	local instance = Instance.new(className :: any)
	instance.Name = name
	configure(instance)
	instance.Parent = Lighting
	return instance
end

local function setupLighting()
	if Lighting.Technology ~= Enum.Technology.Future then
		warn("[Environment] Set Lighting.Technology to Future in Studio (it can't be changed by scripts).")
	end
	Lighting.GlobalShadows = true
	Lighting.EnvironmentDiffuseScale = 1
	Lighting.EnvironmentSpecularScale = 1
	ensure("Atmosphere", "ApexAtmosphere", function(instance)
		local atmosphere = instance :: Atmosphere
		atmosphere.Density = GameConfig.Environment.CityAtmosphereDensity
		atmosphere.Offset = 0.2
		atmosphere.Color = Color3.fromRGB(199, 199, 205)
		atmosphere.Decay = Color3.fromRGB(106, 112, 125)
		atmosphere.Glare = 0.4
		atmosphere.Haze = 1.6
	end)
	ensure("BloomEffect", "ApexBloom", function(instance)
		local bloom = instance :: BloomEffect
		bloom.Intensity = 0.7
		bloom.Size = 26
		bloom.Threshold = 1.35
	end)
	ensure("ColorCorrectionEffect", "ApexGrade", function(instance)
		local grade = instance :: ColorCorrectionEffect
		grade.Contrast = 0.08
		grade.Saturation = 0.06
		grade.TintColor = Color3.fromRGB(255, 250, 244)
	end)
	ensure("SunRaysEffect", "ApexSunRays", function(instance)
		local rays = instance :: SunRaysEffect
		rays.Intensity = 0.06
		rays.Spread = 0.75
	end)
	ensure("DepthOfFieldEffect", "ApexDepthOfField", function(instance)
		local dof = instance :: DepthOfFieldEffect
		dof.FarIntensity = 0.12
		dof.FocusDistance = 80
		dof.InFocusRadius = 70
		dof.NearIntensity = 0
	end)
end

-- Ambient colours by time of day (keyframes over ClockTime).
type AmbientKey = { t: number, ambient: Color3, outdoor: Color3 }
local AMBIENT_KEYS: { AmbientKey } = {
	{ t = 0, ambient = Color3.fromRGB(30, 34, 52), outdoor = Color3.fromRGB(40, 46, 70) },
	{ t = 5.5, ambient = Color3.fromRGB(46, 44, 60), outdoor = Color3.fromRGB(70, 64, 80) },
	{ t = 7, ambient = Color3.fromRGB(110, 96, 90), outdoor = Color3.fromRGB(150, 130, 120) },
	{ t = 12, ambient = Color3.fromRGB(128, 128, 132), outdoor = Color3.fromRGB(150, 150, 156) },
	{ t = 17.5, ambient = Color3.fromRGB(120, 100, 90), outdoor = Color3.fromRGB(160, 120, 100) },
	{ t = 19, ambient = Color3.fromRGB(50, 48, 66), outdoor = Color3.fromRGB(70, 66, 90) },
	{ t = 24, ambient = Color3.fromRGB(30, 34, 52), outdoor = Color3.fromRGB(40, 46, 70) },
}

local function ambientAt(clock: number): (Color3, Color3)
	for i = 1, #AMBIENT_KEYS - 1 do
		local a, b = AMBIENT_KEYS[i], AMBIENT_KEYS[i + 1]
		if clock >= a.t and clock <= b.t then
			local t = (clock - a.t) / (b.t - a.t)
			return a.ambient:Lerp(b.ambient, t), a.outdoor:Lerp(b.outdoor, t)
		end
	end
	return AMBIENT_KEYS[1].ambient, AMBIENT_KEYS[1].outdoor
end

local function dayNight()
	local env = GameConfig.Environment
	local hoursPerSecond = 24 / env.DayLengthSeconds
	Lighting.ClockTime = env.StartClockTime
	task.spawn(function()
		local last = os.clock()
		while true do
			task.wait(0.25)
			local now = os.clock()
			local clock = (Lighting.ClockTime + (now - last) * hoursPerSecond) % 24
			last = now
			Lighting.ClockTime = clock
			local ambient, outdoor = ambientAt(clock)
			Lighting.Ambient = ambient
			Lighting.OutdoorAmbient = outdoor
			local night = clock < env.DawnClockTime or clock > env.DuskClockTime
			Lighting.Brightness = if night then 1.2 else 2.6
			if workspace:GetAttribute("ApexNight") ~= night then
				workspace:SetAttribute("ApexNight", night)
			end
		end
	end)
end

local function weather()
	local env = GameConfig.Environment
	workspace:SetAttribute("ApexRain", 0)
	local holder = Instance.new("NumberValue")
	holder.Value = 0
	holder.Changed:Connect(function(value)
		workspace:SetAttribute("ApexRain", math.floor(value * 100) / 100)
	end)
	task.spawn(function()
		while true do
			task.wait(math.random(env.RainCheckInterval[1], env.RainCheckInterval[2]))
			if math.random() < env.RainChance then
				local intensity = 0.5 + math.random() * 0.5
				TweenService:Create(holder, TweenInfo.new(25), { Value = intensity }):Play()
				task.wait(math.random(env.RainDuration[1], env.RainDuration[2]))
				TweenService:Create(holder, TweenInfo.new(30), { Value = 0 }):Play()
				task.wait(30)
			end
		end
	end)
end

function EnvironmentService.init()
	setupLighting()
	dayNight()
	weather()
end

return EnvironmentService
