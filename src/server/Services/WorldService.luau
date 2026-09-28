--!strict
-- Owns the map at runtime: generates New Harbor if it isn't baked into the
-- place, then runs the living-world loops (glass lift, traffic lights) and
-- the server side of the map border.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("ApexCity")
local MapConfig = require(Shared.Config.MapConfig)

local NetService = require(script.Parent.NetService)
local MovementService = require(script.Parent.MovementService)

local WorldService = {}

local LIFT_WAIT = 6
local HARD_LIMIT_EXTRA = 400 -- beyond this outside the border = exploit / glitch

local function startLifts()
	for _, platform in CollectionService:GetTagged("ApexLift") do
		if not platform:IsA("BasePart") then
			continue
		end
		local align = platform:FindFirstChildOfClass("AlignPosition")
		local bottom = platform:GetAttribute("ApexLiftBottom")
		local top = platform:GetAttribute("ApexLiftTop")
		if not align or typeof(bottom) ~= "Vector3" or typeof(top) ~= "Vector3" then
			continue
		end
		task.spawn(function()
			local goingUp = true
			while platform.Parent do
				align.Position = if goingUp then top else bottom
				local target = align.Position
				local started = os.clock()
				while platform.Parent and (platform.Position - target).Magnitude > 1 and os.clock() - started < 20 do
					task.wait(0.25)
				end
				task.wait(LIFT_WAIT)
				goingUp = not goingUp
			end
		end)
	end
end

local function startTrafficLights()
	task.spawn(function()
		local phase = 1
		while true do
			for _, bulb in CollectionService:GetTagged("ApexTrafficBulb") do
				if bulb:IsA("BasePart") then
					local index = bulb:GetAttribute("ApexBulb")
					-- cycle green (3) -> amber (2) -> red (1)
					local lit = ({ 3, 2, 1 })[phase]
					bulb.Transparency = if index == lit then 0 else 0.75
				end
			end
			task.wait(if phase == 2 then 3 else 12)
			phase = phase % 3 + 1
		end
	end)
end

-- Server-side border safety net (the client handles the smooth pushback).
local function borderCheck()
	local radius = MapConfig.Border.Radius
	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator < 0.5 then
			return
		end
		accumulator = 0
		for _, player in Players:GetPlayers() do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if root and root:IsA("BasePart") then
				local flat = Vector3.new(root.Position.X, 0, root.Position.Z)
				if flat.Magnitude > radius + HARD_LIMIT_EXTRA then
					local inside = flat.Unit * (radius - 60)
					MovementService.exempt(player, 2)
					character:PivotTo(CFrame.new(inside.X, root.Position.Y + 5, inside.Z))
					NetService.strike(player, "outside map border")
				end
			end
		end
	end)
end

function WorldService.init()
	if not workspace.StreamingEnabled then
		warn("[World] Workspace.StreamingEnabled is OFF. Turn it on in Studio (Workspace > StreamingEnabled) for the full map.")
	end
	borderCheck()
	task.spawn(function()
		if MapConfig.Generate and not workspace:FindFirstChild(MapConfig.ModelName) then
			local WorldBuilder = require(script.Parent.Parent.World.WorldBuilder)
			local ok, err = pcall(WorldBuilder.build)
			if not ok then
				warn("[World] generation failed: " .. tostring(err))
			end
		end
		local root = workspace:FindFirstChild(MapConfig.ModelName)
		if root and MapConfig.DisableOtherSpawns then
			for _, spawn in workspace:GetDescendants() do
				if spawn:IsA("SpawnLocation") and not spawn:IsDescendantOf(root) and spawn.Enabled then
					spawn.Enabled = false
					print("[World] Disabled spawn outside the map: " .. spawn:GetFullName() .. " (MapConfig.DisableOtherSpawns)")
				end
			end
		end
		startLifts()
		startTrafficLights()
		workspace:SetAttribute("ApexWorldReady", true)
	end)
end

return WorldService
