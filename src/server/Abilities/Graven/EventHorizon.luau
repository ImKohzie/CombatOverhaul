--!strict
-- Graven G (Ultimate): Event Horizon. Channel a massive gravity well that
-- drags everyone in and tears buildings apart piece by piece into its centre.

local RunService = game:GetService("RunService")

local AbilityTypes = require(script.Parent.Parent.Parent.AbilityTypes)
local AbilityKit = require(script.Parent.Parent.Parent.AbilityKit)

local EventHorizon: AbilityTypes.AbilityModule = {
	Begin = function(ctx)
		local duration = ctx.Balance.Duration or 6
		local range = ctx.Balance.Range or 120
		local center = ctx.AimPoint
		local ground = AbilityKit.groundBelow(center + Vector3.new(0, 10, 0), 200)
		if ground then
			center = ground.Position + Vector3.new(0, 18, 0)
		end
		AbilityKit.pose(ctx, "Channel", { Loop = true })
		AbilityKit.Status.apply(ctx.Character, "Horizon", "Speed", duration, 0.05)
		AbilityKit.fx("BlackHole", center, { Position = center, Radius = range, Duration = duration, Huge = true })
		local budget = AbilityKit.budget(ctx.Balance.Damage)
		task.spawn(function()
			local elapsed = 0
			local accumulator = 0
			local tearTimer = 0
			while elapsed < duration and AbilityKit.isAlive(ctx.Character) do
				local dt = RunService.Heartbeat:Wait()
				elapsed += dt
				accumulator += dt
				tearTimer += dt
				if accumulator >= 0.2 then
					accumulator = 0
					AbilityKit.pull(ctx, center, range, 45)
					for _, victim in AbilityKit.inSphere(center, range * 0.5, { ctx.Character }) do
						local root = AbilityKit.rootOf(victim)
						local close = root ~= nil and (root.Position - center).Magnitude < 25
						local amount = budget(victim, (if close then 90 else 40) * 0.2)
						if amount > 0 then
							AbilityKit.damage(ctx, victim, amount, { Kind = "DoT", NoReaction = true, Unblockable = true, Position = center })
						end
					end
				end
				if tearTimer >= 0.35 then
					tearTimer = 0
					local radius = 20 + (range * 0.5 - 20) * (elapsed / duration)
					AbilityKit.Hooks.structureDamageSphere(center, radius, 220, 2500, ctx.Character)
					AbilityKit.Hooks.pullDebris(center, range, 70)
				end
			end
			AbilityKit.stopPose(ctx)
			AbilityKit.fx("Explosion", center, { Position = center, Radius = 25, Kind = "Gravity" })
		end)
		return true
	end,
}

return EventHorizon
