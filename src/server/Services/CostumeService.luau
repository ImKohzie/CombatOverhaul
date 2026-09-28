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
local GOLD = Color3.fromRGB(232, 184, 60)
local DARK = Color3.fromRGB(22, 22, 26)

--------------------------------------------------------------------------------
-- Armour kit: layered plates that turn the blocky rig into a hero silhouette
--------------------------------------------------------------------------------
type ArmorStyle = {
	plate: Color3,
	material: Enum.Material,
	trim: Color3?, -- neon trim colour (nil = no glowing trims)
	reflectance: number?,
	shoulders: number?, -- shoulder pad scale (0 = none)
	chest: boolean?,
	gauntlets: boolean?,
	boots: boolean?,
	belt: Color3?,
}

local function neon(character: Model, bodyName: string, size: Vector3, offset: CFrame, color: Color3): Part?
	local strip = attach(character, bodyName, size, offset, color, Enum.Material.Neon)
	if strip then
		strip.CastShadow = false
		strip.Name = "ApexGlow"
	end
	return strip
end

local function plate(character: Model, bodyName: string, size: Vector3, offset: CFrame, style: ArmorStyle): Part?
	local piece = attach(character, bodyName, size, offset, style.plate, style.material)
	if piece and style.reflectance then
		piece.Reflectance = style.reflectance
	end
	return piece
end

local function armorKit(character: Model, style: ArmorStyle)
	local shoulders = style.shoulders or 1
	if shoulders > 0 then
		for _, side in { -1, 1 } do
			local arm = if side < 0 then "LeftUpperArm" else "RightUpperArm"
			plate(character, arm, Vector3.new(1.35, 0.5, 1.3) * shoulders, CFrame.new(side * 0.12, 0.52, 0) * CFrame.Angles(0, 0, math.rad(side * -14)), style)
			plate(character, arm, Vector3.new(1.2, 0.35, 1.2) * shoulders, CFrame.new(side * 0.18, 0.2, 0) * CFrame.Angles(0, 0, math.rad(side * -22)), style)
			if style.trim then
				neon(character, arm, Vector3.new(1.37, 0.07, 1.32) * shoulders, CFrame.new(side * 0.12, 0.3, 0) * CFrame.Angles(0, 0, math.rad(side * -14)), style.trim)
			end
		end
	end
	if style.chest ~= false then
		plate(character, "UpperTorso", Vector3.new(1.9, 1.05, 0.3), CFrame.new(0, 0.22, -0.52), style)
		plate(character, "UpperTorso", Vector3.new(1.3, 0.4, 0.25), CFrame.new(0, -0.5, -0.5), style)
		plate(character, "UpperTorso", Vector3.new(1.7, 1.2, 0.25), CFrame.new(0, 0.1, 0.52), style)
		if style.trim then
			neon(character, "UpperTorso", Vector3.new(1.92, 0.06, 0.32), CFrame.new(0, -0.3, -0.52), style.trim)
			neon(character, "UpperTorso", Vector3.new(0.08, 0.9, 0.27), CFrame.new(0, 0.25, 0.53), style.trim)
		end
	end
	if style.gauntlets ~= false then
		for _, arm in { "LeftLowerArm", "RightLowerArm" } do
			plate(character, arm, Vector3.new(1.16, 0.75, 1.16), CFrame.new(0, -0.18, 0), style)
			if style.trim then
				neon(character, arm, Vector3.new(1.18, 0.07, 1.18), CFrame.new(0, -0.5, 0), style.trim)
			end
		end
	end
	if style.boots ~= false then
		for _, leg in { "LeftLowerLeg", "RightLowerLeg" } do
			plate(character, leg, Vector3.new(1.14, 0.85, 1.18), CFrame.new(0, -0.22, -0.02), style)
			plate(character, leg, Vector3.new(0.8, 0.4, 0.3), CFrame.new(0, 0.42, -0.55), style) -- knee guard
			if style.trim then
				neon(character, leg, Vector3.new(0.1, 0.7, 0.05), CFrame.new(0, -0.2, -0.61), style.trim)
			end
		end
		for _, foot in { "LeftFoot", "RightFoot" } do
			plate(character, foot, Vector3.new(1.08, 0.36, 1.25), CFrame.new(0, 0.02, -0.08), style)
		end
	end
	if style.belt then
		attach(character, "LowerTorso", Vector3.new(2.08, 0.3, 1.1), CFrame.new(0, 0.05, 0), style.belt, Enum.Material.Metal)
		if style.trim then
			neon(character, "LowerTorso", Vector3.new(0.42, 0.34, 0.1), CFrame.new(0, 0.05, -0.56), style.trim)
		end
	end
