--!strict
-- Undertow R: Whirlpool. A vortex that drags enemies in and spins them.

local AbilityTypes = require(script.Parent.Parent.Parent.AbilityTypes)
local AbilityKit = require(script.Parent.Parent.Parent.AbilityKit)

local function groundAt(point: Vector3): Vector3
	local ground = AbilityKit.groundBelow(point + Vector3.new(0, 20, 0), 200)
	return if ground then ground.Position else point
end

local TICK = 0.25

local Whirlpool: AbilityTypes.AbilityModule = {
	Begin = function(ctx)
		AbilityKit.pose(ctx, "CastBoth")
		local duration = ctx.Balance.Duration or 3
		local pullRadius = AbilityKit.param(ctx, "PullRadius", 28)
		local center = groundAt(ctx.AimPoint)
		local budget = AbilityKit.budget(ctx.Balance.Damage)
		local perTick = ctx.Balance.Damage / (duration / TICK) * 1.5
		AbilityKit.fx("Vortex", center, { Position = center, Radius = pullRadius * 0.7, Height = 2, Duration = duration, Color = Color3.fromRGB(40, 140, 210), Material = Enum.Material.Glass })
		task.spawn(function()
			local elapsed = 0
			while elapsed < duration do
				task.wait(TICK)
				elapsed += TICK
				AbilityKit.pull(ctx, center, pullRadius, 38)
				for _, victim in AbilityKit.inSphere(center, pullRadius * 0.45, { ctx.Character }) do
					local amount = budget(victim, perTick)
					if amount > 0 then
						AbilityKit.damage(ctx, victim, amount, { Kind = "DoT", Position = center, NoReaction = true })
					end
					AbilityKit.Status.apply(victim, "Drenched", "Speed", TICK + 0.3, 0.6, ctx.Player)
				end
			end
		end)
		return true
	end,
}

return Whirlpool
