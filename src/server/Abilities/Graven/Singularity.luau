--!strict
-- Graven Q: Singularity. Launch a small black hole that pulls players and
-- debris in, then detonates.

local RunService = game:GetService("RunService")

local AbilityTypes = require(script.Parent.Parent.Parent.AbilityTypes)
local AbilityKit = require(script.Parent.Parent.Parent.AbilityKit)

local function hole(ctx: AbilityTypes.AbilityContext, center: Vector3)
	local duration = ctx.Balance.Duration or 2.5
	local radius = AbilityKit.param(ctx, "PullRadius", 40)
	local budget = AbilityKit.budget(ctx.Balance.Damage)
	local dotShare = ctx.Balance.Damage * 0.5
	AbilityKit.fx("BlackHole", center, { Position = center, Radius = radius, Duration = duration })
	local elapsed = 0
	local accumulator = 0
	while elapsed < duration do
		local dt = RunService.Heartbeat:Wait()
		elapsed += dt
		accumulator += dt
		if accumulator >= 0.2 then
			accumulator = 0
			AbilityKit.pull(ctx, center, radius, 30)
			for _, victim in AbilityKit.inSphere(center, radius * 0.5, { ctx.Character }) do
				local amount = budget(victim, dotShare * 0.2 / duration)
				if amount > 0 then
					AbilityKit.damage(ctx, victim, amount, { Kind = "DoT", NoReaction = true, Position = center })
				end
			end
		end
	end
	-- Detonate
	for _, victim in AbilityKit.inSphere(center, 15, { ctx.Character }) do
		local amount = budget(victim, ctx.Balance.Damage)
		if amount > 0 then
			AbilityKit.damage(ctx, victim, amount, {
				Kind = "AoE",
				Position = center,
				Knockback = AbilityKit.awayFrom(center, victim, 80, 35),
				Ragdoll = 1,
				HitStun = 0.7,
			})
		end
	end
	AbilityKit.Hooks.structureDamageSphere(center, 14, 300, 3000, ctx.Character)
	AbilityKit.fx("Explosion", center, { Position = center, Radius = 15, Kind = "Gravity" })
end

local Singularity: AbilityTypes.AbilityModule = {
	Begin = function(ctx)
		AbilityKit.pose(ctx, "CastRight")
		local origin = ctx.Root.Position + Vector3.new(0, 1.5, 0) + ctx.Root.CFrame.LookVector * 2
		local range = math.min((ctx.AimPoint - origin).Magnitude, ctx.Balance.Range or 150)
		AbilityKit.projectile({
			Origin = origin,
			Direction = ctx.AimPoint - origin,
			Speed = 90,
			Range = math.max(range, 8),
			Radius = 1,
			Owner = ctx.Character,
			Visual = "Orb",
			VisualData = { Color = Color3.fromRGB(40, 0, 70), Width = 1.6 },
			OnHit = function(position)
				task.spawn(hole, ctx, position)
			end,
		})
		return true
	end,
}

return Singularity
