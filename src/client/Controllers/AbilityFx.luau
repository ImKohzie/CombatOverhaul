--!strict
-- Signature visuals for character abilities (all procedural): ground
-- cracks, colossal stomps, smoke clouds, glider blade trails, radiation
-- zones with heat shimmer, light absorption, black holes, gravity rings,
-- ice spikes, area frost, nanite swirls, grey tide, shadow puffs and the
-- Eclipse lighting override.

local Debris = game:GetService("Debris")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local CameraController = require(script.Parent.CameraController)
local EffectsController = require(script.Parent.EffectsController)
local SoundLibrary = require(script.Parent.SoundLibrary)

local player = Players.LocalPlayer

local AbilityFx = {}

local function vec(value: any): Vector3?
	return if typeof(value) == "Vector3" then value else nil
end

local function num(value: any, default: number): number
	return if type(value) == "number" then value else default
end

local function col(value: any, default: Color3): Color3
	return if typeof(value) == "Color3" then value else default
end

local function myDistance(position: Vector3): number
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return (root.Position - position).Magnitude
	end
	return math.huge
end

local function emitterAt(position: Vector3, lifetime: number): (Part, Attachment)
	local anchor = EffectsController.part()
	anchor.Transparency = 1
	anchor.Size = Vector3.one
	anchor.CFrame = CFrame.new(position)
	anchor.Parent = EffectsController.folder()
	local attachment = Instance.new("Attachment")
	attachment.Parent = anchor
	Debris:AddItem(anchor, lifetime)
	return anchor, attachment
end

-- Temporary local colour grade, faded in and out.
local function grade(name: string, props: { [string]: any }, duration: number)
	local existing = Lighting:FindFirstChild(name)
	if existing then
		existing:Destroy()
	end
	local correction = Instance.new("ColorCorrectionEffect")
	correction.Name = name
	correction.Parent = Lighting
	TweenService:Create(correction, TweenInfo.new(0.35), props):Play()
	task.delay(math.max(duration - 0.4, 0), function()
		if correction.Parent then
			TweenService:Create(correction, TweenInfo.new(0.4), { Brightness = 0, Contrast = 0, Saturation = 0, TintColor = Color3.new(1, 1, 1) }):Play()
			Debris:AddItem(correction, 0.45)
		end
	end)
end

--------------------------------------------------------------------------------
local function groundCracks(payload: { [string]: any })
	local position = vec(payload.Position)
	if not position then
		return
	end
	local radius = num(payload.Radius, 20)
	local color = col(payload.Color, Color3.fromRGB(255, 120, 40))
	local count = math.clamp(math.floor(radius / 2), 8, 24)
	for i = 1, count do
		local angle = (i / count) * math.pi * 2 + math.random() * 0.3
		local length = radius * (0.4 + math.random() * 0.6)
		local crack = EffectsController.part()
		crack.Material = Enum.Material.Neon
		crack.Color = color
		crack.Size = Vector3.new(0.35, 0.1, length)
		crack.CFrame = CFrame.new(position + Vector3.new(0, 0.06, 0)) * CFrame.Angles(0, angle, 0) * CFrame.new(0, 0, -length / 2)
		crack.Parent = EffectsController.folder()
		TweenService:Create(crack, TweenInfo.new(3, Enum.EasingStyle.Linear, Enum.EasingDirection.In, 0, false, 2), { Transparency = 1, Color = Color3.fromRGB(30, 25, 20) }):Play()
		Debris:AddItem(crack, 5.1)
	end
end

