--!strict
-- Magnus R: Repulse. A magnetic shockwave that hurls enemies and debris away.

local AbilityTypes = require(script.Parent.Parent.Parent.AbilityTypes)
local AbilityKit = require(script.Parent.Parent.Parent.AbilityKit)


local Repulse: AbilityTypes.AbilityModule = {
	Begin = function(ctx)
		AbilityKit.pose(ctx, "Clap")
		local radius = ctx.Balance.Range or 40
		local center = ctx.Root.Position
		AbilityKit.blast(ctx, center, radius, ctx.Balance.Damage, 125, 35, 0.9, 260)
		AbilityKit.Hooks.pullDebris(center, radius + 15, -160)
		AbilityKit.fx("Shockwave", center, { Position = center, Direction = Vector3.xAxis, Range = radius, Angle = 360, Color = Color3.fromRGB(255, 70, 90) })
		AbilityKit.fx("Explosion", center, { Position = center, Radius = 8, Kind = "Electric" })
		return true
	end,
}

return Repulse
