--!strict
-- Combat feedback. Every hit gets: an impact burst, a layered sound, a
-- floating damage number, hit-stop on both characters, camera shake and
-- controller rumble scaled to damage, plus a hit marker for the attacker.
-- Also: parries, guard breaks, wall splats, remote swing/ability poses,
-- ultimate cinematic + sting, afterimages, charge auras, kill feed.

local Debris = game:GetService("Debris")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("ApexCity")
local BalanceConfig = require(Shared.Config.BalanceConfig)
local Pool = require(Shared.Util.Pool)

local HudEvents = require(script.Parent.Parent.HudEvents)
local CameraController = require(script.Parent.CameraController)
local EffectsController = require(script.Parent.EffectsController)
local PoseController = require(script.Parent.PoseController)
local SoundLibrary = require(script.Parent.SoundLibrary)

local player = Players.LocalPlayer

local CombatFx = {}

--------------------------------------------------------------------------------
-- Pools
--------------------------------------------------------------------------------
type NumberTag = { part: Part, gui: BillboardGui, label: TextLabel }

local numberPool = Pool.new(function(): NumberTag
	local part = Instance.new("Part")
	part.Name = "ApexDamageNumber"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = 1
	part.Size = Vector3.new(0.1, 0.1, 0.1)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(120, 50)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = 250
	gui.Parent = part
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextStrokeTransparency = 0.2
	label.Parent = gui
	return { part = part, gui = gui, label = label }
end, function(tag: NumberTag)
	tag.part.Parent = nil
end, 48)

type Burst = { part: Part, sparks: ParticleEmitter, flash: ParticleEmitter, light: PointLight }

local burstPool = Pool.new(function(): Burst
	local part = Instance.new("Part")
	part.Name = "ApexImpact"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = 1
	part.Size = Vector3.new(0.2, 0.2, 0.2)
	local sparks = Instance.new("ParticleEmitter")
	sparks.Rate = 0
	sparks.LightEmission = 1
	sparks.Lifetime = NumberRange.new(0.12, 0.3)
	sparks.Speed = NumberRange.new(20, 45)
	sparks.SpreadAngle = Vector2.new(180, 180)
	sparks.Drag = 6
	sparks.Size = NumberSequence.new(0.35, 0)
	sparks.Parent = part
	local flash = Instance.new("ParticleEmitter")
	flash.Rate = 0
	flash.LightEmission = 1
	flash.Lifetime = NumberRange.new(0.08, 0.12)
	flash.Speed = NumberRange.new(0, 0)
	flash.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.5), NumberSequenceKeypoint.new(1, 4) })
	flash.Transparency = NumberSequence.new(0.2, 1)
	flash.Parent = part
	local light = Instance.new("PointLight")
	light.Range = 10
	light.Brightness = 0
	light.Parent = part
	return { part = part, sparks = sparks, flash = flash, light = light }
end, function(burst: Burst)
	burst.part.Parent = nil
end, 32)