local function stomp(payload: { [string]: any })
	local position = vec(payload.Position)
	if not position then
		return
	end
	local radius = num(payload.Radius, 14)
	local _, attachment = emitterAt(position, 2)
	local dust = Instance.new("ParticleEmitter")
	dust.Color = ColorSequence.new(Color3.fromRGB(150, 140, 125))
	dust.Transparency = NumberSequence.new(0.3, 1)
	dust.Size = NumberSequence.new(2, 6)
	dust.Lifetime = NumberRange.new(0.8, 1.4)
	dust.Speed = NumberRange.new(radius, radius * 2)
	dust.SpreadAngle = Vector2.new(180, 5)
	dust.EmissionDirection = Enum.NormalId.Top
	dust.Drag = 4
	dust.Rate = 0
	dust.Parent = attachment
	dust:Emit(20)
	SoundLibrary.play("Sound.Hit.Heavy", { Position = position, Volume = 1.2, Pitch = 0.3, MaxDistance = 400 })
	local distance = myDistance(position)
	if distance < radius * 6 then
		CameraController.shake(math.clamp(1 - distance / (radius * 6), 0, 1) * 0.45)
	end
end

local function smokeCloud(payload: { [string]: any })
	local position = vec(payload.Position)
	if not position then
		return
	end
	local radius = num(payload.Radius, 10)
	local duration = num(payload.Duration, 4)
	local _, attachment = emitterAt(position, duration + 2)
	local smoke = Instance.new("ParticleEmitter")
	smoke.Color = ColorSequence.new(col(payload.Color, Color3.fromRGB(20, 20, 24)))
	smoke.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, 0.15), NumberSequenceKeypoint.new(1, 1) })
	smoke.Size = NumberSequence.new(radius * 0.5, radius)
	smoke.Lifetime = NumberRange.new(1.5, 2.5)
	smoke.Speed = NumberRange.new(1, 3)
	smoke.SpreadAngle = Vector2.new(180, 180)
	smoke.Rate = 18
	smoke.Parent = attachment
	local fire = Instance.new("ParticleEmitter")
	fire.Color = ColorSequence.new(Color3.fromRGB(255, 150, 50), Color3.fromRGB(180, 40, 10))
	fire.LightEmission = 1
	fire.Size = NumberSequence.new(1.5, 0)
	fire.Lifetime = NumberRange.new(0.4, 0.8)
	fire.Speed = NumberRange.new(2, 5)
	fire.SpreadAngle = Vector2.new(60, 60)
	fire.EmissionDirection = Enum.NormalId.Top
	fire.Rate = 30
	fire.Parent = attachment
	task.delay(duration, function()
		smoke.Enabled = false
		fire.Enabled = false
	end)
end

local function bladeTrail(payload: { [string]: any })
	local source = payload.Source
	local root = if typeof(source) == "Instance" then source:FindFirstChild("HumanoidRootPart") else nil
	if not root or not root:IsA("BasePart") then
		return
	end
	local duration = num(payload.Duration, 0.6)
	local color = col(payload.Color, Color3.fromRGB(140, 255, 60))
	for side = -1, 1, 2 do
		local a0 = Instance.new("Attachment")
		a0.Position = Vector3.new(side * 6, -2, 0)
		a0.Parent = root
		local a1 = Instance.new("Attachment")
		a1.Position = Vector3.new(side * 3, -2, 0)
		a1.Parent = root
		local trail = Instance.new("Trail")
		trail.Attachment0 = a0
		trail.Attachment1 = a1
		trail.Color = ColorSequence.new(Color3.new(1, 1, 1), color)
		trail.LightEmission = 1
		trail.Lifetime = 0.25
		trail.Parent = root
		Debris:AddItem(trail, duration + 0.3)
		Debris:AddItem(a0, duration + 0.3)
		Debris:AddItem(a1, duration + 0.3)
	end
	SoundLibrary.play("Sound.Whoosh", { Position = root.Position, Volume = 0.6, Pitch = 0.8 })
end

