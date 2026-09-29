--!strict
-- Glitch E: Buffer. Vanish and move faster.

local AbilityTypes = require(script.Parent.Parent.Parent.AbilityTypes)
local AbilityKit = require(script.Parent.Parent.Parent.AbilityKit)


local Buffer: AbilityTypes.AbilityModule = {
	Begin = function(ctx)
		local duration = ctx.Balance.Duration or 3
		AbilityKit.Status.apply(ctx.Character, "Invisible", "Flag", duration)
		AbilityKit.Status.apply(ctx.Character, "BufferSpeed", "Speed", duration, AbilityKit.param(ctx, "SpeedMultiplier", 1.5))
		AbilityKit.fx("PixelBurst", ctx.Root.Position, { Position = ctx.Root.Position, Radius = 6, Color = Color3.fromRGB(255, 40, 200) })
		return true
	end,
}

return Buffer
