--!strict
-- Builds one costumed, anchored preview rig per selectable character into
-- ReplicatedStorage.ApexCity.PreviewRigs for the character-select 3D view.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("ApexCity")
local CharacterRegistry = require(Shared.CharacterRegistry)

local CostumeService = require(script.Parent.CostumeService)
local NPCService = require(script.Parent.NPCService)

local PreviewService = {}

function PreviewService.init()
	task.spawn(function()
		local folder = Instance.new("Folder")
		folder.Name = "PreviewRigs"
		for _, config in CharacterRegistry.list(false) do
			local rig = NPCService.createRig(config.Id)
			if rig then
				CostumeService.apply(rig, config.Id)
				for _, descendant in rig:GetDescendants() do
					if descendant:IsA("BasePart") then
						descendant.Anchored = true
						descendant.CanCollide = false
					elseif descendant:IsA("Script") or descendant:IsA("LocalScript") then
						descendant:Destroy()
					end
				end
				local humanoid = rig:FindFirstChildOfClass("Humanoid")
				if humanoid then
					humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
				end
				rig:SetAttribute("ApexCharacter", config.Id)
				rig.Parent = folder
			end
			task.wait()
		end
		folder.Parent = Shared
	end)
end

return PreviewService