local function radiation(payload: { [string]: any })
	local position = vec(payload.Position)
	if not position then
		return
	end
	local radius = num(payload.Radius, 30)
	local duration = num(payload.Duration, 6)
	local zone = EffectsController.part()
	zone.Shape = Enum.PartType.Cylinder
	zone.Material = Enum.Material.ForceField
	zone.Color = Color3.fromRGB(150, 255, 130)
	zone.Size = Vector3.new(0.5, radius * 2, radius * 2)
	zone.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
	zone.Parent = EffectsController.folder()
	Debris:AddItem(zone, duration)
	local _, attachment = emitterAt(position, duration + 1)
	local motes = Instance.new("ParticleEmitter")
	motes.Color = ColorSequence.new(Color3.fromRGB(190, 255, 170))
	motes.LightEmission = 1
	motes.Size = NumberSequence.new(0.3, 0)
	motes.Lifetime = NumberRange.new(1, 2)
	motes.Speed = NumberRange.new(2, 5)
	motes.SpreadAngle = Vector2.new(180, 20)
	motes.EmissionDirection = Enum.NormalId.Top
	motes.Rate = 40
	motes.Parent = attachment
	task.delay(duration, function()
		motes.Enabled = false
	end)
	-- Heat shimmer approximation (blur + green grade) while inside the zone
	task.spawn(function()
		local blur = Instance.new("BlurEffect")
		blur.Name = "ApexRadiationShimmer"
		blur.Size = 0
		local camera = workspace.CurrentCamera
		blur.Parent = camera
		local elapsed = 0
		while elapsed < duration do
			elapsed += RunService.RenderStepped:Wait()
			local inside = myDistance(position) < radius
			local target = if inside then 3 + math.sin(os.clock() * 8) * 1.2 else 0
			blur.Size += (target - blur.Size) * 0.2
		end
		blur:Destroy()
	end)
	if myDistance(position) < radius * 1.5 then
		grade("ApexRadiationGrade", { TintColor = Color3.fromRGB(220, 255, 210), Saturation = -0.1 }, duration)
	end
end

local function absorb(payload: { [string]: any })
	local position = vec(payload.Position)
	if not position then
		return
	end
	local radius = num(payload.Radius, 90)
	local duration = num(payload.Duration, 1.2)
	local _, attachment = emitterAt(position, duration + 1)
	local inward = Instance.new("ParticleEmitter")
	inward.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(150, 200, 255))
	inward.LightEmission = 1
	inward.Size = NumberSequence.new(0.1, 0.5)
	inward.Lifetime = NumberRange.new(0.6, 0.8)
	inward.Speed = NumberRange.new(-radius * 0.6, -radius * 0.4)
	inward.SpreadAngle = Vector2.new(180, 180)
	inward.Rate = 150
	inward.Parent = attachment
	task.delay(duration, function()
		inward.Enabled = false
	end)
	if myDistance(position) < radius then
		grade("ApexAbsorb", { Brightness = -0.35, Contrast = 0.2, Saturation = -0.4 }, duration + 0.3)
	end
end

