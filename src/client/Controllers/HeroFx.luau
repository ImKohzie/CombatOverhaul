--!strict
-- Visuals for the second wave of heroes (Cinder, Tempest, Magnus, Rebound,
-- Hexa, Thornwild, Glitch, Undertow). Cosmetic only.
--   Vortex     { Position, Radius, Height?, Duration, Color, Material? } tornado / whirlpool
--   Wave       { Position, Direction, Width, Height, Distance, Duration, Color }
--   Rune       { Position, Radius, Duration, Color }
--   PixelBurst { Position, Radius, Color }
--   Stretch    { Source, To, Color } rubber arm shooting out and back

local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local CameraController = require(script.Parent.CameraController)
local EffectsController = require(script.Parent.EffectsController)
local SoundLibrary = require(script.Parent.SoundLibrary)

local HeroFx = {}

local function vec(value: any): Vector3?
	return if typeof(value) == "Vector3" then value else nil
end

local function num(value: any, default: number): number
	return if type(value) == "number" then value else default
end

local function col(value: any, default: Color3): Color3
	return if typeof(value) == "Color3" then value else default
end

local function nearShake(position: Vector3, amount: number)
	local camera = workspace.CurrentCamera
	if camera and (camera.CFrame.Position - position).Magnitude < 90 then
		CameraController.shake(amount)
	end
end

-- Stacked spinning rings that form a funnel (tornado) or a flat swirl
-- (whirlpool, when Height is small).
local function vortex(payload: { [string]: any })
	local maybePosition = vec(payload.Position)
	if not maybePosition then
		return
	end
	local position: Vector3 = maybePosition
	-- Optional Source: the vortex follows that character (Eye of the Storm)
	local source = payload.Source
	local followRoot = if typeof(source) == "Instance" then source:FindFirstChild("HumanoidRootPart") else nil
	local radius = num(payload.Radius, 20)
	local height = num(payload.Height, 40)
	local duration = num(payload.Duration, 3)
	local color = col(payload.Color, Color3.fromRGB(200, 230, 235))
	local material = if typeof(payload.Material) == "EnumItem" then (payload.Material :: any) else Enum.Material.SmoothPlastic
	local layers = if height > 8 then 7 else 3
	local rings: { { part: Part, y: number, r: number, speed: number } } = {}
	for i = 1, layers do
		local t = (i - 1) / math.max(layers - 1, 1)
		local r = if height > 8 then radius * (0.25 + t * 0.9) else radius * (1 - t * 0.55)
		local ring = EffectsController.part()
		ring.Shape = Enum.PartType.Cylinder
		ring.Material = material
		ring.Color = color
		ring.Transparency = 0.55 + t * 0.2
		ring.Size = Vector3.new(0.6, r * 2, r * 2)
		ring.Parent = EffectsController.folder()
		table.insert(rings, { part = ring, y = t * height, r = r, speed = 6 + (1 - t) * 6 })
		-- debris streaks orbiting the funnel
		local streak = EffectsController.part()
		streak.Material = Enum.Material.Neon
		streak.Color = color:Lerp(Color3.new(1, 1, 1), 0.4)
		streak.Size = Vector3.new(0.3, 0.3, r * 0.8)
		streak.Parent = ring
	end
	local elapsed = 0
	local connection: RBXScriptConnection
	connection = RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if followRoot and followRoot:IsA("BasePart") and followRoot.Parent then
			position = followRoot.Position - Vector3.new(0, 3, 0)
		end
		local fade = math.clamp((duration - elapsed) / 0.4, 0, 1)
		for index, entry in rings do
			local angle = elapsed * entry.speed + index
			local sway = Vector3.new(math.sin(elapsed * 2 + index * 0.5), 0, math.cos(elapsed * 1.7 + index * 0.5)) * (entry.y * 0.04)
			entry.part.CFrame = CFrame.new(position + Vector3.new(0, entry.y, 0) + sway) * CFrame.Angles(0, angle, math.rad(90))
			entry.part.Transparency = 1 - (1 - (0.55 + index * 0.03)) * fade
			local streak = entry.part:FindFirstChildOfClass("Part")
			if streak then
				streak.CFrame = CFrame.new(position + Vector3.new(0, entry.y, 0)) * CFrame.Angles(0, -angle * 1.3, 0) * CFrame.new(entry.r * 0.9, 0, 0)
				streak.Transparency = 1 - fade * 0.8
			end
		end
		if elapsed >= duration then
			connection:Disconnect()
			for _, entry in rings do
				entry.part:Destroy()
			end
		end
	end)
	SoundLibrary.play("Sound.Hit.Heavy", { Position = position, Volume = 0.5, Pitch = 0.4 })
