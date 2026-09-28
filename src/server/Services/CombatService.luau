--!strict
-- Server-authoritative melee:
--   M1 tap  -> 4-hit combo (0.35s input window, buffered during recovery)
--   M1 hold -> charged heavy (ragdoll launch)
--   airborne tap -> aerial combo hit, airborne hold -> dive slam
--   F on the ground -> block; perfect parry in the first 0.2s
-- Hitboxes are GetPartBoundsInBox queries fired at each attack's WindUp time
-- (the "Hit" marker of the swing). The client only sends intents.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("ApexCity")
local BalanceConfig = require(Shared.Config.BalanceConfig)
local Validate = require(Shared.Net.Validate)

local AbilityKit = require(script.Parent.Parent.AbilityKit)
local BeamService = require(script.Parent.BeamService)
local DamageService = require(script.Parent.DamageService)
local MovementService = require(script.Parent.MovementService)
local NetService = require(script.Parent.NetService)
local StatusService = require(script.Parent.StatusService)

type AttackTiming = BalanceConfig.AttackTiming

local EFFECT_RADIUS = 400

local CombatService = {}

type AttackerState = {
	comboStep: number,
	busyUntil: number, -- can't start another attack before this
	lastAttackEnd: number,
	pressStart: number?,
	buffered: string?, -- "Light" pressed during recovery
	diving: boolean,
}

local states: { [Player]: AttackerState } = {}

local function getState(player: Player): AttackerState
	local state = states[player]
	if not state then
		state = { comboStep = 0, busyUntil = 0, lastAttackEnd = 0, pressStart = nil, buffered = nil, diving = false }
		states[player] = state
	end
	return state
end

local function parts(player: Player): (Model?, Humanoid?, BasePart?)
	local character = player.Character
	if not character then
		return nil, nil, nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = AbilityKit.rootOf(character)
	return character, humanoid, root
end

local function canAct(character: Model, humanoid: Humanoid): boolean
	return humanoid.Health > 0
		and not StatusService.isStunned(character)
		and character:GetAttribute("ApexServerMotion") ~= true
end

local function airborne(character: Model, humanoid: Humanoid): boolean
	return humanoid.FloorMaterial == Enum.Material.Air or character:GetAttribute("ApexFlying") == true
end

--------------------------------------------------------------------------------
-- Hitbox + damage
--------------------------------------------------------------------------------
local function strike(player: Player, character: Model, timing: AttackTiming, damage: number, kind: "Melee" | "Heavy", tag: string, sizeScale: number?)
	local root = AbilityKit.rootOf(character)
	if not root or not AbilityKit.isAlive(character) or StatusService.isStunned(character) then
		return
	end
	local melee = BalanceConfig.Melee
	local scale = sizeScale or 1
	local colossal = character:GetAttribute("ApexColossal") == true
	if colossal then
		scale *= 3
	end
	local size = melee.HitboxSize * scale
	local cframe = root.CFrame * CFrame.new(0, 0, -size.Z / 2 + 0.5)
	local rage = character:GetAttribute("ApexDamageBonus")
	local bonus = 1 + (if type(rage) == "number" then rage else 0)
	for _, victim in AbilityKit.inBox(cframe, size, { character }) do
		local victimRoot = AbilityKit.rootOf(victim)
		if not victimRoot then
			continue
		end
		-- Sanity: never hit beyond the configured reach.
		if (victimRoot.Position - root.Position).Magnitude > melee.MaxServerReach * scale then
			continue
		end
		local forward = root.CFrame.LookVector
		local knockback = Vector3.new(forward.X, 0, forward.Z).Unit * timing.Knockback + Vector3.new(0, timing.Lift or 0, 0)
		DamageService.apply(victim, {
			Amount = damage * bonus,
			Attacker = player,
			AttackerCharacter = character,
			Kind = kind,
			Position = victimRoot.Position:Lerp(root.Position, 0.35) + Vector3.new(0, 0.5, 0),
			Knockback = knockback,
			Ragdoll = timing.Ragdoll,
			HitStun = timing.HitStun,
			CanParry = true,
			Tag = tag,
		})
	end
