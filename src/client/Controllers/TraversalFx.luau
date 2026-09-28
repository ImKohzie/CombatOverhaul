--!strict
-- Impact frames + traversal effects for every character's F movement.
--   TraversalImpact { Position, Direction?, Color?, Source?, Target?, Strength?, Kind }
--     Kind "Start" - launch shockwave + speed-line burst
--     Kind "Wall"  - smashing / phasing through a wall
--     Kind "Hit"   - slamming into an enemy (full impact frame + hit-stop)
--     Kind "Blast" - end-of-move blast
-- The anime-style impact frame (1-2 frames of inverted / flat colour) only
-- shows for the players involved or standing close, so crowds don't strobe.

local Debris = game:GetService("Debris")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local CameraController = require(script.Parent.CameraController)
local EffectsController = require(script.Parent.EffectsController)
local PoseController = require(script.Parent.PoseController)
local SoundLibrary = require(script.Parent.SoundLibrary)

local player = Players.LocalPlayer

local TraversalFx = {}

local flashFrame: Frame? = nil
local lastFrame = 0
local selfFreezeUntil = 0

local function overlay(): Frame?
	if flashFrame and flashFrame.Parent then
		return flashFrame
	end
	local playerGui = player:FindFirstChildOfClass("PlayerGui")
	if not playerGui then
		return nil
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "ApexImpactFrame"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 50
	gui.Parent = playerGui
	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BorderSizePixel = 0
	frame.BackgroundTransparency = 1
	frame.Parent = gui
	flashFrame = frame
	return frame
end

-- 2-step impact frame: flat black with a colour-correction invert, then a
-- white flash that fades.
local function impactFrame(color: Color3, strength: number)
	local now = os.clock()
	if now - lastFrame < 0.12 then
		return
	end
	lastFrame = now
	local frame = overlay()
	if not frame then
		return
	end
	local correction = Instance.new("ColorCorrectionEffect")
	correction.Name = "ApexImpactInvert"
	correction.Contrast = 1.5
	correction.Saturation = -1
	correction.Brightness = 0.1
	correction.TintColor = color:Lerp(Color3.new(1, 1, 1), 0.4)
	correction.Parent = Lighting
	frame.BackgroundColor3 = Color3.new(0, 0, 0)
	frame.BackgroundTransparency = 0.35
	task.delay(0.045, function()
		frame.BackgroundColor3 = Color3.new(1, 1, 1)
		frame.BackgroundTransparency = 0.25 + (1 - strength) * 0.4
		correction.Contrast = 0.6
		correction.Saturation = 0.4
		correction.TintColor = Color3.new(1, 1, 1)
		TweenService:Create(frame, TweenInfo.new(0.14), { BackgroundTransparency = 1 }):Play()
		TweenService:Create(correction, TweenInfo.new(0.14), { Contrast = 0, Saturation = 0, Brightness = 0 }):Play()
		Debris:AddItem(correction, 0.2)
	end)
end

-- Freeze our own character for a couple of frames (physics hit-stop).
local function freezeSelf(duration: number)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") or root.Anchored then
		return
	end
	local now = os.clock()
	if now < selfFreezeUntil then
		return
	end
	selfFreezeUntil = now + duration + 0.05
	local velocity = root.AssemblyLinearVelocity
	root.Anchored = true
	task.delay(duration, function()
		if root.Parent then
			root.Anchored = false
			root.AssemblyLinearVelocity = velocity
		end
	end)
end

local function ring(position: Vector3, normal: Vector3, color: Color3, radius: number, life: number)
	local part = EffectsController.part()
	part.Shape = Enum.PartType.Cylinder
	part.Material = Enum.Material.Neon
	part.Color = color
	part.Transparency = 0.15
	part.Size = Vector3.new(0.3, 1, 1)
	part.CFrame = CFrame.lookAt(position, position + normal) * CFrame.Angles(0, math.rad(90), 0)
	part.Parent = EffectsController.folder()
	TweenService:Create(part, TweenInfo.new(life, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.05, radius * 2, radius * 2),
		Transparency = 1,
	}):Play()
	Debris:AddItem(part, life + 0.05)
end