--------------------------------------------------------------------------------
-- Pieces
--------------------------------------------------------------------------------
local function damageNumber(position: Vector3, amount: number, color: Color3, big: boolean)
	local tag = numberPool:acquire()
	tag.label.Text = tostring(amount)
	tag.label.TextColor3 = color
	tag.gui.Size = if big then UDim2.fromOffset(150, 64) else UDim2.fromOffset(110, 44)
	local offset = Vector3.new(math.random() * 2 - 1, 2 + math.random(), math.random() * 2 - 1)
	tag.part.CFrame = CFrame.new(position + offset)
	tag.label.TextTransparency = 0
	tag.label.TextStrokeTransparency = 0.2
	tag.part.Parent = EffectsController.folder()
	local info = TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(tag.part, info, { CFrame = tag.part.CFrame + Vector3.new(0, 3, 0) }):Play()
	TweenService:Create(tag.label, TweenInfo.new(0.35, Enum.EasingStyle.Linear, Enum.EasingDirection.In, 0, false, 0.5), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	task.delay(0.9, function()
		numberPool:release(tag)
	end)
end

local function impact(position: Vector3, color: Color3, strength: number)
	local burst = burstPool:acquire()
	burst.part.CFrame = CFrame.new(position)
	burst.part.Parent = EffectsController.folder()
	burst.sparks.Color = ColorSequence.new(Color3.new(1, 1, 1), color)
	burst.flash.Color = ColorSequence.new(Color3.new(1, 1, 1):Lerp(color, 0.5))
	burst.sparks:Emit(math.floor(8 + strength * 22))
	burst.flash:Emit(1)
	burst.light.Color = color
	burst.light.Brightness = 3 + strength * 4
	TweenService:Create(burst.light, TweenInfo.new(0.2), { Brightness = 0 }):Play()
	task.delay(0.4, function()
		burstPool:release(burst)
	end)
end

local function isMe(model: any): boolean
	return model ~= nil and model == player.Character
end

--------------------------------------------------------------------------------
-- Handlers
--------------------------------------------------------------------------------
local function onHit(payload: { [string]: any })
	local target = payload.Target
	local attacker = payload.Attacker
	local amount = if type(payload.Amount) == "number" then payload.Amount else 0
	local position = if typeof(payload.Position) == "Vector3" then payload.Position else nil
	local result = payload.Result
	local heavy = payload.Heavy == true
	local hitStop = if type(payload.HitStop) == "number" then payload.HitStop else 0
	if not position then
		return
	end
	local color = EffectsController.glowFor(attacker)
	local strength = math.clamp(amount / 120, 0.1, 1)

	if result == "Blocked" or result == "GuardBreak" then
		impact(position, Color3.fromRGB(200, 220, 255), 0.3)
		SoundLibrary.play("Sound.Hit.Block", { Position = position, Volume = 0.6, Pitch = 1.6 })
		if amount > 0 then
			damageNumber(position, amount, Color3.fromRGB(170, 170, 180), false)
		end
	elseif result == "Hit" then
		impact(position, color, strength)
		SoundLibrary.play(if heavy then "Sound.Hit.Heavy" else "Sound.Hit.Light", {
			Position = position,
			Volume = 0.6 + strength * 0.6,
			Pitch = if heavy then 0.55 else 0.9 + math.random() * 0.25,
		})
		if heavy then
			-- crunch layer + debris tail
			SoundLibrary.play("Sound.Hit.Heavy", { Position = position, Volume = 0.5, Pitch = 1.4 })
		end
		if amount > 0 then
			damageNumber(position, amount, if heavy then Color3.fromRGB(255, 210, 60) else Color3.new(1, 1, 1), heavy)
		end
		if typeof(target) == "Instance" and target:IsA("Model") and not heavy and payload.Kind ~= "Beam" then
			PoseController.play(target, "Flinch")
		end
	end

	-- Hit-stop on both characters
	if hitStop > 0 then
		if typeof(target) == "Instance" and target:IsA("Model") then
			PoseController.freeze(target, hitStop)
		end
		if typeof(attacker) == "Instance" and attacker:IsA("Model") then
			PoseController.freeze(attacker, hitStop)
		end
	end

	-- Camera shake + rumble + HUD for the people involved
	if isMe(attacker) and amount > 0 then
		CameraController.shake(0.06 + strength * 0.25)
		CameraController.hitMarker(heavy)
		HudEvents.HitMarker:Fire(amount, heavy)
	end
	if isMe(target) and amount > 0 then
		CameraController.shake(0.12 + strength * 0.4)
		local attackerRoot = if typeof(attacker) == "Instance" then attacker:FindFirstChild("HumanoidRootPart") else nil
		HudEvents.DamageTaken:Fire(amount, if attackerRoot and attackerRoot:IsA("BasePart") then attackerRoot.Position else position)
	end
end

local function onParry(payload: { [string]: any })
	local target = payload.Target
	local root = if typeof(target) == "Instance" then target:FindFirstChild("HumanoidRootPart") else nil
	if not root or not root:IsA("BasePart") then
		return
	end
	local position = root.Position + root.CFrame.LookVector * 1.5 + Vector3.new(0, 1, 0)
	impact(position, Color3.fromRGB(120, 200, 255), 1)
	SoundLibrary.play("Sound.Parry", { Position = position, Volume = 1, Pitch = 2.2 })
	local ring = EffectsController.part()
	ring.Shape = Enum.PartType.Cylinder
	ring.Material = Enum.Material.Neon
	ring.Color = Color3.fromRGB(150, 220, 255)
	ring.Size = Vector3.new(0.2, 2, 2)
	ring.CFrame = CFrame.lookAt(position, position + root.CFrame.LookVector) * CFrame.Angles(0, math.rad(90), 0)
	ring.Parent = EffectsController.folder()
	TweenService:Create(ring, TweenInfo.new(0.3, Enum.EasingStyle.Quad), { Size = Vector3.new(0.05, 12, 12), Transparency = 1 }):Play()
	Debris:AddItem(ring, 0.35)
	if isMe(target) or isMe(payload.Attacker) then
		CameraController.shake(0.35)
	end
	if typeof(payload.Attacker) == "Instance" and payload.Attacker:IsA("Model") then
		PoseController.freeze(payload.Attacker, 0.12)
	end
end

local function onGuardBreak(payload: { [string]: any })
	local target = payload.Target
	local root = if typeof(target) == "Instance" then target:FindFirstChild("HumanoidRootPart") else nil
	if not root or not root:IsA("BasePart") then
		return
	end
	for _ = 1, 10 do
		local shard = EffectsController.part()
		shard.Anchored = false
		shard.Material = Enum.Material.Glass
		shard.Color = Color3.fromRGB(170, 210, 255)
		shard.Transparency = 0.3
		shard.Size = Vector3.new(0.4, 0.1, 0.6)
		shard.CFrame = root.CFrame * CFrame.new(math.random() * 2 - 1, 1 + math.random(), -1.5)
		shard.Parent = EffectsController.folder()
		shard.AssemblyLinearVelocity = Vector3.new(math.random() * 30 - 15, 15 + math.random() * 10, math.random() * 30 - 15)
		Debris:AddItem(shard, 1.2)
	end
	SoundLibrary.play("Sound.Hit.Block", { Position = root.Position, Volume = 1, Pitch = 0.6 })
	if isMe(target) then
		CameraController.shake(0.45)
	end
end

local function onWallSplat(payload: { [string]: any })
	local position = payload.Position
	local normal = payload.Normal
	if typeof(position) ~= "Vector3" or typeof(normal) ~= "Vector3" then
		return
	end
	local strength = if type(payload.Strength) == "number" then payload.Strength else 0.6
	local tangent = normal:Cross(Vector3.yAxis)
	if tangent.Magnitude < 1e-3 then
		tangent = normal:Cross(Vector3.xAxis)
	end
	local base = CFrame.fromMatrix(position, tangent.Unit, tangent.Unit:Cross(normal).Unit * -1, normal)
	-- Radial crack slabs pressed into the wall
	for i = 1, 8 do
		local angle = i / 8 * math.pi * 2
		local crack = EffectsController.part()
		crack.Material = Enum.Material.Slate
		crack.Color = Color3.fromRGB(40, 38, 36)
		crack.Size = Vector3.new(0.25, 2 + math.random() * 3 * strength, 0.08)
		crack.CFrame = base * CFrame.Angles(0, 0, angle) * CFrame.new(0, crack.Size.Y / 2 + 0.5, -0.02)
		crack.Parent = EffectsController.folder()
		task.delay(15, function()
			TweenService:Create(crack, TweenInfo.new(2), { Transparency = 1 }):Play()
			Debris:AddItem(crack, 2.1)
		end)
	end
	impact(position, Color3.fromRGB(230, 220, 200), strength)
	SoundLibrary.play("Sound.Hit.Heavy", { Position = position, Volume = 1.2, Pitch = 0.45 })
	local camera = workspace.CurrentCamera
	if camera and (camera.CFrame.Position - position).Magnitude < 60 then
		CameraController.shake(0.3 * strength)
	end
end

local function onSwing(payload: { [string]: any })
	local source = payload.Source
	if typeof(source) ~= "Instance" or not source:IsA("Model") or isMe(source) then
		return -- local swings are predicted
	end
	if type(payload.Action) == "string" then
		PoseController.play(source, payload.Action, { Speed = if type(payload.Speed) == "number" then payload.Speed else nil })
		local root = source:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			SoundLibrary.play("Sound.Whoosh", { Position = root.Position, Volume = 0.25, Pitch = 1.3 })
		end
	end
end

local function onPose(payload: { [string]: any })
	local source = payload.Source
	if typeof(source) ~= "Instance" or not source:IsA("Model") then
		return
	end
	local action = payload.Action
	if action == "" then
		PoseController.stop(source)
	elseif type(action) == "string" then
		PoseController.play(source, action, {
			Loop = payload.Loop == true,
			Duration = if type(payload.Duration) == "number" then payload.Duration else nil,
			Speed = if type(payload.Speed) == "number" then payload.Speed else nil,
		})
	end
end

local function onUltCinematic(payload: { [string]: any })
	local source = payload.Source
	if typeof(source) == "Instance" and source:IsA("Model") then
		CameraController.cinematic(source, BalanceConfig.Ultimate.CinematicMaxDuration, if typeof(payload.Color) == "Color3" then payload.Color else nil)
	end
end

local function onUltSting(payload: { [string]: any })
	local source = payload.Source
	local root = if typeof(source) == "Instance" then source:FindFirstChild("HumanoidRootPart") else nil
	if not root or not root:IsA("BasePart") then
		return
	end
	SoundLibrary.play("Sound.Ult.Sting", { Position = root.Position, Volume = 1.2, Pitch = 0.5, MaxDistance = 700 })
	local color = if typeof(payload.Color) == "Color3" then payload.Color else Color3.new(1, 1, 1)
	local pillar = EffectsController.part()
	pillar.Shape = Enum.PartType.Cylinder
	pillar.Material = Enum.Material.Neon
	pillar.Color = color
	pillar.Transparency = 0.3
	pillar.Size = Vector3.new(400, 3, 3)
	pillar.CFrame = CFrame.new(root.Position + Vector3.new(0, 200, 0)) * CFrame.Angles(0, 0, math.rad(90))
	pillar.Parent = EffectsController.folder()
	TweenService:Create(pillar, TweenInfo.new(0.9), { Size = Vector3.new(400, 0.2, 0.2), Transparency = 1 }):Play()
	Debris:AddItem(pillar, 1)
	if type(payload.Name) == "string" and not isMe(source) then
		local name = if source:IsA("Model") then source.Name else "?"
		HudEvents.Notify:Fire(`{name}: {payload.Name}!`)
	end
end

local function onAfterimage(payload: { [string]: any })
	local source = payload.Source
	local from = payload.From
	local to = payload.To
	if typeof(source) ~= "Instance" or not source:IsA("Model") or typeof(from) ~= "Vector3" or typeof(to) ~= "Vector3" then
		return
	end
	local color = if typeof(payload.Color) == "Color3" then payload.Color else Color3.new(1, 1, 0.5)
	local root = source:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		local shift = from - root.Position
		for _, limb in source:GetChildren() do
			if limb:IsA("BasePart") and limb.Name ~= "HumanoidRootPart" and limb.Transparency < 1 and limb.Name ~= "ApexCostume" then
				local ghost = EffectsController.part()
				ghost.Size = limb.Size
				ghost.CFrame = limb.CFrame + shift
				ghost.Material = Enum.Material.Neon
				ghost.Color = color
				ghost.Transparency = 0.5
				ghost.Parent = EffectsController.folder()
				TweenService:Create(ghost, TweenInfo.new(0.35), { Transparency = 1 }):Play()
				Debris:AddItem(ghost, 0.4)
			end
		end
	end
	-- Streak
	local streak = EffectsController.part()
	streak.Material = Enum.Material.Neon
	streak.Color = color
	local length = (to - from).Magnitude
	streak.Size = Vector3.new(0.3, 0.3, math.max(length, 0.1))
	streak.CFrame = CFrame.lookAt(from:Lerp(to, 0.5), to)
	streak.Parent = EffectsController.folder()
	TweenService:Create(streak, TweenInfo.new(0.2), { Transparency = 1, Size = Vector3.new(0.05, 0.05, math.max(length, 0.1)) }):Play()
	Debris:AddItem(streak, 0.25)
end

local function onChargeAura(payload: { [string]: any })
	local source = payload.Source
	local root = if typeof(source) == "Instance" then source:FindFirstChild("HumanoidRootPart") else nil
	if not root or not root:IsA("BasePart") then
		return
	end
	local color = if typeof(payload.Color) == "Color3" then payload.Color else Color3.new(1, 1, 1)
	local attachment = Instance.new("Attachment")
	attachment.Parent = root
	local aura = Instance.new("ParticleEmitter")
	aura.Color = ColorSequence.new(color)
	aura.LightEmission = 1
	aura.Size = NumberSequence.new(0.3, 0)
	aura.Lifetime = NumberRange.new(0.2, 0.4)
	aura.Speed = NumberRange.new(4, 10)
	aura.SpreadAngle = Vector2.new(180, 180)
	aura.Rate = 80
	aura.Parent = attachment
	Debris:AddItem(attachment, if type(payload.Duration) == "number" then payload.Duration else 1)
end

local riftCorrection: ColorCorrectionEffect? = nil
local function onRift(payload: { [string]: any })
	local source = payload.Source
	local duration = if type(payload.Duration) == "number" then payload.Duration else 6
	local radius = if type(payload.Radius) == "number" then payload.Radius else 200
	local root = if typeof(source) == "Instance" then source:FindFirstChild("HumanoidRootPart") else nil
	if not root or not root:IsA("BasePart") then
		return
	end
	-- Dome marking the rift
	local dome = EffectsController.part()
	dome.Shape = Enum.PartType.Ball
	dome.Material = Enum.Material.ForceField
	dome.Color = Color3.fromRGB(255, 230, 120)
	dome.Size = Vector3.new(2, 2, 2)
	dome.CFrame = root.CFrame
	dome.Parent = EffectsController.folder()
	TweenService:Create(dome, TweenInfo.new(0.5, Enum.EasingStyle.Quad), { Size = Vector3.new(radius * 2, radius * 2, radius * 2) }):Play()
	task.delay(duration - 0.4, function()
		TweenService:Create(dome, TweenInfo.new(0.4), { Transparency = 1 }):Play()
	end)
	Debris:AddItem(dome, duration + 0.1)

	-- Desaturated, frozen view for the speedster; tint for everyone inside
	local mine = isMe(source)
	local myRoot = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local inside = myRoot and myRoot:IsA("BasePart") and (myRoot.Position - root.Position).Magnitude <= radius
	if not mine and not inside then
		return
	end
	if riftCorrection then
		riftCorrection:Destroy()
	end
	local correction = Instance.new("ColorCorrectionEffect")
	correction.Name = "ApexRift"
	correction.Saturation = if mine then -0.85 else -0.4
	correction.TintColor = if mine then Color3.fromRGB(235, 240, 255) else Color3.fromRGB(255, 240, 200)
	correction.Contrast = 0.1
	correction.Parent = Lighting
	riftCorrection = correction
	if mine then
		player:SetAttribute("ApexWorldFrozen", true)
	end
	task.delay(duration, function()
		TweenService:Create(correction, TweenInfo.new(0.4), { Saturation = 0, Contrast = 0 }):Play()
		Debris:AddItem(correction, 0.45)
		if mine then
			player:SetAttribute("ApexWorldFrozen", false)
		end
	end)
end

local function onKillFeed(payload: { [string]: any })
	HudEvents.KillFeed:Fire(
		if type(payload.Killer) == "string" then payload.Killer else nil,
		if type(payload.Victim) == "string" then payload.Victim else "?",
		if type(payload.Tag) == "string" then payload.Tag else nil
	)
end

function CombatFx.init()
	EffectsController.register("Hit", onHit)
	EffectsController.register("Parry", onParry)
	EffectsController.register("GuardBreak", onGuardBreak)
	EffectsController.register("WallSplat", onWallSplat)
	EffectsController.register("Swing", onSwing)
	EffectsController.register("Pose", onPose)
	EffectsController.register("UltCinematic", onUltCinematic)
	EffectsController.register("UltSting", onUltSting)
	EffectsController.register("Afterimage", onAfterimage)
	EffectsController.register("ChargeAura", onChargeAura)
	EffectsController.register("Rift", onRift)
	EffectsController.register("KillFeed", onKillFeed)
end

return CombatFx
