--!strict
-- Original character looks built from the R15 body + welded detail parts
-- (no free models, no copyrighted designs). Each costume recolours the body
-- with the character's palette, sets materials (fabric, metal, chrome...),
-- and adds signature pieces: capes, shields, plates, masks, glowing seams.
-- When real meshes / SurfaceAppearance assets are added to the
-- AssetRegistry, they can replace these builders one character at a time.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("ApexCity")
local CharacterRegistry = require(Shared.CharacterRegistry)
local Types = require(Shared.Types)

type Palette = Types.Palette

local CostumeService = {}

local LIMBS: { [string]: { string } } = {
	Upper = { "UpperTorso", "LowerTorso" },
	Arms = { "LeftUpperArm", "LeftLowerArm", "RightUpperArm", "RightLowerArm" },
	Hands = { "LeftHand", "RightHand" },
	Legs = { "LeftUpperLeg", "LeftLowerLeg", "RightUpperLeg", "RightLowerLeg" },
	Feet = { "LeftFoot", "RightFoot" },
}

local function part(character: Model, name: string): BasePart?
	local p = character:FindFirstChild(name)
	return if p and p:IsA("BasePart") then p else nil
end

local function paint(character: Model, names: { string }, color: Color3, material: Enum.Material, reflectance: number?)
	for _, name in names do
		local p = part(character, name)
		if p then
			p.Color = color
			p.Material = material
			p.Reflectance = reflectance or 0
		end
	end
end

-- Weld a detail part to a body part at a local offset.
local function attach(character: Model, bodyName: string, size: Vector3, offset: CFrame, color: Color3, material: Enum.Material, shape: Enum.PartType?): Part?
	local body = part(character, bodyName)
	if not body then
		return nil
	end
	local detail = Instance.new("Part")
	detail.Name = "ApexCostume"
	detail.Size = size
	detail.Color = color
	detail.Material = material
	detail.CanCollide = false
	detail.CanQuery = false
	detail.CanTouch = false
	detail.Massless = true
	detail.CastShadow = material ~= Enum.Material.Neon
	if shape then
		detail.Shape = shape
	end
	detail.CFrame = body.CFrame * offset
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = body
	weld.Part1 = detail
	weld.Parent = detail
	detail.Parent = character
	return detail
end

local function stripAvatar(character: Model, keepFace: boolean)
	for _, child in character:GetChildren() do
		if child:IsA("Accessory") or child:IsA("Shirt") or child:IsA("Pants") or child:IsA("ShirtGraphic") or child:IsA("CharacterMesh") then
			child:Destroy()
		end
	end
	local head = part(character, "Head")
	if head and not keepFace then
		local face = head:FindFirstChildOfClass("Decal")
		if face then
			face:Destroy()
		end
	end
end

local function baseSuit(character: Model, palette: Palette, material: Enum.Material, skin: Color3?)
	paint(character, LIMBS.Upper, palette.Primary, material)
	paint(character, LIMBS.Arms, palette.Primary, material)
	paint(character, LIMBS.Legs, palette.Primary, material)
	paint(character, LIMBS.Hands, palette.Secondary, material)
	paint(character, LIMBS.Feet, palette.Secondary, material)
	if skin then
		paint(character, { "Head" }, skin, Enum.Material.SmoothPlastic)
	else
		paint(character, { "Head" }, palette.Primary, material)
	end
end

local function glowStrip(character: Model, bodyName: string, size: Vector3, offset: CFrame, palette: Palette): Part?
	local strip = attach(character, bodyName, size, offset, palette.Glow, Enum.Material.Neon)
	if strip then
		strip.CastShadow = false
	end
	return strip
end

local function eyes(character: Model, color: Color3, size: number?)
	local s = size or 0.18
	for side = -1, 1, 2 do
		local eye = attach(character, "Head", Vector3.new(s * 1.6, s, 0.08), CFrame.new(side * 0.2, 0.12, -0.58), color, Enum.Material.Neon)
		if eye then
			eye.Name = "ApexEye"
		end
	end
end

local function scale(character: Model, factor: number)
	pcall(function()
		character:ScaleTo(factor)
	end)
end

local SKIN = Color3.fromRGB(204, 142, 105)

--------------------------------------------------------------------------------
-- Builders
--------------------------------------------------------------------------------
local builders: { [string]: (character: Model, palette: Palette) -> () } = {}

