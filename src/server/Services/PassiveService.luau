--!strict
-- Loads per-character passives from ServerScriptService.ApexCity.Passives.<Id>.
-- A passive module returns { onCharacter = function(player, character) -> cleanup? }.

local Players = game:GetService("Players")

local PlayerStateService = require(script.Parent.PlayerStateService)

export type Passive = {
	onCharacter: (player: Player, character: Model) -> (() -> ())?,
}

local PassiveService = {}

local passives: { [string]: Passive } = {}
local cleanups: { [Player]: () -> () } = {}

local function runCleanup(player: Player)
	local cleanup = cleanups[player]
	cleanups[player] = nil
	if cleanup then
		local ok, err = pcall(cleanup :: any)
		if not ok then
			warn("[PassiveService] cleanup error: " .. tostring(err))
		end
	end
end

-- Called by CharacterService once the character is set up.
function PassiveService.start(player: Player, character: Model)
	runCleanup(player)
	local state = PlayerStateService.get(player)
	local passive = state and passives[state.CharacterId]
	if not passive then
		return
	end
	local ok, result = pcall(passive.onCharacter, player, character)
	if ok and type(result) == "function" then
		cleanups[player] = result
	elseif not ok then
		warn("[PassiveService] start error: " .. tostring(result))
	end
end

function PassiveService.init()
	local folder = script.Parent.Parent:FindFirstChild("Passives")
	if folder then
		for _, module in folder:GetChildren() do
			if module:IsA("ModuleScript") then
				local ok, result = pcall(require, module)
				if ok and type(result) == "table" then
					passives[module.Name] = result :: any
				else
					warn(`[PassiveService] failed to load {module.Name}: {result}`)
				end
			end
		end
	end
	local function hook(player: Player)
		player.CharacterRemoving:Connect(function()
			runCleanup(player)
		end)
	end
	Players.PlayerAdded:Connect(hook)
	for _, player in Players:GetPlayers() do
		hook(player)
	end
	Players.PlayerRemoving:Connect(runCleanup)
end

return PassiveService