local function blackHole(payload: { [string]: any })
	local position = vec(payload.Position)
	if not position then
		return
	end
	local radius = num(payload.Radius, 40)
	local duration = num(payload.Duration, 2.5)
	local huge = payload.Huge == true
	local core = EffectsController.part()
	core.Shape = Enum.PartType.Ball
	core.Material = Enum.Material.SmoothPlastic
	core.Color = Color3.new(0, 0, 0)
	core.Size = Vector3.one
	core.CFrame = CFrame.new(position)
	core.Parent = EffectsController.folder()
	local coreSize = if huge then 16 else 5
	TweenService:Create(core, TweenInfo.new(0.4, Enum.EasingStyle.Back), { Size = Vector3.one * coreSize }):Play()
	local ring = EffectsController.part()
	ring.Shape = Enum.PartType.Cylinder
	ring.Material = Enum.Material.Neon
	ring.Color = Color3.fromRGB(150, 90, 255)
	ring.Transparency = 0.3
	ring.Size = Vector3.new(0.15, coreSize * 2.2, coreSize * 2.2)
	ring.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
	ring.Parent = EffectsController.folder()
	local attachment = Instance.new("Attachment")
	attachment.Parent = core
	local swirl = Instance.new("ParticleEmitter")
	swirl.Color = ColorSequence.new(Color3.fromRGB(170, 110, 255), Color3.fromRGB(20, 0, 40))
	swirl.LightEmission = 0.6
	swirl.Size = NumberSequence.new(0.6, 0)
	swirl.Lifetime = NumberRange.new(0.7, 1)
	swirl.Speed = NumberRange.new(-radius * 0.9, -radius * 0.6)
	swirl.SpreadAngle = Vector2.new(180, 180)
	swirl.Rate = if huge then 220 else 90
	swirl.Parent = attachment
	local spin = RunService.RenderStepped:Connect(function(dt: number)
		ring.CFrame *= CFrame.Angles(dt * 3, 0, 0)
	end)
	task.delay(duration, function()
		spin:Disconnect()
		TweenService:Create(core, TweenInfo.new(0.2), { Size = Vector3.one * 0.1 }):Play()
		ring:Destroy()
		Debris:AddItem(core, 0.25)
	end)
	if huge and myDistance(position) < radius * 1.5 then
		grade("ApexHorizon", { Brightness = -0.15, Saturation = -0.3, TintColor = Color3.fromRGB(225, 210, 255) }, duration)
	end
end

local function gravityRings(payload: { [string]: any })
	local source = payload.Source
	local root = if typeof(source) == "Instance" then source:FindFirstChild("HumanoidRootPart") else nil
	if not root or not root:IsA("BasePart") then
		return
	end
	local duration = num(payload.Duration, 4)
	local color = col(payload.Color, Color3.fromRGB(170, 110, 255))
	local attachment = Instance.new("Attachment")
	attachment.Position = Vector3.new(0, 3, 0)
	attachment.Parent = root
	local rings = Instance.new("ParticleEmitter")
	rings.Color = ColorSequence.new(color)
	rings.LightEmission = 1
	rings.Size = NumberSequence.new(3, 0.5)
	rings.Transparency = NumberSequence.new(0.3, 1)
	rings.Lifetime = NumberRange.new(0.5)
	rings.Speed = NumberRange.new(8)
	rings.EmissionDirection = Enum.NormalId.Bottom
	rings.Rate = 6
	rings.Parent = attachment
	Debris:AddItem(attachment, duration)
end

local function iceSpike(payload: { [string]: any })
	local position = vec(payload.Position)
	if not position then
		return
	end
	local height = num(payload.Height, 7)
	for i = 1, 3 do
		local spike = EffectsController.part()
		-- Optional Color/Material: thorns, coral, crystal... (default ice)
		spike.Material = if typeof(payload.Material) == "EnumItem" then (payload.Material :: any) else Enum.Material.Ice
		spike.Color = if typeof(payload.Color) == "Color3" then payload.Color else Color3.fromRGB(185, 235, 255)
		spike.Transparency = if spike.Material == Enum.Material.Ice then 0.15 else 0
		local h = height * (0.6 + math.random() * 0.5)
		spike.Size = Vector3.new(1.4 + math.random(), h, 1.4 + math.random())
		local tilt = CFrame.Angles(math.rad(math.random(-18, 18)), math.random() * 6, math.rad(math.random(-18, 18)))
		local offset = Vector3.new(math.random() * 3 - 1.5, 0, math.random() * 3 - 1.5)
		local final = CFrame.new(position + offset) * tilt * CFrame.new(0, h / 2 - 0.5, 0)
		spike.CFrame = final * CFrame.new(0, -h, 0)
		spike.Parent = EffectsController.folder()
		TweenService:Create(spike, TweenInfo.new(0.12, Enum.EasingStyle.Back), { CFrame = final }):Play()
		task.delay(3 + i * 0.1, function()
			TweenService:Create(spike, TweenInfo.new(0.6), { Transparency = 1, CFrame = final * CFrame.new(0, -h * 0.5, 0) }):Play()
			Debris:AddItem(spike, 0.65)
		end)
	end
	SoundLibrary.play("Sound.Hit.Block", { Position = position, Volume = 0.5, Pitch = 1.8 })
