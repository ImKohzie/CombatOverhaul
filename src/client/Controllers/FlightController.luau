--!strict
-- Custom flight controller (LinearVelocity + AlignOrientation, no default
-- physics). Camera-directed: fly where the camera points, WASD strafes
-- relative to camera, Space ascends, Left Ctrl descends.
--   Hover  : aiming or slow / precise
--   Cruise : default
--   Boost  : hold Sprint, drains stamina (server-side), FOV kick, speed
--            lines, sonic boom ring on entry, wind scales with speed
-- Board (Argent) and Glider (Nightwing Goblin) share the controller with
-- their own profile, stance and banking. Glider dash = trick-spin dodge.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("ApexCity")
local AssetRegistry = require(Shared.AssetRegistry)
local BalanceConfig = require(Shared.Config.BalanceConfig)
local CharacterRegistry = require(Shared.CharacterRegistry)
local Remotes = require(Shared.Net.Remotes)
local Signal = require(Shared.Util.Signal)
local Types = require(Shared.Types)

local CameraController = require(script.Parent.CameraController)
local EffectsController = require(script.Parent.EffectsController)
local InputController = require(script.Parent.InputController)
local MotionModifiers = require(script.Parent.MotionModifiers)
local PoseController = require(script.Parent.PoseController)

type FlightProfile = BalanceConfig.FlightProfile

local player = Players.LocalPlayer

local MAX_TILT = { Flight = 0.94, Board = 0.22, Glider = 0.3 } :: { [string]: number }
local BANK_GAIN = 0.35
local TAKEOFF_KICK = 28
local LAND_PROBE = 1.6
local SERVER_CONFIRM_TIME = 0.8
local TRICK_SPIN_TIME = 0.45
local TRICK_SPIN_PUSH = 70

local FlightController = {}

FlightController.Started = Signal.new()
FlightController.Landed = Signal.new() -- (impactSpeed: number, hard: boolean)

local movementRemote: RemoteEvent
local controls: any = nil

type Session = {
	character: Model,
	humanoid: Humanoid,
	root: BasePart,
	kind: Types.MovementKind,
	profile: FlightProfile,
	glow: Color3,
	linear: LinearVelocity,
	align: AlignOrientation,
	wind: Sound?,
	velocity: Vector3,
	roll: number,
	lastHeading: Vector3,
	boosting: boolean,
	startedAt: number,
	spinStart: number?,
	spinAxis: Vector3,
}

local session: Session? = nil
local lastJumpRequest = 0

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------
local function currentConfig()
	local id = player:GetAttribute("ApexCharacter")
	return if type(id) == "string" then CharacterRegistry.get(id) else nil
end

function FlightController.canFly(): boolean
	local config = currentConfig()
	return config ~= nil and config.Movement ~= "Ground"
end

function FlightController.isFlying(): boolean
	return session ~= nil
end

local function getMoveVector(): Vector3
	if controls then
		local ok, value = pcall(function()
			return controls:GetMoveVector()
		end)
		if ok and typeof(value) == "Vector3" and value.Magnitude > 0.01 then
			return value
		end
	end
	-- Fallback 1: the Humanoid's move direction, converted to camera space
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local camera = workspace.CurrentCamera
	if humanoid and camera and humanoid.MoveDirection.Magnitude > 0.05 then
		local look = Vector3.new(camera.CFrame.LookVector.X, 0, camera.CFrame.LookVector.Z)
		local right = Vector3.new(camera.CFrame.RightVector.X, 0, camera.CFrame.RightVector.Z)
		if look.Magnitude > 1e-3 and right.Magnitude > 1e-3 then
			local dir = humanoid.MoveDirection
			return Vector3.new(dir:Dot(right.Unit), 0, -dir:Dot(look.Unit))
		end
	end
	-- Fallback 2: raw keys
	local x = (if UserInputService:IsKeyDown(Enum.KeyCode.D) then 1 else 0) - (if UserInputService:IsKeyDown(Enum.KeyCode.A) then 1 else 0)
	local z = (if UserInputService:IsKeyDown(Enum.KeyCode.S) then 1 else 0) - (if UserInputService:IsKeyDown(Enum.KeyCode.W) then 1 else 0)
	return Vector3.new(x, 0, z)
end

local function ascendHeld(humanoid: Humanoid): boolean
	return humanoid.Jump
		or UserInputService:IsKeyDown(Enum.KeyCode.Space)
		or UserInputService:IsGamepadButtonDown(Enum.UserInputType.Gamepad1, Enum.KeyCode.ButtonA)
end

local function flat(v: Vector3, fallback: Vector3): Vector3
	local f = Vector3.new(v.X, 0, v.Z)
	return if f.Magnitude > 1e-3 then f.Unit else fallback
end

