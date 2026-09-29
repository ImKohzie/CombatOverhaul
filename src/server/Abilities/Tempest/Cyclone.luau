--!strict
-- Tempest E: Cyclone. A tornado that drags enemies and debris in.

local AbilityTypes = require(script.Parent.Parent.Parent.AbilityTypes)
local AbilityKit = require(script.Parent.Parent.Parent.AbilityKit)

local function groundAt(point: Vector3): Vector3
	local ground = AbilityKit.groundBelow(point + Vector3.new(0, 20, 0), 200)
	return if ground then ground.Position else point
end

local TICK = 0.25

local Cyclone: AbilityTypes.AbilityModule = {
	Begin = function(ctx)
		AbilityKit.pose(ctx, "CastBoth")
		local duration = ctx.Balance.Duration or 3
		local pullRadius = AbilityKit.param(ctx, "PullRadius", 30)
		local center = groundAt(ctx.AimPoint)
		local budget = AbilityKit.budget(ctx.Balance.Damage)
		local perTick = ctx.Balance.Damage / (duration / TICK) * 1.6
		AbilityKit.fx("Vortex", center, { Position = center, Radius = 12, Height = 55, Duration = duration, Color = Color3.fromRGB(200, 225, 230) })
		task.spawn(function()
			local elapsed = 0
			while elapsed < duration do
				task.wait(TICK)
				elapsed += TICK
				AbilityKit.pull(ctx, center, pullRadius, 45)
				for _, victim in AbilityKit.inSphere(center + Vector3.new(0, 6, 0), 9, { ctx.Character }) do
					local amount = budget(victim, perTick)
					if amount > 0 then
						AbilityKit.damage(ctx, victim, amount, { Kind = "DoT", Position = center, Knockback = Vector3.new(0, 45, 0), HitStun = 0.3 })
					end
				end
				AbilityKit.Hooks.structureDamageSphere(center + Vector3.new(0, 8, 0), 9, 60, 1500, ctx.Character)
			end
		end)
		return true
	end,
}

return Cyclone