end

-- A rolling wall that travels along Direction.
local function wave(payload: { [string]: any })
	local position = vec(payload.Position)
	local direction = vec(payload.Direction)
	if not position or not direction or direction.Magnitude < 1e-3 then
		return
	end
	local flat = Vector3.new(direction.X, 0, direction.Z)
	flat = if flat.Magnitude > 1e-3 then flat.Unit else Vector3.zAxis
	local width = num(payload.Width, 30)
	local height = num(payload.Height, 14)
	local distance = num(payload.Distance, 100)
	local duration = num(payload.Duration, 1.2)
	local color = col(payload.Color, Color3.fromRGB(50, 150, 220))
	local start = CFrame.lookAt(position, position + flat)
	local wall = EffectsController.part()
	wall.Material = Enum.Material.Glass
	wall.Color = color
	wall.Transparency = 0.25
	wall.Reflectance = 0.2
	wall.Size = Vector3.new(width, height, 6)
	wall.CFrame = start * CFrame.new(0, height / 2 - 2, 0)
	wall.Parent = EffectsController.folder()
	local crest = EffectsController.part()
	crest.Material = Enum.Material.Snow
	crest.Color = Color3.fromRGB(235, 245, 250)
	crest.Size = Vector3.new(width + 2, 2, 7)
	crest.CFrame = wall.CFrame * CFrame.new(0, height / 2, -1)
	crest.Parent = wall
	local spray = Instance.new("ParticleEmitter")
	spray.Color = ColorSequence.new(Color3.fromRGB(230, 245, 255))
	spray.Size = NumberSequence.new(1.5, 4)
	spray.Transparency = NumberSequence.new(0.3, 1)
	spray.Lifetime = NumberRange.new(0.5, 0.9)
	spray.Speed = NumberRange.new(10, 22)
	spray.SpreadAngle = Vector2.new(40, 40)
	spray.Rate = 120
	spray.EmissionDirection = Enum.NormalId.Top
	spray.Parent = crest
	local finish = start * CFrame.new(0, height / 2 - 2, -distance)
	TweenService:Create(wall, TweenInfo.new(duration, Enum.EasingStyle.Linear), { CFrame = finish }):Play()
	local elapsed = 0
	local connection: RBXScriptConnection
	connection = RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		crest.CFrame = wall.CFrame * CFrame.new(0, height / 2, -1)
		if elapsed >= duration then
			connection:Disconnect()
			spray.Enabled = false
			TweenService:Create(wall, TweenInfo.new(0.4), { Transparency = 1, Size = Vector3.new(width, 0.5, 6) }):Play()
			TweenService:Create(crest, TweenInfo.new(0.4), { Transparency = 1 }):Play()
			Debris:AddItem(wall, 1)
		end
	end)
	nearShake(position, 0.3)
	SoundLibrary.play("Sound.Hit.Heavy", { Position = position, Volume = 0.8, Pitch = 0.35 })
end

-- Glowing rune circle on the ground.
local function rune(payload: { [string]: any })
	local position = vec(payload.Position)
	if not position then
		return
	end
	local radius = num(payload.Radius, 20)
	local duration = num(payload.Duration, 2)
	local color = col(payload.Color, Color3.fromRGB(200, 120, 255))
	local holder: { Part } = {}
	for i, r in { radius, radius * 0.72, radius * 0.4 } do
		local ring = EffectsController.part()
		ring.Shape = Enum.PartType.Cylinder
		ring.Material = Enum.Material.Neon
		ring.Color = color
		ring.Transparency = 0.35 + i * 0.1
		ring.Size = Vector3.new(0.15, r * 2, r * 2)
		ring.CFrame = CFrame.new(position + Vector3.new(0, 0.1 * i, 0)) * CFrame.Angles(0, 0, math.rad(90))
		ring.Parent = EffectsController.folder()
		table.insert(holder, ring)
	end
	-- spokes
	for i = 1, 6 do
		local angle = i * math.pi / 3
		local spoke = EffectsController.part()
		spoke.Material = Enum.Material.Neon
		spoke.Color = color
		spoke.Size = Vector3.new(0.25, 0.1, radius * 1.4)
		spoke.CFrame = CFrame.new(position + Vector3.new(0, 0.35, 0)) * CFrame.Angles(0, angle, 0)
		spoke.Parent = EffectsController.folder()
		table.insert(holder, spoke)
	end
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = math.min(radius * 1.5, 60)
	light.Brightness = 2
	light.Parent = holder[1]
	local elapsed = 0
	local connection: RBXScriptConnection
	connection = RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		for i, part in holder do
			part.CFrame = CFrame.new(position) * CFrame.Angles(0, dt * (if i % 2 == 0 then 0.8 else -0.6), 0) * (CFrame.new(-position) * part.CFrame)
		end
		if elapsed >= duration then
			connection:Disconnect()
			for _, part in holder do
				TweenService:Create(part, TweenInfo.new(0.3), { Transparency = 1 }):Play()
				Debris:AddItem(part, 0.35)
			end
		end
	end)
