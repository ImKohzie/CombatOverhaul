--!strict
-- APEX CITY client bootstrap.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage:WaitForChild("ApexCity").Config.GameConfig)

local Controllers = script.Parent.Controllers

require(Controllers.InputController).init()
require(Controllers.AbilityInputController).init()
require(Controllers.EffectsController).init()
if GameConfig.Debug.ShowDebugHud then
	require(Controllers.DebugHud).init()
end
