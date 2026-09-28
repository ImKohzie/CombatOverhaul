--!strict
-- Rampage G (Ultimate): World Breaker. Repeated ground punches that fracture
-- everything in a widening radius with gamma-green eruptions.

local AbilityTypes = require(script.Parent.Parent.Parent.AbilityTypes)
local AbilityKit = require(script.Parent.Parent.Parent.AbilityKit)

local PUNCHES = 8

local WorldBreaker: AbilityTypes.AbilityModule = {
	Begin = function(ctx)
		local duration = ctx.Balance.Duration or 4
		local maxRadius = ctx.Balance.Range or 80
		local interval = duration / PUNCHES
		local budget = AbilityKit.budget(ctx.Balance.Damage)
		AbilityKit.Status.apply(ctx.Character, "WorldBreaker", "Speed", duration, 0.05)
		AbilityKit.Status.apply(ctx.Character, "Unstoppable", "Flag", duration)
		task.spawn(function()
			for i = 1, PUNCHES do
				if not AbilityKit.isAlive(ctx.Character) then
					break
				end
				AbilityKit.pose(ctx, "Slam", { Speed = 1.6 })
				task.wait(interval * 0.45)
				local ground = AbilityKit.groundBelow(ctx.Root.Position)
				local center = if ground then ground.Position else ctx.Root.Position
				local radius = 20 + (maxRadius - 20) * (i / PUNCHES)
				local final = i == PUNCHES
				for _, victim in AbilityKit.inSphere(center, radius, { ctx.Character }) do
					local amount = budget(victim, if final then 120 else 50)
					if amount > 0 then
						AbilityKit.damage(ctx, victim, amount, {
							Kind = "AoE",
							Position = center,
							Knockback = AbilityKit.awayFrom(center, victim, if final then 90 else 20, if final then 50 else 35),
							Ragdoll = if final then 1.5 else nil,
							HitStun = 0.6,
						})
					end
				end
				AbilityKit.Hooks.structureDamageSphere(center, radius, if final then 900 else 350, 4000, ctx.Character)
				AbilityKit.fx("Shockwave", center, { Position = center, Direction = Vector3.xAxis, Range = radius, Angle = 360, Color = Color3.fromRGB(150, 255, 90) })
				AbilityKit.fx("GroundCracks", center, { Position = center, Radius = radius, Color = Color3.fromRGB(120, 255, 60) })
				for _ = 1, 3 do
					local angle = math.random() * math.pi * 2
					local distance = math.random() * radius
					local spot = center + Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance)
					AbilityKit.fx("Explosion", spot, { Position = spot, Radius = 8, Kind = "Radiation" })
				end
				task.wait(interval * 0.55)
			end
		end)
		return true
	end,
}

return WorldBreaker
