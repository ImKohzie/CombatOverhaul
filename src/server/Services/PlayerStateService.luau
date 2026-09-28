--!strict
-- Authoritative per-player state: selected character, stamina, ultimate
-- meter, cooldowns and combat tag. Replicated to the owning client (and
-- everyone, for HUD/nameplates) through Player attributes:
--   ApexCharacter, ApexStamina, ApexUltimate, ApexInCombat, ApexCD_<Slot>
-- Cooldown attributes hold the server time (workspace:GetServerTimeNow())
-- when the ability becomes ready, so clients can draw cooldown sweeps.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("ApexCity")
local BalanceConfig = require(Shared.Config.BalanceConfig)
local GameConfig = require(Shared.Config.GameConfig)

export type PlayerState = {
	CharacterId: string,
	Stamina: number,
	LastStaminaUse: number,
	Ultimate: number,
	LastCombatTime: number,
	LastCharacterSwitch: number,
	Cooldowns: { [string]: number }, -- slot -> server time when ready
}

local PlayerStateService = {}

local states: { [Player]: PlayerState } = {}

local function now(): number
	return workspace:GetServerTimeNow()
end

function PlayerStateService.get(player: Player): PlayerState?
	return states[player]
end

--------------------------------------------------------------------------------
-- Stamina
--------------------------------------------------------------------------------
function PlayerStateService.consumeStamina(player: Player, amount: number): boolean
	local state = states[player]
	if not state or state.Stamina < amount then
		return false
	end
	state.Stamina -= amount
	state.LastStaminaUse = now()
	player:SetAttribute("ApexStamina", math.floor(state.Stamina))
	return true
end

-- Continuous drain (sprint/boost). Returns false when stamina ran out.
function PlayerStateService.drainStamina(player: Player, amount: number): boolean
	local state = states[player]
	if not state then
		return false
	end
	state.Stamina = math.max(0, state.Stamina - amount)
	state.LastStaminaUse = now()
	return state.Stamina > 0
end

--------------------------------------------------------------------------------
-- Cooldowns
--------------------------------------------------------------------------------
function PlayerStateService.isReady(player: Player, slot: string): boolean
	local state = states[player]
	if not state then
		return false
	end
	return now() >= (state.Cooldowns[slot] or 0)
end

function PlayerStateService.startCooldown(player: Player, slot: string, duration: number)
	local state = states[player]
	if not state then
		return
	end
	local readyAt = now() + duration
	state.Cooldowns[slot] = readyAt
	player:SetAttribute("ApexCD_" .. slot, readyAt)
end

function PlayerStateService.resetCooldowns(player: Player)
	local state = states[player]
	if not state then
		return
	end
	for slot in state.Cooldowns do
		player:SetAttribute("ApexCD_" .. slot, 0)
	end
	table.clear(state.Cooldowns)
end

--------------------------------------------------------------------------------
-- Ultimate meter
--------------------------------------------------------------------------------
local function setUltimate(player: Player, state: PlayerState, value: number)
	state.Ultimate = math.clamp(value, 0, BalanceConfig.Ultimate.Max)
	player:SetAttribute("ApexUltimate", math.floor(state.Ultimate))
end

function PlayerStateService.addUltimate(player: Player, amount: number)
	local state = states[player]
	if state then
		setUltimate(player, state, state.Ultimate + amount)
	end
end

function PlayerStateService.isUltimateReady(player: Player): boolean
	local state = states[player]
	return state ~= nil and state.Ultimate >= BalanceConfig.Ultimate.Max
end

function PlayerStateService.consumeUltimate(player: Player)
	local state = states[player]
	if state then
		setUltimate(player, state, 0)
	end
end

-- Call from the damage pipeline (Phase 3) for both attacker and victim.
function PlayerStateService.onDamage(attacker: Player?, victim: Player?, amount: number)
	if attacker then
		PlayerStateService.addUltimate(attacker, amount * BalanceConfig.Ultimate.GainPerDamageDealt)
		PlayerStateService.markCombat(attacker)
	end
	if victim then
		PlayerStateService.addUltimate(victim, amount * BalanceConfig.Ultimate.GainPerDamageTaken)
		PlayerStateService.markCombat(victim)
	end
end

--------------------------------------------------------------------------------
-- Combat tag (5s out-of-combat rule for character switching)
--------------------------------------------------------------------------------
function PlayerStateService.markCombat(player: Player)
	local state = states[player]
	if state then
		state.LastCombatTime = now()
		player:SetAttribute("ApexInCombat", true)
	end
end

function PlayerStateService.isInCombat(player: Player): boolean
	local state = states[player]
	return state ~= nil and now() - state.LastCombatTime < BalanceConfig.Combat.OutOfCombatTime
end

--------------------------------------------------------------------------------
-- Character selection
--------------------------------------------------------------------------------
function PlayerStateService.setCharacter(player: Player, characterId: string)
	local state = states[player]
	if not state then
		return
	end
	state.CharacterId = characterId
	state.LastCharacterSwitch = now()
	player:SetAttribute("ApexCharacter", characterId)
end

--------------------------------------------------------------------------------
-- Lifecycle
--------------------------------------------------------------------------------
local function onPlayerAdded(player: Player)
	local state: PlayerState = {
		CharacterId = GameConfig.DefaultCharacter,
		Stamina = BalanceConfig.Stamina.Max,
		LastStaminaUse = 0,
		Ultimate = 0,
		LastCombatTime = -math.huge,
		LastCharacterSwitch = -math.huge,
		Cooldowns = {},
	}
	states[player] = state
	player:SetAttribute("ApexCharacter", state.CharacterId)
	player:SetAttribute("ApexStamina", state.Stamina)
	player:SetAttribute("ApexUltimate", 0)
	player:SetAttribute("ApexInCombat", false)
end

local REPLICATE_INTERVAL = 0.1
local accumulator = 0

local function step(dt: number)
	local t = now()
	local stamina = BalanceConfig.Stamina
	for _, state in states do
		if state.Stamina < stamina.Max and t - state.LastStaminaUse >= stamina.RegenDelay then
			state.Stamina = math.min(stamina.Max, state.Stamina + stamina.RegenPerSecond * dt)
		end
	end

	accumulator += dt
	if accumulator < REPLICATE_INTERVAL then
		return
	end
	accumulator = 0
	for player, state in states do
		local rounded = math.floor(state.Stamina)
		if player:GetAttribute("ApexStamina") ~= rounded then
			player:SetAttribute("ApexStamina", rounded)
		end
		local inCombat = t - state.LastCombatTime < BalanceConfig.Combat.OutOfCombatTime
		if player:GetAttribute("ApexInCombat") ~= inCombat then
			player:SetAttribute("ApexInCombat", inCombat)
		end
	end
end

function PlayerStateService.init()
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		states[player] = nil
	end)
	RunService.Heartbeat:Connect(step)
end

return PlayerStateService
