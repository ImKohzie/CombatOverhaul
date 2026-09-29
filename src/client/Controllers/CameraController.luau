--!strict
-- Camera feel layer on top of the default Roblox camera:
--   * FOV targets (sprint / boost kicks) with smooth blending
--   * over-the-shoulder aim mode (RMB / L2 / Aim button) with crosshair
--   * trauma-based camera shake + gamepad rumble
--   * speed lines overlay
-- Shake is applied after the default camera updates and removed before its
-- next update so it never drifts the camera.

local HapticService = game:GetService("HapticService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("ApexCity")
local BalanceConfig = require(Shared.Config.BalanceConfig)

local InputController = require(script.Parent.InputController)

local player = Players.LocalPlayer

local AIM_OFFSET = Vector3.new(1.9, 0.6, 0)
local AIM_ZOOM = 0.86 -- FOV multiplier while aiming
local FOV_SMOOTH = 10
local SPEED_LINE_COUNT = 28

local CameraController = {}

local fovTargets: { [string]: number } = {}
local currentFov = BalanceConfig.Flight.BaseFOV
local aiming = false
local aimBlend = 0
local trauma = 0
local appliedShake = CFrame.identity
local speedLineIntensity = 0
local speedLines: { Frame } = {}
local crosshair: Frame
local hitMarkerFrames: { Frame } = {}
local hitMarkerUntil = 0
local aimBlocked = false
local cinematicActive = false
local lookProvider: ((camera: Camera, dt: number) -> CFrame?)? = nil

--------------------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------------------

-- Request an absolute FOV under a name; nil clears it. Highest target wins.
function CameraController.setFov(name: string, fov: number?)
	if fov then
		fovTargets[name] = fov
	else
		fovTargets[name] = nil
	end
end

function CameraController.isAiming(): boolean
	return aiming
end

-- Some states (menus, ragdoll) disable aim mode.
function CameraController.setAimBlocked(blocked: boolean)
	aimBlocked = blocked
end

-- Lock-on: a provider that may override the camera CFrame each frame
-- (applied after the default camera, before shake).
function CameraController.setLookProvider(provider: ((camera: Camera, dt: number) -> CFrame?)?)
	lookProvider = provider
end

-- intensity 0..1. Stacks as "trauma"; shake strength = trauma^2.
function CameraController.shake(intensity: number)
	trauma = math.clamp(trauma + intensity, 0, 1)
	if UserInputService.GamepadEnabled and intensity > 0.05 then
		local gamepad = Enum.UserInputType.Gamepad1
		pcall(function()
			if HapticService:IsMotorSupported(gamepad, Enum.VibrationMotor.Large) then
				HapticService:SetMotor(gamepad, Enum.VibrationMotor.Large, math.clamp(intensity, 0, 1))
				task.delay(0.12 + intensity * 0.2, function()
					HapticService:SetMotor(gamepad, Enum.VibrationMotor.Large, 0)
				end)
			end
		end)
	end
end

-- 0..1, drawn as streaks around the screen edge.
function CameraController.setSpeedLines(intensity: number)
	speedLineIntensity = math.clamp(intensity, 0, 1)
end

--------------------------------------------------------------------------------
-- Internals
--------------------------------------------------------------------------------
local function getHumanoid(): Humanoid?
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

local function buildOverlay()
	local gui = Instance.new("ScreenGui")
	gui.Name = "ApexCameraOverlay"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 5
	gui.Parent = player:WaitForChild("PlayerGui")

	crosshair = Instance.new("Frame")
	crosshair.Name = "Crosshair"
	crosshair.AnchorPoint = Vector2.new(0.5, 0.5)
	crosshair.Position = UDim2.fromScale(0.5, 0.5)
	crosshair.Size = UDim2.fromOffset(6, 6)
	crosshair.BackgroundColor3 = Color3.new(1, 1, 1)
	crosshair.BackgroundTransparency = 1
	crosshair.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = crosshair
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.new(0, 0, 0)
	stroke.Transparency = 1
	stroke.Parent = crosshair

	-- Hit marker: four short diagonal ticks around the crosshair
	for i = 0, 3 do
		local tick = Instance.new("Frame")
		tick.Name = "HitMarker"
		tick.AnchorPoint = Vector2.new(0.5, 0.5)
		local angle = math.rad(45 + i * 90)
		tick.Position = UDim2.new(0.5, math.cos(angle) * 11, 0.5, math.sin(angle) * 11)
		tick.Size = UDim2.fromOffset(9, 2)
		tick.Rotation = 45 + i * 90
		tick.BorderSizePixel = 0
		tick.BackgroundColor3 = Color3.new(1, 1, 1)
		tick.BackgroundTransparency = 1
		tick.Parent = gui
		table.insert(hitMarkerFrames, tick)
	end

	for i = 1, SPEED_LINE_COUNT do
		local line = Instance.new("Frame")
		line.Name = "SpeedLine" .. i
		line.AnchorPoint = Vector2.new(0.5, 0.5)
		line.BackgroundColor3 = Color3.new(1, 1, 1)
		line.BorderSizePixel = 0
		line.BackgroundTransparency = 1
		line.Parent = gui
		table.insert(speedLines, line)
	end
end

local function updateSpeedLines()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local visible = speedLineIntensity > 0.02
	local viewport = camera.ViewportSize
	local radius = math.max(viewport.X, viewport.Y) * 0.5
	for _, line in speedLines do
		if visible and math.random() < 0.6 then
			local angle = math.random() * math.pi * 2
			local distance = radius * (0.55 + math.random() * 0.45)
			local length = 40 + math.random() * 160 * speedLineIntensity
			line.Position = UDim2.fromOffset(viewport.X / 2 + math.cos(angle) * distance, viewport.Y / 2 + math.sin(angle) * distance)
			line.Size = UDim2.fromOffset(length, 2)
			line.Rotation = math.deg(angle)
			line.BackgroundTransparency = 1 - speedLineIntensity * (0.25 + math.random() * 0.35)
		elseif not visible then
			line.BackgroundTransparency = 1
		end
	end
end

local function beforeCamera()
	-- Remove last frame's shake so the default camera never sees it.
	local camera = workspace.CurrentCamera
	if camera and appliedShake ~= CFrame.identity then
		camera.CFrame = camera.CFrame * appliedShake:Inverse()
		appliedShake = CFrame.identity
	end
end

local function afterCamera(dt: number)
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end

	-- Aim state
	local wantAim = InputController.isHeld("Aim") and not aimBlocked
	local humanoid = getHumanoid()
	if humanoid and humanoid.Health <= 0 then
		wantAim = false
	end
	if aiming and not wantAim then
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	end
	aiming = wantAim
	aimBlend += ((if aiming then 1 else 0) - aimBlend) * math.min(1, dt * 14)
	if humanoid then
		humanoid.CameraOffset = AIM_OFFSET * aimBlend
	end
	if aiming then
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
	end
	crosshair.BackgroundTransparency = 1 - aimBlend * 0.9
	local stroke = crosshair:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Transparency = 1 - aimBlend * 0.6
	end

	-- FOV
	local target = BalanceConfig.Flight.BaseFOV
	for _, fov in fovTargets do
		target = math.max(target, fov)
	end
	-- No aim zoom / shoulder shift while moving fast (flight, sprint, F moves)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local fast = root ~= nil and root:IsA("BasePart") and root.AssemblyLinearVelocity.Magnitude > 45
	target *= 1 + (AIM_ZOOM - 1) * (if fast then 0 else aimBlend)
	currentFov += (target - currentFov) * math.min(1, dt * FOV_SMOOTH)
	camera.FieldOfView = currentFov

	-- Lock-on tracking
	local provider = lookProvider
	if provider and not cinematicActive then
		local ok, override = pcall(provider, camera, dt)
		if ok and override then
			camera.CFrame = override
		end
	end

	-- Shake
	if trauma > 0 then
		local strength = trauma * trauma
		local t = os.clock() * 28
		local pitch = math.noise(t, 0.3) * 0.045 * strength
		local yaw = math.noise(0.7, t) * 0.045 * strength
		local roll = math.noise(t, t * 0.5) * 0.03 * strength
		appliedShake = CFrame.Angles(pitch, yaw, roll)
		camera.CFrame = camera.CFrame * appliedShake
		trauma = math.max(0, trauma - dt * 1.6)
	end

	updateSpeedLines()

	-- Hit marker fade
	local markerAlpha = math.clamp((hitMarkerUntil - os.clock()) / 0.18, 0, 1)
	for _, tick in hitMarkerFrames do
		tick.BackgroundTransparency = 1 - markerAlpha
	end
end

-- Flash the hit marker (red for heavy hits).
function CameraController.hitMarker(heavy: boolean)
	hitMarkerUntil = os.clock() + 0.18
	for _, tick in hitMarkerFrames do
		tick.BackgroundColor3 = if heavy then Color3.fromRGB(255, 80, 70) else Color3.new(1, 1, 1)
		tick.Size = if heavy then UDim2.fromOffset(12, 3) else UDim2.fromOffset(9, 2)
	end
end

function CameraController.isCinematic(): boolean
	return cinematicActive
end

-- Short ultimate camera moment for the local player only. Any input skips
-- it; it never affects other players' cameras.
function CameraController.cinematic(character: Model, duration: number, color: Color3?)
	local camera = workspace.CurrentCamera
	local root = character:FindFirstChild("HumanoidRootPart")
	if cinematicActive or not camera or not root or not root:IsA("BasePart") then
		return
	end
	cinematicActive = true
	local previousType = camera.CameraType
	local previousCFrame = camera.CFrame
	camera.CameraType = Enum.CameraType.Scriptable

	local gui = player:FindFirstChild("PlayerGui") and player.PlayerGui:FindFirstChild("ApexCameraOverlay")
	local flash: Frame? = nil
	if gui then
		local frame = Instance.new("Frame")
		frame.Size = UDim2.fromScale(1, 1)
		frame.BackgroundColor3 = color or Color3.new(1, 1, 1)
		frame.BackgroundTransparency = 0.6
		frame.BorderSizePixel = 0
		frame.ZIndex = 10
		frame.Parent = gui
		flash = frame
		for _, y in { 0, 1 } do
			local bar = Instance.new("Frame")
			bar.AnchorPoint = Vector2.new(0, y)
			bar.Position = UDim2.fromScale(0, y)
			bar.Size = UDim2.new(1, 0, 0.1, 0)
			bar.BackgroundColor3 = Color3.new(0, 0, 0)
			bar.BorderSizePixel = 0
			bar.ZIndex = 11
			bar.Parent = frame
		end
	end

	local skipped = false
	local skipConnection = UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.UserInputType ~= Enum.UserInputType.MouseMovement then
			skipped = true
		end
	end)
	local started = os.clock()
	local connection: RBXScriptConnection
	local function finish()
		connection:Disconnect()
		skipConnection:Disconnect()
		if flash then
			flash:Destroy()
		end
		camera.CameraType = previousType
		if previousType == Enum.CameraType.Scriptable then
			camera.CFrame = previousCFrame
		end
		cinematicActive = false
	end
	connection = RunService.RenderStepped:Connect(function()
		local t = (os.clock() - started) / duration
		if t >= 1 or skipped or root.Parent == nil then
			finish()
			return
		end
		if flash then
			flash.BackgroundTransparency = 0.6 + 0.4 * math.min(1, t * 3)
		end
		local center = root.Position + Vector3.new(0, 1.5, 0)
		local angle = math.rad(-40 + 80 * t) + math.atan2(-root.CFrame.LookVector.X, -root.CFrame.LookVector.Z)
		local distance = 11 - 3 * t
		local eye = center + Vector3.new(math.sin(angle) * distance, 1 - 2.5 * t, math.cos(angle) * distance)
		camera.CFrame = CFrame.lookAt(eye, center)
	end)
end

function CameraController.init()
	buildOverlay()
	RunService:BindToRenderStep("ApexCameraPre", Enum.RenderPriority.Camera.Value - 1, beforeCamera)
	RunService:BindToRenderStep("ApexCameraPost", Enum.RenderPriority.Camera.Value + 1, afterCamera)
end

return CameraController
