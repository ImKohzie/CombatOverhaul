--!strict
-- Continuous beams (heat vision, cosmic lance, Judgement sweep).
-- The client renders the beam every frame from its own crosshair; the
-- server re-casts at BalanceConfig.Beam.TickRate (10Hz) for damage using
-- the last validated aim (turn-rate clamped), and relays the end point to
-- other players. Channel time is limited by a heat meter (ApexHeat).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("ApexCity")
local BalanceConfig = require(Shared.Config.BalanceConfig)

local AbilityKit = require(script.Parent.Parent.AbilityKit)
local DamageService = require(script.Parent.DamageService)
local NetService = require(script.Parent.NetService)
local Hooks = require(script.Parent.Parent.Hooks)

local EFFECT_RADIUS = 900

export type SourceKind = "Eyes" | "Hands" | "Chest"

export type BeamOptions = {
	Id: string,
	Dps: number,
	Range: number,
	Width: number,
	Radius: number?, -- hit thickness (spherecast radius)
	Color: Color3,
	Source: SourceKind,
	Twin: boolean?,
	StructureDps: number?,
	HeatPerSecond: number?,
	MaxDamagePerTarget: number?,
	Sweep: boolean?, -- direction driven by the caller, ignores client aim
	Pierce: number?, -- keep going through up to N structure parts per tick
	Tag: string,
}

export type Beam = {
	player: Player,
	character: Model,
	options: BeamOptions,
	direction: Vector3,
	lastTick: number,
	lastAimAt: number,
	damageDone: { [Model]: number },
	active: boolean,
	endPoint: Vector3,
}

local BeamService = {}

local beams: { [Player]: { [string]: Beam } } = {}
local heat: { [Player]: number } = {}
local overheatUntil: { [Player]: number } = {}

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------
function BeamService.origin(character: Model, source: SourceKind): Vector3
	local head = character:FindFirstChild("Head")
	local root = AbilityKit.rootOf(character)
	if source == "Eyes" and head and head:IsA("BasePart") then
		return (head.CFrame * CFrame.new(0, 0.2, -0.6)).Position
	elseif source == "Hands" then
		local right = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
		local left = character:FindFirstChild("LeftHand") or character:FindFirstChild("Left Arm")
		if right and left and right:IsA("BasePart") and left:IsA("BasePart") then
			return (right.Position + left.Position) / 2
		end
	end
	if root then
		return (root.CFrame * CFrame.new(0, 1, -1.5)).Position
	end
	return Vector3.zero
end

function BeamService.canFire(player: Player): boolean
	return os.clock() >= (overheatUntil[player] or 0)
end

function BeamService.getHeat(player: Player): number
	return heat[player] or 0
end

local function setHeat(player: Player, value: number)
	heat[player] = math.clamp(value, 0, BalanceConfig.Beam.HeatMax)
	local rounded = math.floor(heat[player])
	if player:GetAttribute("ApexHeat") ~= rounded then
		player:SetAttribute("ApexHeat", rounded)
	end
end

--------------------------------------------------------------------------------
-- Lifecycle
--------------------------------------------------------------------------------
function BeamService.start(player: Player, character: Model, options: BeamOptions, initialPoint: Vector3): Beam?
	if not BeamService.canFire(player) then
		NetService.fireClient("Notify", player, "Overheated!")
		return nil
	end
	local list = beams[player]
	if not list then
		list = {}
		beams[player] = list
	end
	if list[options.Id] then
		BeamService.stop(player, options.Id)
	end
	local origin = BeamService.origin(character, options.Source)
	local dir = initialPoint - origin
	local beam: Beam = {
		player = player,
		character = character,
		options = options,
		direction = if dir.Magnitude > 1e-3 then dir.Unit else character:GetPivot().LookVector,
		lastTick = 0,
		lastAimAt = os.clock(),
		damageDone = {},
		active = true,
		endPoint = initialPoint,
	}
	list[options.Id] = beam
	NetService.fireNear("Effect", origin, EFFECT_RADIUS, "BeamStart", {
		Id = options.Id,
		Source = character,
		Color = options.Color,
		Width = options.Width,
		SourceKind = options.Source,
		Twin = options.Twin == true,
		Range = options.Range,
		Sweep = options.Sweep == true,
		End = initialPoint,
	})
	return beam
end

function BeamService.stop(player: Player, id: string)
	local list = beams[player]
	local beam = list and list[id]
	if not beam or not list then
		return
	end
	beam.active = false
	list[id] = nil
	NetService.fireAll("Effect", "BeamStop", { Id = id, Source = beam.character })
end

function BeamService.stopAll(player: Player)
	local list = beams[player]
	if list then
		for id in table.clone(list) do
			BeamService.stop(player, id)
		end
	end
end

-- Sweep beams: the ability drives the direction itself.
function BeamService.setDirection(beam: Beam, direction: Vector3)
	if direction.Magnitude > 1e-3 then
		beam.direction = direction.Unit
	end
end