end

local function broadcastSwing(character: Model, action: string, speed: number?)
	local root = AbilityKit.rootOf(character)
	if root then
		NetService.fireNear("Effect", root.Position, EFFECT_RADIUS, "Swing", {
			Source = character,
			Action = action,
			Speed = speed,
		})
	end
end

local function schedule(player: Player, state: AttackerState, timing: AttackTiming, run: () -> ())
	local now = os.clock()
	state.busyUntil = now + timing.WindUp + timing.Active + timing.Recovery
	state.lastAttackEnd = state.busyUntil
	task.delay(timing.WindUp, run)
	-- Buffered input fires as soon as recovery ends.
	task.delay(timing.WindUp + timing.Active + timing.Recovery, function()
		local current = states[player]
		if current and current.buffered == "Light" then
			current.buffered = nil
			CombatService.light(player)
		end
	end)
end

--------------------------------------------------------------------------------
-- Attacks
--------------------------------------------------------------------------------
function CombatService.light(player: Player)
	local character, humanoid, root = parts(player)
	if not character or not humanoid or not root or not canAct(character, humanoid) then
		return
	end
	local state = getState(player)
	local now = os.clock()
	if now < state.busyUntil then
		-- Buffer one press made during recovery.
		if state.busyUntil - now <= BalanceConfig.Melee.ComboInputWindow then
			state.buffered = "Light"
		end
		return
	end
	if DamageService.isBlocking(character) then
		DamageService.setBlocking(character, false)
	end

	local melee = BalanceConfig.Melee
	-- Continue the chain only inside the input window after the last swing.
	if now - state.lastAttackEnd > melee.ComboInputWindow + 0.05 or state.comboStep >= #melee.ComboSteps then
		state.comboStep = 0
	end

	if airborne(character, humanoid) then
		state.comboStep = (state.comboStep % #melee.ComboSteps) + 1
		local timing = melee.Aerial
		broadcastSwing(character, "Aerial")
		schedule(player, state, timing, function()
			strike(player, character, timing, melee.AerialDamage, "Melee", "Aerial Combo")
		end)
		return
	end

	state.comboStep += 1
	local step = state.comboStep
	local timing = melee.ComboSteps[step]
	broadcastSwing(character, "Combo" .. step)
	schedule(player, state, timing, function()
		strike(player, character, timing, melee.ComboDamage[step], "Melee", "Combo")
	end)
	if step >= #melee.ComboSteps then
		state.comboStep = 0
	end
end

function CombatService.heavy(player: Player)
	local character, humanoid, root = parts(player)
	if not character or not humanoid or not root or not canAct(character, humanoid) then
		return
	end
	local state = getState(player)
	local now = os.clock()
	local melee = BalanceConfig.Melee
	-- The client must actually have held M1 for the charge time.
	if not state.pressStart or now - state.pressStart < melee.HeavyChargeTime * 0.75 then
		NetService.strike(player, "heavy without charge")
		return
	end
	state.pressStart = nil
	if now < state.busyUntil then
		return
	end
	if DamageService.isBlocking(character) then
		DamageService.setBlocking(character, false)
	end
	state.comboStep = 0

	if airborne(character, humanoid) then
		CombatService.diveSlam(player, character, humanoid, root, state)
		return
	end

	local timing = melee.Heavy
	broadcastSwing(character, "Heavy")
	schedule(player, state, timing, function()
		strike(player, character, timing, melee.HeavyDamage, "Heavy", "Heavy Strike", 1.15)
	end)
end

function CombatService.diveSlam(player: Player, character: Model, humanoid: Humanoid, root: BasePart, state: AttackerState)
	local dive = BalanceConfig.Melee.DiveSlam
	if state.diving then
		return
	end
	state.diving = true
	state.busyUntil = os.clock() + dive.MaxDiveTime + 0.4
	MovementService.forceLand(player)
	MovementService.exempt(player, dive.MaxDiveTime + 1)
	broadcastSwing(character, "DiveSlam")
	local forward = root.CFrame.LookVector
	NetService.fireClient("Impulse", player, "Self", Vector3.new(forward.X * 30, -dive.DiveSpeed, forward.Z * 30), dive.MaxDiveTime)

	task.spawn(function()
		local started = os.clock()
		while os.clock() - started < dive.MaxDiveTime do
			RunService.Heartbeat:Wait()
			if not AbilityKit.isAlive(character) then
				state.diving = false
				return
			end
			if humanoid.FloorMaterial ~= Enum.Material.Air and os.clock() - started > 0.08 then
				break
			end
		end
		state.diving = false
		NetService.fireClient("Impulse", player, "Stop", Vector3.zero, nil)
		local center = root.Position - Vector3.new(0, root.Size.Y / 2 + humanoid.HipHeight, 0)
		local melee = BalanceConfig.Melee
		for _, victim in AbilityKit.inSphere(center, dive.Radius, { character }) do
			DamageService.apply(victim, {
				Amount = melee.DiveSlamDamage,
				Attacker = player,
				AttackerCharacter = character,
				Kind = "Heavy",
				Position = center,
				Knockback = AbilityKit.awayFrom(center, victim, dive.Knockback, dive.Lift),
				Ragdoll = dive.Ragdoll,
				HitStun = 0.6,
				Tag = "Dive Slam",
			})
		end
		AbilityKit.Hooks.structureDamageSphere(center, dive.Radius * 0.7, 120, 900, character)
		NetService.fireNear("Effect", center, EFFECT_RADIUS, "Crater", {
			Position = center,
			Strength = 0.7,
			Source = character,
		})
		state.busyUntil = os.clock() + 0.35
	end)
end

--------------------------------------------------------------------------------
-- Block
--------------------------------------------------------------------------------
local function setBlock(player: Player, on: boolean)
	local character, humanoid = parts(player)
	if not character or not humanoid then
		return
	end
	if on then
		local state = getState(player)
		if not canAct(character, humanoid) or os.clock() < state.busyUntil then
			return
		end
		if character:GetAttribute("ApexFlying") == true then
			return
		end
	end
	DamageService.setBlocking(character, on)
end

--------------------------------------------------------------------------------
-- Remote
--------------------------------------------------------------------------------
local function onCombatInput(player: Player, action: string, vector: Vector3?)
	if action == "BeamAim" then
		if vector then
			BeamService.updateAim(player, vector)
		end
	elseif action == "M1Down" then
		getState(player).pressStart = os.clock()
	elseif action == "Light" then
		getState(player).pressStart = nil
		CombatService.light(player)
	elseif action == "Heavy" then
		CombatService.heavy(player)
	elseif action == "BlockDown" then
		setBlock(player, true)
	elseif action == "BlockUp" then
		setBlock(player, false)
	elseif action == "Emote" then
		local character = player.Character
		if character and not StatusService.isStunned(character) then
			broadcastSwing(character, "Emote")
		end
	end
end

function CombatService.init()
	NetService.onEvent("CombatInput", {
		Validate.enum({ "M1Down", "Light", "Heavy", "BlockDown", "BlockUp", "BeamAim", "Emote" }),
		Validate.optional(Validate.vector3(1e6)),
	}, onCombatInput :: any, { RequireAlive = false })

	Players.PlayerRemoving:Connect(function(player)
		states[player] = nil
	end)

	-- Parried / guard-broken / stunned players drop their guard.
	RunService.Heartbeat:Connect(function()
		for player in states do
			local character = player.Character
			if character and DamageService.isBlocking(character) and StatusService.isStunned(character) then
				DamageService.setBlocking(character, false)
			end
		end
	end)
end

return CombatService