end

local function frost(payload: { [string]: any })
	local position = vec(payload.Position)
	if not position then
		return
	end
	local radius = num(payload.Radius, 150)
	local duration = num(payload.Duration, 8)
	local sheet = EffectsController.part()
	sheet.Shape = Enum.PartType.Cylinder
	sheet.Material = Enum.Material.Ice
	sheet.Color = Color3.fromRGB(200, 235, 255)
	sheet.Transparency = 0.45
	sheet.Size = Vector3.new(0.2, 4, 4)
	sheet.CFrame = CFrame.new(position - Vector3.new(0, 2.8, 0)) * CFrame.Angles(0, 0, math.rad(90))
	sheet.Parent = EffectsController.folder()
	TweenService:Create(sheet, TweenInfo.new(0.6, Enum.EasingStyle.Quad), { Size = Vector3.new(0.2, radius * 2, radius * 2) }):Play()
	task.delay(duration - 0.8, function()
		TweenService:Create(sheet, TweenInfo.new(0.8), { Transparency = 1 }):Play()
	end)
	Debris:AddItem(sheet, duration + 0.1)
	local _, attachment = emitterAt(position + Vector3.new(0, 20, 0), duration + 2)
	local snow = Instance.new("ParticleEmitter")
	snow.Color = ColorSequence.new(Color3.new(1, 1, 1))
	snow.Size = NumberSequence.new(0.25)
	snow.Lifetime = NumberRange.new(3, 5)
	snow.Speed = NumberRange.new(2, 5)
	snow.SpreadAngle = Vector2.new(180, 180)
	snow.Acceleration = Vector3.new(0, -4, 0)
	snow.Rate = 120
	snow.Parent = attachment
	task.delay(duration, function()
		snow.Enabled = false
	end)
	if myDistance(position) < radius then
		grade("ApexFrost", { TintColor = Color3.fromRGB(215, 235, 255), Saturation = -0.35, Brightness = 0.05 }, duration)
	end
end

local function naniteSwirl(payload: { [string]: any })
	local source = payload.Source
	local root = if typeof(source) == "Instance" then source:FindFirstChild("HumanoidRootPart") else nil
	if not root or not root:IsA("BasePart") then
		return
	end
	local duration = num(payload.Duration, 1.5)
	local radius = num(payload.Radius, 14)
	local attachment = Instance.new("Attachment")
	attachment.Parent = root
	local swarm = Instance.new("ParticleEmitter")
	swarm.Color = ColorSequence.new(Color3.fromRGB(190, 195, 205))
	swarm.Size = NumberSequence.new(0.2, 0.05)
	swarm.Lifetime = NumberRange.new(0.3, 0.5)
	swarm.Speed = NumberRange.new(radius * 1.5, radius * 2)
	swarm.SpreadAngle = Vector2.new(5, 180)
	swarm.RotSpeed = NumberRange.new(360)
	swarm.Rate = 400
	swarm.Parent = attachment
	Debris:AddItem(attachment, duration)
end

