--!strict
-- Hexa G (Ultimate): Rune Circle. A giant rune that erupts again and again.

local AbilityTypes = require(script.Parent.Parent.Parent.AbilityTypes)
local AbilityKit = require(script.Parent.Parent.Parent.AbilityKit)

local function groundAt(point: Vector3): Vector3
	local ground = AbilityKit.groundBelow(point + Vector3.new(0, 20, 0), 200)
	return if ground then ground.Position else point
end

local TICK = 0.5

local RuneCircle: AbilityTypes.AbilityModule = {
	Begin = function(ctx)
		local duration = ctx.Balance.Duration or 5
		local radius = AbilityKit.param(ctx, "Radius", 40)
		local center = groundAt(ctx.AimPoint)
		local budget = AbilityKit.budget(ctx.Balance.Damage)
		local perTick = ctx.Balance.Damage / (duration / TICK) * 1.3
		AbilityKit.pose(ctx, "Channel", { Duration = 1 })
		AbilityKit.fx("Rune", center, { Position = center, Radius = radius, Duration = duration, Color = Color3.fromRGB(200, 120, 255) })
		task.spawn(function()
			local elapsed = 0
			while elapsed < duration do
				task.wait(TICK)
				elapsed += TICK
				for _, victim in AbilityKit.inSphere(center, radius, { ctx.Character }) do
					local root = AbilityKit.rootOf(victim)
					if root and math.abs(root.Position.Y - center.Y) < 25 then
						local amount = budget(victim, perTick)
						if amount > 0 then
							AbilityKit.damage(ctx, victim, amount, { Kind = "DoT", Position = root.Position, Knockback = Vector3.new(0, 30, 0), HitStun = 0.3 })
						end
						AbilityKit.Status.apply(victim, "RuneSlow", "Speed", TICK + 0.2, 0.55, ctx.Player)
					end
				end
				local angle = math.random() * math.pi * 2
				local spot = center + Vector3.new(math.cos(angle), 0, math.sin(angle)) * math.random() * radius
				AbilityKit.fx("Explosion", spot, { Position = spot, Radius = 7, Kind = "Nova" })
				AbilityKit.Hooks.structureDamageSphere(spot, 8, 220, 2500, ctx.Character)
			end
		end)
		return true
	end,
}

return RuneCircle
