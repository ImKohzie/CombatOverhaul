--!strict
-- Client visuals for server-simulated projectiles (mirrors the server's
-- kinematics so they line up), explosions and cone shockwaves.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local CameraController = require(script.Parent.CameraController)
local EffectsController = require(script.Parent.EffectsController)
local SoundLibrary = require(script.Parent.SoundLibrary)

local player = Players.LocalPlayer

local ProjectileFx = {}

type Flying = {
	model: BasePart,
	velocity: Vector3,
	gravity: number,
	homing: Model?,
	homingStrength: number,
	expires: number,
	spin: Vector3,
}

local flying: { [number]: Flying } = {}

local function trail(part: BasePart, color: Color3, width: number, lifetime: number)
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, width / 2, 0)
	a0.Parent = part
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -width / 2, 0)
	a1.Parent = part
	local t = Instance.new("Trail")
	t.Attachment0 = a0
	t.Attachment1 = a1
	t.Color = ColorSequence.new(Color3.new(1, 1, 1), color)
	t.LightEmission = 1
	t.Lifetime = lifetime
	t.Transparency = NumberSequence.new(0.1, 1)
	t.FaceCamera = true
	t.Parent = part
end

local function smoke(part: BasePart, color: Color3, rate: number)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(color)
	emitter.Transparency = NumberSequence.new(0.4, 1)
	emitter.Size = NumberSequence.new(0.6, 2.2)
	emitter.Lifetime = NumberRange.new(0.5, 0.9)
	emitter.Speed = NumberRange.new(0.5, 1.5)
	emitter.Rate = rate
	emitter.Parent = part
end

-- Build the visual for a projectile kind.
local function build(kind: string, color: Color3, width: number): (BasePart, Vector3)
	local part = EffectsController.part()
	local spin = Vector3.zero
	if kind == "Bolt" then
		part.Material = Enum.Material.Neon
		part.Color = color
		part.Size = Vector3.new(width, width, width * 5)
		trail(part, color, width * 1.5, 0.25)
		local light = Instance.new("PointLight")
		light.Color = color
		light.Range = 14
		light.Brightness = 3
		light.Parent = part
	elseif kind == "Bomb" then
		part.Shape = Enum.PartType.Ball
		part.Material = Enum.Material.Metal
		part.Color = Color3.fromRGB(20, 20, 22)
		part.Size = Vector3.new(1.1, 1.1, 1.1)
		local fuse = Instance.new("PointLight")
		fuse.Color = color
		fuse.Range = 6
		fuse.Brightness = 2
		fuse.Parent = part
		smoke(part, Color3.fromRGB(40, 40, 40), 20)
		spin = Vector3.new(8, 5, 0)
	elseif kind == "Missile" then
		part.Material = Enum.Material.Metal
		part.Color = Color3.fromRGB(35, 35, 40)
		part.Size = Vector3.new(0.5, 0.5, 2.2)
		trail(part, Color3.fromRGB(255, 160, 60), 0.6, 0.35)
		smoke(part, Color3.fromRGB(90, 90, 90), 30)
	elseif kind == "Shield" then
		part.Shape = Enum.PartType.Cylinder
		part.Material = Enum.Material.DiamondPlate
		part.Color = Color3.fromRGB(160, 160, 165)
		part.Size = Vector3.new(0.25, 2.6, 2.6)
		trail(part, Color3.fromRGB(200, 200, 210), 1.2, 0.15)
		spin = Vector3.new(0, 25, 0)
	elseif kind == "Shard" then
		part.Material = Enum.Material.Ice
		part.Color = color
		part.Size = Vector3.new(width, width, width * 3)
		trail(part, color, width, 0.2)
	elseif kind == "Rock" then
		part.Material = Enum.Material.Slate
		part.Color = color
		part.Size = Vector3.new(width, width * 0.8, width)
		smoke(part, Color3.fromRGB(120, 110, 100), 12)
		spin = Vector3.new(3, 2, 1)
	elseif kind == "Board" then
		part.Material = Enum.Material.Foil
		part.Reflectance = 0.6
		part.Color = Color3.fromRGB(215, 220, 230)
		part.Size = Vector3.new(2.6, 0.3, 7.5)
		trail(part, color, 2, 0.4)
		spin = Vector3.new(0, 14, 0)
	else -- Orb
		part.Shape = Enum.PartType.Ball
		part.Material = Enum.Material.Neon
		part.Color = color
		part.Size = Vector3.new(width, width, width)
		trail(part, color, width, 0.3)
		local light = Instance.new("PointLight")
		light.Color = color
		light.Range = 10
		light.Brightness = 2
		light.Parent = part
	end
	return part, spin
end

