--!strict
-- Thornwild G (Ultimate): Overgrowth. Vines erupt everywhere, binding and crushing.

local AbilityTypes = require(script.Parent.Parent.Parent.AbilityTypes)
local AbilityKit = require(script.Parent.Parent.Parent.AbilityKit)


local Overgrowth: AbilityTypes.AbilityModule = {
	Begin = function(ctx)
		local windUp = ctx.Balance.WindUp or 0.6
		local radius = ctx.Balance.Range or 70
		local bindTime = AbilityKit.param(ctx, "BindTime", 2)
		AbilityKit.pose(ctx, "Slam", { Duration = windUp + 0.4 })
		AbilityKit.fx("ChargeAura", ctx.Root.Position, { Source = ctx.Character, Color = Color3.fromRGB(160, 255, 80), Duration = windUp })
		task.delay(windUp, function()
			if not AbilityKit.isAlive(ctx.Character) then
				return
			end
			local center = ctx.Root.Position
			local hits = AbilityKit.falloffBlast(ctx, center, radius, 20, ctx.Balance.Damage, 0.6, 30, 55, nil)
			for _, victim in hits do
				if AbilityKit.isAlive(victim) then
					AbilityKit.Status.apply(victim, "Bind", "Control", bindTime, 1, ctx.Player)
				end
			end
			for ring = 1, 4 do
				task.delay(ring * 0.08, function()
					local count = 6 + ring * 4
					local distance = radius * ring / 4
					for i = 1, count do
						local angle = (i / count) * math.pi * 2 + ring
						local probe = center + Vector3.new(math.cos(angle) * distance, 20, math.sin(angle) * distance)
						local ground = AbilityKit.groundBelow(probe, 80)
						if ground then
							AbilityKit.fx("IceSpike", ground.Position, { Position = ground.Position, Height = 10 + ring * 2, Color = Color3.fromRGB(96, 120, 52), Material = Enum.Material.Wood })
							if i % 3 == 0 then
								AbilityKit.Hooks.structureDamageSphere(ground.Position, 8, 350, 3000, ctx.Character)
							end
						end
					end
				end)
			end
			AbilityKit.fx("Shockwave", center, { Position = center, Direction = Vector3.xAxis, Range = radius, Angle = 360, Color = Color3.fromRGB(140, 220, 80) })
		end)
		return true
	end,
}

return Overgrowth