-- Radial spikes flying out of the impact point.
local function spikes(position: Vector3, direction: Vector3, color: Color3, count: number, length: number)
	for i = 1, count do
		local spread = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 2
		local dir = (direction * 0.6 + spread)
		if dir.Magnitude < 1e-3 then
			dir = Vector3.yAxis
		end
		dir = dir.Unit
		local part = EffectsController.part()
		part.Material = Enum.Material.Neon
		part.Color = if i % 3 == 0 then Color3.new(1, 1, 1) else color
		part.Size = Vector3.new(0.25, 0.25, length * (0.5 + math.random()))
		part.CFrame = CFrame.lookAt(position, position + dir) * CFrame.new(0, 0, -part.Size.Z / 2)
		part.Parent = EffectsController.folder()
		TweenService:Create(part, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			CFrame = part.CFrame + dir * length,
			Size = Vector3.new(0.05, 0.05, part.Size.Z * 1.6),
			Transparency = 1,
		}):Play()
		Debris:AddItem(part, 0.25)
	end
end

local function flash(position: Vector3, color: Color3, range: number)
	local part = EffectsController.part()
	part.Transparency = 1
	part.Size = Vector3.new(0.2, 0.2, 0.2)
	part.CFrame = CFrame.new(position)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = range
	light.Brightness = 8
	light.Parent = part
	part.Parent = EffectsController.folder()
	TweenService:Create(light, TweenInfo.new(0.25), { Brightness = 0 }):Play()
	Debris:AddItem(part, 0.3)
end

local function involves(model: any): boolean
	return model ~= nil and model == player.Character
end

local function onImpact(payload: { [string]: any })
	local position = payload.Position
	if typeof(position) ~= "Vector3" then
		return
	end
	local kind = if type(payload.Kind) == "string" then payload.Kind else "Hit"
	local direction = if typeof(payload.Direction) == "Vector3" and payload.Direction.Magnitude > 1e-3 then payload.Direction.Unit else Vector3.zAxis
	local color = if typeof(payload.Color) == "Color3" then payload.Color else EffectsController.glowFor(payload.Source)
	local strength = if type(payload.Strength) == "number" then math.clamp(payload.Strength, 0.1, 1) else 0.7
	local source = payload.Source
	local target = payload.Target
	local mine = involves(source) or involves(target)
	local camera = workspace.CurrentCamera
	local distance = if camera then (camera.CFrame.Position - position).Magnitude else 0
	local near = distance < 60

	if kind == "Start" then
		ring(position, direction, color, 14 * strength + 6, 0.35)
		ring(position, direction, Color3.new(1, 1, 1), 8, 0.2)
		spikes(position, -direction, color, 8, 10)
		if mine then
			CameraController.setSpeedLines(1)
			task.delay(0.35, function()
				CameraController.setSpeedLines(0)
			end)
		end
		return
	end

	-- Wall / Hit / Blast: full impact
	ring(position, direction, color, 22 * strength + 6, 0.4)
	ring(position, Vector3.yAxis, Color3.new(1, 1, 1), 16 * strength + 4, 0.3)
	spikes(position, direction, color, 14, 14 * strength + 4)
	flash(position, color, 30)
	SoundLibrary.play("Sound.Hit.Heavy", { Position = position, Volume = 0.7 + strength * 0.5, Pitch = if kind == "Wall" then 0.7 else 0.5 })

	local stop = if kind == "Hit" then 0.09 + strength * 0.06 elseif kind == "Blast" then 0.08 else 0.05
	if typeof(source) == "Instance" and source:IsA("Model") then
		PoseController.freeze(source, stop)
	end
	if typeof(target) == "Instance" and target:IsA("Model") then
		PoseController.freeze(target, stop)
	end
	if mine or near then
		CameraController.shake(if mine then 0.35 + strength * 0.35 else 0.2)
		if kind ~= "Wall" or mine then
			impactFrame(color, strength)
		end
	end
	if mine then
		if kind ~= "Wall" then
			freezeSelf(stop)
		end
		CameraController.setFov("TraversalPunch", if kind == "Wall" then 104 else 62)
		task.delay(0.08, function()
			CameraController.setFov("TraversalPunch", nil)
		end)
	end
end

-- Stream ghost afterimages + a streak behind a moving character.
function TraversalFx.trail(character: Model, from: Vector3, to: Vector3, color: Color3)
	EffectsController.play("Afterimage", { Source = character, From = from, To = to, Color = color })
end

function TraversalFx.init()
	EffectsController.register("TraversalImpact", onImpact)
	player.CharacterAdded:Connect(function()
		selfFreezeUntil = 0
	end)
end

return TraversalFx
