--!strict
-- Sovereign R: Skyfall Grab. Seize the target in front, rocket straight up,
-- then drive them into the ground. The server takes physics control of both
-- characters for the sequence (always released, even on error).

local RunService = game:GetService("RunService")

local AbilityTypes = require(script.Parent.Parent.Parent.AbilityTypes)
local AbilityKit = require(script.Parent.Parent.Parent.AbilityKit)

local RISE_TIME = 0.8
local HANG_TIME = 0.15
local SLAM_TIME = 0.32

local function sequence(ctx: AbilityTypes.AbilityContext, victim: Model)
	local victimRoot = AbilityKit.rootOf(victim)
	if not victimRoot then
		return
	end
	local lift = AbilityKit.param(ctx, "LiftHeight", 120)
	AbilityKit.takeControl(ctx.Character)
	AbilityKit.takeControl(victim)
	AbilityKit.Status.apply(victim, "Grabbed", "Control", RISE_TIME + HANG_TIME + SLAM_TIME + 0.5, 1, ctx.Player)
	AbilityKit.pose(ctx, "Grab")

	local start = ctx.Root.CFrame
	local top = start + Vector3.new(0, lift, 0)
	local function holdVictim(attackerCF: CFrame)
		local held = attackerCF * CFrame.new(0, 0, -3.2) * CFrame.Angles(0, math.pi, 0)
		victimRoot.CFrame = held
	end

	-- Rise
	local elapsed = 0
	while elapsed < RISE_TIME and ctx.Root.Parent and victimRoot.Parent do
		elapsed += RunService.Heartbeat:Wait()
		local t = math.clamp(elapsed / RISE_TIME, 0, 1)
		local eased = 1 - (1 - t) ^ 3
		local cf = start:Lerp(top, eased)
		ctx.Root.CFrame = cf
		holdVictim(cf)
	end
	task.wait(HANG_TIME)

	-- Slam: flip over and drive down to the ground below
	local ground = AbilityKit.groundBelow(top.Position, lift + 400)
	local groundY = if ground then ground.Position.Y else start.Position.Y - 3
	local slamTarget = CFrame.new(top.Position.X, groundY + 3, top.Position.Z) * top.Rotation
	local from = ctx.Root.CFrame
	elapsed = 0
	while elapsed < SLAM_TIME and ctx.Root.Parent and victimRoot.Parent do
		elapsed += RunService.Heartbeat:Wait()
		local t = math.clamp(elapsed / SLAM_TIME, 0, 1)
		local cf = from:Lerp(slamTarget, t * t)
		ctx.Root.CFrame = cf
		victimRoot.CFrame = CFrame.new(cf.Position.X, cf.Position.Y - 2.5, cf.Position.Z - 0) * CFrame.Angles(math.rad(90), 0, 0)
	end

	local impact = Vector3.new(slamTarget.Position.X, groundY, slamTarget.Position.Z)
	AbilityKit.releaseControl(victim, Vector3.zero)
	AbilityKit.releaseControl(ctx.Character, Vector3.new(0, 20, 0))
	AbilityKit.Status.remove(victim, "Grabbed")
	AbilityKit.damage(ctx, victim, ctx.Balance.Damage, {
		Kind = "Heavy",
		Unblockable = true,
		Position = impact,
		Ragdoll = 1.4,
		Knockback = Vector3.new(0, 25, 0),
		HitStun = 1,
	})
	-- Splash damage to anyone standing at the impact point
	for _, other in AbilityKit.inSphere(impact, 14, { ctx.Character, victim }) do
		AbilityKit.damage(ctx, other, ctx.Balance.Damage * 0.35, {
			Kind = "AoE",
			Position = impact,
			Knockback = AbilityKit.awayFrom(impact, other, 55, 30),
			Ragdoll = 0.8,
		})
	end
	AbilityKit.Hooks.structureDamageSphere(impact, 16, 220, 2500, ctx.Character)
	AbilityKit.fx("Crater", impact, { Position = impact, Strength = 1, Source = ctx.Character, Color = Color3.fromRGB(255, 60, 40) })
end

local SkyfallGrab: AbilityTypes.AbilityModule = {
	Begin = function(ctx)
		local victim = AbilityKit.aimTarget(ctx, ctx.Balance.Range or 14, 50)
		if not victim then
			AbilityKit.notify(ctx, "Nobody in reach to grab")
			return false
		end
		task.spawn(function()
			local ok, err = pcall(sequence, ctx, victim)
			if not ok then
				warn("[SkyfallGrab] " .. tostring(err))
				AbilityKit.releaseControl(ctx.Character)
				AbilityKit.releaseControl(victim)
			end
		end)
		return true
	end,
}

return SkyfallGrab
