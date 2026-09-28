--!strict
-- Entry point for building the map. Used by WorldService at runtime, and
-- can be run from the Studio command bar in edit mode to BAKE the map into
-- the place (then the server skips generation on start):
--   require(game.ServerScriptService.ApexCity.World.WorldBuilder).build()

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MapConfig = require(ReplicatedStorage:WaitForChild("ApexCity").Config.MapConfig)

local Builder = require(script.Parent.Builder)
local CityGenerator = require(script.Parent.CityGenerator)
local ForestGenerator = require(script.Parent.ForestGenerator)

local WorldBuilder = {}

function WorldBuilder.build(): Model
	local existing = workspace:FindFirstChild(MapConfig.ModelName)
	if existing and existing:IsA("Model") then
		return existing
	end
	local started = os.clock()
	local root = Instance.new("Model")
	root.Name = MapConfig.ModelName
	root.Parent = workspace
	ForestGenerator.generate(root)
	local result = CityGenerator.generate(root)

	-- Spawn pads around the park fountain
	local spawns = Builder.folder(root, "Spawns")
	for index, cf in result.Spawns do
		local spawn = Instance.new("SpawnLocation")
		spawn.Name = "ApexSpawn" .. index
		spawn.Size = Vector3.new(10, 1, 10)
		spawn.CFrame = cf
		spawn.Anchored = true
		spawn.Neutral = true
		spawn.Duration = 3
		spawn.Material = Enum.Material.Marble
		spawn.Color = Color3.fromRGB(200, 196, 188)
		local decal = spawn:FindFirstChildOfClass("Decal")
		if decal then
			decal:Destroy()
		end
		spawn.Parent = spawns
	end
	-- Marker used by NPCService for the training dummies
	local marker = Instance.new("Part")
	marker.Name = "ApexTrainingArea"
	marker.Anchored = true
	marker.CanCollide = false
	marker.CanQuery = false
	marker.Transparency = 1
	marker.Size = Vector3.new(4, 1, 4)
	marker.CFrame = result.TrainingArea
	marker.Parent = root
	local sign = Builder.part(root, "TrainingSign", Vector3.new(24, 4, 0.5), result.TrainingArea * CFrame.new(0, 8, 12), Color3.fromRGB(25, 25, 30), Enum.Material.SmoothPlastic)
	Builder.sign(sign, Enum.NormalId.Back, "TRAINING GROUNDS", Color3.fromRGB(255, 220, 120))

	root:SetAttribute("ApexGeneratedParts", Builder.count())
	print(string.format("[World] New Harbor generated: %d parts in %.1fs", Builder.count(), os.clock() - started))
	return root
end

return WorldBuilder
