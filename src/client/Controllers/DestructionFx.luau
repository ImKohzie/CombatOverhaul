--!strict
-- "Breaking at the smallest level": client-only micro-debris for every
-- fractured chunk (glass shards, concrete grit, brick bits, wood splinters,
-- steel sparks), dust clouds, layered break sounds (thump + crunch + debris
-- tail) and camera shake. Micro-debris parts are pooled and never collide
-- with characters.

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Pool = require(ReplicatedStorage:WaitForChild("ApexCity").Util.Pool)

local CameraController = require(script.Parent.CameraController)
local EffectsController = require(script.Parent.EffectsController)
local SoundLibrary = require(script.Parent.SoundLibrary)

local MAX_ACTIVE_BITS = 260

local DestructionFx = {}

local active = 0

local bitPool = Pool.new(function(): Part
	local bit = Instance.new("Part")
	bit.Name = "MicroDebris"
	bit.CanQuery = false
	bit.CanTouch = false
	bit.CastShadow = false
	bit.CollisionGroup = "ApexFx"
	bit.TopSurface = Enum.SurfaceType.Smooth
	bit.BottomSurface = Enum.SurfaceType.Smooth
	return bit
end, function(bit: Part)
	bit.Parent = nil
	bit.Anchored = true
end, 300)

local function distanceToCamera(position: Vector3): number
	local camera = workspace.CurrentCamera
	return if camera then (camera.CFrame.Position - position).Magnitude else 0
end

local function spawnBits(origin: CFrame, size: Vector3, count: number, bitSize: NumberRange, color: Color3, material: Enum.Material, transparency: number, impact: Vector3?, speed: number, flat: boolean?)
	for _ = 1, count do
		if active >= MAX_ACTIVE_BITS then
			return
		end
		active += 1
		local bit = bitPool:acquire()
		local s = bitSize.Min + math.random() * (bitSize.Max - bitSize.Min)
		bit.Size = if flat then Vector3.new(s, s * 0.08 + 0.05, s * 0.7) else Vector3.new(s, s * (0.6 + math.random() * 0.6), s)
		bit.Color = color
		bit.Material = material
		bit.Transparency = transparency
		bit.CFrame = origin * CFrame.new((math.random() - 0.5) * size.X, (math.random() - 0.5) * size.Y, (math.random() - 0.5) * size.Z) * CFrame.Angles(math.random() * 6, math.random() * 6, math.random() * 6)
		bit.Anchored = false
		bit.CanCollide = true
		bit.Parent = EffectsController.folder()
		local away = if impact then bit.Position - impact else Vector3.new(math.random() - 0.5, 0.3, math.random() - 0.5)
		local dir = if away.Magnitude > 1e-3 then away.Unit else Vector3.yAxis
		bit.AssemblyLinearVelocity = dir * speed * (0.4 + math.random() * 0.8) + Vector3.new(0, speed * 0.25, 0)
		bit.AssemblyAngularVelocity = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 20
		task.delay(2.5 + math.random() * 2, function()
			active -= 1
			bitPool:release(bit)
		end)
	end
end

local function dust(position: Vector3, size: number, color: Color3, amount: number)
	local anchor = EffectsController.part()
	anchor.Transparency = 1
	anchor.Size = Vector3.one
	anchor.CFrame = CFrame.new(position)
	anchor.Parent = EffectsController.folder()
	local cloud = Instance.new("ParticleEmitter")
	cloud.Color = ColorSequence.new(color:Lerp(Color3.fromRGB(200, 196, 188), 0.5))
	cloud.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) })
	cloud.Size = NumberSequence.new(size * 0.4, size * 1.3)
	cloud.Lifetime = NumberRange.new(1.4, 2.6)
	cloud.Speed = NumberRange.new(size * 0.4, size * 1.2)
	cloud.SpreadAngle = Vector2.new(180, 180)
	cloud.Drag = 3
	cloud.Acceleration = Vector3.new(0, -2, 0)
	cloud.Rate = 0
	cloud.Parent = anchor
	cloud:Emit(amount)
	Debris:AddItem(anchor, 3)
end

local function sparks(position: Vector3, amount: number)
	local anchor = EffectsController.part()
	anchor.Transparency = 1
	anchor.Size = Vector3.one
	anchor.CFrame = CFrame.new(position)
	anchor.Parent = EffectsController.folder()
	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(Color3.fromRGB(255, 230, 150), Color3.fromRGB(255, 120, 30))
	emitter.LightEmission = 1
	emitter.Size = NumberSequence.new(0.2, 0)
	emitter.Lifetime = NumberRange.new(0.3, 0.7)
	emitter.Speed = NumberRange.new(20, 45)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Acceleration = Vector3.new(0, -60, 0)
	emitter.Rate = 0
	emitter.Parent = anchor
	emitter:Emit(amount)
	Debris:AddItem(anchor, 1)
