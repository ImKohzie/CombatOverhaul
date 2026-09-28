--!strict
-- Hit reactions: knockback, ragdoll launches with get-up, and wall-splats.
-- Player characters are physics-owned by their own client, so knockback is
-- sent to that client through the Impulse remote; NPCs are moved directly.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("ApexCity")
local BalanceConfig = require(Shared.Config.BalanceConfig)

local Hooks = require(script.Parent.Parent.Hooks)
local NetService = require(script.Parent.NetService)
local StatusService = require(script.Parent.StatusService)
local MovementService = require(script.Parent.MovementService)

local EFFECT_RADIUS = 500

local ReactionService = {}

type Launch = { expires: number, attacker: Player?, attackerCharacter: Model? }
local launched: { [Model]: Launch } = {}
local ragdollTokens: { [Model]: number } = {}

local function rootOf(character: Model): BasePart?
	local root = character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

--------------------------------------------------------------------------------
-- Ragdoll
--------------------------------------------------------------------------------
function ReactionService.setupRagdoll(character: Model)
	for _, motor in character:GetDescendants() do
		if motor:IsA("Motor6D") and motor.Name ~= "Root" and motor.Part0 and motor.Part1 then
			local part0 = motor.Part0 :: BasePart
			local part1 = motor.Part1 :: BasePart
			if part1:FindFirstChild("ApexRagSocket_" .. motor.Name) then
				continue
			end
			local a0 = Instance.new("Attachment")
			a0.Name = "ApexRagA0_" .. motor.Name
			a0.CFrame = motor.C0
			a0.Parent = part0
			local a1 = Instance.new("Attachment")
			a1.Name = "ApexRagA1_" .. motor.Name
			a1.CFrame = motor.C1
			a1.Parent = part1
			local socket = Instance.new("BallSocketConstraint")
			socket.Name = "ApexRagSocket_" .. motor.Name
			socket.Attachment0 = a0
			socket.Attachment1 = a1
			socket.LimitsEnabled = true
			socket.TwistLimitsEnabled = true
			local isNeck = motor.Name == "Neck"
			socket.UpperAngle = if isNeck then 30 else 60
			socket.TwistLowerAngle = if isNeck then -20 else -45
			socket.TwistUpperAngle = if isNeck then 20 else 45
			socket.Enabled = false
			socket.Parent = part1
		end
	end
end

local function setRagdolled(character: Model, enabled: boolean)
	for _, descendant in character:GetDescendants() do
		if descendant:IsA("Motor6D") and descendant.Name ~= "Root" then
			descendant.Enabled = not enabled
		elseif descendant:IsA("BallSocketConstraint") and descendant.Name:sub(1, 14) == "ApexRagSocket_" then
			descendant.Enabled = enabled
		elseif descendant:IsA("BasePart") and descendant.Name ~= "HumanoidRootPart" and descendant.Parent == character then
			if enabled then
				descendant:SetAttribute("ApexWasCollide", descendant.CanCollide)
				descendant.CanCollide = true
			else
				local was = descendant:GetAttribute("ApexWasCollide")
				if type(was) == "boolean" then
					descendant.CanCollide = was
				end
			end
		end
	end
	character:SetAttribute("ApexRagdoll", enabled)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid and character:GetAttribute("ApexNPC") == true then
		humanoid:ChangeState(if enabled then Enum.HumanoidStateType.Physics else Enum.HumanoidStateType.GettingUp)
	end
end

function ReactionService.ragdoll(character: Model, duration: number)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end
	local token = (ragdollTokens[character] or 0) + 1
	ragdollTokens[character] = token
	StatusService.apply(character, "Ragdoll", "Control", duration + BalanceConfig.Reactions.RagdollGetUpTime)
	setRagdolled(character, true)
	task.delay(duration, function()
		if ragdollTokens[character] ~= token or character.Parent == nil then
			return
		end
		local h = character:FindFirstChildOfClass("Humanoid")
		if h and h.Health > 0 then
			setRagdolled(character, false)
		end
	end)
end

-- Permanent ragdoll on death (visual only).
function ReactionService.deathRagdoll(character: Model)
	ragdollTokens[character] = (ragdollTokens[character] or 0) + 1
	setRagdolled(character, true)
end

--------------------------------------------------------------------------------
-- Knockback
--------------------------------------------------------------------------------
local function knockbackResistance(character: Model): number
	if character:GetAttribute("ApexUnstoppable") == true then
		return 1
	end
	local base = character:GetAttribute("ApexKnockbackResist")
	local role = character:GetAttribute("ApexRole")
	local roleResist = 0
	if type(role) == "string" then
		local roleBalance = (BalanceConfig.Roles :: any)[role]
		if roleBalance then
			roleResist = roleBalance.KnockbackResistance
		end
	end
	return math.clamp(roleResist + (if type(base) == "number" then base else 0), 0, 0.95)
