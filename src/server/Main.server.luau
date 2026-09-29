--!strict
-- APEX CITY server bootstrap. Services start in dependency order.

local Services = script.Parent.Services

local names = {
	"NetService", "PlayerStateService", "StatusService", "MovementService", "ReactionService",
	"DamageService", "BeamService", "TraversalService", "CombatService", "PassiveService", "CharacterService",
	"DestructionService", "WorldService", "EnvironmentService", "NPCService", "BotService", "PreviewService",
	"AbilityService", "PerformanceService",
}

local started = os.clock()
-- One failing service must never stop the others from starting.
for _, name in names do
	local ok, err = pcall(function()
		(require :: any)(Services:FindFirstChild(name)).init()
	end)
	if not ok then
		warn(string.format("[APEX CITY] %s failed to start: %s", name, tostring(err)))
	end
end
print(string.format("[APEX CITY] server ready in %.1f ms", (os.clock() - started) * 1000))

-- Balance report (time-to-kill matrix) for tuning BalanceConfig
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("ApexCity")
local GameConfig = require(Shared.Config.GameConfig)
if GameConfig.Debug.PrintBalanceMatrix then
	task.defer(function()
		local BalanceSim = require(Shared.BalanceSim)
		local BalanceConfig = require(Shared.Config.BalanceConfig)
		local CharacterRegistry = require(Shared.CharacterRegistry)
		local ids = {}
		for _, config in CharacterRegistry.list(false) do
			table.insert(ids, config.Id)
		end
		BalanceSim.run(BalanceConfig, ids, print)
	end)
end
