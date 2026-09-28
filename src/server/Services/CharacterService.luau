--!strict
-- Spawns players as their selected APEX character and applies role stats.
-- Handles the SelectCharacter request (5s out-of-combat rule).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("ApexCity")
local BalanceConfig = require(Shared.Config.BalanceConfig)
local GameConfig = require(Shared.Config.GameConfig)
local CharacterRegistry = require(Shared.CharacterRegistry)
local Validate = require(Shared.Net.Validate)

local NetService = require(script.Parent.NetService)
local PlayerStateService = require(script.Parent.PlayerStateService)

local CharacterService = {}

local function applyCharacter(player: Player, character: Model)
	local state = PlayerStateService.get(player)
	if not state then
		return
	end
	local config = CharacterRegistry.get(state.CharacterId) or CharacterRegistry.get(GameConfig.DefaultCharacter)
	if not config then
		warn(`[CharacterService] no config for {state.CharacterId}`)
		return
	end
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not humanoid or not humanoid:IsA("Humanoid") then
		return
	end
	local role = BalanceConfig.Roles[config.Role]

	-- Health is managed by our damage system: remove default regen script.
	local regen = character:FindFirstChild("Health")
	if regen and regen:IsA("Script") then
		regen:Destroy()
	end

	humanoid.MaxHealth = role.Health
	humanoid.Health = role.Health
	humanoid.WalkSpeed = role.WalkSpeed
	humanoid.UseJumpPower = true
	humanoid.JumpPower = BalanceConfig.Movement.JumpPower
	humanoid.BreakJointsOnDeath = false -- ragdoll handled by combat system

	character:SetAttribute("ApexCharacter", config.Id)
	character:SetAttribute("ApexRole", config.Role)
	character:SetAttribute("ApexDamageReduction", role.DamageReduction)
end

local function selectCharacter(player: Player, characterId: string): (boolean, string?)
	local config = CharacterRegistry.get(characterId)
	if not config then
		return false, "Unknown character"
	end
	local state = PlayerStateService.get(player)
	if not state then
		return false, "Not ready"
	end
	if state.CharacterId == characterId then
		return false, "Already playing " .. config.DisplayName
	end
	if PlayerStateService.isInCombat(player) then
		return false, "Can't switch while in combat"
	end
	local sinceSwitch = workspace:GetServerTimeNow() - state.LastCharacterSwitch
	if sinceSwitch < BalanceConfig.Combat.CharacterSwitchCooldown then
		return false, "Switching too fast"
	end
	PlayerStateService.setCharacter(player, characterId)
	PlayerStateService.resetCooldowns(player)
	player:LoadCharacterAsync()
	return true, nil
end

function CharacterService.init()
	Players.RespawnTime = BalanceConfig.Combat.RespawnTime

	local function hook(player: Player)
		player.CharacterAdded:Connect(function(character)
			applyCharacter(player, character)
		end)
		if player.Character then
			task.spawn(applyCharacter, player, player.Character)
		end
	end
	Players.PlayerAdded:Connect(hook)
	for _, player in Players:GetPlayers() do
		hook(player)
	end

	NetService.onInvoke(
		"SelectCharacter",
		{ Validate.string(GameConfig.Net.MaxStringLength) },
		selectCharacter :: any,
		{ RequireAlive = false }
	)
end

return CharacterService
