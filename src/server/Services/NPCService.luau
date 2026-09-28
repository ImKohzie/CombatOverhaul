--!strict
-- Training dummies (one per health tier) near the spawn so combat, damage
-- numbers, parries and time-to-kill can be tested solo. They respawn after
-- death. All NPCs live in workspace.ApexNPCs and carry ApexNPC = true.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("ApexCity")
local BalanceConfig = require(Shared.Config.BalanceConfig)
local GameConfig = require(Shared.Config.GameConfig)
local Types = require(Shared.Types)

local DamageService = require(script.Parent.DamageService)

local NPCService = {}

local folder: Folder

function NPCService.folder(): Folder
	return folder
end

local function spawnAnchor(): CFrame
	local marker = workspace:FindFirstChild("ApexTrainingArea", true)
	if marker and marker:IsA("BasePart") then
		return marker.CFrame
	end
	local spawn = workspace:FindFirstChildOfClass("SpawnLocation")
	if spawn then
		return spawn.CFrame * CFrame.new(0, 0, -30)
	end
	return CFrame.new(0, 5, -30)
end

-- Build a plain R15 rig. Used for dummies, clones and decoys.
function NPCService.createRig(name: string, color: Color3?): Model?
	local ok, model = pcall(function()
		return Players:CreateHumanoidModelFromDescription(Instance.new("HumanoidDescription"), Enum.HumanoidRigType.R15)
	end)
	if not ok or not model then
		warn("[NPCService] could not create rig: " .. tostring(model))
		return nil
	end
	model.Name = name
	if color then
		for _, part in model:GetDescendants() do
			if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
				part.Color = color
			end
		end
	end
	local animate = model:FindFirstChild("Animate")
	if animate then
		animate:Destroy() -- server-side LocalScript would not run anyway
	end
	return model
end

local function spawnDummy(role: Types.Role, offset: CFrame)
	local roleBalance = BalanceConfig.Roles[role]
	local model = NPCService.createRig(
		string.format("Dummy · %s (%d)", role, roleBalance.Health),
		Color3.fromRGB(200, 170, 120)
	)
	if not model then
		return
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		model:Destroy()
		return
	end
	humanoid.MaxHealth = roleBalance.Health
	humanoid.Health = roleBalance.Health
	humanoid.WalkSpeed = 0
	humanoid.BreakJointsOnDeath = false
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOn
	model:SetAttribute("ApexNPC", true)
	model:SetAttribute("ApexRole", role)
	model:SetAttribute("ApexDamageReduction", roleBalance.DamageReduction)
	model:PivotTo(spawnAnchor() * offset)
	model.Parent = folder
	DamageService.watch(model)

	humanoid.Died:Connect(function()
		task.delay(GameConfig.Dummies.RespawnTime, function()
			model:Destroy()
			spawnDummy(role, offset)
		end)
	end)
end

function NPCService.init()
	local existing = workspace:FindFirstChild("ApexNPCs")
	if existing and existing:IsA("Folder") then
		folder = existing
	else
		local created = Instance.new("Folder")
		created.Name = "ApexNPCs"
		created.Parent = workspace
		folder = created
	end
	if not GameConfig.Dummies.Enabled then
		return
	end
	task.spawn(function()
		-- Wait for the map so the dummies stand in the training grounds.
		local waited = 0
		while workspace:GetAttribute("ApexWorldReady") ~= true and waited < 90 do
			waited += task.wait(0.5)
		end
		for index, role in GameConfig.Dummies.Roles do
			local x = (index - (#GameConfig.Dummies.Roles + 1) / 2) * 12
			spawnDummy(role :: any, CFrame.new(x, 3, 0) * CFrame.Angles(0, math.pi, 0))
		end
	end)
end

return NPCService
