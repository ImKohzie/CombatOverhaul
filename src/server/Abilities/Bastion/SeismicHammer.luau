--!strict
-- Bastion R: Seismic Hammer. Double-fist ground slam: radial shockwave and
-- ground cracks.

local AbilityTypes = require(script.Parent.Parent.Parent.AbilityTypes)
local AbilityKit = require(script.Parent.Parent.Parent.AbilityKit)

local SeismicHammer: AbilityTypes.AbilityModule = {
	Begin = function(ctx)
		local windUp = ctx.Balance.WindUp or 0.6
		AbilityKit.pose(ctx, "Slam")
		AbilityKit.Status.apply(ctx.Character, "SlamRoot", "Speed", windUp + 0.3, 0.2)
		task.delay(windUp, function()
			if not AbilityKit.isAlive(ctx.Character) then
				return
			end
			local radius = ctx.Balance.Range or 30
			local ground = AbilityKit.groundBelow(ctx.Root.Position)
			local center = if ground then ground.Position else ctx.Root.Position - Vector3.new(0, 3, 0)
			AbilityKit.falloffBlast(ctx, center, radius, radius * 0.35, ctx.Balance.Damage, 0.5, 55, 45, 0.8)
			AbilityKit.Hooks.structureDamageSphere(center, radius * 0.6, 300, 2500, ctx.Character)
			AbilityKit.fx("Shockwave", center, { Position = center, Direction = Vector3.xAxis, Range = radius, Angle = 360, Color = Color3.fromRGB(255, 150, 80) })
			AbilityKit.fx("GroundCracks", center, { Position = center, Radius = radius, Color = Color3.fromRGB(255, 120, 40) })
		end)
		return true
	end,
}

return SeismicHammer
