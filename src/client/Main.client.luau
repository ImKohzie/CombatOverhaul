--!strict
-- APEX CITY client bootstrap.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage:WaitForChild("ApexCity").Config.GameConfig)

local Controllers = script.Parent.Controllers

require(Controllers.InputController).init()
require(Controllers.CameraController).init()
require(Controllers.PoseController).init()
require(Controllers.EffectsController).init()
require(Controllers.CombatFx).init()
require(Controllers.ProjectileFx).init()
require(Controllers.AbilityFx).init()
require(Controllers.DestructionFx).init()
require(Controllers.FlightController).init()
require(Controllers.MovementController).init()
require(Controllers.ImpulseController).init()
require(Controllers.CombatController).init()
require(Controllers.AbilityInputController).init()
require(Controllers.BeamController).init()
require(Controllers.CharacterFx).init()
require(Controllers.BorderController).init()
require(Controllers.EnvironmentController).init()
task.spawn(function()
	require(Controllers.AmbienceController).init()
end)
require(Controllers.PerfMonitor).init()

-- HUD
local UI = script.Parent.UI
local StarterGui = game:GetService("StarterGui")
pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false) -- Tab = character select
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false) -- our own health bar
end)
require(UI.Hud).init()
local hudGui = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("ApexHud")
require(UI.Minimap).init(hudGui)
require(UI.KillFeed).init(hudGui)
require(UI.CharacterSelect).init(hudGui)

if GameConfig.Debug.ShowDebugHud then
	require(Controllers.DebugHud).init()
end
