--!strict
-- Part factory for map generation: anchored parts with sane defaults,
-- structure chunks for the destruction system, CollectionService tags, and
-- a yield budget so generating tens of thousands of parts never trips the
-- script timeout.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MapConfig = require(ReplicatedStorage:WaitForChild("ApexCity").Config.MapConfig)

export type ChunkMaterial = "Glass" | "Concrete" | "Steel" | "Wood" | "Brick"

local Builder = {}

local created = 0

function Builder.count(): number
	return created
end

function Builder.tick()
	created += 1
	if created % MapConfig.YieldEvery == 0 then
		task.wait()
	end
end

function Builder.folder(parent: Instance, name: string): Folder
	local existing = parent:FindFirstChild(name)
	if existing and existing:IsA("Folder") then
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

function Builder.model(parent: Instance, name: string): Model
	local model = Instance.new("Model")
	model.Name = name
	model.Parent = parent
	return model
end

function Builder.part(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	Builder.tick()
	return part
end

-- Non-colliding decoration.
function Builder.decor(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material): Part
	local part = Builder.part(parent, name, size, cframe, color, material)
	part.CanCollide = false
	part.CanTouch = false
	part.CastShadow = false
	return part
end

function Builder.cylinder(parent: Instance, name: string, length: number, diameter: number, cframe: CFrame, color: Color3, material: Enum.Material): Part
	-- Cylinder axis is X: callers pass a CFrame whose X axis is the length axis
	local part = Builder.part(parent, name, Vector3.new(length, diameter, diameter), cframe, color, material)
	part.Shape = Enum.PartType.Cylinder
	return part
end

-- Vertical cylinder standing on `base` (length along world Y).
function Builder.pillar(parent: Instance, name: string, base: Vector3, height: number, diameter: number, color: Color3, material: Enum.Material): Part
	return Builder.cylinder(parent, name, height, diameter, CFrame.new(base + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)), color, material)
end

-- A destructible structure chunk. DestructionService builds the support
-- graph lazily from these attributes + geometry.
function Builder.chunk(parent: Instance, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material, kind: ChunkMaterial, buildingId: string, grounded: boolean): Part
	local part = Builder.part(parent, kind, size, cframe, color, material)
	part:SetAttribute("ApexChunk", kind)
	part:SetAttribute("ApexBuilding", buildingId)
	if grounded then
		part:SetAttribute("ApexGrounded", true)
	end
	CollectionService:AddTag(part, "ApexStructure")
	return part
end

function Builder.tag(instance: Instance, tag: string)
	CollectionService:AddTag(instance, tag)
end

function Builder.pointLight(parent: Instance, color: Color3, range: number, brightness: number, tag: string?): PointLight
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = range
	light.Brightness = brightness
	light.Shadows = false
	light.Parent = parent
	if tag then
		CollectionService:AddTag(light, tag)
	end
	return light
end

function Builder.sign(part: BasePart, face: Enum.NormalId, text: string, textColor: Color3, background: Color3?, font: Enum.Font?): SurfaceGui
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 20
	gui.LightInfluence = 0.2
	gui.Parent = part
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = background or Color3.new(0, 0, 0)
	label.BackgroundTransparency = if background then 0 else 1
	label.TextColor3 = textColor
	label.Font = font or Enum.Font.GothamBlack
	label.TextScaled = true
	label.Text = text
	label.Parent = gui
	return gui
end

return Builder
