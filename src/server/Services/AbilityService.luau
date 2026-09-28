--!strict
-- Server half of the shared AbilityController. Loads any character's
-- abilities from config and runs them after authoritative checks:
-- alive, not stunned, cooldown, ultimate meter, stamina, aim sanity.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("ApexCity")
local Types = require(Shared.Types)
local BalanceConfig = require(Shared.Config.BalanceConfig)
local GameConfig = require(Shared.Config.GameConfig)
local CharacterRegistry = require(Shared.CharacterRegistry)
local Validate = require(Shared.Net.Validate)

local AbilityTypes = require(script.Parent.Parent.AbilityTypes)
local NetService = require(script.Parent.NetService)
local PlayerStateService = require(script.Parent.PlayerStateService)
local RunService = game:GetService("RunService")

type AbilityContext = AbilityTypes.AbilityContext
type AbilityModule = AbilityTypes.AbilityModule

local AbilityService = {}

-- modules[characterId][abilityId]
local modules: { [string]: { [string]: AbilityModule } } = {}
-- active Hold/Charge abilities: active[player][slot]
local active: { [Player]: { [string]: AbilityContext } } = {}

local function loadModules()
	local folder = script.Parent.Parent:FindFirstChild("Abilities")
	if not folder then
		return
	end
	local count = 0
	for _, characterFolder in folder:GetChildren() do
		local set: { [string]: AbilityModule } = {}
		for _, module in characterFolder:GetChildren() do
			if module:IsA("ModuleScript") then
				local ok, result = pcall(require, module)
				if ok and type(result) == "table" and type((result :: any).Begin) == "function" then
					set[module.Name] = result :: AbilityModule
					count += 1
				else
					warn(`[AbilityService] bad ability module {characterFolder.Name}.{module.Name}: {result}`)
				end
			end
		end
		modules[characterFolder.Name] = set
	end
	print(`[AbilityService] loaded {count} ability modules`)
end

local function getModule(characterId: string, abilityId: string): AbilityModule?
	local set = modules[characterId]
	return if set then set[abilityId] else nil
end

local function endAbility(player: Player, slot: string)
	local list = active[player]
	local ctx = list and list[slot]
	if not ctx or not list then
		return
	end
	list[slot] = nil
	local module = getModule(ctx.CharacterId, ctx.Def.Id)
	if module and module.End then
		local ok, err = pcall(module.End :: any, ctx)
		if not ok then
			warn(`[AbilityService] {ctx.CharacterId}.{ctx.Def.Id} End error: {err}`)
		end
	end
end

local function sanitizeAim(root: BasePart, head: BasePart?, balance: Types.AbilityBalance, origin: Vector3?, point: Vector3?): (Vector3?, Vector3?)
	local anchor = if head then head.Position else root.Position
	local aimOrigin = origin or anchor
	if (aimOrigin - anchor).Magnitude > GameConfig.Net.MaxAimOriginOffset then
		return nil, nil
	end
	local aimPoint = point or (root.Position + root.CFrame.LookVector * (balance.Range or 50))
	if (aimPoint - root.Position).Magnitude > GameConfig.Net.MaxAimDistance then
		return nil, nil
	end
	-- Clamp to the ability's range so long aims still work, just shorter.
	local range = balance.Range
	if range then
		local offset = aimPoint - aimOrigin
		if offset.Magnitude > range then
			aimPoint = aimOrigin + offset.Unit * range
		end
	end
	return aimOrigin, aimPoint
end

