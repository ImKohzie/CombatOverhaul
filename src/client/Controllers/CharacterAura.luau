--!strict
-- Animated signature auras for every character on screen (client-side, so
-- they cost no network traffic). Each character id gets a small rig with
-- update(dt) / destroy(). Only characters near the camera are animated.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local CharacterRegistry = require(ReplicatedStorage:WaitForChild("ApexCity").CharacterRegistry)

local EffectsController = require(script.Parent.EffectsController)

local ACTIVE_RANGE = 260

type Rig = { update: (dt: number) -> (), destroy: () -> () }

local CharacterAura = {}

local rigs: { [Model]: { id: string, rig: Rig } } = {}

local function limb(character: Model, name: string): BasePart?
	local p = character:FindFirstChild(name)
	return if p and p:IsA("BasePart") then p else nil
end

local function fxPart(size: Vector3, color: Color3, material: Enum.Material, shape: Enum.PartType?): Part
	local p = EffectsController.part()
	p.Size = size
	p.Color = color
	p.Material = material
	if shape then
		p.Shape = shape
	end
	p.Parent = EffectsController.folder()
	return p
end

local function glowParts(character: Model): { BasePart }
	local list: { BasePart } = {}
	for _, child in character:GetChildren() do
		if (child.Name == "ApexGlow" or child.Name == "ApexCore") and child:IsA("BasePart") then
			table.insert(list, child)
		end
	end
	return list
end

-- Parts orbiting a body part
local function orbiters(character: Model, count: number, radius: number, height: number, speed: number, make: (i: number) -> Part, wobble: number?): Rig
	local parts: { Part } = {}
	for i = 1, count do
		table.insert(parts, make(i))
	end
	local t = math.random() * 10
	return {
		update = function(dt: number)
			t += dt
			local torso = limb(character, "UpperTorso") or limb(character, "HumanoidRootPart")
			if not torso then
				return
			end
			local scale = character:GetScale()
			for i, p in parts do
				local angle = t * speed + (i / count) * math.pi * 2
				local bob = math.sin(t * 2 + i) * (wobble or 0.3)
				local offset = Vector3.new(math.cos(angle) * radius, height + bob, math.sin(angle) * radius) * scale
				p.CFrame = CFrame.new(torso.Position + offset) * CFrame.Angles(t * 1.3 + i, t * 0.7, i)
			end
		end,
		destroy = function()
			for _, p in parts do
				p:Destroy()
			end
		end,
	}
end

--------------------------------------------------------------------------------
-- Per-character rigs
--------------------------------------------------------------------------------
local builders: { [string]: (Model) -> Rig } = {}

