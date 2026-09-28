--!strict
-- Procedural animation layer for EVERY character on this client
-- (Motor6D.Transform doesn't replicate, so each client poses everyone from
-- replicated state). Layers, bottom to top:
--   flight / hero landing  ->  block guard  ->  stun sway  ->  action
-- Actions are keyframed sequences from PoseLibrary.Actions (swings, casts).
-- freeze() implements hit-stop: actions and animation tracks pause briefly.
-- When real animation assets are registered, controllers can play those
-- instead; the timings in BalanceConfig should then match their markers.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("ApexCity")
local BalanceConfig = require(Shared.Config.BalanceConfig)
local CharacterRegistry = require(Shared.CharacterRegistry)
local PoseLibrary = require(Shared.Movement.PoseLibrary)

type Pose = PoseLibrary.Pose
type Action = PoseLibrary.Action

local LANDING_TIME = 0.85
local FADE_IN = 0.06
local FADE_OUT = 0.14

local PoseController = {}

type ActionState = {
	action: Action,
	time: number,
	speed: number,
	loop: boolean,
	duration: number,
}

type Entry = {
	motors: { [string]: Motor6D },
	flightBlend: number,
	blockBlend: number,
	stunBlend: number,
	landingStart: number?,
	action: ActionState?,
	frozenUntil: number,
	yawSpin: number?, -- radians/second body spin (Spin action)
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
		entry = {
			motors = motors,
			flightBlend = 0,
			blockBlend = 0,
			stunBlend = 0,
			frozenUntil = 0,
		}
		entries[character] = entry
		character.Destroying:Connect(function()
			entries[character] = nil
		end)
		character.AncestryChanged:Connect(function(_, parent)
			if parent == nil then
				entries[character] = nil
			end
		end)
	end
	return entry
end

--------------------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------------------
export type PlayOptions = {
	Loop: boolean?,
	Speed: number?,
	Duration: number?, -- override the action's natural duration
}

function PoseController.play(character: Model, actionName: string, options: PlayOptions?)
	local action = PoseLibrary.Actions[actionName]
	if not action then
		return
	end
	local entry = getEntry(character)
	entry.action = {
		action = action,
		time = 0,
		speed = if options and options.Speed then options.Speed else 1,
		loop = if options and options.Loop then true else false,
		duration = if options and options.Duration then options.Duration else action.Duration,
	}
end

function PoseController.stop(character: Model)
	local entry = entries[character]
	if entry then
		entry.action = nil
	end
end

function PoseController.isPlaying(character: Model, actionName: string): boolean
	local entry = entries[character]
	local state = entry and entry.action
	return state ~= nil and state.action == PoseLibrary.Actions[actionName]
end

-- Superhero landing on a character (local or remote).
function PoseController.playLanding(character: Model)
	getEntry(character).landingStart = os.clock()
end

-- Hit-stop: pause the character's action and animation tracks.
function PoseController.freeze(character: Model, duration: number)
	local entry = getEntry(character)
	local untilTime = os.clock() + duration
	if untilTime <= entry.frozenUntil then
		return
	end
	entry.frozenUntil = untilTime
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if animator then
		local paused: { [AnimationTrack]: number } = {}
		for _, track in animator:GetPlayingAnimationTracks() do
			paused[track] = track.Speed
			track:AdjustSpeed(0)
		end
		task.delay(duration, function()
			for track, speed in paused do
				if track.IsPlaying then
					track:AdjustSpeed(speed)
				end
			end
		end)
	end
end

--------------------------------------------------------------------------------
-- Per-frame
--------------------------------------------------------------------------------
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

local function approach(current: number, target: number, rate: number, dt: number): number
	return current + (target - current) * math.min(1, dt * rate)
end

local function updateCharacter(character: Model, entry: Entry, dt: number, now: number)
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return
	end
	if character:GetAttribute("ApexRagdoll") == true then
		return -- physics owns the limbs
	end

	local flying = character:GetAttribute("ApexFlying") == true
	local blocking = character:GetAttribute("ApexBlocking") == true
	local stunned = character:GetAttribute("ApexStunned") == true and character:GetAttribute("ApexFrozen") ~= true
	entry.flightBlend = approach(entry.flightBlend, if flying then 1 else 0, 10, dt)
	entry.blockBlend = approach(entry.blockBlend, if blocking then 1 else 0, 18, dt)
	entry.stunBlend = approach(entry.stunBlend, if stunned then 1 else 0, 8, dt)

	local pose: Pose = {}
	local any = false

	if entry.flightBlend > 0.01 then
		pose = PoseLibrary.weight(flightPose(character, root), entry.flightBlend)
		any = true
	elseif entry.landingStart then
		local t = (now - entry.landingStart) / LANDING_TIME
		if t >= 1 then
			entry.landingStart = nil
		else
			local weight = if t < 0.6 then 1 else 1 - (t - 0.6) / 0.4
			pose = PoseLibrary.weight(PoseLibrary.HeroLanding, weight)
			any = true
		end
	end

	if entry.blockBlend > 0.01 then
		pose = PoseLibrary.overlay(pose, PoseLibrary.Block, entry.blockBlend)
		any = true
	end

	if entry.stunBlend > 0.01 then
		local sway = PoseLibrary.sample(PoseLibrary.Actions.Stunned, (now * 0.9) % 1)
		pose = PoseLibrary.overlay(pose, sway, entry.stunBlend)
		any = true
	end

	local state = entry.action
	if state then
		if now >= entry.frozenUntil then
			state.time += dt * state.speed
		end
		local duration = math.max(state.duration, 1e-3)
		local t = state.time / duration
		if not state.loop and t >= 1 then
			entry.action = nil
		else
			local normalized = if state.loop then t % 1 else t
			local weight = 1
			if not state.loop then
				local elapsed = state.time
				local remaining = duration - elapsed
				weight = math.min(1, elapsed / FADE_IN, remaining / FADE_OUT)
				weight = math.clamp(weight, 0, 1)
			else
				weight = math.min(1, state.time / FADE_IN)
			end
			pose = PoseLibrary.overlay(pose, PoseLibrary.sample(state.action, normalized), weight)
			any = true
		end
	end

	if any then
		for name, cf in pose do
			local motor = entry.motors[name]
			if motor then
				motor.Transform = cf
			end
		end
	end
end

local function step(dt: number)
	local now = os.clock()
	local visited: { [Model]: boolean } = {}
	for _, player in Players:GetPlayers() do
		local character = player.Character
		if character then
			visited[character] = true
			local interesting = entries[character] ~= nil
				or character:GetAttribute("ApexFlying") == true
				or character:GetAttribute("ApexBlocking") == true
				or character:GetAttribute("ApexStunned") == true
			if interesting then
				updateCharacter(character, getEntry(character), dt, now)
			end
		end
	end
	-- NPCs (training dummies, clones) that have entries
	for character, entry in entries do
		if not visited[character] and character.Parent then
			updateCharacter(character, entry, dt, now)
		end
	end
end

function PoseController.init()
	RunService.PreSimulation:Connect(step)
end

return PoseController