local function setAnimate(character: Model, enabled: boolean)
	local animate = character:FindFirstChild("Animate")
	if animate and animate:IsA("LocalScript") then
		animate.Enabled = enabled
	end
	if not enabled then
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
		if animator then
			for _, track in animator:GetPlayingAnimationTracks() do
				track:Stop(0.15)
			end
		end
	end
end

--------------------------------------------------------------------------------
-- Start / stop
--------------------------------------------------------------------------------
function FlightController.start()
	if session or not FlightController.canFly() then
		return
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not character or not humanoid or humanoid.Health <= 0 or not root or not root:IsA("BasePart") then
		return
	end
	if character:GetAttribute("ApexStunned") == true or character:GetAttribute("ApexGrounded") == true then
		return
	end
	local config = currentConfig()
	if not config then
		return
	end
	local profileName = config.FlightProfile or "Standard"
	local profile = BalanceConfig.Flight.Profiles[profileName] or BalanceConfig.Flight.Profiles.Standard

	local attachment = root:FindFirstChild("RootAttachment")
	if not attachment or not attachment:IsA("Attachment") then
		local created = Instance.new("Attachment")
		created.Name = "RootAttachment"
		created.Parent = root
		attachment = created
	end
	local rootAttachment = attachment :: Attachment

	local linear = Instance.new("LinearVelocity")
	linear.Name = "ApexFlightVelocity"
	linear.Attachment0 = rootAttachment
	linear.RelativeTo = Enum.ActuatorRelativeTo.World
	linear.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	linear.MaxForce = math.huge
	linear.Parent = root

	local align = Instance.new("AlignOrientation")
	align.Name = "ApexFlightOrientation"
	align.Mode = Enum.OrientationAlignmentMode.OneAttachment
	align.Attachment0 = rootAttachment
	align.Responsiveness = profile.TurnResponsiveness
	align.MaxTorque = math.huge
	align.MaxAngularVelocity = math.huge
	align.CFrame = root.CFrame
	align.Parent = root

	local velocity = root.AssemblyLinearVelocity
	if humanoid.FloorMaterial ~= Enum.Material.Air then
		velocity += Vector3.new(0, TAKEOFF_KICK, 0)
	end

	local wind: Sound? = nil
	local windId = AssetRegistry.contentId("Sound.Flight.Wind")
	if windId then
		local sound = Instance.new("Sound")
		sound.Name = "ApexFlightWind"
		sound.SoundId = windId
		sound.Looped = true
		sound.Volume = 0
		sound.RollOffMaxDistance = 120
		sound.Parent = root
		sound:Play()
		wind = sound
	end

	humanoid.PlatformStand = true
	setAnimate(character, false)
	character:SetAttribute("ApexFlying", true) -- local prediction; server confirms

	session = {
		character = character,
		humanoid = humanoid,
		root = root,
		kind = config.Movement,
		profile = profile,
		glow = config.Palette.Glow,
		linear = linear,
		align = align,
		wind = wind,
		velocity = velocity,
		roll = 0,
		lastHeading = flat(root.CFrame.LookVector, Vector3.new(0, 0, -1)),
		boosting = false,
		startedAt = os.clock(),
		spinStart = nil,
		spinAxis = Vector3.zero,
	}
	movementRemote:FireServer("Flight", true)
	FlightController.Started:Fire()
end

-- impactSpeed is set when touching down; nil for a mid-air toggle off.
function FlightController.stop(impactSpeed: number?)
	local s = session
	if not s then
		return
	end
	session = nil
	s.linear:Destroy()
	s.align:Destroy()
	if s.wind then
		s.wind:Destroy()
	end
	CameraController.setFov("Flight", nil)
	CameraController.setSpeedLines(0)
	if s.boosting then
		movementRemote:FireServer("Boost", false)
	end

	local alive = s.humanoid.Parent ~= nil and s.humanoid.Health > 0
	if alive then
		s.humanoid.PlatformStand = false
		setAnimate(s.character, true)
		-- keep upright after flight tilt
		local look = flat(s.root.CFrame.LookVector, s.lastHeading)
		s.root.CFrame = CFrame.lookAt(s.root.Position, s.root.Position + look)
		s.root.AssemblyAngularVelocity = Vector3.zero
		if impactSpeed then
			s.root.AssemblyLinearVelocity = Vector3.zero
			s.humanoid:ChangeState(Enum.HumanoidStateType.Landed)
		else
			s.root.AssemblyLinearVelocity = s.velocity
			s.humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
		end
	end
	s.character:SetAttribute("ApexFlying", false)
	movementRemote:FireServer("Flight", false)

	if impactSpeed and alive then
		local hard = impactSpeed >= BalanceConfig.Flight.HardLandingSpeed
		if hard then
			local strength = math.clamp(impactSpeed / s.profile.Boost, 0.3, 1)
			PoseController.playLanding(s.character)
			CameraController.shake(0.35 + strength * 0.5)
			EffectsController.play("Crater", {
				Position = s.root.Position - Vector3.new(0, s.humanoid.HipHeight + s.root.Size.Y / 2, 0),
				Strength = strength,
				Color = s.glow,
			})
			movementRemote:FireServer("Land", impactSpeed)
		end
		FlightController.Landed:Fire(impactSpeed, hard)
	end
