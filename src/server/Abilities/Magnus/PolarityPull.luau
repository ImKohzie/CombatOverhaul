--!strict
-- Magnus E: Polarity Pull. Yank the enemy under the crosshair to you.

local AbilityTypes = require(script.Parent.Parent.Parent.AbilityTypes)
local AbilityKit = require(script.Parent.Parent.Parent.AbilityKit)


local PolarityPull: AbilityTypes.AbilityModule = {
	Begin = function(ctx)
		local target = AbilityKit.aimTarget(ctx, ctx.Balance.Range or 120, 14)
		local targetRoot = target and AbilityKit.rootOf(target)
		if not target or not targetRoot then
			AbilityKit.notify(ctx, "No target in range")
			return false
		end
		AbilityKit.pose(ctx, "Grab")
		local offset = ctx.Root.Position - targetRoot.Position
		local speed = math.clamp(offset.Magnitude * 2.4, 60, 220)
		AbilityKit.damage(ctx, target, ctx.Balance.Damage, {
			Kind = "AoE",
			Position = targetRoot.Position,
			Knockback = offset.Unit * speed + Vector3.new(0, 25, 0),
			HitStun = 0.7,
		})
		AbilityKit.fx("GravityRings", targetRoot.Position, { Source = target, Color = Color3.fromRGB(255, 70, 90), Duration = 0.8 })
		AbilityKit.fx("Afterimage", targetRoot.Position, { Source = ctx.Character, From = ctx.Root.Position, To = targetRoot.Position, Color = Color3.fromRGB(255, 70, 90) })
		return true
	end,
}

return PolarityPull