end

-- Multi-segment hinged cloth (capes, cloaks, coat tails)
local function cape(character: Model, color: Color3, material: Enum.Material, segments: number, width: number, length: number, anchorOffset: CFrame)
	local torso = part(character, "UpperTorso")
	if not torso then
		return
	end
	local previous: BasePart = torso
	local previousOffset = anchorOffset
	local segmentLength = length / segments
	for i = 1, segments do
		local segment = Instance.new("Part")
		segment.Name = "ApexCape"
		segment.Size = Vector3.new(width + i * 0.18, segmentLength, 0.08)
		segment.Color = color
		segment.Material = material
		segment.CanCollide = false
		segment.CanQuery = false
		segment.CanTouch = false
		segment.Massless = true
		local a0 = Instance.new("Attachment")
		a0.CFrame = previousOffset
		a0.Parent = previous
		local a1 = Instance.new("Attachment")
		a1.CFrame = CFrame.new(0, segmentLength / 2, 0)
		a1.Parent = segment
		segment.CFrame = previous.CFrame * previousOffset * CFrame.new(0, -segmentLength / 2, 0)
		segment.Parent = character
		local hinge = Instance.new("BallSocketConstraint")
		hinge.Attachment0 = a0
		hinge.Attachment1 = a1
		hinge.LimitsEnabled = true
		hinge.UpperAngle = if i == 1 then 55 else 30
		hinge.TwistLimitsEnabled = true
		hinge.TwistLowerAngle = -8
		hinge.TwistUpperAngle = 8
		hinge.Parent = segment
		previous = segment
		previousOffset = CFrame.new(0, -segmentLength / 2, 0)
	end
end

local function helmet(character: Model, color: Color3, material: Enum.Material, visor: Color3?, visorMaterial: Enum.Material?)
	attach(character, "Head", Vector3.new(1.32, 1.32, 1.32), CFrame.new(0, 0.05, 0.02), color, material, Enum.PartType.Ball)
	attach(character, "Head", Vector3.new(1.1, 0.45, 0.55), CFrame.new(0, -0.38, -0.42), color, material) -- jaw guard
	if visor then
		local v = attach(character, "Head", Vector3.new(1.1, 0.3, 0.3), CFrame.new(0, 0.12, -0.58), visor, visorMaterial or Enum.Material.Neon)
		if v then
			v.Name = "ApexEye"
		end
	end
end

local function hair(character: Model, color: Color3)
	attach(character, "Head", Vector3.new(1.25, 0.4, 1.25), CFrame.new(0, 0.58, 0.05), color, Enum.Material.SmoothPlastic)
	attach(character, "Head", Vector3.new(1.25, 0.8, 0.3), CFrame.new(0, 0.25, 0.5), color, Enum.Material.SmoothPlastic)
end

local function emitter(character: Model, bodyName: string, props: { [string]: any }): ParticleEmitter?
	local body = part(character, bodyName)
	if not body then
		return nil
	end
	local e = Instance.new("ParticleEmitter")
	for key, value in props do
		(e :: any)[key] = value
	end
	e.Parent = body
	return e
end

local function glowLight(character: Model, bodyName: string, color: Color3, range: number, brightness: number)
	local body = part(character, bodyName)
	if body then
		local light = Instance.new("PointLight")
		light.Name = "ApexAuraLight"
		light.Color = color
		light.Range = range
		light.Brightness = brightness
		light.Shadows = false
		light.Parent = body
	end
end

--------------------------------------------------------------------------------
-- Builders
--------------------------------------------------------------------------------
local builders: { [string]: (character: Model, palette: Palette) -> () } = {}

builders.Recruit = function(character, palette)
	baseSuit(character, palette, Enum.Material.Fabric, SKIN)
	armorKit(character, { plate = palette.Secondary, material = Enum.Material.Metal, trim = palette.Glow, belt = DARK })
end