local function beginAbility(player: Player, slot: string, origin: Vector3?, point: Vector3?)
	local state = PlayerStateService.get(player)
	local character = player.Character
	if not state or not character then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or humanoid.Health <= 0 or not root or not root:IsA("BasePart") then
		return
	end
	if character:GetAttribute("ApexStunned") == true or character:GetAttribute("ApexServerMotion") == true then
		return
	end
	local list = active[player]
	if list and list[slot] then
		return -- already channelling this slot
	end

	local config = CharacterRegistry.get(state.CharacterId)
	local def = config and config.Abilities[slot]
	local balance = BalanceConfig.getAbility(state.CharacterId, slot)
	if not config or not def or not balance then
		return
	end

	if not PlayerStateService.isReady(player, slot) then
		return
	end
	if slot == "Ultimate" and not PlayerStateService.isUltimateReady(player) then
		return
	end
	local staminaCost = balance.StaminaCost or 0
	if staminaCost > 0 and state.Stamina < staminaCost then
		return
	end

	local head = character:FindFirstChild("Head")
	local aimOrigin, aimPoint = sanitizeAim(root, if head and head:IsA("BasePart") then head else nil, balance, origin, point)
	if not aimOrigin or not aimPoint then
		NetService.strike(player, "AbilityInput: aim out of range")
		return
	end

	local module = getModule(state.CharacterId, def.Id)
	if not module then
		NetService.fireClient("Notify", player, `{def.Name} isn't built yet.`)
		return
	end

	local ctx: AbilityContext = {
		Player = player,
		Character = character,
		Humanoid = humanoid,
		Root = root,
		CharacterId = state.CharacterId,
		Slot = slot,
		Def = def,
		Balance = balance,
		AimOrigin = aimOrigin,
		AimPoint = aimPoint,
		StartTime = workspace:GetServerTimeNow(),
	}

	local ok, fired = pcall(module.Begin, ctx)
	if not ok then
		warn(`[AbilityService] {state.CharacterId}.{def.Id} Begin error: {fired}`)
		return
	end
	if fired == false then
		return
	end

	if staminaCost > 0 then
		PlayerStateService.consumeStamina(player, staminaCost)
	end
	if slot == "Ultimate" then
		PlayerStateService.consumeUltimate(player)
		-- Short skippable cinematic for the caster only; everyone nearby hears the sting.
		NetService.fireClient("Effect", player, "UltCinematic", {
			Source = character,
			Name = def.Name,
			Color = config.Palette.Glow,
		})
		NetService.fireNear("Effect", root.Position, 700, "UltSting", {
			Source = character,
			Name = def.Name,
			Color = config.Palette.Glow,
		})
	end
	PlayerStateService.startCooldown(player, slot, balance.Cooldown)

	if def.Input ~= "Instant" then
		local playerActive = active[player]
		if not playerActive then
			playerActive = {}
			active[player] = playerActive
		end
		playerActive[slot] = ctx
		-- Hard cap on channel time (heat meter etc. can end it sooner).
		local maxTime = balance.Duration or 3
		task.delay(maxTime, function()
			local current = active[player]
			if current and current[slot] == ctx then
				endAbility(player, slot)
			end
		end)
	end
end

local function onAbilityInput(player: Player, slot: string, phase: string, origin: Vector3?, point: Vector3?)
	if phase == "Begin" then
		beginAbility(player, slot, origin, point)
	else
		-- Charge / hold releases carry the latest aim (e.g. Lightning Hurl).
		local list = active[player]
		local ctx = list and list[slot]
		if ctx and (origin or point) then
			local head = ctx.Character:FindFirstChild("Head")
			local aimOrigin, aimPoint = sanitizeAim(ctx.Root, if head and head:IsA("BasePart") then head else nil, ctx.Balance, origin, point)
			if aimOrigin and aimPoint then
				ctx.AimOrigin = aimOrigin
				ctx.AimPoint = aimPoint
			end
		end
		endAbility(player, slot)
	end
end

-- Current context of a channelled ability (for modules that poll aim).
function AbilityService.getActive(player: Player, slot: string): AbilityContext?
	local list = active[player]
	return if list then list[slot] else nil
end

-- Force-end everything (death, character switch, stun).
function AbilityService.cancelAll(player: Player)
	local list = active[player]
	if not list then
		return
	end
	for slot in table.clone(list) do
		endAbility(player, slot)
	end
end

function AbilityService.init()
	loadModules()

	NetService.onEvent("AbilityInput", {
		Validate.enum(CharacterRegistry.Slots),
		Validate.enum({ "Begin", "End" }),
		Validate.optional(Validate.vector3(1e6)),
		Validate.optional(Validate.vector3(1e6)),
	}, onAbilityInput :: any, { RequireAlive = false })

	local function hook(player: Player)
		player.CharacterRemoving:Connect(function()
			AbilityService.cancelAll(player)
		end)
	end
	Players.PlayerAdded:Connect(hook)
	for _, player in Players:GetPlayers() do
		hook(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		AbilityService.cancelAll(player)
		active[player] = nil
	end)

	-- Stuns interrupt channelled abilities.
	RunService.Heartbeat:Connect(function()
		for player, list in active do
			if next(list) == nil then
				continue
			end
			local character = player.Character
			if character and character:GetAttribute("ApexStunned") == true and character:GetAttribute("ApexServerMotion") ~= true then
				AbilityService.cancelAll(player)
			end
		end
	end)
end

return AbilityService