-- Voltline: crackling lightning arcs between limbs, afterimages at speed
builders.Voltline = function(character)
	local names = { "Head", "UpperTorso", "LeftHand", "RightHand", "LeftFoot", "RightFoot", "LeftLowerArm", "RightLowerLeg", "LowerTorso" }
	local attachments: { Attachment } = {}
	for _, name in names do
		local p = limb(character, name)
		if p then
			local a = Instance.new("Attachment")
			a.Name = "ApexArc"
			a.Parent = p
			table.insert(attachments, a)
		end
	end
	local arcs: { Beam } = {}
	for i = 1, 5 do
		local beam = Instance.new("Beam")
		beam.LightEmission = 1
		beam.LightInfluence = 0
		beam.FaceCamera = true
		beam.Segments = 8
		beam.Width0 = 0.14
		beam.Width1 = 0.05
		beam.Color = ColorSequence.new(Color3.fromRGB(255, 250, 190), Color3.fromRGB(255, 200, 40))
		beam.Enabled = false
		beam.Parent = attachments[1] or character
		arcs[i] = beam
	end
	local nextShuffle = 0
	local nextGhost = 0
	return {
		update = function(dt: number)
			local now = os.clock()
			local tier = character:GetAttribute("ApexMomentumTier")
			local level = if type(tier) == "number" then tier else 1
			if character:GetAttribute("ApexPhasing") == true then
				level = 4
			end
			if now >= nextShuffle and #attachments >= 2 then
				nextShuffle = now + 0.05 + math.random() * 0.06
				for i, beam in arcs do
					local active = i <= level + 1 and math.random() < 0.75
					beam.Enabled = active
					if active then
						local a = attachments[math.random(1, #attachments)]
						local b = attachments[math.random(1, #attachments)]
						if a ~= b then
							beam.Attachment0 = a
							beam.Attachment1 = b
							beam.CurveSize0 = math.random(-3, 3)
							beam.CurveSize1 = math.random(-3, 3)
							beam.Width0 = 0.08 + level * 0.04
						else
							beam.Enabled = false
						end
					end
				end
			end
			-- Afterimages when moving fast
			local root = limb(character, "HumanoidRootPart")
			if root and level >= 3 and now >= nextGhost and root.AssemblyLinearVelocity.Magnitude > 50 then
				nextGhost = now + (if level >= 4 then 0.06 else 0.1)
				EffectsController.play("Afterimage", {
					Source = character,
					From = root.Position,
					To = root.Position,
					Color = if level >= 4 then Color3.fromRGB(255, 70, 40) else Color3.fromRGB(255, 220, 60),
				})
			end
		end,
		destroy = function()
			for _, a in attachments do
				a:Destroy()
			end
		end,
	}
end

-- Graven: orbiting gravity stones
builders.Graven = function(character)
	return orbiters(character, 6, 2.6, 0.6, 1.4, function()
		local stone = fxPart(Vector3.new(0.5, 0.45, 0.55), Color3.fromRGB(60, 55, 70), Enum.Material.Basalt)
		local glow = Instance.new("PointLight")
		glow.Color = Color3.fromRGB(170, 110, 255)
		glow.Range = 4
		glow.Brightness = 1
		glow.Parent = stone
		return stone
	end, 0.5)
end

-- Rime: slow circling ice shards
builders.Rime = function(character)
	return orbiters(character, 4, 2.2, 1.4, 0.9, function()
		local shard = fxPart(Vector3.new(0.3, 1, 0.3), Color3.fromRGB(190, 240, 255), Enum.Material.Ice)
		shard.Transparency = 0.15
		return shard
	end, 0.4)
end

-- Swarm: a jittery cloud of nanite cubes
builders.Swarm = function(character)
	local inner = orbiters(character, 10, 1.9, 0.2, 3.2, function()
		return fxPart(Vector3.new(0.18, 0.18, 0.18), Color3.fromRGB(170, 175, 185), Enum.Material.Metal)
	end, 1.2)
	return inner
end

-- Argent: cosmic sparks orbiting fast
builders.Argent = function(character)
	return orbiters(character, 3, 1.8, 0.8, 4, function()
		local spark = fxPart(Vector3.new(0.25, 0.25, 0.25), Color3.fromRGB(200, 230, 255), Enum.Material.Neon, Enum.PartType.Ball)
		local trail0 = Instance.new("Attachment")
		trail0.Position = Vector3.new(0, 0.1, 0)
		trail0.Parent = spark
		local trail1 = Instance.new("Attachment")
		trail1.Position = Vector3.new(0, -0.1, 0)
		trail1.Parent = spark
		local trail = Instance.new("Trail")
		trail.Attachment0 = trail0
		trail.Attachment1 = trail1
		trail.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(140, 200, 255))
		trail.LightEmission = 1
		trail.Lifetime = 0.35
		trail.FaceCamera = true
		trail.WidthScale = NumberSequence.new(1, 0)
		trail.Parent = spark
		return spark
	end, 0.8)
end

-- Echo: sound-wave rings pulsing from the chest
builders.Echo = function(character)
	local nextPulse = 0
	return {
		update = function(_dt: number)
			local now = os.clock()
			if now < nextPulse then
				return
			end
			nextPulse = now + 1.1
			local torso = limb(character, "UpperTorso")
			if not torso then
				return
			end
			local ring = fxPart(Vector3.new(0.05, 1, 1), Color3.fromRGB(255, 90, 210), Enum.Material.Neon, Enum.PartType.Cylinder)
			ring.Transparency = 0.3
			ring.CFrame = torso.CFrame * CFrame.new(0, 0.25, -0.7) * CFrame.Angles(0, math.rad(90), 0)
			TweenService:Create(ring, TweenInfo.new(0.9, Enum.EasingStyle.Quad), {
				Size = Vector3.new(0.02, 5, 5),
				Transparency = 1,
				CFrame = ring.CFrame * CFrame.new(-2, 0, 0),
			}):Play()
			task.delay(0.95, function()
				ring:Destroy()
			end)
		end,
		destroy = function() end,
	}
end

-- Pulsing glow (Bastion molten seams, Old Guard reactor, Rampage rage veins)
local function pulse(character: Model, low: Color3, high: Color3, speed: number, rageDriven: boolean?): Rig
	local parts = glowParts(character)
	local t = math.random() * 5
	local light: PointLight? = nil
	local torso = limb(character, "UpperTorso")
	if torso then
		light = torso:FindFirstChild("ApexAuraLight") :: PointLight?
	end
	return {
		update = function(dt: number)
			t += dt
			local amount = (math.sin(t * speed) + 1) / 2
			if rageDriven then
				local rage = character:GetAttribute("ApexRage")
				local r = if type(rage) == "number" then rage / 100 else 0
				amount = math.clamp(amount * 0.4 + r * 0.8, 0, 1)
			end
			local color = low:Lerp(high, amount)
			for _, p in parts do
				if p.Parent then
					p.Color = color
				end
			end
			if light then
				light.Brightness = 0.6 + amount * 1.4
			end
		end,
		destroy = function() end,
	}
end

builders.Bastion = function(character)
	return pulse(character, Color3.fromRGB(255, 90, 20), Color3.fromRGB(255, 210, 90), 2.2)
end

builders.OldGuard = function(character)
	return pulse(character, Color3.fromRGB(60, 200, 90), Color3.fromRGB(210, 255, 200), 3)
end

builders.Rampage = function(character)
	return pulse(character, Color3.fromRGB(60, 160, 40), Color3.fromRGB(190, 255, 110), 4, true)
end

-- Umbra: shadow tendrils curling from the body to the ground
builders.Umbra = function(character)
	local root = limb(character, "HumanoidRootPart")
	local anchors: { Attachment } = {}
	local beams: { Beam } = {}
	local ground = fxPart(Vector3.one, Color3.new(0, 0, 0), Enum.Material.SmoothPlastic)
	ground.Transparency = 1
	if root then
		for i = 1, 3 do
			local top = Instance.new("Attachment")
			top.Position = Vector3.new(math.cos(i * 2.1) * 0.6, 0.5, math.sin(i * 2.1) * 0.6)
			top.Parent = root
			local bottom = Instance.new("Attachment")
			bottom.Parent = ground
			local beam = Instance.new("Beam")
			beam.Attachment0 = top
			beam.Attachment1 = bottom
			beam.Color = ColorSequence.new(Color3.fromRGB(40, 10, 70), Color3.fromRGB(10, 0, 20))
			beam.Transparency = NumberSequence.new(0.2, 0.9)
			beam.Width0 = 0.4
			beam.Width1 = 0.05
			beam.Segments = 10
			beam.FaceCamera = true
			beam.LightInfluence = 1
			beam.Parent = top
			table.insert(anchors, top)
			table.insert(anchors, bottom)
			table.insert(beams, beam)
		end
	end
	local t = 0
	return {
		update = function(dt: number)
			t += dt
			if not root then
				return
			end
			ground.CFrame = CFrame.new(root.Position - Vector3.new(0, 3, 0))
			for i, beam in beams do
				local bottom = beam.Attachment1
				if bottom then
					bottom.Position = Vector3.new(math.cos(t + i * 2.1) * 2.2, 0, math.sin(t + i * 2.1) * 2.2)
				end
				beam.CurveSize0 = math.sin(t * 2 + i) * 2
				beam.CurveSize1 = math.cos(t * 1.7 + i) * 2
				beam.Enabled = character:GetAttribute("ApexInvisible") ~= true
			end
		end,
		destroy = function()
			for _, a in anchors do
				a:Destroy()
			end
			ground:Destroy()
		end,
	}
end

-- Sovereign: vapour contrails from the hands and feet at speed
builders.Sovereign = function(character)
	local trails: { Trail } = {}
	local attachments: { Attachment } = {}
	for _, name in { "LeftHand", "RightHand", "LeftFoot", "RightFoot" } do
		local p = limb(character, name)
		if p then
			local a0 = Instance.new("Attachment")
			a0.Position = Vector3.new(0.15, 0, 0)
			a0.Parent = p
			local a1 = Instance.new("Attachment")
			a1.Position = Vector3.new(-0.15, 0, 0)
			a1.Parent = p
			local trail = Instance.new("Trail")
			trail.Attachment0 = a0
			trail.Attachment1 = a1
			trail.Color = ColorSequence.new(Color3.new(1, 1, 1))
			trail.Transparency = NumberSequence.new(0.4, 1)
			trail.Lifetime = 0.8
			trail.LightEmission = 0.4
			trail.WidthScale = NumberSequence.new(1, 3)
			trail.Enabled = false
			trail.Parent = p
			table.insert(trails, trail)
			table.insert(attachments, a0)
			table.insert(attachments, a1)
		end
	end
	return {
		update = function(_dt: number)
			local root = limb(character, "HumanoidRootPart")
			local fast = root ~= nil and character:GetAttribute("ApexFlying") == true and root.AssemblyLinearVelocity.Magnitude > 90
			for _, trail in trails do
				trail.Enabled = fast
			end
		end,
		destroy = function()
			for _, a in attachments do
				a:Destroy()
			end
			for _, trail in trails do
				trail:Destroy()
			end
		end,
	}
end

--------------------------------------------------------------------------------
-- Tracking
--------------------------------------------------------------------------------
local function characters(): { Model }
	local list: { Model } = {}
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(list, player.Character)
		end
	end
	local npcs = workspace:FindFirstChild("ApexNPCs")
	if npcs then
		for _, npc in npcs:GetChildren() do
			if npc:IsA("Model") and npc:GetAttribute("ApexClone") == true then
				table.insert(list, npc)
			end
		end
	end
	return list
end

local function step(dt: number)
	local camera = workspace.CurrentCamera
	local cameraPosition = if camera then camera.CFrame.Position else Vector3.zero
	local seen: { [Model]: boolean } = {}
	for _, character in characters() do
		local id = character:GetAttribute("ApexCharacter")
		local root = character:FindFirstChild("HumanoidRootPart")
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if type(id) ~= "string" or not root or not root:IsA("BasePart") or not humanoid or humanoid.Health <= 0 then
			continue
		end
		if (root.Position - cameraPosition).Magnitude > ACTIVE_RANGE then
			continue
		end
		seen[character] = true
		local entry: { id: string, rig: Rig }? = rigs[character]
		if entry and entry.id ~= id then
			entry.rig.destroy()
			rigs[character] = nil
			entry = nil
		end
		if not entry and builders[id] and CharacterRegistry.get(id) and character:FindFirstChild("ApexCostume") then
			local ok, rig = pcall(builders[id], character)
			if ok then
				entry = { id = id, rig = rig }
				rigs[character] = entry
			end
		end
		if entry then
			local ok = pcall(entry.rig.update, dt)
			if not ok then
				entry.rig.destroy()
				rigs[character] = nil
			end
		end
	end
	for character, entry in rigs do
		if not seen[character] then
			pcall(entry.rig.destroy)
			rigs[character] = nil
		end
	end
end

function CharacterAura.init()
	RunService.RenderStepped:Connect(step)
end

return CharacterAura
