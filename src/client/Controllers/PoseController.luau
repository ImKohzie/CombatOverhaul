--!strict
-- Applies procedural flight / landing poses to EVERY character on this
-- client (Motor6D.Transform doesn't replicate, so each client poses all
-- flyers itself from replicated state: ApexFlying + velocity).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("ApexCity")
local BalanceConfig = require(Shared.Config.BalanceConfig)
local CharacterRegistry = require(Shared.CharacterRegistry)
local PoseLibrary = require(Shared.Movement.PoseLibrary)

type Pose = PoseLibrary.Pose

local LANDING_TIME = 0.85

local PoseController = {}

type Entry = {
	motors: { [string]: Motor6D },
	landingStart: number?,
	flightBlend: number,
}

local entries: { [Model]: Entry } = {}

local function getEntry(character: Model): Entry
	local entry = entries[character]
	if not entry then
		local motors: { [string]: Motor6D } = {}
		for _, descendant in character:GetDescendants() do
			if descendant:IsA("Motor6D") then
				motors[descendant.Name] = descendant
			end
		end
		entry = { motors = motors, flightBlend = 0 }
		entries[character] = entry
		character.Destroying:Connect(function()
			entries[character] = nil
		end)
	end
	return entry
end

-- Play the superhero landing on a character (local or remote).
function PoseController.playLanding(character: Model)
	getEntry(character).landingStart = os.clock()
end

local function flightPose(character: Model, root: BasePart): Pose
	local id = character:GetAttribute("ApexCharacter")
	local config = if type(id) == "string" then CharacterRegistry.get(id) else nil
	local movement = if config then config.Movement else "Flight"
	if movement == "Board" or movement == "Glider" then
		return PoseLibrary.Surf
	end
	local profileName = if config and config.FlightProfile then config.FlightProfile else "Standard"
	local profile = BalanceConfig.Flight.Profiles[profileName] or BalanceConfig.Flight.Profiles.Standard
	local speed = root.AssemblyLinearVelocity.Magnitude
	local alpha = math.clamp((speed - profile.Hover) / (profile.Cruise - profile.Hover), 0, 1)
	return PoseLibrary.blend(PoseLibrary.Hover, PoseLibrary.Superhero, alpha)
end

local function apply(entry: Entry, pose: Pose)
	for name, cf in pose do
		local motor = entry.motors[name]
		if motor then
			motor.Transform = cf
		end
	end
end

local function step(dt: number)
	local now = os.clock()
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not character or not root or not root:IsA("BasePart") then
			continue
		end
		local flying = character:GetAttribute("ApexFlying") == true
		local entry = entries[character]
		if not flying and not entry then
			continue
		end
		entry = getEntry(character)
		entry.flightBlend += ((if flying then 1 else 0) - entry.flightBlend) * math.min(1, dt * 10)

		local landingWeight = 0
		if entry.landingStart then
			local t = (now - entry.landingStart) / LANDING_TIME
			if t >= 1 then
				entry.landingStart = nil
			else
				-- snap in fast, ease out over the last 40%
				landingWeight = if t < 0.6 then 1 else 1 - (t - 0.6) / 0.4
			end
		end

		if entry.flightBlend > 0.01 then
			apply(entry, PoseLibrary.weight(flightPose(character, root), entry.flightBlend))
		elseif landingWeight > 0 then
			apply(entry, PoseLibrary.weight(PoseLibrary.HeroLanding, landingWeight))
		end
	end
end

function PoseController.init()
	RunService.PreSimulation:Connect(step)
end

return PoseController