end

local function onFracture(payload: { [string]: any })
	local position = payload.Position
	local size = payload.Size
	local cframe = payload.CFrame
	if typeof(position) ~= "Vector3" or typeof(size) ~= "Vector3" or typeof(cframe) ~= "CFrame" then
		return
	end
	local distance = distanceToCamera(position)
	if distance > 500 then
		return
	end
	local detail = math.clamp(1 - distance / 500, 0.25, 1)
	local kind = if type(payload.Kind) == "string" then payload.Kind else "Concrete"
	local color = if typeof(payload.Color) == "Color3" then payload.Color else Color3.fromRGB(150, 150, 150)
	local impact = if typeof(payload.Impact) == "Vector3" then payload.Impact else nil
	local force = if type(payload.Force) == "number" then payload.Force else 500
	local speed = math.clamp(force / 50, 10, 70)
	local volumeScale = math.clamp(size.Magnitude / 20, 0.5, 2.5)

	if kind == "Glass" then
		spawnBits(cframe, size, math.floor(24 * detail * volumeScale), NumberRange.new(0.3, 1.4), color:Lerp(Color3.fromRGB(200, 230, 240), 0.5), Enum.Material.Glass, 0.35, impact, speed, true)
		SoundLibrary.play("Sound.Glass.Shatter", { Position = position, Volume = 0.8, Pitch = 2.4 + math.random() * 0.4 })
	elseif kind == "Wood" then
		spawnBits(cframe, size, math.floor(14 * detail * volumeScale), NumberRange.new(0.2, 1.4), color, Enum.Material.Wood, 0, impact, speed, false)
		dust(position, 4 * volumeScale, Color3.fromRGB(150, 120, 90), math.floor(8 * detail))
		SoundLibrary.play("Sound.Crumble", { Position = position, Volume = 0.8, Pitch = 1.1 })
	elseif kind == "Steel" then
		spawnBits(cframe, size, math.floor(6 * detail * volumeScale), NumberRange.new(0.4, 1.2), color, Enum.Material.Metal, 0, impact, speed, true)
		sparks(position, math.floor(30 * detail))
		SoundLibrary.play("Sound.Metal.Clang", { Position = position, Volume = 1, Pitch = 0.6 })
	else -- Concrete / Brick: grit + dust
		local material = if kind == "Brick" then Enum.Material.Brick else Enum.Material.Concrete
		spawnBits(cframe, size, math.floor(18 * detail * volumeScale), NumberRange.new(0.25, 1.1), color, material, 0, impact, speed, false)
		dust(position, 6 * volumeScale, color, math.floor(16 * detail * volumeScale))
		-- thump + crunch + debris tail
		SoundLibrary.play("Sound.Crumble", { Position = position, Volume = 1.1, Pitch = 0.45 })
		SoundLibrary.play("Sound.Crumble", { Position = position, Volume = 0.7, Pitch = 0.9 })
		task.delay(0.25, function()
			SoundLibrary.play("Sound.Crumble", { Position = position, Volume = 0.35, Pitch = 1.6 })
		end)
	end
	if distance < 80 then
		CameraController.shake(math.clamp((1 - distance / 80) * 0.18 * volumeScale, 0, 0.35))
	end
end

local function onChip(payload: { [string]: any })
	local position = payload.Position
	if typeof(position) ~= "Vector3" or distanceToCamera(position) > 200 then
		return
	end
	local color = if typeof(payload.Color) == "Color3" then payload.Color else Color3.fromRGB(150, 150, 150)
	local kind = payload.Kind
	if kind == "Steel" then
		sparks(position, 8)
	else
		spawnBits(CFrame.new(position), Vector3.one, 4, NumberRange.new(0.2, 0.5), color, Enum.Material.Concrete, 0, nil, 12, false)
		dust(position, 2, color, 3)
	end
end

local function onCollapse(payload: { [string]: any })
	local position = payload.Position
	if typeof(position) ~= "Vector3" then
		return
	end
	local size = if type(payload.Size) == "number" then payload.Size else 5
	local scale = math.clamp(size / 10, 0.5, 4)
	dust(position, 10 * scale, Color3.fromRGB(170, 164, 150), math.floor(20 * scale))
	SoundLibrary.play("Sound.Collapse", { Position = position, Volume = 1.5, Pitch = 0.3, MaxDistance = 700 })
	local distance = distanceToCamera(position)
	if distance < 300 then
		CameraController.shake(math.clamp((1 - distance / 300) * 0.25 * scale, 0, 0.6))
	end
end

function DestructionFx.init()
	EffectsController.register("Fracture", onFracture)
	EffectsController.register("Chip", onChip)
	EffectsController.register("Collapse", onCollapse)
end

return DestructionFx
