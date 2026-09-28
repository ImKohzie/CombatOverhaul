--!strict
-- Bastion E: Harden. Crystallise armour: big damage reduction, reflects
-- light projectiles, slower movement.

local AbilityTypes = require(script.Parent.Parent.Parent.AbilityTypes)
local AbilityKit = require(script.Parent.Parent.Parent.AbilityKit)

local Harden: AbilityTypes.AbilityModule = {
	Begin = function(ctx)
		local duration = ctx.Balance.Duration or 4
		AbilityKit.Status.apply(ctx.Character, "Hardened", "Flag", duration)
		AbilityKit.Status.apply(ctx.Character, "HardenArmor", "Reduction", duration, AbilityKit.param(ctx, "DamageReduction", 0.6))
		AbilityKit.Status.apply(ctx.Character, "HardenSlow", "Speed", duration, AbilityKit.param(ctx, "SpeedMultiplier", 0.7))
		AbilityKit.fx("ChargeAura", ctx.Root.Position, { Source = ctx.Character, Color = Color3.fromRGB(255, 170, 90), Duration = 0.6 })
		return true
	end,
}

return Harden
