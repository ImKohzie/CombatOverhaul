--!strict
-- Loads every ReplicatedStorage.ApexCity.Characters.<Name>.Config and checks
-- it against BalanceConfig so data mistakes show up in the output on start.

local Types = require(script.Parent.Types)
local BalanceConfig = require(script.Parent.Config.BalanceConfig)

type CharacterConfig = Types.CharacterConfig

-- Values are Types.AbilitySlot names.
local SLOTS: { string } = { "Ability1", "Ability2", "Ability3", "Ultimate" }

local registry: { [string]: CharacterConfig } = {}
local ordered: { CharacterConfig } = {}

local function validate(config: CharacterConfig)
	if not BalanceConfig.Roles[config.Role] then
		warn(`[CharacterRegistry] {config.Id}: unknown role {config.Role}`)
	end
	if config.FlightProfile and not BalanceConfig.Flight.Profiles[config.FlightProfile] then
		warn(`[CharacterRegistry] {config.Id}: unknown flight profile {config.FlightProfile}`)
	end
	for _, slot in SLOTS do
		if not config.Abilities[slot] then
			warn(`[CharacterRegistry] {config.Id}: missing ability for {slot}`)
		elseif not BalanceConfig.getAbility(config.Id, slot) then
			warn(`[CharacterRegistry] {config.Id}: no BalanceConfig entry for {slot}`)
		end
	end
end

for _, folder in script.Parent.Characters:GetChildren() do
	local module = folder:FindFirstChild("Config")
	if module and module:IsA("ModuleScript") then
		local ok, result = pcall(require, module)
		if ok and type(result) == "table" then
			local config = result :: CharacterConfig
			if config.Id ~= folder.Name then
				warn(`[CharacterRegistry] folder {folder.Name} has Config.Id {config.Id}`)
			end
			validate(config)
			registry[config.Id] = config
			table.insert(ordered, config)
		else
			warn(`[CharacterRegistry] failed to load {folder.Name}: {result}`)
		end
	end
end

table.sort(ordered, function(a, b)
	return a.Order < b.Order
end)

local CharacterRegistry = {}

CharacterRegistry.Slots = SLOTS

function CharacterRegistry.get(id: string): CharacterConfig?
	return registry[id]
end

-- All characters in select-screen order. includeHidden adds test characters.
function CharacterRegistry.list(includeHidden: boolean?): { CharacterConfig }
	local result = {}
	for _, config in ordered do
		if includeHidden or not config.Hidden then
			table.insert(result, config)
		end
	end
	return result
end

function CharacterRegistry.maxHealth(config: CharacterConfig): number
	return BalanceConfig.Roles[config.Role].Health
end

return CharacterRegistry