end

function FlightController.toggle()
	if session then
		FlightController.stop(nil)
	else
		FlightController.start()
	end
end

--------------------------------------------------------------------------------
-- Dash in flight: burst (Flight/Board) or trick-spin dodge (Glider)
--------------------------------------------------------------------------------
function FlightController.dash(): boolean
	local s = session
	if not s then
		return false
	end
	local stamina = player:GetAttribute("ApexStamina")
	if type(stamina) ~= "number" or stamina < BalanceConfig.Stamina.DashCost then
		return false
	end
	local camera = workspace.CurrentCamera
	if not camera then
		return false
	end
	local move = getMoveVector()
	if s.kind == "Glider" then
		local side = if move.X < 0 then -1 else 1
		local axis = if s.velocity.Magnitude > 1 then s.velocity.Unit else camera.CFrame.LookVector
		s.spinStart = os.clock()
		s.spinAxis = axis
		s.velocity += camera.CFrame.RightVector * side * TRICK_SPIN_PUSH
	else
		local dir = if s.velocity.Magnitude > 1 then s.velocity.Unit else camera.CFrame.LookVector
		s.velocity = dir * math.max(s.velocity.Magnitude, s.profile.Boost * 0.9)
	end
	CameraController.shake(0.15)
	movementRemote:FireServer("Dash")
	return true
end