end

-- Burst of glitchy cubes that snap around then vanish.
local function pixelBurst(payload: { [string]: any })
	local position = vec(payload.Position)
	if not position then
		return
	end
	local radius = num(payload.Radius, 6)
	local color = col(payload.Color, Color3.fromRGB(255, 40, 200))
	for i = 1, 18 do
		local cube = EffectsController.part()
		cube.Material = Enum.Material.Neon
		cube.Color = if i % 3 == 0 then Color3.fromRGB(0, 255, 170) else color
		local size = 0.4 + math.random() * 1.2
		cube.Size = Vector3.new(size, size, size)
		local offset = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * radius * 2
		cube.CFrame = CFrame.new(position + offset * 0.3)
		cube.Parent = EffectsController.folder()
		-- stepped (not smooth) motion reads as "glitch"
		task.delay(0.05, function()
			cube.CFrame = CFrame.new(position + offset)
		end)
		task.delay(0.12 + math.random() * 0.2, function()
			cube.CFrame = CFrame.new(position + offset * 1.3 + Vector3.new(0, 1, 0))
			cube.Transparency = 0.5
		end)
		Debris:AddItem(cube, 0.45 + math.random() * 0.2)
	end
	nearShake(position, 0.12)
end

-- Rubber arm: a stretched limb shoots from the source to the target and snaps back.
local function stretch(payload: { [string]: any })
	local source = payload.Source
	local target = vec(payload.To)
	if typeof(source) ~= "Instance" or not target then
		return
	end
	local hand = source:FindFirstChild("RightHand") or source:FindFirstChild("HumanoidRootPart")
	if not hand or not hand:IsA("BasePart") then
		return
	end
	local color = col(payload.Color, Color3.fromRGB(255, 200, 40))
	local arm = EffectsController.part()
	arm.Material = Enum.Material.SmoothPlastic
	arm.Color = color
	arm.Parent = EffectsController.folder()
	local fist = EffectsController.part()
	fist.Shape = Enum.PartType.Ball
	fist.Material = Enum.Material.SmoothPlastic
	fist.Color = color:Lerp(Color3.new(1, 1, 1), 0.2)
	fist.Size = Vector3.new(2.2, 2.2, 2.2)
	fist.Parent = EffectsController.folder()
	local elapsed = 0
	local total = 0.32
	local connection: RBXScriptConnection
	connection = RunService.RenderStepped:Connect(function(dt)
		elapsed += dt
		local from = hand.Position
		local t = elapsed / total
		local reach = if t < 0.45 then t / 0.45 else math.max(0, 1 - (t - 0.45) / 0.55)
		local tip = from:Lerp(target, reach)
		local length = math.max((tip - from).Magnitude, 0.1)
		arm.Size = Vector3.new(0.7, 0.7, length)
		arm.CFrame = CFrame.lookAt(from:Lerp(tip, 0.5), tip)
		fist.CFrame = CFrame.new(tip)
		if elapsed >= total then
			connection:Disconnect()
			arm:Destroy()
			fist:Destroy()
		end
	end)
end

function HeroFx.init()
	EffectsController.register("Vortex", vortex)
	EffectsController.register("Wave", wave)
	EffectsController.register("Rune", rune)
	EffectsController.register("PixelBurst", pixelBurst)
	EffectsController.register("Stretch", stretch)
end

return HeroFx
