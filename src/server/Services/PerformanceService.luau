--!strict
-- Server performance report, printed once the world is ready and on demand
-- (PerformanceService.report()): part counts, structures, debris, NPCs,
-- memory, physics/heartbeat timings and script activity.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Stats = game:GetService("Stats")

local DestructionService = require(script.Parent.DestructionService)

local PerformanceService = {}

local heartbeatTimes: { number } = {}

function PerformanceService.report()
	local parts, scripts, lights, emitters = 0, 0, 0, 0
	for _, descendant in workspace:GetDescendants() do
		if descendant:IsA("BasePart") then
			parts += 1
		elseif descendant:IsA("Light") then
			lights += 1
		elseif descendant:IsA("ParticleEmitter") then
			emitters += 1
		end
	end
	for _, container in { game:GetService("ServerScriptService"), game:GetService("ReplicatedStorage"), game:GetService("StarterPlayer") } do
		for _, descendant in container:GetDescendants() do
			if descendant:IsA("LuaSourceContainer") then
				scripts += 1
			end
		end
	end
	local total = 0
	local worst = 0
	for _, t in heartbeatTimes do
		total += t
		worst = math.max(worst, t)
	end
	local average = if #heartbeatTimes > 0 then total / #heartbeatTimes else 0
	local destruction = DestructionService.stats()
	local npcs = workspace:FindFirstChild("ApexNPCs")
	print("================ APEX CITY performance report ================")
	print(string.format("Parts in workspace: %d  (lights %d, particle emitters %d)", parts, lights, emitters))
	print(string.format("Destructible chunks: %d in %d structures, %d broken, loose debris %d (cap %d)", destruction.chunks, destruction.buildings, destruction.broken, destruction.looseDebris, 1200))
	print(string.format("NPCs: %d  ·  Players: %d", if npcs then #npcs:GetChildren() else 0, #Players:GetPlayers()))
	print(string.format("Scripts/modules in the game: %d", scripts))
	print(string.format("Server heartbeat: avg %.2f ms, worst %.2f ms over the last %d frames", average * 1000, worst * 1000, #heartbeatTimes))
	print(string.format("Memory: %.0f MB total", Stats:GetTotalMemoryUsageMb()))
	print(string.format("Workspace.StreamingEnabled: %s", tostring(workspace.StreamingEnabled)))
	print("===============================================================")
end

function PerformanceService.init()
	RunService.Heartbeat:Connect(function(dt)
		table.insert(heartbeatTimes, dt)
		if #heartbeatTimes > 600 then
			table.remove(heartbeatTimes, 1)
		end
	end)
	task.spawn(function()
		local waited = 0
		while workspace:GetAttribute("ApexWorldReady") ~= true and waited < 120 do
			waited += task.wait(1)
		end
		task.wait(10)
		PerformanceService.report()
	end)
end

return PerformanceService
