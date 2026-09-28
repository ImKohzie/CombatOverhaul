--!strict
-- Client half of the AbilityController: turns Q/E/R/G input into
-- AbilityInput requests with the current crosshair aim. The server decides
-- whether anything actually happens.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("ApexCity")
local Remotes = require(Shared.Net.Remotes)
local CharacterRegistry = require(Shared.CharacterRegistry)
local Types = require(Shared.Types)

local InputController = require(script.Parent.InputController)

local AIM_DISTANCE = 1000

local player = Players.LocalPlayer
local abilityRemote: RemoteEvent

local SLOTS: { [string]: string } = {
	Ability1 = "Ability1",
	Ability2 = "Ability2",
	Ability3 = "Ability3",
	Ultimate = "Ultimate",
}

local AbilityInputController = {}

-- Returns the aim origin (head) and the world point under the crosshair.
function AbilityInputController.getAim(): (Vector3?, Vector3?)
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	local camera = workspace.CurrentCamera
	if not character or not head or not head:IsA("BasePart") or not camera then
		return nil, nil
	end
	local viewport = camera.ViewportSize
	local ray = camera:ViewportPointToRay(viewport.X / 2, viewport.Y / 2)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	local result = workspace:Raycast(ray.Origin, ray.Direction * AIM_DISTANCE, params)
	local point = if result then result.Position else ray.Origin + ray.Direction * AIM_DISTANCE
	return head.Position, point
end

local function currentInputKind(slot: string): Types.InputKind?
	local id = player:GetAttribute("ApexCharacter")
	local config = if type(id) == "string" then CharacterRegistry.get(id) else nil
	local def = config and config.Abilities[slot]
	return if def then def.Input else nil
end

function AbilityInputController.init()
	abilityRemote = Remotes.event("AbilityInput")

	InputController.Began:Connect(function(action: string)
		local slot = SLOTS[action]
		if not slot then
			return
		end
		local origin, point = AbilityInputController.getAim()
		abilityRemote:FireServer(slot, "Begin", origin, point)
	end)

	InputController.Ended:Connect(function(action: string)
		local slot = SLOTS[action]
		if slot and currentInputKind(slot) ~= "Instant" then
			abilityRemote:FireServer(slot, "End")
		end
	end)
end

return AbilityInputController
