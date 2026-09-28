--!strict
-- The single damage pipeline. Every source of damage (melee, beams,
-- abilities, splats) goes through DamageService.apply, which handles:
--   modifiers (shatter, resonance marks, rage...) -> block / perfect parry /
--   posture / guard break -> role + status damage reduction -> health ->
--   ultimate meter + combat tag -> hit stun, knockback, ragdoll ->
--   cosmetic hit event (numbers, sparks, sound, shake, hit-stop) -> kill feed

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("ApexCity")
local BalanceConfig = require(Shared.Config.BalanceConfig)
local Signal = require(Shared.Util.Signal)

local Hooks = require(script.Parent.Parent.Hooks)
local NetService = require(script.Parent.NetService)
local PlayerStateService = require(script.Parent.PlayerStateService)
local ReactionService = require(script.Parent.ReactionService)
local StatusService = require(script.Parent.StatusService)

type DamageInfo = Hooks.DamageInfo
export type Result = "Hit" | "Blocked" | "Parried" | "GuardBreak" | "Immune"
export type Modifier = (victim: Model, info: DamageInfo) -> ()

local EFFECT_RADIUS = 450
local MAX_TOTAL_REDUCTION = 0.85
local KILL_CREDIT_TIME = 10

local DamageService = {}

DamageService.Damaged = Signal.new() -- (victim: Model, info: DamageInfo, dealt: number, result: Result)
DamageService.Killed = Signal.new() -- (victim: Model, killer: Player?, tag: string?)

type BlockState = { blocking: boolean, start: number, posture: number, lastPostureHit: number }
type LastHit = { player: Player?, character: Model?, tag: string?, time: number }

local modifiers: { Modifier } = {}
local blockStates: { [Model]: BlockState } = {}
local lastHits: { [Model]: LastHit } = {}
local deathHandled: { [Model]: boolean } = {}

function DamageService.addModifier(modifier: Modifier)
	table.insert(modifiers, modifier)
end

--------------------------------------------------------------------------------
-- Blocking / posture
--------------------------------------------------------------------------------
local function getBlock(character: Model): BlockState
	local state = blockStates[character]
	if not state then
		state = { blocking = false, start = 0, posture = BalanceConfig.Defence.PostureMax, lastPostureHit = 0 }
		blockStates[character] = state
		character.AncestryChanged:Connect(function(_, parent)
			if parent == nil then
				blockStates[character] = nil
				lastHits[character] = nil
				deathHandled[character] = nil
			end
		end)
	end
	return state
end

function DamageService.setBlocking(character: Model, blocking: boolean)
	local state = getBlock(character)
	if blocking and not state.blocking then
		state.start = os.clock()
	end
	state.blocking = blocking
	character:SetAttribute("ApexBlocking", blocking)
	if blocking then
		StatusService.slow(character, "Block", BalanceConfig.Defence.BlockMoveSpeedMultiplier, 3600)
	else
		StatusService.remove(character, "Block")
	end
end

function DamageService.isBlocking(character: Model): boolean
	local state = blockStates[character]
	return state ~= nil and state.blocking
end

function DamageService.getPosture(character: Model): number
	return getBlock(character).posture
end

local function isFacing(victim: Model, from: Vector3?): boolean
	local root = victim:FindFirstChild("HumanoidRootPart")
	if not from or not root or not root:IsA("BasePart") then
		return true
	end
	local offset = from - root.Position
	local flat = Vector3.new(offset.X, 0, offset.Z)
	if flat.Magnitude < 1e-3 then
		return true
	end
	return root.CFrame.LookVector:Dot(flat.Unit) > 0.15
end

--------------------------------------------------------------------------------
-- Apply
--------------------------------------------------------------------------------
local function hitStopFor(info: DamageInfo, dealt: number): number
	if info.Kind ~= "Melee" and info.Kind ~= "Heavy" then
		return 0
	end
	local melee = BalanceConfig.Melee
	local t = math.clamp(dealt / 80, 0, 1)
	return melee.HitStopMin + (melee.HitStopMax - melee.HitStopMin) * t
