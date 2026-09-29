--!strict
-- Magnus G (Ultimate): Iron Storm. Wreckage rains down on the target area.

local AbilityTypes = require(script.Parent.Parent.Parent.AbilityTypes)
local AbilityKit = require(script.Parent.Parent.Parent.AbilityKit)

local function groundAt(point: Vector3): Vector3
	local ground = AbilityKit.groundBelow(point + Vector3.new(0, 20, 0), 200)
	return if ground then ground.Position else point
end

local IronStorm: AbilityTypes.AbilityModule = {
	Begin = function(ctx)
		local duration = ctx.Balance.Duration or 3
		local radius = AbilityKit.param(ctx, "Radius", 35)
		local center = groundAt(ctx.AimPoint)
		local budget = AbilityKit.budget(ctx.Balance.Damage)
		local drops = math.floor(duration / 0.12)
		local each = ctx.Balance.Damage / 6
		AbilityKit.pose(ctx, "CastBoth", { Duration = duration })
		AbilityKit.fx("GroundCracks", center, { Position = center, Radius = radius, Color = Color3.fromRGB(255, 70, 90) })
		AbilityKit.fx("GravityRings", ctx.Root.Position, { Source = ctx.Character, Color = Color3.fromRGB(255, 70, 90), Duration = duration })
		task.spawn(function()
			for _ = 1, drops do
				if not AbilityKit.isAlive(ctx.Character) then
					return
				end
				local angle = math.random() * math.pi * 2
				local distance = math.sqrt(math.random()) * radius
				local spot = center + Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance)
				AbilityKit.projectile({
					Origin = spot + Vector3.new(math.random(-20, 20), 140, math.random(-20, 20)),
					Direction = (spot - (spot + Vector3.new(0, 140, 0))),
					Speed = 220,
					Range = 180,
					Radius = 2.5,
					Owner = ctx.Character,
					Visual = "Rock",
					VisualData = { Color = Color3.fromRGB(90, 90, 98), Width = 3.5 },
					OnHit = function(position)
						for _, victim in AbilityKit.inSphere(position, 8, { ctx.Character }) do
							local amount = budget(victim, each)
							if amount > 0 then
								AbilityKit.damage(ctx, victim, amount, { Kind = "AoE", Position = position, Knockback = AbilityKit.awayFrom(position, victim, 40, 25), HitStun = 0.5 })
							end
						end
						AbilityKit.Hooks.structureDamageSphere(position, 8, 450, 4000, ctx.Character)
						AbilityKit.fx("Explosion", position, { Position = position, Radius = 5, Kind = "Electric" })
					end,
				})
				task.wait(0.12)
			end
		end)
		return true
	end,
}

return IronStorm
