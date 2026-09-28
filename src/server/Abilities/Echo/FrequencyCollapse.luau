--!strict
-- Echo G (Ultimate): Frequency Collapse. A massive resonant pulse: heavy
-- damage with falloff, and buildings vibrate and crumble from the base.

local AbilityTypes = require(script.Parent.Parent.Parent.AbilityTypes)
local AbilityKit = require(script.Parent.Parent.Parent.AbilityKit)

local FrequencyCollapse: AbilityTypes.AbilityModule = {
	Begin = function(ctx)
		local windUp = ctx.Balance.WindUp or 0.8
		local radius = ctx.Balance.Range or 120
		AbilityKit.pose(ctx, "Scream", { Duration = windUp + 0.6 })
		AbilityKit.fx("ChargeAura", ctx.Root.Position, { Source = ctx.Character, Color = Color3.fromRGB(255, 110, 220), Duration = windUp })
		task.delay(windUp, function()
			if not AbilityKit.isAlive(ctx.Character) then
				return
			end
			local center = ctx.Root.Position
			local hits = AbilityKit.falloffBlast(ctx, center, radius, 40, ctx.Balance.Damage, 0.5, 70, 25, nil)
			for _, victim in hits do
				AbilityKit.Status.stun(victim, 1, ctx.Player)
			end
			AbilityKit.Hooks.collapseFromBase(center, radius * 0.7, ctx.Character)
			AbilityKit.Hooks.shatterGlassCone(center, Vector3.xAxis, radius, 180, ctx.Character)
			for i = 0, 2 do
				task.delay(i * 0.12, function()
					AbilityKit.fx("Shockwave", center, { Position = center, Direction = Vector3.xAxis, Range = radius * (0.5 + i * 0.25), Angle = 360, Color = Color3.fromRGB(255, 110, 220) })
				end)
			end
			AbilityKit.fx("Explosion", center, { Position = center, Radius = 20, Kind = "Sonic" })
		end)
		return true
	end,
}

return FrequencyCollapse