builders.Sovereign = function(character, palette)
	baseSuit(character, palette, Enum.Material.Fabric, SKIN)
	hair(character, Color3.fromRGB(28, 24, 22))
	paint(character, LIMBS.Feet, palette.Secondary, Enum.Material.Leather)
	paint(character, { "LowerTorso" }, palette.Secondary, Enum.Material.Fabric)
	armorKit(character, { plate = palette.Primary:Lerp(Color3.new(0, 0, 0), 0.2), material = Enum.Material.Fabric, shoulders = 0, gauntlets = false, boots = true, belt = GOLD, trim = GOLD })
	-- Original emblem: white disc, gold chevron-star
	attach(character, "UpperTorso", Vector3.new(0.1, 1.15, 1.15), CFrame.new(0, 0.2, -0.7) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(240, 240, 245), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
	for _, angle in { -38, 38 } do
		attach(character, "UpperTorso", Vector3.new(0.72, 0.18, 0.12), CFrame.new(0, 0.26, -0.77) * CFrame.Angles(0, 0, math.rad(angle)) * CFrame.new(math.sign(angle) * 0.2, 0, 0), GOLD, Enum.Material.Metal)
	end
	neon(character, "UpperTorso", Vector3.new(0.22, 0.22, 0.12), CFrame.new(0, 0.05, -0.78), Color3.fromRGB(255, 240, 200))
	-- Gold wrist cuffs
	for _, arm in { "LeftLowerArm", "RightLowerArm" } do
		attach(character, arm, Vector3.new(1.14, 0.3, 1.14), CFrame.new(0, -0.35, 0), GOLD, Enum.Material.Metal)
	end
	cape(character, palette.Secondary, Enum.Material.Fabric, 5, 2.4, 6.5, CFrame.new(0, 0.85, 0.6))
	attach(character, "UpperTorso", Vector3.new(2.3, 0.35, 0.5), CFrame.new(0, 0.8, 0.45), GOLD, Enum.Material.Metal) -- cape clasp bar
	eyes(character, Color3.fromRGB(255, 60, 40), 0.1)
	for _, eye in character:GetChildren() do
		if eye.Name == "ApexEye" and eye:IsA("BasePart") then
			eye.Transparency = 0.85 -- brightens during heat vision
		end
	end
	glowLight(character, "UpperTorso", Color3.fromRGB(255, 235, 200), 10, 0.6)
end

builders.Voltline = function(character, palette)
	baseSuit(character, palette, Enum.Material.Fabric)
	paint(character, LIMBS.Arms, palette.Secondary, Enum.Material.Fabric)
	paint(character, LIMBS.Legs, palette.Secondary, Enum.Material.Fabric)
	armorKit(character, { plate = palette.Primary, material = Enum.Material.SmoothPlastic, reflectance = 0.15, trim = palette.Glow, shoulders = 0.8, belt = DARK })
	helmet(character, palette.Secondary, Enum.Material.SmoothPlastic, Color3.fromRGB(255, 240, 120))
	-- Lightning-bolt ear fins
	for _, side in { -1, 1 } do
		attach(character, "Head", Vector3.new(0.12, 0.7, 0.35), CFrame.new(side * 0.7, 0.35, 0.05) * CFrame.Angles(0, 0, math.rad(side * -25)), palette.Glow, Enum.Material.Neon)
		attach(character, "Head", Vector3.new(0.12, 0.45, 0.3), CFrame.new(side * 0.8, 0.75, 0.05) * CFrame.Angles(0, 0, math.rad(side * 20)), palette.Glow, Enum.Material.Neon)
	end
	-- Chest lightning bolt (zig-zag)
	neon(character, "UpperTorso", Vector3.new(0.18, 0.55, 0.1), CFrame.new(0.1, 0.45, -0.7) * CFrame.Angles(0, 0, math.rad(25)), palette.Glow)
	neon(character, "UpperTorso", Vector3.new(0.5, 0.14, 0.1), CFrame.new(0, 0.15, -0.7), palette.Glow)
	neon(character, "UpperTorso", Vector3.new(0.18, 0.55, 0.1), CFrame.new(-0.1, -0.15, -0.7) * CFrame.Angles(0, 0, math.rad(25)), palette.Glow)
	-- Lightning veins down the limbs
	for _, limb in { "LeftUpperLeg", "RightUpperLeg", "LeftUpperArm", "RightUpperArm", "LeftLowerLeg", "RightLowerLeg" } do
		neon(character, limb, Vector3.new(0.07, 1, 0.05), CFrame.new(0.2, 0, -0.52) * CFrame.Angles(0, 0, math.rad(18)), palette.Glow)
	end
	emitter(character, "UpperTorso", {
		Color = ColorSequence.new(Color3.fromRGB(255, 250, 180), palette.Glow),
		LightEmission = 1,
		Size = NumberSequence.new(0.18, 0),
		Lifetime = NumberRange.new(0.08, 0.16),
		Speed = NumberRange.new(6, 12),
		SpreadAngle = Vector2.new(180, 180),
		Rate = 20,
	})
	glowLight(character, "UpperTorso", palette.Glow, 9, 0.8)
end

builders.Bastion = function(character, palette)
	scale(character, 1.25)
	baseSuit(character, palette, Enum.Material.Basalt)
	armorKit(character, { plate = palette.Primary:Lerp(Color3.new(0.35, 0.33, 0.3), 0.4), material = Enum.Material.Slate, trim = palette.Glow, shoulders = 1.6, belt = palette.Secondary })
	-- Boulder shoulders + horned stone helm
	for _, side in { -1, 1 } do
		attach(character, "UpperTorso", Vector3.new(1.6, 1.2, 1.6), CFrame.new(side * 1.35, 0.95, 0) * CFrame.Angles(math.rad(20), math.rad(35), math.rad(side * 15)), palette.Primary, Enum.Material.Basalt)
		neon(character, "UpperTorso", Vector3.new(1.62, 0.06, 1.62), CFrame.new(side * 1.35, 0.75, 0) * CFrame.Angles(math.rad(20), math.rad(35), math.rad(side * 15)), palette.Glow)
		attach(character, "Head", Vector3.new(0.3, 0.9, 0.3), CFrame.new(side * 0.55, 0.75, 0.1) * CFrame.Angles(0, 0, math.rad(side * -30)), palette.Primary, Enum.Material.Basalt)
	end
	helmet(character, palette.Primary, Enum.Material.Basalt, palette.Glow)
	-- Molten cracks across the torso
	for i = 1, 6 do
		neon(character, "UpperTorso", Vector3.new(0.06, 0.4 + (i % 3) * 0.2, 0.05), CFrame.new(-0.8 + i * 0.25, (i % 2) * 0.3 - 0.1, -0.69) * CFrame.Angles(0, 0, math.rad(i * 37 % 60 - 30)), palette.Glow)
	end
	-- Steam vents + embers
	local back = attach(character, "UpperTorso", Vector3.new(0.5, 0.5, 0.3), CFrame.new(0, 0.6, 0.7), palette.Secondary, Enum.Material.Metal)
	if back then
		local steam = Instance.new("ParticleEmitter")
		steam.Color = ColorSequence.new(Color3.fromRGB(230, 230, 230))
		steam.Transparency = NumberSequence.new(0.55, 1)
		steam.Size = NumberSequence.new(0.6, 3)
		steam.Lifetime = NumberRange.new(0.8, 1.4)
		steam.Speed = NumberRange.new(3, 6)
		steam.Rate = 10
		steam.EmissionDirection = Enum.NormalId.Top
		steam.Parent = back
	end
	emitter(character, "UpperTorso", {
		Color = ColorSequence.new(Color3.fromRGB(255, 200, 80), Color3.fromRGB(255, 80, 20)),
		LightEmission = 1,
		Size = NumberSequence.new(0.15, 0),
		Lifetime = NumberRange.new(0.6, 1.2),
		Speed = NumberRange.new(1, 3),
		SpreadAngle = Vector2.new(180, 180),
		Acceleration = Vector3.new(0, 4, 0),
		Rate = 12,
	})
	glowLight(character, "UpperTorso", palette.Glow, 14, 1.2)
end

builders.OldGuard = function(character, palette)
	baseSuit(character, palette, Enum.Material.Fabric, SKIN)
	hair(character, Color3.fromRGB(90, 80, 70))
	attach(character, "Head", Vector3.new(1.0, 0.35, 0.3), CFrame.new(0, -0.45, -0.5), Color3.fromRGB(90, 80, 70), Enum.Material.SmoothPlastic) -- stubble jaw
	paint(character, LIMBS.Feet, Color3.fromRGB(40, 30, 25), Enum.Material.Leather)
	paint(character, LIMBS.Hands, Color3.fromRGB(60, 45, 35), Enum.Material.Leather)
	armorKit(character, { plate = palette.Secondary:Lerp(Color3.new(0.2, 0.2, 0.2), 0.3), material = Enum.Material.Fabric, shoulders = 0.9, belt = Color3.fromRGB(50, 40, 30), trim = nil })
	-- Pouches + straps + dog tags
	for _, x in { -0.6, -0.2, 0.2, 0.6 } do
		attach(character, "LowerTorso", Vector3.new(0.34, 0.4, 0.3), CFrame.new(x, -0.1, -0.62), Color3.fromRGB(70, 75, 55), Enum.Material.Fabric)
	end
	attach(character, "UpperTorso", Vector3.new(0.25, 1.9, 1.25), CFrame.new(0, 0, 0) * CFrame.Angles(0, 0, math.rad(30)), Color3.fromRGB(50, 40, 30), Enum.Material.Leather)
	attach(character, "UpperTorso", Vector3.new(0.2, 0.3, 0.04), CFrame.new(0.1, 0.35, -0.72), Color3.fromRGB(170, 170, 170), Enum.Material.Metal)
	-- Battered round shield on the back (concentric rings, no emblem)
	local shield = attach(character, "UpperTorso", Vector3.new(0.2, 2.8, 2.8), CFrame.new(0, 0.1, 0.8) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(150, 150, 155), Enum.Material.DiamondPlate, Enum.PartType.Cylinder)
	if shield then
		shield.Name = "ApexShield"
	end
	attach(character, "UpperTorso", Vector3.new(0.22, 1.9, 1.9), CFrame.new(0, 0.1, 0.8) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(120, 36, 32), Enum.Material.Metal, Enum.PartType.Cylinder)
	attach(character, "UpperTorso", Vector3.new(0.24, 1.0, 1.0), CFrame.new(0, 0.1, 0.8) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(150, 150, 155), Enum.Material.Metal, Enum.PartType.Cylinder)
	-- Chest reactor (the meltdown core)
	attach(character, "UpperTorso", Vector3.new(0.12, 0.55, 0.55), CFrame.new(0, 0.2, -0.72) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(60, 60, 60), Enum.Material.Metal, Enum.PartType.Cylinder)
	local core = neon(character, "UpperTorso", Vector3.new(0.14, 0.36, 0.36), CFrame.new(0, 0.2, -0.74) * CFrame.Angles(0, math.rad(90), 0), palette.Glow)
	if core then
		core.Shape = Enum.PartType.Cylinder
		core.Name = "ApexCore"
	end
	glowLight(character, "UpperTorso", palette.Glow, 8, 1)
end

builders.Rampage = function(character, palette)
	scale(character, 1.3)
	baseSuit(character, palette, Enum.Material.SmoothPlastic, palette.Primary)
	paint(character, LIMBS.Legs, palette.Secondary, Enum.Material.Fabric)
	paint(character, { "LowerTorso" }, palette.Secondary, Enum.Material.Fabric)
	hair(character, Color3.fromRGB(20, 30, 18))
	-- Bulk: huge forearms, traps and fists
	for _, arm in { "LeftLowerArm", "RightLowerArm" } do
		attach(character, arm, Vector3.new(1.35, 1.1, 1.35), CFrame.new(0, -0.05, 0), palette.Primary, Enum.Material.SmoothPlastic)
	end
	for _, hand in { "LeftHand", "RightHand" } do
		attach(character, hand, Vector3.new(1.35, 0.7, 1.35), CFrame.new(0, -0.15, 0), palette.Primary, Enum.Material.SmoothPlastic)
	end
	attach(character, "UpperTorso", Vector3.new(2.3, 0.7, 1.2), CFrame.new(0, 0.75, 0), palette.Primary, Enum.Material.SmoothPlastic)
	attach(character, "UpperTorso", Vector3.new(2.1, 1.0, 0.3), CFrame.new(0, 0.1, -0.55), palette.Primary:Lerp(Color3.new(0, 0, 0), 0.08), Enum.Material.SmoothPlastic) -- pecs
	-- Torn shorts ragged hem
	for i = -3, 3 do
		attach(character, if i < 0 then "LeftUpperLeg" else "RightUpperLeg", Vector3.new(0.3, 0.4, 1.05), CFrame.new(i % 2 * 0.2 - 0.1, -0.55, 0) * CFrame.Angles(0, 0, math.rad(i * 9)), palette.Secondary, Enum.Material.Fabric)
	end
	-- Gamma veins
	for _, limb in { "LeftUpperArm", "RightUpperArm", "LeftLowerArm", "RightLowerArm", "UpperTorso" } do
		neon(character, limb, Vector3.new(0.06, 0.9, 0.05), CFrame.new(0.15, 0, -0.62) * CFrame.Angles(0, 0, math.rad(25)), palette.Glow)
		neon(character, limb, Vector3.new(0.05, 0.6, 0.05), CFrame.new(-0.2, 0.15, -0.62) * CFrame.Angles(0, 0, math.rad(-35)), palette.Glow)
	end
	eyes(character, palette.Glow, 0.12)
	emitter(character, "UpperTorso", {
		Color = ColorSequence.new(palette.Glow),
		LightEmission = 1,
		Transparency = NumberSequence.new(0.5, 1),
		Size = NumberSequence.new(0.2, 0),
		Lifetime = NumberRange.new(0.5, 1),
		Speed = NumberRange.new(1, 3),
		SpreadAngle = Vector2.new(180, 180),
		Rate = 14,
	})
	glowLight(character, "UpperTorso", palette.Glow, 10, 0.8)
end

builders.NightwingGoblin = function(character, palette)
	baseSuit(character, palette, Enum.Material.Rubber)
	armorKit(character, { plate = Color3.fromRGB(34, 34, 40), material = Enum.Material.Metal, reflectance = 0.1, trim = palette.Glow, shoulders = 1.2, belt = DARK })
	-- Insect helm: dome, big angled lenses, mandibles, antennae
	attach(character, "Head", Vector3.new(1.4, 1.4, 1.4), CFrame.new(0, 0.05, 0), palette.Primary, Enum.Material.Metal, Enum.PartType.Ball)
	for _, side in { -1, 1 } do
		local lens = attach(character, "Head", Vector3.new(0.5, 0.32, 0.1), CFrame.new(side * 0.28, 0.15, -0.69) * CFrame.Angles(0, 0, math.rad(side * 25)), palette.Glow, Enum.Material.Neon)
		if lens then
			lens.Name = "ApexEye"
		end
		attach(character, "Head", Vector3.new(0.15, 0.5, 0.25), CFrame.new(side * 0.22, -0.42, -0.58) * CFrame.Angles(0, 0, math.rad(side * -20)), palette.Secondary, Enum.Material.Metal)
		attach(character, "Head", Vector3.new(0.06, 0.9, 0.06), CFrame.new(side * 0.3, 0.9, -0.2) * CFrame.Angles(math.rad(-20), 0, math.rad(side * 25)), palette.Secondary, Enum.Material.Metal)
		-- Bat-wing fins on the back
		for f = 0, 2 do
			attach(character, "UpperTorso", Vector3.new(1.6 - f * 0.3, 0.12, 0.6), CFrame.new(side * (1.2 + f * 0.45), 0.6 - f * 0.35, 0.6) * CFrame.Angles(0, math.rad(side * -20), math.rad(side * (25 + f * 12))), palette.Primary, Enum.Material.Metal)
			neon(character, "UpperTorso", Vector3.new(1.6 - f * 0.3, 0.04, 0.62), CFrame.new(side * (1.2 + f * 0.45), 0.54 - f * 0.35, 0.6) * CFrame.Angles(0, math.rad(side * -20), math.rad(side * (25 + f * 12))), palette.Glow)
		end
		-- Claw gauntlets
		for c = -1, 1 do
			attach(character, if side < 0 then "LeftHand" else "RightHand", Vector3.new(0.12, 0.5, 0.12), CFrame.new(c * 0.3, -0.35, -0.3) * CFrame.Angles(math.rad(-30), 0, 0), palette.Secondary, Enum.Material.Metal)
		end
	end
	-- Jet pack
	local pack = attach(character, "UpperTorso", Vector3.new(1.1, 1.1, 0.5), CFrame.new(0, 0, 0.72), Color3.fromRGB(30, 30, 34), Enum.Material.Metal)
	if pack then
		for _, side in { -1, 1 } do
			local nozzle = Instance.new("Attachment")
			nozzle.Position = Vector3.new(side * 0.35, -0.6, 0.1)
			nozzle.Parent = pack
			local flame = Instance.new("ParticleEmitter")
			flame.Color = ColorSequence.new(Color3.fromRGB(255, 220, 120), palette.Glow)
			flame.LightEmission = 1
			flame.Size = NumberSequence.new(0.35, 0)
			flame.Lifetime = NumberRange.new(0.1, 0.18)
			flame.Speed = NumberRange.new(8, 12)
			flame.EmissionDirection = Enum.NormalId.Bottom
			flame.Rate = 50
			flame.Parent = nozzle
		end
	end
	glowLight(character, "Head", palette.Glow, 8, 1)
end

builders.Argent = function(character, palette)
	for _, group in LIMBS do
		paint(character, group, palette.Primary, Enum.Material.Foil, 0.7)
	end
	paint(character, { "Head" }, palette.Primary, Enum.Material.Foil, 0.7)
	-- Smooth sculpted chrome: brow, chest ridge, flowing lines
	for _, piece in {
		attach(character, "Head", Vector3.new(1.3, 1.3, 1.3), CFrame.new(0, 0.05, 0.05), palette.Primary, Enum.Material.Foil, Enum.PartType.Ball),
		attach(character, "UpperTorso", Vector3.new(1.9, 1.0, 0.2), CFrame.new(0, 0.25, -0.52), palette.Primary, Enum.Material.Foil),
	} do
		if piece then
			piece.Reflectance = 0.75
		end
	end
	for _, limb in { "LeftUpperArm", "RightUpperArm", "LeftUpperLeg", "RightUpperLeg", "UpperTorso" } do
		neon(character, limb, Vector3.new(0.04, 1.0, 0.04), CFrame.new(0, 0, -0.62), palette.Glow)
	end
	eyes(character, Color3.fromRGB(230, 245, 255), 0.13)
	emitter(character, "UpperTorso", {
		Color = ColorSequence.new(Color3.new(1, 1, 1), palette.Glow),
		LightEmission = 1,
		Size = NumberSequence.new(0.12, 0),
		Lifetime = NumberRange.new(0.8, 1.6),
		Speed = NumberRange.new(0.5, 1.5),
		SpreadAngle = Vector2.new(180, 180),
		Rate = 25,
	})
	glowLight(character, "UpperTorso", palette.Glow, 10, 0.7)
end

builders.Graven = function(character, palette)
	baseSuit(character, palette, Enum.Material.Fabric)
	armorKit(character, { plate = palette.Primary:Lerp(Color3.new(0, 0, 0), 0.3), material = Enum.Material.Fabric, trim = palette.Glow, shoulders = 0.9, belt = palette.Secondary, gauntlets = true, boots = true })
	-- Deep hood and long coat tails
	attach(character, "Head", Vector3.new(1.4, 1.45, 1.4), CFrame.new(0, 0.12, 0.1), palette.Primary, Enum.Material.Fabric, Enum.PartType.Ball)
	cape(character, palette.Primary, Enum.Material.Fabric, 3, 1.9, 4, CFrame.new(0, -0.4, 0.55))
	eyes(character, palette.Glow, 0.1)
	-- Halo ring (orbiting stones are animated on clients)
	local halo = neon(character, "UpperTorso", Vector3.new(0.08, 3.4, 3.4), CFrame.new(0, 0.9, 1.1) * CFrame.Angles(0, math.rad(90), 0), palette.Glow)
	if halo then
		halo.Shape = Enum.PartType.Cylinder
		halo.Transparency = 0.55
	end
	glowLight(character, "UpperTorso", palette.Glow, 10, 0.9)
end

builders.Rime = function(character, palette)
	baseSuit(character, palette, Enum.Material.Fabric)
	armorKit(character, { plate = palette.Glow:Lerp(Color3.new(1, 1, 1), 0.3), material = Enum.Material.Ice, trim = palette.Glow, shoulders = 1.1, belt = palette.Secondary })
	paint(character, { "Head" }, palette.Primary, Enum.Material.Glass)
	-- Ice crown + shoulder shards
	for i = -2, 2 do
		attach(character, "Head", Vector3.new(0.18, 0.7 - math.abs(i) * 0.12, 0.18), CFrame.new(i * 0.25, 0.85, 0) * CFrame.Angles(0, 0, math.rad(-i * 12)), palette.Glow, Enum.Material.Ice)
	end
	for _, side in { -1, 1 } do
		for s = 0, 2 do
			attach(character, "UpperTorso", Vector3.new(0.22, 1.0 - s * 0.22, 0.22), CFrame.new(side * (0.95 + s * 0.18), 1.0, 0.12 * s) * CFrame.Angles(0, 0, math.rad(side * (-25 - s * 15))), palette.Glow, Enum.Material.Ice)
		end
	end
	eyes(character, Color3.fromRGB(200, 250, 255), 0.11)
	emitter(character, "UpperTorso", {
		Color = ColorSequence.new(Color3.new(1, 1, 1)),
		Transparency = NumberSequence.new(0.4, 1),
		Size = NumberSequence.new(0.25, 0.05),
		Lifetime = NumberRange.new(0.8, 1.5),
		Speed = NumberRange.new(0.5, 1.5),
		Acceleration = Vector3.new(0, -4, 0),
		Rate = 14,
	})
	glowLight(character, "UpperTorso", palette.Glow, 10, 0.8)
end

builders.Swarm = function(character, palette)
	baseSuit(character, palette, Enum.Material.Metal)
	for _, group in LIMBS do
		paint(character, group, palette.Primary, Enum.Material.DiamondPlate, 0.12)
	end
	armorKit(character, { plate = palette.Secondary, material = Enum.Material.Metal, reflectance = 0.2, trim = palette.Glow, shoulders = 1, belt = DARK })
	helmet(character, palette.Secondary, Enum.Material.Metal, palette.Glow)
	emitter(character, "UpperTorso", {
		Color = ColorSequence.new(Color3.fromRGB(160, 165, 175)),
		Transparency = NumberSequence.new(0.1, 1),
		Size = NumberSequence.new(0.12, 0.04),
		Lifetime = NumberRange.new(0.8, 1.5),
		Speed = NumberRange.new(2, 5),
		SpreadAngle = Vector2.new(180, 180),
		RotSpeed = NumberRange.new(-300, 300),
		Rate = 60,
	})
	glowLight(character, "Head", palette.Glow, 8, 0.9)
end

builders.Echo = function(character, palette)
	baseSuit(character, palette, Enum.Material.Fabric)
	armorKit(character, { plate = palette.Secondary, material = Enum.Material.SmoothPlastic, trim = palette.Glow, shoulders = 0, belt = palette.Secondary })
	helmet(character, palette.Secondary, Enum.Material.SmoothPlastic, palette.Glow)
	-- Speaker discs: shoulders and chest
	for _, spot in { CFrame.new(-1.15, 0.6, 0), CFrame.new(1.15, 0.6, 0) } do
		attach(character, "UpperTorso", Vector3.new(0.3, 1.0, 1.0), spot * CFrame.Angles(0, 0, 0), Color3.fromRGB(30, 30, 36), Enum.Material.DiamondPlate, Enum.PartType.Cylinder)
		local ring = neon(character, "UpperTorso", Vector3.new(0.32, 0.7, 0.7), spot, palette.Glow)
		if ring then
			ring.Shape = Enum.PartType.Cylinder
		end
	end
	for i = 0, 2 do
		local ring = neon(character, "UpperTorso", Vector3.new(0.05, 0.5 + i * 0.3, 0.5 + i * 0.3), CFrame.new(0, 0.25, -0.62 - i * 0.02) * CFrame.Angles(0, math.rad(90), 0), palette.Glow)
		if ring then
			ring.Shape = Enum.PartType.Cylinder
			ring.Transparency = i * 0.25
		end
	end
	glowLight(character, "UpperTorso", palette.Glow, 9, 0.9)
end

builders.Umbra = function(character, palette)
	baseSuit(character, palette, Enum.Material.Fabric)
	armorKit(character, { plate = palette.Secondary, material = Enum.Material.Fabric, trim = palette.Glow, shoulders = 0.8, belt = DARK, chest = false })
	-- Hooded cloak
	attach(character, "Head", Vector3.new(1.45, 1.55, 1.45), CFrame.new(0, 0.15, 0.12), palette.Primary, Enum.Material.Fabric, Enum.PartType.Ball)
	attach(character, "Head", Vector3.new(1.2, 0.9, 0.2), CFrame.new(0, -0.1, -0.62), Color3.fromRGB(4, 4, 6), Enum.Material.SmoothPlastic) -- shadowed face
	cape(character, palette.Primary, Enum.Material.Fabric, 5, 2.3, 6.5, CFrame.new(0, 0.85, 0.55))
	eyes(character, palette.Glow, 0.1)
	emitter(character, "UpperTorso", {
		Color = ColorSequence.new(Color3.fromRGB(20, 10, 35)),
		Transparency = NumberSequence.new(0.35, 1),
		Size = NumberSequence.new(1, 3),
		Lifetime = NumberRange.new(0.7, 1.3),
		Speed = NumberRange.new(0.5, 1.5),
		Rate = 22,
	})
	for _, leg in { "LeftFoot", "RightFoot" } do
		emitter(character, leg, {
			Color = ColorSequence.new(Color3.fromRGB(30, 10, 50)),
			Transparency = NumberSequence.new(0.3, 1),
			Size = NumberSequence.new(0.8, 2),
			Lifetime = NumberRange.new(0.5, 0.9),
			Speed = NumberRange.new(0.3, 1),
			Rate = 10,
		})
	end
	glowLight(character, "Head", palette.Glow, 7, 0.9)
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