end

-- velocity: world-space launch velocity. ragdoll: seconds (nil = none).
function ReactionService.knockback(victim: Model, velocity: Vector3, ragdoll: number?, attacker: Player?, attackerCharacter: Model?)
	local root = rootOf(victim)
	local humanoid = victim:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 then
		return
	end
	local resist = knockbackResistance(victim)
	local applied = velocity * (1 - resist)
	if resist >= 1 then
		return
	end
	local ragdollTime = if ragdoll and resist < 0.6 then ragdoll * (1 - resist) else nil

	local player = Players:GetPlayerFromCharacter(victim)
	if player then
		MovementService.exempt(player, 1.5 + (ragdollTime or 0))
		if ragdollTime or applied.Magnitude > 60 then
			MovementService.forceLand(player)
		end
		NetService.fireClient("Impulse", player, "Knockback", applied, ragdollTime)
	else
		-- NPC: short forced velocity
		local attachment = root:FindFirstChild("RootAttachment")
		if attachment and attachment:IsA("Attachment") then
			local linear = Instance.new("LinearVelocity")
			linear.Attachment0 = attachment
			linear.RelativeTo = Enum.ActuatorRelativeTo.World
			linear.MaxForce = 1e6
			linear.VectorVelocity = applied
			linear.Parent = root
			task.delay(0.15, function()
				linear:Destroy()
			end)
		else
			root.AssemblyLinearVelocity = applied
		end
	end

	if ragdollTime then
		ReactionService.ragdoll(victim, ragdollTime)
	end
	if applied.Magnitude >= BalanceConfig.Reactions.LaunchSpeedForWallSplat then
		launched[victim] = {
			expires = os.clock() + BalanceConfig.Reactions.WallSplatWindow,
			attacker = attacker,
			attackerCharacter = attackerCharacter,
		}
	end
end

--------------------------------------------------------------------------------
-- Wall-splat: launched bodies that hit a wall either break through it
-- (structure too weak) or splat against it.
--------------------------------------------------------------------------------
local function checkSplats(dt: number)
	local now = os.clock()
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore: { Instance } = {}
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(ignore, player.Character)
		end
	end
	for victim, launch in launched do
		if now > launch.expires or victim.Parent == nil then
			launched[victim] = nil
			continue
		end
		local root = rootOf(victim)
		if not root then
			launched[victim] = nil
			continue
		end
		local velocity = root.AssemblyLinearVelocity
		local speed = velocity.Magnitude
		if speed < BalanceConfig.Reactions.LaunchSpeedForWallSplat * 0.6 then
			continue
		end
		local ignoreList = table.clone(ignore)
		table.insert(ignoreList, victim)
		params.FilterDescendantsInstances = ignoreList
		local dir = velocity.Unit
		local hit = workspace:Raycast(root.Position, dir * (speed * dt * 3 + 2.5), params)
		if not hit or not hit.Instance:IsA("BasePart") then
			continue
		end
		if hit.Normal:Dot(dir) > -0.35 then
			continue -- glancing / floor
		end
		local part = hit.Instance :: BasePart
		if Hooks.structureImpact(part, hit.Position, speed * 10, launch.attackerCharacter) then
			continue -- smashed through; keep flying
		end
		launched[victim] = nil
		local reactions = BalanceConfig.Reactions
		Hooks.applyDamage(victim, {
			Amount = reactions.WallSplatDamage,
			Attacker = launch.attacker,
			AttackerCharacter = launch.attackerCharacter,
			Kind = "Splat",
			Position = hit.Position,
			NoReaction = true,
			Unblockable = true,
			Tag = "Wall Splat",
		})
		StatusService.stun(victim, reactions.WallSplatStun)
		local player = Players:GetPlayerFromCharacter(victim)
		if player then
			NetService.fireClient("Impulse", player, "Stop", Vector3.zero, nil)
		else
			root.AssemblyLinearVelocity = Vector3.zero
		end
		NetService.fireNear("Effect", hit.Position, EFFECT_RADIUS, "WallSplat", {
			Position = hit.Position,
			Normal = hit.Normal,
			Strength = math.clamp(speed / 150, 0.3, 1),
		})
	end
end

function ReactionService.init()
	RunService.Heartbeat:Connect(checkSplats)
end

return ReactionService