builders.Recruit = function(character, palette)
	baseSuit(character, palette, Enum.Material.Fabric, SKIN)
	glowStrip(character, "UpperTorso", Vector3.new(0.2, 1.4, 0.05), CFrame.new(0, 0, -0.52), palette)
end

builders.Sovereign = function(character, palette)
	baseSuit(character, palette, Enum.Material.Fabric, SKIN)
	paint(character, LIMBS.Feet, palette.Secondary, Enum.Material.Leather)
	paint(character, { "LowerTorso" }, palette.Secondary, Enum.Material.Fabric)
	-- Original chest emblem: a raised gold chevron over a white disc
	attach(character, "UpperTorso", Vector3.new(0.08, 1.1, 1.1), CFrame.new(0, 0.15, -0.52) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(235, 235, 240), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
	attach(character, "UpperTorso", Vector3.new(0.7, 0.18, 0.1), CFrame.new(-0.18, 0.2, -0.58) * CFrame.Angles(0, 0, math.rad(-35)), Color3.fromRGB(230, 180, 40), Enum.Material.Metal)
	attach(character, "UpperTorso", Vector3.new(0.7, 0.18, 0.1), CFrame.new(0.18, 0.2, -0.58) * CFrame.Angles(0, 0, math.rad(35)), Color3.fromRGB(230, 180, 40), Enum.Material.Metal)
	-- Belt
	attach(character, "LowerTorso", Vector3.new(2.05, 0.25, 1.1), CFrame.new(0, 0.3, 0), Color3.fromRGB(230, 180, 40), Enum.Material.Metal)
	-- Cape: three hinged segments that swing with movement
	local torso = part(character, "UpperTorso")
	if torso then
		local previous: BasePart = torso
		local previousOffset = CFrame.new(0, 0.9, 0.55)
		for i = 1, 3 do
			local segment = Instance.new("Part")
			segment.Name = "ApexCape"
			segment.Size = Vector3.new(2.3 + i * 0.25, 1.3, 0.08)
			segment.Color = palette.Secondary
			segment.Material = Enum.Material.Fabric
			segment.CanCollide = false
			segment.CanQuery = false
			segment.CanTouch = false
			segment.Massless = true
			local a0 = Instance.new("Attachment")
			a0.CFrame = previousOffset
			a0.Parent = previous
			local a1 = Instance.new("Attachment")
			a1.CFrame = CFrame.new(0, 0.65, 0)
			a1.Parent = segment
			segment.CFrame = previous.CFrame * previousOffset * CFrame.new(0, -0.65, 0)
			segment.Parent = character
			local hinge = Instance.new("BallSocketConstraint")
			hinge.Attachment0 = a0
			hinge.Attachment1 = a1
			hinge.LimitsEnabled = true
			hinge.UpperAngle = if i == 1 then 50 else 35
			hinge.TwistLimitsEnabled = true
			hinge.TwistLowerAngle = -10
			hinge.TwistUpperAngle = 10
			hinge.Parent = segment
			previous = segment
			previousOffset = CFrame.new(0, -0.65, 0)
		end
	end
	eyes(character, Color3.fromRGB(255, 60, 40), 0.1)
	for _, eye in character:GetChildren() do
		if eye.Name == "ApexEye" and eye:IsA("BasePart") then
			eye.Transparency = 0.85 -- brightens during heat vision
		end
	end
end

builders.Voltline = function(character, palette)
	baseSuit(character, palette, Enum.Material.Fabric)
	paint(character, LIMBS.Arms, palette.Secondary, Enum.Material.Fabric)
	paint(character, LIMBS.Legs, palette.Secondary, Enum.Material.Fabric)
	-- Aerodynamic visor
	attach(character, "Head", Vector3.new(1.05, 0.28, 0.2), CFrame.new(0, 0.12, -0.55), Color3.fromRGB(20, 20, 20), Enum.Material.Glass)
	-- Lightning veins
	glowStrip(character, "UpperTorso", Vector3.new(0.12, 1.5, 0.05), CFrame.new(-0.3, 0, -0.52) * CFrame.Angles(0, 0, math.rad(20)), palette)
	glowStrip(character, "UpperTorso", Vector3.new(0.12, 1.5, 0.05), CFrame.new(0.3, 0, -0.52) * CFrame.Angles(0, 0, math.rad(-20)), palette)
	for _, limb in { "LeftUpperLeg", "RightUpperLeg", "LeftUpperArm", "RightUpperArm" } do
		glowStrip(character, limb, Vector3.new(0.08, 1, 0.05), CFrame.new(0, 0, -0.5) * CFrame.Angles(0, 0, math.rad(15)), palette)
	end
	-- Ear bolts
	attach(character, "Head", Vector3.new(0.12, 0.5, 0.3), CFrame.new(0.62, 0.3, 0) * CFrame.Angles(0, 0, math.rad(-30)), palette.Glow, Enum.Material.Neon)
	attach(character, "Head", Vector3.new(0.12, 0.5, 0.3), CFrame.new(-0.62, 0.3, 0) * CFrame.Angles(0, 0, math.rad(30)), palette.Glow, Enum.Material.Neon)
end

builders.Bastion = function(character, palette)
	scale(character, 1.25)
	baseSuit(character, palette, Enum.Material.Slate)
	paint(character, { "Head" }, palette.Primary, Enum.Material.Basalt)
	-- Plates
	attach(character, "UpperTorso", Vector3.new(2.3, 1.2, 0.35), CFrame.new(0, 0.2, -0.55), palette.Primary:Lerp(Color3.new(0.3, 0.3, 0.3), 0.3), Enum.Material.Slate)
	for side = -1, 1, 2 do
		attach(character, "UpperTorso", Vector3.new(1.3, 0.6, 1.4), CFrame.new(side * 1.25, 0.75, 0) * CFrame.Angles(0, 0, math.rad(side * -15)), palette.Primary, Enum.Material.Basalt)
		glowStrip(character, "UpperTorso", Vector3.new(0.9, 0.06, 1.42), CFrame.new(side * 1.25, 0.55, 0) * CFrame.Angles(0, 0, math.rad(side * -15)), palette)
	end
	glowStrip(character, "UpperTorso", Vector3.new(2.2, 0.06, 0.05), CFrame.new(0, -0.15, -0.74), palette)
	glowStrip(character, "Head", Vector3.new(0.6, 0.08, 0.05), CFrame.new(0, 0.1, -0.6), palette)
	-- Steam vents on the back
	local back = attach(character, "UpperTorso", Vector3.new(0.4, 0.4, 0.2), CFrame.new(0, 0.5, 0.55), palette.Secondary, Enum.Material.Metal)
	if back then
		local steam = Instance.new("ParticleEmitter")
		steam.Color = ColorSequence.new(Color3.fromRGB(230, 230, 230))
		steam.Transparency = NumberSequence.new(0.6, 1)
		steam.Size = NumberSequence.new(0.5, 2.5)
		steam.Lifetime = NumberRange.new(0.8, 1.4)
		steam.Speed = NumberRange.new(3, 6)
		steam.Rate = 8
		steam.EmissionDirection = Enum.NormalId.Top
		steam.Parent = back
	end
end

builders.OldGuard = function(character, palette)
	baseSuit(character, palette, Enum.Material.Fabric, SKIN)
	paint(character, LIMBS.Feet, Color3.fromRGB(40, 30, 25), Enum.Material.Leather)
	paint(character, LIMBS.Hands, Color3.fromRGB(60, 45, 35), Enum.Material.Leather)
	-- Tactical vest + straps
	attach(character, "UpperTorso", Vector3.new(2.1, 1.5, 1.2), CFrame.new(0, 0.05, 0), palette.Secondary, Enum.Material.Fabric)
	attach(character, "UpperTorso", Vector3.new(0.25, 1.9, 1.25), CFrame.new(0, 0, 0) * CFrame.Angles(0, 0, math.rad(30)), Color3.fromRGB(50, 40, 30), Enum.Material.Leather)
	-- Dog tags
	attach(character, "UpperTorso", Vector3.new(0.2, 0.3, 0.04), CFrame.new(0.1, 0.35, -0.64), Color3.fromRGB(170, 170, 170), Enum.Material.Metal)
	-- Battered round shield on the back (concentric rings, no emblem)
	local shield = attach(character, "UpperTorso", Vector3.new(0.2, 2.6, 2.6), CFrame.new(0, 0.1, 0.72) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(150, 150, 155), Enum.Material.DiamondPlate, Enum.PartType.Cylinder)
	if shield then
		shield.Name = "ApexShield"
	end
	attach(character, "UpperTorso", Vector3.new(0.22, 1.8, 1.8), CFrame.new(0, 0.1, 0.72) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(110, 40, 35), Enum.Material.Metal, Enum.PartType.Cylinder)
	attach(character, "UpperTorso", Vector3.new(0.24, 0.9, 0.9), CFrame.new(0, 0.1, 0.72) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(150, 150, 155), Enum.Material.Metal, Enum.PartType.Cylinder)
	-- Chest reactor glow (hint of the meltdown)
	glowStrip(character, "UpperTorso", Vector3.new(0.35, 0.35, 0.05), CFrame.new(0, 0.2, -0.62), palette)
end

builders.Rampage = function(character, palette)
	scale(character, 1.3)
	baseSuit(character, palette, Enum.Material.SmoothPlastic, palette.Primary)
	paint(character, LIMBS.Legs, palette.Secondary, Enum.Material.Fabric)
	paint(character, { "LowerTorso" }, palette.Secondary, Enum.Material.Fabric)
	-- Torn shorts ragged hems + glowing veins
	for _, limb in { "LeftUpperArm", "RightUpperArm", "UpperTorso" } do
		glowStrip(character, limb, Vector3.new(0.06, 0.9, 0.05), CFrame.new(0.15, 0, -0.52) * CFrame.Angles(0, 0, math.rad(25)), palette)
	end
	eyes(character, palette.Glow, 0.12)
	local torso = part(character, "UpperTorso")
	if torso then
		local shimmer = Instance.new("ParticleEmitter")
		shimmer.Color = ColorSequence.new(palette.Glow)
		shimmer.LightEmission = 1
		shimmer.Transparency = NumberSequence.new(0.7, 1)
		shimmer.Size = NumberSequence.new(0.15, 0)
		shimmer.Lifetime = NumberRange.new(0.5, 1)
		shimmer.Speed = NumberRange.new(1, 2)
		shimmer.Rate = 10
		shimmer.Parent = torso
	end
end

builders.NightwingGoblin = function(character, palette)
	baseSuit(character, palette, Enum.Material.Rubber)
	paint(character, LIMBS.Upper, palette.Primary, Enum.Material.Metal, 0.05)
	-- Insect mask: domed helmet, big angled lenses, mandible plates
	attach(character, "Head", Vector3.new(1.35, 1.35, 1.35), CFrame.new(0, 0.05, 0), palette.Primary, Enum.Material.Metal, Enum.PartType.Ball)
	for side = -1, 1, 2 do
		attach(character, "Head", Vector3.new(0.45, 0.28, 0.1), CFrame.new(side * 0.28, 0.15, -0.66) * CFrame.Angles(0, 0, math.rad(side * 25)), palette.Glow, Enum.Material.Neon)
		attach(character, "Head", Vector3.new(0.15, 0.45, 0.25), CFrame.new(side * 0.22, -0.4, -0.55) * CFrame.Angles(0, 0, math.rad(side * -20)), palette.Secondary, Enum.Material.Metal)
	end
	-- Chest armour ridges
	for i = 0, 2 do
		attach(character, "UpperTorso", Vector3.new(1.8 - i * 0.3, 0.12, 0.1), CFrame.new(0, 0.5 - i * 0.35, -0.55), palette.Secondary, Enum.Material.Metal)
	end
end

builders.Argent = function(character, palette)
	for _, group in LIMBS do
		paint(character, group, palette.Primary, Enum.Material.Foil, 0.6)
	end
	paint(character, { "Head" }, palette.Primary, Enum.Material.Foil, 0.6)
	eyes(character, palette.Glow, 0.12)
end

builders.Graven = function(character, palette)
	baseSuit(character, palette, Enum.Material.Fabric)
	-- Hooded mask
	attach(character, "Head", Vector3.new(1.3, 1.3, 1.3), CFrame.new(0, 0.1, 0.05), palette.Primary, Enum.Material.Fabric, Enum.PartType.Ball)
	eyes(character, palette.Glow, 0.1)
	-- Orbiting stones (static halo behind the back)
	for i = 0, 4 do
		local angle = i / 5 * math.pi * 2
		attach(character, "UpperTorso", Vector3.new(0.35, 0.35, 0.35), CFrame.new(math.cos(angle) * 1.4, 0.6 + math.sin(angle) * 1.4, 0.9) * CFrame.Angles(angle, angle, 0), Color3.fromRGB(60, 55, 65), Enum.Material.Basalt)
	end
	glowStrip(character, "UpperTorso", Vector3.new(0.3, 0.3, 0.05), CFrame.new(0, 0.1, -0.52), palette)
end

builders.Rime = function(character, palette)
	baseSuit(character, palette, Enum.Material.Fabric)
	paint(character, { "Head" }, palette.Primary, Enum.Material.Glass)
	for side = -1, 1, 2 do
		for i = 0, 2 do
			attach(character, "UpperTorso", Vector3.new(0.25, 0.9 - i * 0.2, 0.25), CFrame.new(side * (0.9 + i * 0.15), 0.9, 0.1 * i) * CFrame.Angles(0, 0, math.rad(side * (-25 - i * 15))), palette.Glow, Enum.Material.Ice)
		end
	end
	eyes(character, palette.Glow, 0.1)
	local torso = part(character, "UpperTorso")
	if torso then
		local frost = Instance.new("ParticleEmitter")
		frost.Color = ColorSequence.new(Color3.new(1, 1, 1))
		frost.Transparency = NumberSequence.new(0.5, 1)
		frost.Size = NumberSequence.new(0.2, 0.05)
		frost.Lifetime = NumberRange.new(0.6, 1.2)
		frost.Speed = NumberRange.new(0.5, 1.5)
		frost.Acceleration = Vector3.new(0, -3, 0)
		frost.Rate = 6
		frost.Parent = torso
	end
end

builders.Swarm = function(character, palette)
	baseSuit(character, palette, Enum.Material.Metal)
	for _, group in LIMBS do
		paint(character, group, palette.Primary, Enum.Material.DiamondPlate, 0.1)
	end
	eyes(character, palette.Glow, 0.1)
	local torso = part(character, "UpperTorso")
	if torso then
		local nanites = Instance.new("ParticleEmitter")
		nanites.Color = ColorSequence.new(Color3.fromRGB(150, 155, 165))
		nanites.Transparency = NumberSequence.new(0.2, 1)
		nanites.Size = NumberSequence.new(0.1, 0.05)
		nanites.Lifetime = NumberRange.new(0.8, 1.5)
		nanites.Speed = NumberRange.new(2, 4)
		nanites.SpreadAngle = Vector2.new(180, 180)
		nanites.Rate = 40
		nanites.Parent = torso
	end
end

builders.Echo = function(character, palette)
	baseSuit(character, palette, Enum.Material.Fabric)
	-- Speaker-grille mask and throat rings
	attach(character, "Head", Vector3.new(0.9, 0.5, 0.1), CFrame.new(0, -0.2, -0.58), palette.Secondary, Enum.Material.DiamondPlate)
	eyes(character, palette.Glow, 0.1)
	for i = 0, 2 do
		attach(character, "UpperTorso", Vector3.new(0.05, 0.6 + i * 0.35, 0.6 + i * 0.35), CFrame.new(0, 0.3, -0.52 - i * 0.02) * CFrame.Angles(0, math.rad(90), 0), palette.Glow, Enum.Material.Neon, Enum.PartType.Cylinder)
	end
end

builders.Umbra = function(character, palette)
	baseSuit(character, palette, Enum.Material.Fabric)
	-- Long hood and trailing shadow
	attach(character, "Head", Vector3.new(1.3, 1.4, 1.3), CFrame.new(0, 0.15, 0.1), palette.Primary, Enum.Material.Fabric, Enum.PartType.Ball)
	eyes(character, palette.Glow, 0.1)
	local torso = part(character, "UpperTorso")
	if torso then
		local smoke = Instance.new("ParticleEmitter")
		smoke.Color = ColorSequence.new(Color3.fromRGB(20, 10, 35))
		smoke.Transparency = NumberSequence.new(0.4, 1)
		smoke.Size = NumberSequence.new(1, 2.5)
		smoke.Lifetime = NumberRange.new(0.6, 1.2)
		smoke.Speed = NumberRange.new(0.5, 1.5)
		smoke.Rate = 15
		smoke.Parent = torso
	end
end

--------------------------------------------------------------------------------
-- Apply
--------------------------------------------------------------------------------
function CostumeService.apply(character: Model, characterId: string)
	local config = CharacterRegistry.get(characterId)
	if not config then
		return
	end
	local builder = builders[characterId] or builders.Recruit
	local keepFace = characterId == "Sovereign" or characterId == "OldGuard" or characterId == "Recruit"
	stripAvatar(character, keepFace)
	-- Avatar items can stream in after spawn; keep the costume clean.
	character.ChildAdded:Connect(function(child)
		if child:IsA("Accessory") or child:IsA("Shirt") or child:IsA("Pants") or child:IsA("ShirtGraphic") then
			task.defer(function()
				child:Destroy()
			end)
		end
	end)
	local ok, err = pcall(builder :: any, character, config.Palette)
	if not ok then
		warn(`[CostumeService] {characterId}: {err}`)
	end
end

return CostumeService