-- Client aim updates for its active beams (turn-rate clamped).
function BeamService.updateAim(player: Player, point: Vector3)
	local list = beams[player]
	if not list then
		return
	end
	local now = os.clock()
	for _, beam in list do
		if beam.options.Sweep then
			continue
		end
		local origin = BeamService.origin(beam.character, beam.options.Source)
		local wanted = point - origin
		if wanted.Magnitude < 1 then
			continue
		end
		wanted = wanted.Unit
		local dt = math.max(now - beam.lastAimAt, 1 / 60)
		beam.lastAimAt = now
		local maxTurn = math.rad(BalanceConfig.Beam.MaxAimTurnDegreesPerSecond) * dt
		local angle = math.acos(math.clamp(beam.direction:Dot(wanted), -1, 1))
		if angle > maxTurn and angle > 1e-3 then
			beam.direction = beam.direction:Lerp(wanted, maxTurn / angle).Unit
		else
			beam.direction = wanted
		end
	end
end

--------------------------------------------------------------------------------
-- Damage tick
--------------------------------------------------------------------------------
local function tick(beam: Beam)
	local options = beam.options
	local character = beam.character
	if not AbilityKit.isAlive(character) or character:GetAttribute("ApexStunned") == true then
		BeamService.stop(beam.player, options.Id)
		return
	end
	local origin = BeamService.origin(character, options.Source)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore: { Instance } = { character, AbilityKit.effectsFolder() }
	local clientFx = workspace:FindFirstChild("ApexClientEffects")
	if clientFx then
		table.insert(ignore, clientFx)
	end
	params.FilterDescendantsInstances = ignore
	local radius = options.Radius or math.max(0.5, options.Width * 0.4)
	local interval = 1 / BalanceConfig.Beam.TickRate
	local remaining = options.Range
	local castFrom = origin
	local pierces = options.Pierce or 0
	local hit: RaycastResult? = nil
	local hitCharacters: { [Model]: boolean } = {}
	while remaining > 0 do
		hit = workspace:Spherecast(castFrom, radius, beam.direction * remaining, params)
		if not hit then
			break
		end
		local victim = AbilityKit.characterFromPart(hit.Instance)
		if victim and victim ~= character then
			if not hitCharacters[victim] then
				hitCharacters[victim] = true
				local done = beam.damageDone[victim] or 0
				local cap = options.MaxDamagePerTarget or math.huge
				local amount = math.min(options.Dps * interval, cap - done)
				if amount > 0 then
					local dealt = DamageService.apply(victim, {
						Amount = amount,
						Attacker = beam.player,
						AttackerCharacter = character,
						Kind = "Beam",
						Position = hit.Position,
						HitStun = 0.15,
						Tag = options.Tag,
					})
					beam.damageDone[victim] = done + dealt
				end
			end
			if pierces <= 0 then
				break
			end
			table.insert(ignore, victim)
		elseif hit.Instance:IsA("BasePart") then
			local part = hit.Instance :: BasePart
			if options.StructureDps then
				Hooks.structureDamageAt(part, hit.Position, options.StructureDps * interval, 200, character)
			end
			if pierces <= 0 or not Hooks.isStructure(part) then
				break
			end
			table.insert(ignore, part)
		else
			break
		end
		pierces -= 1
		params.FilterDescendantsInstances = ignore
		local travelled = (hit.Position - castFrom).Magnitude
		remaining -= travelled
		castFrom = hit.Position
	end
	local endPoint = if hit then hit.Position else origin + beam.direction * options.Range
	beam.endPoint = endPoint

	NetService.fireNear("Effect", origin, EFFECT_RADIUS, "BeamUpdate", {
		Id = options.Id,
		Source = character,
		End = endPoint,
		Hit = hit ~= nil,
		Normal = if hit then hit.Normal else nil,
	})
end

function BeamService.init()
	RunService.Heartbeat:Connect(function(dt)
		local now = os.clock()
		local beamConfig = BalanceConfig.Beam
		for _, player in Players:GetPlayers() do
			local list = beams[player]
			local channelling = false
			if list then
				for _, beam in list do
					channelling = true
					local rate = beam.options.HeatPerSecond or beamConfig.HeatPerSecond
					setHeat(player, (heat[player] or 0) + rate * dt)
					if now - beam.lastTick >= 1 / beamConfig.TickRate then
						beam.lastTick = now
						tick(beam)
					end
				end
				if (heat[player] or 0) >= beamConfig.HeatMax then
					overheatUntil[player] = now + beamConfig.OverheatLockout
					NetService.fireClient("Notify", player, "Overheated!")
					BeamService.stopAll(player)
				end
			end
			if not channelling and (heat[player] or 0) > 0 then
				setHeat(player, (heat[player] or 0) - beamConfig.HeatCoolPerSecond * dt)
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		beams[player] = nil
		heat[player] = nil
		overheatUntil[player] = nil
	end)
	local function hook(player: Player)
		player.CharacterRemoving:Connect(function()
			BeamService.stopAll(player)
		end)
	end
	Players.PlayerAdded:Connect(hook)
	for _, player in Players:GetPlayers() do
		hook(player)
	end
end

return BeamService
