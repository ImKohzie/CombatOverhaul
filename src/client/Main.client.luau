--!strict
-- APEX CITY client bootstrap.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage:WaitForChild("ApexCity").Config.GameConfig)

local Controllers = script.Parent.Controllers

require(Controllers.InputController).init()
require(Controllers.CameraController).init()
require(Controllers.PoseController).init()
require(Controllers.EffectsController).init()
require(Controllers.FlightController).init()
require(Controllers.MovementController).init()
require(Controllers.AbilityInputController).init()
if GameConfig.Debug.ShowDebugHud then
	require(Controllers.DebugHud).init()
end
