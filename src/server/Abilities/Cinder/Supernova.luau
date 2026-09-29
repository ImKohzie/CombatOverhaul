--!strict
-- Cinder G (Ultimate): Supernova. Charge, then detonate like a star.

local AbilityTypes = require(script.Parent.Parent.Parent.AbilityTypes)
local AbilityKit = require(script.Parent.Parent.Parent.AbilityKit)


local Supernova: AbilityTypes.AbilityModule = {
	Begin = function(ctx)
		local windUp = ctx.Balance.WindUp or 1.2
		local radius = ctx.Balance.Range or 90
		AbilityKit.Status.apply(ctx.Character, "Unstoppable", "Flag", windUp + 0.3)
		AbilityKit.pose(ctx, "Charge", { Duration = windUp, Loop = true })
		AbilityKit.fx("ChargeAura", ctx.Root.Position, { Source = ctx.Character, Color = Color3.fromRGB(255, 150, 40), Duration = windUp })
		task.delay(windUp, function()
			if not AbilityKit.isAlive(ctx.Character) then
				return
			end
			AbilityKit.stopPose(ctx)
			local center = ctx.Root.Position
			AbilityKit.falloffBlast(ctx, center, radius, 25, ctx.Balance.Damage, 0.4, 120, 50, 1.4)
			AbilityKit.Hooks.collapseFromBase(center, radius * 0.45, ctx.Character)
			AbilityKit.Hooks.structureDamageSphere(center, radius * 0.5, 900, 7000, ctx.Character)
			AbilityKit.Hooks.shatterGlassCone(center, Vector3.xAxis, radius * 1.4, 180, ctx.Character)
			AbilityKit.fx("Explosion", center, { Position = center, Radius = 34, Kind = "Fire" })
			for i = 0, 2 do
				task.delay(i * 0.12, function()
					AbilityKit.fx("Shockwave", center, { Position = center, Direction = Vector3.xAxis, Range = radius * (0.5 + i * 0.25), Angle = 360, Color = Color3.fromRGB(255, 190, 90) })
				end)
			end
			AbilityKit.fx("TraversalImpact", center, { Kind = "Blast", Position = center, Direction = Vector3.yAxis, Color = Color3.fromRGB(255, 150, 40), Source = ctx.Character, Strength = 1 })
		end)
		return true
	end,
}

return Supernova
