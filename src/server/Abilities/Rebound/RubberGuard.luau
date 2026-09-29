--!strict
-- Rebound R: Rubber Guard. Go elastic: less damage, and light projectiles bounce back.

local AbilityTypes = require(script.Parent.Parent.Parent.AbilityTypes)
local AbilityKit = require(script.Parent.Parent.Parent.AbilityKit)


local RubberGuard: AbilityTypes.AbilityModule = {
	Begin = function(ctx)
		local duration = ctx.Balance.Duration or 3
		AbilityKit.Status.apply(ctx.Character, "Hardened", "Flag", duration)
		AbilityKit.Status.apply(ctx.Character, "RubberArmor", "Reduction", duration, AbilityKit.param(ctx, "DamageReduction", 0.5))
		AbilityKit.Status.apply(ctx.Character, "Unstoppable", "Flag", duration)
		AbilityKit.pose(ctx, "Crouch", { Duration = 0.5 })
		AbilityKit.fx("ChargeAura", ctx.Root.Position, { Source = ctx.Character, Color = Color3.fromRGB(255, 200, 40), Duration = duration })
		return true
	end,
}

return RubberGuard