local function onProjectile(payload: { [string]: any })
	local id = payload.Id
	local origin = payload.Origin
	local velocity = payload.Velocity
	if type(id) ~= "number" or typeof(origin) ~= "Vector3" or typeof(velocity) ~= "Vector3" then
		return
	end
	local color = if typeof(payload.Color) == "Color3" then payload.Color else Color3.new(1, 1, 1)
	local width = if type(payload.Width) == "number" then payload.Width else 1
	local kind = if type(payload.Kind) == "string" then payload.Kind else "Orb"
	local part, spin = build(kind, color, width)
	part.CFrame = CFrame.lookAt(origin, origin + velocity)
	part.Parent = EffectsController.folder()
	flying[id] = {
		model = part,
		velocity = velocity,
		gravity = if type(payload.Gravity) == "number" then payload.Gravity else 0,
		homing = if typeof(payload.Homing) == "Instance" and payload.Homing:IsA("Model") then payload.Homing else nil,
		homingStrength = if type(payload.HomingStrength) == "number" then payload.HomingStrength else 0,
		expires = os.clock() + (if type(payload.Life) == "number" then payload.Life else 5) + 0.5,
		spin = spin,
	}
end

local function finish(id: number)
	local item = flying[id]
	if item then
		flying[id] = nil
		item.model.Transparency = 1
		for _, child in item.model:GetDescendants() do
			if child:IsA("ParticleEmitter") then
				child.Enabled = false
			elseif child:IsA("PointLight") then
				child.Enabled = false
			end
		end
		Debris:AddItem(item.model, 0.5)
	end
end

local function onProjectileEnd(payload: { [string]: any })
	if type(payload.Id) == "number" then
		finish(payload.Id)
	end
end

local function step(dt: number)
	local now = os.clock()
	for id, item in flying do
		if now > item.expires or item.model.Parent == nil then
			finish(id)
			continue
		end
		if item.homing and item.homingStrength > 0 then
			local root = item.homing:FindFirstChild("HumanoidRootPart")
			if root and root:IsA("BasePart") then
				local desired = root.Position - item.model.Position
				if desired.Magnitude > 1 then
					local current = item.velocity.Unit
					local wanted = desired.Unit
					local angle = math.acos(math.clamp(current:Dot(wanted), -1, 1))
					local t = if angle > 1e-3 then math.min(1, item.homingStrength * dt / angle) else 1
					item.velocity = current:Lerp(wanted, t).Unit * item.velocity.Magnitude
				end
			end
		end
		item.velocity += Vector3.new(0, -item.gravity * dt, 0)
		local position = item.model.Position + item.velocity * dt
		local look = CFrame.lookAt(position, position + item.velocity)
		if item.spin.Magnitude > 0 then
			look *= CFrame.Angles(item.spin.X * now, item.spin.Y * now, item.spin.Z * now)
		end
		item.model.CFrame = look
	end
end

--------------------------------------------------------------------------------
-- Explosions & shockwaves
--------------------------------------------------------------------------------
local EXPLOSION_STYLES: { [string]: { core: Color3, smoke: Color3 } } = {
	Fire = { core = Color3.fromRGB(255, 170, 60), smoke = Color3.fromRGB(45, 40, 38) },
	Electric = { core = Color3.fromRGB(255, 240, 120), smoke = Color3.fromRGB(80, 80, 90) },
	Dark = { core = Color3.fromRGB(110, 60, 200), smoke = Color3.fromRGB(15, 10, 20) },
	Ice = { core = Color3.fromRGB(190, 240, 255), smoke = Color3.fromRGB(220, 235, 245) },
	Nova = { core = Color3.fromRGB(230, 240, 255), smoke = Color3.fromRGB(120, 150, 220) },
	Radiation = { core = Color3.fromRGB(170, 255, 150), smoke = Color3.fromRGB(70, 110, 60) },
	Gravity = { core = Color3.fromRGB(150, 90, 255), smoke = Color3.fromRGB(30, 20, 45) },
	Sonic = { core = Color3.fromRGB(255, 120, 220), smoke = Color3.fromRGB(80, 60, 80) },
}