local function greyTide(payload: { [string]: any })
	local position = vec(payload.Position)
	if not position then
		return
	end
	local radius = num(payload.Radius, 110)
	local duration = num(payload.Duration, 6)
	local wave = EffectsController.part()
	wave.Shape = Enum.PartType.Cylinder
	wave.Material = Enum.Material.DiamondPlate
	wave.Color = Color3.fromRGB(120, 125, 135)
	wave.Size = Vector3.new(2.5, 4, 4)
	wave.CFrame = CFrame.new(position - Vector3.new(0, 2, 0)) * CFrame.Angles(0, 0, math.rad(90))
	wave.Parent = EffectsController.folder()
	TweenService:Create(wave, TweenInfo.new(duration * 0.5, Enum.EasingStyle.Sine), { Size = Vector3.new(1.2, radius * 2, radius * 2) }):Play()
	task.delay(duration - 0.8, function()
		TweenService:Create(wave, TweenInfo.new(0.8), { Transparency = 1 }):Play()
	end)
	Debris:AddItem(wave, duration + 0.1)
	local _, attachment = emitterAt(position, duration + 1)
	local motes = Instance.new("ParticleEmitter")
	motes.Color = ColorSequence.new(Color3.fromRGB(180, 185, 195))
	motes.Size = NumberSequence.new(0.35, 0.1)
	motes.Lifetime = NumberRange.new(1.5, 2)
	motes.Speed = NumberRange.new(radius * 0.4, radius * 0.6)
	motes.SpreadAngle = Vector2.new(180, 10)
	motes.Rate = 300
	motes.Parent = attachment
	task.delay(duration, function()
		motes.Enabled = false
	end)
end

local function shadowPuff(payload: { [string]: any })
	local position = vec(payload.Position)
	if not position then
		return
	end
	local _, attachment = emitterAt(position, 2)
	local puff = Instance.new("ParticleEmitter")
	puff.Color = ColorSequence.new(Color3.fromRGB(25, 10, 45))
	puff.Transparency = NumberSequence.new(0.1, 1)
	puff.Size = NumberSequence.new(2, 5)
	puff.Lifetime = NumberRange.new(0.5, 0.9)
	puff.Speed = NumberRange.new(4, 10)
	puff.SpreadAngle = Vector2.new(180, 180)
	puff.Rate = 0
	puff.Parent = attachment
	puff:Emit(30)
	SoundLibrary.play("Sound.Whoosh", { Position = position, Volume = 0.6, Pitch = 0.5 })
end

local function eclipse(payload: { [string]: any })
	local position = vec(payload.Position)
	if not position then
		return
	end
	local radius = num(payload.Radius, 200)
	local duration = num(payload.Duration, 8)
	local dome = EffectsController.part()
	dome.Shape = Enum.PartType.Ball
	dome.Material = Enum.Material.ForceField
	dome.Color = Color3.fromRGB(60, 20, 110)
	dome.Size = Vector3.one * 4
	dome.CFrame = CFrame.new(position)
	dome.Parent = EffectsController.folder()
	TweenService:Create(dome, TweenInfo.new(0.6), { Size = Vector3.one * radius * 2 }):Play()
	task.delay(duration - 0.5, function()
		TweenService:Create(dome, TweenInfo.new(0.5), { Transparency = 1 }):Play()
	end)
	Debris:AddItem(dome, duration + 0.1)
	if myDistance(position) < radius then
		grade("ApexEclipse", { Brightness = -0.45, Contrast = 0.25, Saturation = -0.6, TintColor = Color3.fromRGB(190, 170, 255) }, duration)
	end
end

function AbilityFx.init()
	EffectsController.register("GroundCracks", groundCracks)
	EffectsController.register("Stomp", stomp)
	EffectsController.register("SmokeCloud", smokeCloud)
	EffectsController.register("BladeTrail", bladeTrail)
	EffectsController.register("Radiation", radiation)
	EffectsController.register("Absorb", absorb)
	EffectsController.register("BlackHole", blackHole)
	EffectsController.register("GravityRings", gravityRings)
	EffectsController.register("IceSpike", iceSpike)
	EffectsController.register("Frost", frost)
	EffectsController.register("NaniteSwirl", naniteSwirl)
	EffectsController.register("GreyTide", greyTide)
	EffectsController.register("ShadowPuff", shadowPuff)
	EffectsController.register("Eclipse", eclipse)
end

return AbilityFx
