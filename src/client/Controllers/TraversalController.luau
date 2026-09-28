--!strict
-- F: each character's signature movement, applied instantly on this client
-- (it owns the character's physics) while the server handles the world
-- interaction (TraversalService). Also runs wall phasing:
--   * Phase moves (Voltline, Swarm, Umbra, Argent surge), Voltline's Phase
--     Run and Argent's board passive slip through walls.
--   * Smash moves burst straight through destructible structures.
-- Flyers: F on the ground takes off with a burst, F in flight bursts,
-- double-tap F in flight to drop out of the air.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("ApexCity")
local BalanceConfig = require(Shared.Config.BalanceConfig)
local Remotes = require(Shared.Net.Remotes)

local AbilityInputController = require(script.Parent.AbilityInputController)
local CameraController = require(script.Parent.CameraController)
local EffectsController = require(script.Parent.EffectsController)
local FlightController = require(script.Parent.FlightController)
local InputController = require(script.Parent.InputController)
local PoseController = require(script.Parent.PoseController)
local TraversalFx = require(script.Parent.TraversalFx)

type Traversal = BalanceConfig.Traversal
type PhaseMode = "None" | "All" | "Structures"

local player = Players.LocalPlayer

local EXIT_SEARCH = 70
local DOUBLE_TAP = 0.3

local TraversalController = {}

local combatRemote: RemoteEvent
local activeUntil = 0
local activeMode: PhaseMode = "None"
local activeForce: LinearVelocity? = nil
local bounceMove: { dir: Vector3, speed: number, bouncesLeft: number }? = nil
local lastPress = 0
local localReadyAt = 0
local nextGhost = 0
local smashedAt: { [Instance]: number } = setmetatable({}, { __mode = "k" }) :: any

local POSES: { [string]: string } = {
	Bastion = "ShoulderCharge",
	OldGuard = "ShoulderCharge",
	Rampage = "Leap",
	Graven = "CastBoth",
	Rime = "Leap",
	Echo = "Scream",
}

local function parts(): (Model?, Humanoid?, BasePart?)
	local character = player.Character
	if not character then
		return nil, nil, nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	return character, humanoid, if root and root:IsA("BasePart") then root else nil
end

local function currentMove(): Traversal?
	local id = player:GetAttribute("ApexCharacter")
	return if type(id) == "string" then (BalanceConfig.Traversal :: any)[id] else nil
end

local function clearForce()
	if activeForce then
		activeForce:Destroy()
		activeForce = nil
	end
	bounceMove = nil
end

local function holdVelocity(root: BasePart, velocity: Vector3, duration: number, horizontalOnly: boolean)
	clearForce()
	local attachment = root:FindFirstChild("RootAttachment")
	if not attachment or not attachment:IsA("Attachment") then
		root.AssemblyLinearVelocity = velocity
		return
	end
	local linear = Instance.new("LinearVelocity")
	linear.Name = "ApexTraversal"
	linear.Attachment0 = attachment
	linear.RelativeTo = Enum.ActuatorRelativeTo.World
	if horizontalOnly then
		linear.ForceLimitMode = Enum.ForceLimitMode.PerAxis
		linear.MaxAxesForce = Vector3.new(1e7, 0, 1e7)
	else
		linear.MaxForce = 1e7
	end
	linear.VectorVelocity = velocity
	linear.Parent = root
	activeForce = linear
	task.delay(duration, function()
		if activeForce == linear then
			clearForce()
			-- keep a little carry so it doesn't feel like hitting a wall
			root.AssemblyLinearVelocity = velocity.Unit * math.min(velocity.Magnitude, 40) + Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
		end
	end)
end

local function flatCameraLook(): Vector3
	local camera = workspace.CurrentCamera
	local look = if camera then camera.CFrame.LookVector else Vector3.new(0, 0, -1)
	local flat = Vector3.new(look.X, 0, look.Z)
	return if flat.Magnitude > 1e-3 then flat.Unit else Vector3.new(0, 0, -1)
end

--------------------------------------------------------------------------------
-- Perform
--------------------------------------------------------------------------------
local function perform()
	local character, humanoid, root = parts()
	local move = currentMove()
	if not character or not humanoid or not root or not move or humanoid.Health <= 0 then
		return
	end
	if character:GetAttribute("ApexStunned") == true or character:GetAttribute("ApexServerMotion") == true then
		return
	end
	local now = os.clock()

	-- Flyers: double-tap F while flying drops out of the air
	if move.Kind == "Flight" and FlightController.isFlying() and now - lastPress < DOUBLE_TAP then
		lastPress = 0
		FlightController.stop(nil)
		return
	end
	lastPress = now

	-- Local cooldown / stamina mirror (the server has the final say)
	local readyAt = player:GetAttribute("ApexCD_Movement")
	if (type(readyAt) == "number" and workspace:GetServerTimeNow() < readyAt) or now < localReadyAt then
		return
	end
	local stamina = player:GetAttribute("ApexStamina")
	if type(stamina) ~= "number" or stamina < move.Stamina then
		return
	end
	localReadyAt = now + move.Cooldown * 0.9

	local _, aimPoint = AbilityInputController.getAim()
	combatRemote:FireServer("Movement", aimPoint)

	local speed = move.Distance / move.Duration
	activeUntil = now + move.Duration + 0.1
	activeMode = if move.Phase then "All" elseif move.Smash then "Structures" else "None"
	local pose = POSES[character:GetAttribute("ApexCharacter") :: string]
	if pose then
		PoseController.play(character, pose, { Duration = move.Duration + 0.2 })
	end
	CameraController.shake(0.18)
	CameraController.setFov("Traversal", 95)
	task.delay(move.Duration, function()
		CameraController.setFov("Traversal", nil)
	end)

	if move.Kind == "Flight" then
		local camera = workspace.CurrentCamera
		local dir = if camera then camera.CFrame.LookVector else root.CFrame.LookVector
		if not FlightController.isFlying() then
			FlightController.start()
			dir = Vector3.new(dir.X, math.max(dir.Y, 0.3), dir.Z)
		end
		FlightController.burst(dir, speed, move.Duration)
	elseif move.Kind == "Leap" then
		clearForce()
		local dir = flatCameraLook()
		humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
		root.AssemblyLinearVelocity = dir * speed + Vector3.new(0, 80, 0)
	elseif move.Kind == "Pull" then
		local origin = root.Position
		local target = if aimPoint then aimPoint else origin + flatCameraLook() * move.Distance
		local offset = target - origin
		if offset.Magnitude > move.Distance then
			target = origin + offset.Unit * move.Distance
		end
		humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
		local travel = (target - origin).Magnitude
		holdVelocity(root, (target - origin).Unit * speed, math.clamp(travel / speed, 0.1, move.Duration * 1.4), false)
		EffectsController.play("ShadowPuff", { Position = origin })
	else -- Dash / Bounce
		local moveDir = humanoid.MoveDirection
		local dir = if moveDir.Magnitude > 0.1 then Vector3.new(moveDir.X, 0, moveDir.Z).Unit else flatCameraLook()
		humanoid:ChangeState(Enum.HumanoidStateType.Running)
		holdVelocity(root, dir * speed, move.Duration, true)
		if move.Kind == "Bounce" then
			bounceMove = { dir = dir, speed = speed, bouncesLeft = move.Bounces or 2 }
		end
		if move.IceTrail then
			EffectsController.play("IceSpike", { Position = root.Position - Vector3.new(0, 3, 0), Height = 4 })
		end
	end
	local glow = EffectsController.glowFor(character)
	EffectsController.play("SonicBoom", { Position = root.Position, Direction = root.CFrame.LookVector, Color = glow })
	EffectsController.play("TraversalImpact", { Kind = "Start", Position = root.Position, Direction = root.CFrame.LookVector, Color = glow, Source = character, Strength = 0.8 })
end

--------------------------------------------------------------------------------
-- Wall phasing + bounces
--------------------------------------------------------------------------------
local function phaseMode(character: Model): PhaseMode
	if os.clock() < activeUntil and activeMode ~= "None" then
		return activeMode
	end
	if character:GetAttribute("ApexPhasing") == true then
		return "All"
	end
	-- Argent's passive: riding the board phases through walls
	if character:GetAttribute("ApexCharacter") == "Argent" and FlightController.isFlying() then
		return "All"
	end
	return "None"
end

local function step(dt: number)
	local character, _, root = parts()
	if not character or not root then
		return
	end
	local velocity = root.AssemblyLinearVelocity
	local speed = velocity.Magnitude
	if speed < 12 then
		return
	end
	local dir = velocity.Unit
	local now = os.clock()
	-- Traversal trail: ghost afterimages while the move is active
	if now < activeUntil and now >= nextGhost then
		nextGhost = now + 0.045
		TraversalFx.trail(character, root.Position, root.Position - dir * math.min(speed * 0.08, 30), EffectsController.glowFor(character))
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character, EffectsController.folder() }
	local reach = math.max(4, speed * dt * 2.5)
	local hit = workspace:Raycast(root.Position, dir * reach, params)
	if not hit then
		return
	end
	local isFloor = hit.Normal.Y > 0.65 or hit.Normal.Y < -0.65
	-- Old Guard's shield slide ricochets off solid walls
	if bounceMove and activeForce and not isFloor and not CollectionService:HasTag(hit.Instance, "ApexStructure") then
		if bounceMove.bouncesLeft > 0 then
			bounceMove.bouncesLeft -= 1
			local flatNormal = Vector3.new(hit.Normal.X, 0, hit.Normal.Z)
			if flatNormal.Magnitude > 1e-3 then
				flatNormal = flatNormal.Unit
				local d = bounceMove.dir
				bounceMove.dir = (d - 2 * d:Dot(flatNormal) * flatNormal).Unit
				activeForce.VectorVelocity = bounceMove.dir * bounceMove.speed
				CameraController.shake(0.2)
				EffectsController.play("Explosion", { Position = hit.Position, Radius = 3, Kind = "Electric", Color = Color3.fromRGB(220, 220, 230) })
			end
			return
		end
	end
	local mode = phaseMode(character)
	if mode == "None" or isFloor or hit.Instance == workspace.Terrain then
		return
	end
	if mode == "Structures" and not CollectionService:HasTag(hit.Instance, "ApexStructure") then
		return
	end
	-- Impact frame as we burst through (once per wall)
	if (smashedAt[hit.Instance] or 0) < now - 0.5 then
		smashedAt[hit.Instance] = now
		EffectsController.play("TraversalImpact", { Kind = "Wall", Position = hit.Position, Direction = hit.Normal, Color = EffectsController.glowFor(character), Source = character, Strength = if mode == "Structures" then 1 else 0.6 })
	end
	-- Find the far side of the obstacle and slip through to it
	local farPoint = hit.Position + dir * EXIT_SEARCH
	local back = workspace:Raycast(farPoint, -dir * EXIT_SEARCH, params)
	local exit = if back then back.Position + dir * 3 else farPoint
	root.CFrame = CFrame.new(exit) * root.CFrame.Rotation
	EffectsController.play("Afterimage", { Source = character, From = hit.Position, To = exit, Color = EffectsController.glowFor(character) })
end

function TraversalController.init()
	combatRemote = Remotes.event("CombatInput")
	InputController.Began:Connect(function(action: string)
		if action == "Movement" then
			perform()
		end
	end)
	player.CharacterAdded:Connect(function()
		clearForce()
		activeUntil = 0
		table.clear(smashedAt)
	end)
	RunService.Heartbeat:Connect(step)
end

return TraversalController