end

local function reductionFor(victim: Model): number
	local role = victim:GetAttribute("ApexDamageReduction")
	local extra = victim:GetAttribute("ApexExtraReduction")
	local total = (if type(role) == "number" then role else 0) + (if type(extra) == "number" then extra else 0)
	return math.clamp(total, 0, MAX_TOTAL_REDUCTION)
end

local function emitHit(victim: Model, info: DamageInfo, dealt: number, result: Result)
	local position = info.Position
	if not position then
		local root = victim:FindFirstChild("HumanoidRootPart")
		position = if root and root:IsA("BasePart") then root.Position else Vector3.zero
	end
	NetService.fireNear("Effect", position :: Vector3, EFFECT_RADIUS, "Hit", {
		Target = victim,
		Attacker = info.AttackerCharacter,
		Amount = math.floor(dealt + 0.5),
		Position = position,
		Kind = info.Kind,
		Result = result,
		HitStop = if result == "Hit" then hitStopFor(info, dealt) else 0.04,
		Heavy = dealt >= BalanceConfig.Reactions.HeavyHitThreshold or info.Ragdoll ~= nil,
	})
end

function DamageService.apply(victim: Model, info: DamageInfo): (number, Result)
	local humanoid = victim:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 or info.Amount <= 0 then
		return 0, "Immune"
	end
	if info.AttackerCharacter == victim then
		return 0, "Immune"
	end
	if victim:GetAttribute("ApexInvulnerable") == true then
		return 0, "Immune"
	end

	if not info.IgnoreModifiers then
		for _, modifier in modifiers do
			local ok, err = pcall(modifier :: any, victim, info)
			if not ok then
				warn("[DamageService] modifier error: " .. tostring(err))
			end
		end
	end

	local amount = info.Amount
	local result: Result = "Hit"
	local attackerRoot = info.AttackerCharacter and info.AttackerCharacter:FindFirstChild("HumanoidRootPart")
	local attackerPos = if attackerRoot and attackerRoot:IsA("BasePart") then attackerRoot.Position else info.Position

	-- Block / parry / posture
	local block = blockStates[victim]
	if block and block.blocking and not info.Unblockable and isFacing(victim, attackerPos) then
		local defence = BalanceConfig.Defence
		local canBlockKind = info.Kind ~= "Beam" or victim:GetAttribute("ApexBraceBeam") == true
		if canBlockKind then
			local isMelee = info.Kind == "Melee" or info.Kind == "Heavy"
			if (info.CanParry ~= false) and isMelee and os.clock() - block.start <= defence.PerfectParryWindow then
				if info.AttackerCharacter then
					StatusService.apply(info.AttackerCharacter, "Parried", "Control", defence.ParryStunDuration, 1, nil)
				end
				emitHit(victim, info, 0, "Parried")
				NetService.fireNear("Effect", attackerPos or Vector3.zero, EFFECT_RADIUS, "Parry", {
					Target = victim,
					Attacker = info.AttackerCharacter,
				})
				return 0, "Parried"
			end
			local blockedAmount = if info.Kind == "Beam" then 0 else amount * defence.BlockDamageMultiplier
			block.posture -= amount * defence.PostureDamageMultiplier
			block.lastPostureHit = os.clock()
			victim:SetAttribute("ApexPosture", math.max(0, math.floor(block.posture)))
			amount = blockedAmount
			result = "Blocked"
			if block.posture <= 0 then
				block.posture = 0
				DamageService.setBlocking(victim, false)
				StatusService.apply(victim, "GuardBreak", "Control", defence.GuardBreakStun)
				result = "GuardBreak"
				NetService.fireNear("Effect", attackerPos or Vector3.zero, EFFECT_RADIUS, "GuardBreak", { Target = victim })
			end
		end
	end

	-- Damage reduction
	amount *= 1 - reductionFor(victim)

	local before = humanoid.Health
	if amount > 0 then
		humanoid:TakeDamage(amount)
	end
	local dealt = before - humanoid.Health

	local attackerPlayer = info.Attacker
	local victimPlayer = Players:GetPlayerFromCharacter(victim)
	if dealt > 0 then
		PlayerStateService.onDamage(attackerPlayer, victimPlayer, dealt)
		if attackerPlayer or info.AttackerCharacter then
			lastHits[victim] = { player = attackerPlayer, character = info.AttackerCharacter, tag = info.Tag, time = os.clock() }
		end
	end

	-- Reactions
	if result == "Hit" and not info.NoReaction and humanoid.Health > 0 then
		if info.HitStun and info.HitStun > 0 then
			StatusService.apply(victim, "HitStun", "Control", info.HitStun)
		end
		if info.Knockback or info.Ragdoll then
			ReactionService.knockback(victim, info.Knockback or Vector3.zero, info.Ragdoll, attackerPlayer, info.AttackerCharacter)
		end
	elseif (result == "Blocked" or result == "GuardBreak") and info.Knockback and humanoid.Health > 0 then
		ReactionService.knockback(victim, info.Knockback * 0.25, nil, attackerPlayer, info.AttackerCharacter)
	end

	emitHit(victim, info, dealt, result)
	DamageService.Damaged:Fire(victim, info, dealt, result)
	return dealt, result
