--!strict
-- APEX CITY server bootstrap. Services start in dependency order.

local Services = script.Parent.Services

local order: { { init: () -> () } } = {
	require(Services.NetService),
	require(Services.PlayerStateService),
	require(Services.StatusService),
	require(Services.MovementService),
	require(Services.ReactionService),
	require(Services.DamageService),
	require(Services.BeamService),
	require(Services.CombatService),
	require(Services.PassiveService),
	require(Services.CharacterService),
	require(Services.DestructionService),
	require(Services.WorldService),
	require(Services.NPCService),
	require(Services.AbilityService),
}

local started = os.clock()
for _, service in order do
	service.init()
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
