--!strict
-- Argent G (Ultimate): Nova Collapse. Absorb the light around you (screen
-- darkens nearby), then release a starburst that disintegrates structures.

local AbilityTypes = require(script.Parent.Parent.Parent.AbilityTypes)
local AbilityKit = require(script.Parent.Parent.Parent.AbilityKit)

local NovaCollapse: AbilityTypes.AbilityModule = {
	Begin = function(ctx)
		local windUp = ctx.Balance.WindUp or 1.2
		local radius = ctx.Balance.Range or 90
		AbilityKit.pose(ctx, "Crouch", { Loop = true })
		AbilityKit.Status.apply(ctx.Character, "Absorb", "Speed", windUp, 0.1)
		AbilityKit.fx("Absorb", ctx.Root.Position, { Source = ctx.Character, Position = ctx.Root.Position, Radius = radius, Duration = windUp })
		task.delay(windUp, function()
			if not AbilityKit.isAlive(ctx.Character) then
				return
			end
			AbilityKit.pose(ctx, "Release")
			local center = ctx.Root.Position
			AbilityKit.falloffBlast(ctx, center, radius, 30, ctx.Balance.Damage, 0.55, 100, 30, 1.5)
			AbilityKit.Hooks.structureDamageSphere(center, radius * 0.5, 6000, 8000, ctx.Character)
			AbilityKit.fx("Explosion", center, { Position = center, Radius = radius * 0.5, Kind = "Nova" })
			AbilityKit.fx("Shockwave", center, { Position = center, Direction = Vector3.xAxis, Range = radius, Angle = 360, Color = Color3.fromRGB(230, 240, 255) })
		end)
		return true
	end,
}

return NovaCollapse