--------------------------------------------------------------------------------
-- Per-frame update
--------------------------------------------------------------------------------
local function step(dt: number)
	local s = session
	if not s then
		return
	end
	if s.humanoid.Health <= 0 or s.character.Parent == nil or s.root.Parent == nil then
		FlightController.stop(nil)
		return
	end
	if s.character:GetAttribute("ApexServerMotion") == true or s.character:GetAttribute("ApexGrounded") == true then
		FlightController.stop(nil)
		return
	end
	-- Server has final say (stuns, grounding abilities, invalid state).
	if os.clock() - s.startedAt > SERVER_CONFIRM_TIME and s.character:GetAttribute("ApexServerFlying") ~= true then
		FlightController.stop(nil)
		return
	end
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local profile = s.profile
	local camCF = camera.CFrame

	-- Desired direction (camera-relative, full 3D)
	local move = getMoveVector()
	local vertical = (if ascendHeld(s.humanoid) then 1 else 0) - (if InputController.isHeld("Descend") then 1 else 0)
	local dir = camCF.LookVector * -move.Z + camCF.RightVector * move.X + Vector3.yAxis * vertical
	if dir.Magnitude > 1 then
		dir = dir.Unit
	end
	local moving = dir.Magnitude > 0.05

	-- Speed state
	local aiming = CameraController.isAiming()
	local stamina = player:GetAttribute("ApexStamina")
	local canBoost = type(stamina) == "number" and stamina > 0
	local wantBoost = moving and not aiming and canBoost and InputController.isHeld("Sprint")
	if wantBoost ~= s.boosting then
		s.boosting = wantBoost
		movementRemote:FireServer("Boost", wantBoost)
		if wantBoost then
			local boomDir = if s.velocity.Magnitude > 1 then s.velocity.Unit else camCF.LookVector
			EffectsController.play("SonicBoom", { Position = s.root.Position, Direction = boomDir, Color = s.glow })
			CameraController.shake(0.3)
		end
	end
	local speed = if wantBoost then profile.Boost elseif aiming then profile.Hover else profile.Cruise
	local target = dir * speed

	-- Momentum: exponential approach, ~AccelTime to cruise / DecelTime to stop
	local accelerating = target.Magnitude >= s.velocity.Magnitude
	local tau = (if accelerating then profile.AccelTime else profile.DecelTime) / 3
	s.velocity = s.velocity:Lerp(target, 1 - math.exp(-dt / math.max(tau, 1e-3)))
	-- Bleed velocity into walls so we don't "stick" at full speed against them
	local actual = s.root.AssemblyLinearVelocity
	if actual.Magnitude < s.velocity.Magnitude * 0.35 and s.velocity.Magnitude > 20 and os.clock() - s.startedAt > 0.3 then
		s.velocity = s.velocity:Lerp(actual, 0.5)
	end
	s.linear.VectorVelocity = s.velocity + MotionModifiers.total()

	-- Orientation: upright hover -> leaning into travel at speed
	local currentSpeed = s.velocity.Magnitude
	local alpha = math.clamp((currentSpeed - profile.Hover) / (profile.Cruise - profile.Hover), 0, 1)
	local velDir = if currentSpeed > 1 then s.velocity.Unit else camCF.LookVector
	local heading = if aiming or alpha < 0.05 then flat(camCF.LookVector, s.lastHeading) else flat(velDir, flat(camCF.LookVector, s.lastHeading))
	local tiltAmount = (MAX_TILT[s.kind] or 0.9) * (if aiming then 0.25 else alpha)
	local tiltDir = if s.kind == "Flight" then velDir else heading
	local up = Vector3.yAxis:Lerp(tiltDir, tiltAmount)
	up = if up.Magnitude > 1e-3 then up.Unit else Vector3.yAxis
	local right = heading:Cross(up)
	right = if right.Magnitude > 1e-3 then right.Unit else camCF.RightVector
	local back = right:Cross(up).Unit
	local pos = s.root.Position
	local cf = CFrame.fromMatrix(pos, right, up, back)

	-- Banking from yaw rate
	local yawRate = 0
	local cross = s.lastHeading:Cross(heading).Y
	local dot = math.clamp(s.lastHeading:Dot(heading), -1, 1)
	if dt > 0 then
		yawRate = math.atan2(cross, dot) / dt
	end
	s.lastHeading = heading
	local maxBank = math.rad(profile.MaxBankDegrees)
	local rollTarget = math.clamp(-yawRate * BANK_GAIN, -maxBank, maxBank) * math.max(alpha, 0.2)
	s.roll += (rollTarget - s.roll) * math.min(1, dt * 6)
	local rollAxis = if s.kind == "Flight" then velDir else heading
	local roll = s.roll

	-- Glider trick spin
	if s.spinStart then
		local t = (os.clock() - s.spinStart) / TRICK_SPIN_TIME
		if t >= 1 then
			s.spinStart = nil
		else
			roll += math.pi * 2 * (1 - (1 - t) ^ 2)
			rollAxis = s.spinAxis
		end
	end
	cf = CFrame.fromAxisAngle(rollAxis, roll) * (cf - pos) + pos
	s.align.CFrame = cf

	-- Feel: FOV, speed lines, wind
	local boostT = math.clamp((currentSpeed - profile.Cruise) / math.max(profile.Boost - profile.Cruise, 1), 0, 1)
	local baseFov = BalanceConfig.Flight.BaseFOV
	CameraController.setFov("Flight", baseFov + (profile.BoostFOV - baseFov) * boostT)
	CameraController.setSpeedLines(boostT)
	if s.wind then
		local ratio = math.clamp(currentSpeed / profile.Boost, 0, 1)
		s.wind.Volume = ratio * 0.9
		s.wind.PlaybackSpeed = 0.75 + ratio * 0.6
	end

	-- Touchdown: close to ground while descending
	if s.velocity.Y < -6 and os.clock() - s.startedAt > 0.35 then
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { s.character }
		local reach = s.root.Size.Y / 2 + s.humanoid.HipHeight + LAND_PROBE + math.max(0, -s.velocity.Y) * dt
		local hit = workspace:Raycast(pos, Vector3.new(0, -reach, 0), params)
		if hit then
			FlightController.stop(currentSpeed)
		end
	end
end

--------------------------------------------------------------------------------
-- Init
--------------------------------------------------------------------------------
local function onCharacter(character: Model)
	if session and session.character ~= character then
		FlightController.stop(nil)
	end
	local humanoid = character:WaitForChild("Humanoid", 10)
	if humanoid and humanoid:IsA("Humanoid") then
		humanoid.Died:Connect(function()
			if session and session.character == character then
				FlightController.stop(nil)
			end
		end)
	end
end

function FlightController.init()
	movementRemote = Remotes.event("MovementState")

	pcall(function()
		local playerModule = player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule", 10)
		if playerModule then
			controls = ((require :: any)(playerModule) :: any):GetControls()
		end
	end)

	-- F: toggles flight when airborne or already flying; grounded F is block
	-- (CombatController). Double-jump also takes off.
	InputController.Began:Connect(function(action: string)
		if action ~= "FlightOrBlock" or not FlightController.canFly() then
			return
		end
		if session then
			FlightController.stop(nil)
			return
		end
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.FloorMaterial == Enum.Material.Air then
			FlightController.start()
		end
	end)

	-- Double-jump starts flight: a fresh jump press while airborne.
	UserInputService.JumpRequest:Connect(function()
		local now = os.clock()
		local gap = now - lastJumpRequest
		lastJumpRequest = now
		if session or gap < 0.12 or not FlightController.canFly() then
			return
		end
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.FloorMaterial == Enum.Material.Air and gap <= 0.6 then
			FlightController.start()
		end
	end)

	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		task.spawn(onCharacter, player.Character)
	end

	RunService.PreSimulation:Connect(step)
end

return FlightController