end

--------------------------------------------------------------------------------
-- Deaths / kill feed
--------------------------------------------------------------------------------
local function displayName(character: Model?): string
	if not character then
		return "?"
	end
	local player = Players:GetPlayerFromCharacter(character)
	if player then
		return player.DisplayName
	end
	return character.Name
end

local function onDied(character: Model)
	if deathHandled[character] then
		return
	end
	deathHandled[character] = true
	ReactionService.deathRagdoll(character)
	local last = lastHits[character]
	local killer: Player? = nil
	local killerCharacter: Model? = nil
	local tag: string? = nil
	if last and os.clock() - last.time < KILL_CREDIT_TIME then
		killer = last.player
		killerCharacter = last.character
		tag = last.tag
	end
	DamageService.Killed:Fire(character, killer, tag)
	NetService.fireAll("Effect", "KillFeed", {
		Killer = if killerCharacter then displayName(killerCharacter) else nil,
		Victim = displayName(character),
		Tag = tag,
	})
end

-- Hook a character's Humanoid.Died (players and NPCs).
function DamageService.watch(character: Model)
	local humanoid = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", 10)
	if humanoid and humanoid:IsA("Humanoid") then
		humanoid.Died:Connect(function()
			onDied(character)
		end)
		ReactionService.setupRagdoll(character)
		getBlock(character)
		character:SetAttribute("ApexPosture", BalanceConfig.Defence.PostureMax)
	end
end

function DamageService.init()
	Hooks.applyDamage = function(victim: Model, info: DamageInfo): number
		local dealt = DamageService.apply(victim, info)
		return dealt
	end

	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function(character)
			DamageService.watch(character)
		end)
		if player.Character then
			task.spawn(DamageService.watch, player.Character)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end

	-- Posture regeneration
	RunService.Heartbeat:Connect(function(dt)
		local defence = BalanceConfig.Defence
		local now = os.clock()
		for character, state in blockStates do
			if state.posture < defence.PostureMax and now - state.lastPostureHit >= defence.PostureRegenDelay then
				state.posture = math.min(defence.PostureMax, state.posture + defence.PostureRegenPerSecond * dt)
				local rounded = math.floor(state.posture)
				if character:GetAttribute("ApexPosture") ~= rounded then
					character:SetAttribute("ApexPosture", rounded)
				end
			end
		end
	end)
end

return DamageService
