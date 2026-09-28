--!strict
-- Applies server-requested motion to the local character (the client owns
-- its physics): knockback launches, ragdoll state, self dashes/leaps, stop,
-- and standing down while the server moves us (grabs, blitz).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("ApexCity")
local Remotes = require(Shared.Net.Remotes)

local CameraController = require(script.Parent.CameraController)
local FlightController = require(script.Parent.FlightController)
local PoseController = require(script.Parent.PoseController)

local player = Players.LocalPlayer

local ImpulseController = {}

local activeForce: LinearVelocity? = nil
local forceToken = 0

local function parts(): (Model?, Humanoid?, BasePart?)
	local character = player.Character
	if not character then
		return nil, nil, nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	return character, humanoid, if root and root:IsA("BasePart") then root else nil
end

local function clearForce()
	forceToken += 1
	if activeForce then
		activeForce:Destroy()
		activeForce = nil
	end
end

-- Hold a velocity for `duration` seconds (overrides the Humanoid's control).
local function holdVelocity(root: BasePart, velocity: Vector3, duration: number, horizontalOnly: boolean?)
	clearForce()
	local attachment = root:FindFirstChild("RootAttachment")
	if not attachment or not attachment:IsA("Attachment") then
		root.AssemblyLinearVelocity = velocity
		return
	end
	local linear = Instance.new("LinearVelocity")
	linear.Name = "ApexImpulse"
	linear.Attachment0 = attachment
	linear.RelativeTo = Enum.ActuatorRelativeTo.World
	if horizontalOnly then
		linear.ForceLimitMode = Enum.ForceLimitMode.PerAxis
		linear.MaxAxesForce = Vector3.new(1e6, 0, 1e6)
	else
		linear.MaxForce = 1e6
	end
	linear.VectorVelocity = velocity
	linear.Parent = root
	activeForce = linear
	local token = forceToken
	task.delay(duration, function()
		if token == forceToken then
			clearForce()
		end
	end)
end

local function onImpulse(kind: string, velocity: Vector3, extra: number?)
	local character, humanoid, root = parts()
	if not character or not humanoid or not root or humanoid.Health <= 0 then
		return
	end
	if kind == "Knockback" then
		if FlightController.isFlying() and (extra or velocity.Magnitude > 60) then
			FlightController.stop(nil)
		end
		if FlightController.isFlying() then
			-- Light hits in the air just nudge the flight
			root.AssemblyLinearVelocity += velocity * 0.5
			return
		end
		if velocity.Magnitude > 1 then
			if velocity.Y > 5 then
				humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
			end
			holdVelocity(root, velocity, if extra then 0.18 else 0.12)
		end
		local strength = math.clamp(velocity.Magnitude / 120, 0.1, 0.6)
		CameraController.shake(strength)
	elseif kind == "Self" then
		if FlightController.isFlying() then
			FlightController.stop(nil)
		end
		humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
		holdVelocity(root, velocity, extra or 0.25)
	elseif kind == "Stop" then
		clearForce()
		root.AssemblyLinearVelocity = Vector3.zero
	elseif kind == "ServerMotion" then
		clearForce()
		if FlightController.isFlying() then
			FlightController.stop(nil)
		end
	end
end

local function watchCharacter(character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not humanoid or not humanoid:IsA("Humanoid") then
		return
	end
	character:GetAttributeChangedSignal("ApexRagdoll"):Connect(function()
		if humanoid.Health <= 0 then
			return
		end
		if character:GetAttribute("ApexRagdoll") == true then
			if FlightController.isFlying() then
				FlightController.stop(nil)
			end
			humanoid:ChangeState(Enum.HumanoidStateType.Physics)
		else
			humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
			PoseController.play(character, "GetUp")
		end
	end)
	character:GetAttributeChangedSignal("ApexServerMotion"):Connect(function()
		if character:GetAttribute("ApexServerMotion") == true and FlightController.isFlying() then
			FlightController.stop(nil)
		end
	end)
end

function ImpulseController.init()
	Remotes.event("Impulse").OnClientEvent:Connect(function(kind: any, velocity: any, extra: any)
		if type(kind) == "string" and typeof(velocity) == "Vector3" then
			onImpulse(kind, velocity, if type(extra) == "number" then extra else nil)
		end
	end)
	player.CharacterAdded:Connect(watchCharacter)
	if player.Character then
		task.spawn(watchCharacter, player.Character)
	end
end

return ImpulseController
