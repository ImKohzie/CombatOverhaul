--!strict
-- Hexa E: Hex Snare. A rune that roots enemies standing in it.

local AbilityTypes = require(script.Parent.Parent.Parent.AbilityTypes)
local AbilityKit = require(script.Parent.Parent.Parent.AbilityKit)

local function groundAt(point: Vector3): Vector3
	local ground = AbilityKit.groundBelow(point + Vector3.new(0, 20, 0), 200)
	return if ground then ground.Position else point
end

local HexSnare: AbilityTypes.AbilityModule = {
	Begin = function(ctx)
		AbilityKit.pose(ctx, "CastBoth")
		local windUp = ctx.Balance.WindUp or 0.4
		local radius = AbilityKit.param(ctx, "Radius", 12)
		local bindTime = AbilityKit.param(ctx, "BindTime", 1.6)
		local center = groundAt(ctx.AimPoint)
		AbilityKit.fx("Rune", center, { Position = center, Radius = radius, Duration = windUp + bindTime, Color = Color3.fromRGB(200, 120, 255) })
		task.delay(windUp, function()
			for _, victim in AbilityKit.inSphere(center + Vector3.new(0, 3, 0), radius, { ctx.Character }) do
				AbilityKit.damage(ctx, victim, ctx.Balance.Damage, { Kind = "AoE", Position = center, NoReaction = true })
				if AbilityKit.isAlive(victim) then
					AbilityKit.Status.apply(victim, "Bind", "Control", bindTime, 1, ctx.Player)
				end
			end
			AbilityKit.fx("Explosion", center, { Position = center, Radius = radius * 0.6, Kind = "Nova" })
		end)
		return true
	end,
}

return HexSnare
