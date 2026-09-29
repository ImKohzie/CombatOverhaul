--!strict
-- Ground movement: sprint (stamina, server-drained), dash, aim-facing,
-- post-landing movement lock and WalkSpeed management.
-- WalkSpeed = role speed * sprint * ApexSpeedMultiplier (server-set
-- attribute used by abilities such as Harden / Weight) * landing lock.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("ApexCity")
local BalanceConfig = require(Shared.Config.BalanceConfig)
local CharacterRegistry = require(Shared.CharacterRegistry)
local Remotes = require(Shared.Net.Remotes)

local CameraController = require(script.Parent.CameraController)
local FlightController = require(script.Parent.FlightController)
local InputController = require(script.Parent.InputController)
local LockOnController = require(script.Parent.LockOnController)

local player = Players.LocalPlayer

local SPRINT_FOV = 76
local HARD_LAND_LOCK = 0.5

local MovementController = {}

local movementRemote: RemoteEvent
local sprinting = false
local lockedUntil = 0
local lastDash = -math.huge

local function getParts(): (Model?, Humanoid?, BasePart?)
	local character = player.Character
	if not character then
		return nil, nil, nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if root and not root:IsA("BasePart") then
		root = nil
	end
	return character, humanoid, root :: BasePart?
end

local function roleSpeed(): number
	local id = player:GetAttribute("ApexCharacter")
	local config = if type(id) == "string" then CharacterRegistry.get(id) else nil
	return if config then BalanceConfig.Roles[config.Role].WalkSpeed else 16
end

function MovementController.lock(duration: number)
	lockedUntil = math.max(lockedUntil, os.clock() + duration)
end

function MovementController.isSprinting(): boolean
	return sprinting
end

local function setSprinting(value: boolean)
	if value == sprinting then
		return
	end
	sprinting = value
	movementRemote:FireServer("Sprint", value)
	CameraController.setFov("Sprint", if value then SPRINT_FOV else nil)
end

local function groundDash()
	local character, humanoid, root = getParts()
	if not character or not humanoid or not root or humanoid.Health <= 0 then
		return
	end
	local stamina = player:GetAttribute("ApexStamina")
	local cfg = BalanceConfig.Stamina
	if type(stamina) ~= "number" or stamina < cfg.DashCost or os.clock() - lastDash < cfg.DashCooldown then
		return
	end
	if character:GetAttribute("ApexStunned") == true or os.clock() < lockedUntil then
		return
	end
	lastDash = os.clock()

	local dir = humanoid.MoveDirection
	if dir.Magnitude < 0.1 then
		dir = root.CFrame.LookVector
	end
	dir = Vector3.new(dir.X, 0, dir.Z).Unit
	local move = BalanceConfig.Movement

	local attachment = root:FindFirstChild("RootAttachment")
	if not attachment or not attachment:IsA("Attachment") then
		return
	end
	local linear = Instance.new("LinearVelocity")
	linear.Name = "ApexDash"
	linear.Attachment0 = attachment
	linear.RelativeTo = Enum.ActuatorRelativeTo.World
	linear.ForceLimitMode = Enum.ForceLimitMode.PerAxis
	linear.MaxAxesForce = Vector3.new(1e6, 0, 1e6)
	local dashScale = if character:GetAttribute("ApexCharacter") == "Voltline" then BalanceConfig.Momentum.DashMultiplier else 1
	linear.VectorVelocity = dir * (move.DashDistance * dashScale / move.DashDuration)
	linear.Parent = root
	task.delay(move.DashDuration, function()
		linear:Destroy()
	end)
	CameraController.shake(0.08)
	movementRemote:FireServer("Dash")
end

-- Locked on (on foot, not sprinting): face the target and strafe around it.
local function lockFacing(humanoid: Humanoid, root: BasePart): boolean
	local target = LockOnController.getTarget()
	local targetRoot = target and target:FindFirstChild("HumanoidRootPart")
	if not targetRoot or not targetRoot:IsA("BasePart") or FlightController.isFlying() or InputController.isHeld("Sprint") then
		return false
	end
	local character = root.Parent
	if character and (character:GetAttribute("ApexRagdoll") == true or character:GetAttribute("ApexStunned") == true) then
		return false
	end
	local offset = targetRoot.Position - root.Position
	local flat = Vector3.new(offset.X, 0, offset.Z)
	if flat.Magnitude < 1 then
		return false
	end
	humanoid.AutoRotate = false
	local current = root.CFrame.LookVector
	local look = Vector3.new(current.X, 0, current.Z):Lerp(flat.Unit, 0.35)
	if look.Magnitude > 1e-3 then
		root.CFrame = CFrame.lookAt(root.Position, root.Position + look.Unit)
	end
	return true
end

local function step(_dt: number)
	local character, humanoid, root = getParts()
	if not character or not humanoid or not root or humanoid.Health <= 0 then
		setSprinting(false)
		return
	end
	local flying = FlightController.isFlying()
	local stamina = player:GetAttribute("ApexStamina")
	local hasStamina = type(stamina) == "number" and stamina > 0
	local moving = humanoid.MoveDirection.Magnitude > 0.1
	setSprinting(not flying and moving and hasStamina and InputController.isHeld("Sprint") and not CameraController.isAiming())

	if flying then
		return
	end

	-- Walk speed
	local multiplier = character:GetAttribute("ApexSpeedMultiplier")
	local speed = roleSpeed()
		* (if sprinting then BalanceConfig.Movement.SprintMultiplier else 1)
		* (if type(multiplier) == "number" then multiplier else 1)
	if os.clock() < lockedUntil or character:GetAttribute("ApexStunned") == true or character:GetAttribute("ApexRagdoll") == true then
		speed = 0
	end
	-- Can't jump while stunned / bound; time-slowed jumps are weak
	local jumpPower = BalanceConfig.Movement.JumpPower
	if character:GetAttribute("ApexStunned") == true then
		jumpPower = 0
	elseif character:GetAttribute("ApexTimeSlowed") == true then
		jumpPower *= 0.4
	end
	if humanoid.JumpPower ~= jumpPower then
		humanoid.JumpPower = jumpPower
	end
	if humanoid.WalkSpeed ~= speed then
		humanoid.WalkSpeed = speed
	end

	-- Face the crosshair while aiming on foot
	if CameraController.isAiming() then
		humanoid.AutoRotate = false
		local camera = workspace.CurrentCamera
		if camera then
			local look = camera.CFrame.LookVector
			local flatLook = Vector3.new(look.X, 0, look.Z)
			if flatLook.Magnitude > 1e-3 then
				root.CFrame = CFrame.lookAt(root.Position, root.Position + flatLook.Unit)
			end
		end
	elseif lockFacing(humanoid, root) then
		-- strafing around the locked target (handled in lockFacing)
	elseif not humanoid.AutoRotate then
		humanoid.AutoRotate = true
	end
end

function MovementController.init()
	movementRemote = Remotes.event("MovementState")

	InputController.Began:Connect(function(action: string)
		if action == "Dash" then
			if FlightController.isFlying() then
				FlightController.dash()
			else
				groundDash()
			end
		end
	end)

	FlightController.Landed:Connect(function(_speed: number, hard: boolean)
		if hard then
			MovementController.lock(HARD_LAND_LOCK)
		end
	end)

	RunService.PreSimulation:Connect(step)
end

return MovementController
