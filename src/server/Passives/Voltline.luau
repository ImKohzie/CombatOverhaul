--!strict
-- Voltline passive: Momentum. Sustained sprinting builds 4 tiers over ~6s,
-- each faster (ApexSpeedMultiplier via StatusService) with stronger lightning
-- visuals client-side (ApexMomentumTier). Slowing down, running into a wall
-- or taking a heavy hit resets it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("ApexCity")
local BalanceConfig = require(Shared.Config.BalanceConfig)

local AbilityKit = require(script.Parent.Parent.AbilityKit)
local DamageService = require(script.Parent.Parent.Services.DamageService)
local StatusService = require(script.Parent.Parent.Services.StatusService)

local Voltline = {}

function Voltline.onCharacter(_player: Player, character: Model): () -> ()
	local momentum = BalanceConfig.Momentum
	local runTime = 0
	local slowTime = 0
	local tier = 1

	local function setTier(newTier: number)
		if newTier == tier then
			return
		end
		tier = newTier
		character:SetAttribute("ApexMomentumTier", tier)
		if tier > 1 then
			StatusService.apply(character, "Momentum", "Speed", 3600, momentum.SpeedMultipliers[tier])
		else
			StatusService.remove(character, "Momentum")
		end
	end

	local function reset()
		runTime = 0
		slowTime = 0
		setTier(1)
	end

	character:SetAttribute("ApexMomentumTier", 1)
	local roleSpeed = BalanceConfig.getRole("Agile").WalkSpeed * BalanceConfig.Movement.SprintMultiplier

	local heartbeat = RunService.Heartbeat:Connect(function(dt)
		local root = AbilityKit.rootOf(character)
		if not root then
			return
		end
		local velocity = root.AssemblyLinearVelocity
		local flat = Vector3.new(velocity.X, 0, velocity.Z)
		local running = flat.Magnitude >= roleSpeed * momentum.MinSpeedFraction
		if running then
			slowTime = 0
			runTime += dt
			-- Wall check: something solid right in front while running flat out
			if tier > 1 then
				local hit = workspace:Raycast(root.Position, flat.Unit * 3, AbilityKit.worldParams())
				if hit and hit.Normal:Dot(flat.Unit) < -0.6 and character:GetAttribute("ApexPhasing") ~= true then
					reset()
					return
				end
			end
		else
			slowTime += dt
			if slowTime > momentum.DropGrace then
				runTime = 0
			end
		end
		setTier(math.clamp(math.floor(runTime / momentum.TierTime) + 1, 1, 4))
	end)

	local damaged = DamageService.Damaged:Connect(function(victim: Model, info: any, dealt: number)
		if victim == character and (dealt >= BalanceConfig.Reactions.HeavyHitThreshold or info.Ragdoll ~= nil) then
			reset()
		end
	end)

	return function()
		heartbeat:Disconnect()
		damaged:Disconnect()
		StatusService.remove(character, "Momentum")
	end
end

return Voltline