local function onExplosion(payload: { [string]: any })
	local position = payload.Position
	if typeof(position) ~= "Vector3" then
		return
	end
	local radius = if type(payload.Radius) == "number" then payload.Radius else 10
	local style = EXPLOSION_STYLES[if type(payload.Kind) == "string" then payload.Kind else "Fire"] or EXPLOSION_STYLES.Fire
	local core = if typeof(payload.Color) == "Color3" then payload.Color else style.core

	local ball = EffectsController.part()
	ball.Shape = Enum.PartType.Ball
	ball.Material = Enum.Material.Neon
	ball.Color = core
	ball.Size = Vector3.new(1, 1, 1)
	ball.CFrame = CFrame.new(position)
	ball.Parent = EffectsController.folder()
	TweenService:Create(ball, TweenInfo.new(0.35, Enum.EasingStyle.Quint), { Size = Vector3.one * radius * 2, Transparency = 1 }):Play()
	Debris:AddItem(ball, 0.4)

	local anchor = EffectsController.part()
	anchor.Transparency = 1
	anchor.Size = Vector3.one
	anchor.CFrame = CFrame.new(position)
	anchor.Parent = EffectsController.folder()
	local light = Instance.new("PointLight")
	light.Color = core
	light.Range = radius * 3
	light.Brightness = 8
	light.Parent = anchor
	TweenService:Create(light, TweenInfo.new(0.6), { Brightness = 0 }):Play()
	local smokeEmitter = Instance.new("ParticleEmitter")
	smokeEmitter.Color = ColorSequence.new(style.smoke)
	smokeEmitter.Transparency = NumberSequence.new(0.2, 1)
	smokeEmitter.Size = NumberSequence.new(radius * 0.4, radius * 0.9)
	smokeEmitter.Lifetime = NumberRange.new(1, 2)
	smokeEmitter.Speed = NumberRange.new(radius * 0.8, radius * 1.6)
	smokeEmitter.SpreadAngle = Vector2.new(180, 180)
	smokeEmitter.Drag = 3
	smokeEmitter.Rate = 0
	smokeEmitter.Parent = anchor
	smokeEmitter:Emit(math.clamp(math.floor(radius * 2), 8, 40))
	local sparks = Instance.new("ParticleEmitter")
	sparks.Color = ColorSequence.new(Color3.new(1, 1, 1), core)
	sparks.LightEmission = 1
	sparks.Size = NumberSequence.new(0.4, 0)
	sparks.Lifetime = NumberRange.new(0.3, 0.7)
	sparks.Speed = NumberRange.new(radius * 3, radius * 6)
	sparks.SpreadAngle = Vector2.new(180, 180)
	sparks.Drag = 2
	sparks.Rate = 0
	sparks.Parent = anchor
	sparks:Emit(math.clamp(math.floor(radius * 3), 10, 60))
	Debris:AddItem(anchor, 2.2)

	SoundLibrary.explosion(position)
	local camera = workspace.CurrentCamera
	if camera then
		local distance = (camera.CFrame.Position - position).Magnitude
		local falloff = math.clamp(1 - distance / (radius * 12), 0, 1)
		if falloff > 0 then
			CameraController.shake(falloff * math.clamp(radius / 25, 0.2, 0.8))
		end
	end
end

local function onShockwave(payload: { [string]: any })
	local position = payload.Position
	local direction = payload.Direction
	if typeof(position) ~= "Vector3" or typeof(direction) ~= "Vector3" or direction.Magnitude < 1e-3 then
		return
	end
	local range = if type(payload.Range) == "number" then payload.Range else 40
	local color = if typeof(payload.Color) == "Color3" then payload.Color else Color3.new(1, 1, 1)
	local angle = if type(payload.Angle) == "number" then payload.Angle else 360
	local full = angle >= 300
	for i = 0, 2 do
		local ring = EffectsController.part()
		ring.Shape = Enum.PartType.Cylinder
		ring.Material = Enum.Material.ForceField
		ring.Color = color
		ring.Transparency = 0.1
		ring.Size = Vector3.new(0.4, 3, 3)
		if full then
			ring.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
		else
			ring.CFrame = CFrame.lookAt(position, position + direction) * CFrame.Angles(0, math.rad(90), 0)
		end
		ring.Parent = EffectsController.folder()
		local size = if full then range * 2 else range * 0.9
		local target = if full then ring.CFrame else ring.CFrame + direction.Unit * range * 0.6
		task.delay(i * 0.07, function()
			TweenService:Create(ring, TweenInfo.new(0.4, Enum.EasingStyle.Quad), {
				Size = Vector3.new(0.1, size, size),
				Transparency = 1,
				CFrame = target,
			}):Play()
		end)
		Debris:AddItem(ring, 0.6)
	end
	SoundLibrary.play("Sound.Hit.Heavy", { Position = position, Volume = 1, Pitch = 0.35 })
	local myRoot = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if myRoot and myRoot:IsA("BasePart") and (myRoot.Position - position).Magnitude < range * 1.5 then
		CameraController.shake(0.3)
	end
end

function ProjectileFx.init()
	EffectsController.register("Projectile", onProjectile)
	EffectsController.register("ProjectileEnd", onProjectileEnd)
	EffectsController.register("Explosion", onExplosion)
	EffectsController.register("Shockwave", onShockwave)
	RunService.RenderStepped:Connect(step)
end

return ProjectileFx
