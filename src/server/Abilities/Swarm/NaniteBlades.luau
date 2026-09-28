--!strict
-- Swarm Q: Nanite Blades. Blades formed from the swarm for a spinning melee.

local AbilityTypes = require(script.Parent.Parent.Parent.AbilityTypes)
local AbilityKit = require(script.Parent.Parent.Parent.AbilityKit)

local TICKS = 6

local NaniteBlades: AbilityTypes.AbilityModule = {
	Begin = function(ctx)
		local duration = ctx.Balance.Duration or 1.5
		local radius = ctx.Balance.Range or 14
		local budget = AbilityKit.budget(ctx.Balance.Damage)
		AbilityKit.pose(ctx, "Spin", { Loop = true, Duration = duration })
		AbilityKit.fx("NaniteSwirl", ctx.Root.Position, { Source = ctx.Character, Radius = radius, Duration = duration })
		task.spawn(function()
			for i = 1, TICKS do
				if not AbilityKit.isAlive(ctx.Character) then
					break
				end
				local center = ctx.Root.Position
				for _, victim in AbilityKit.inSphere(center, radius, { ctx.Character }) do
					local amount = budget(victim, ctx.Balance.Damage / TICKS)
					if amount > 0 then
						AbilityKit.damage(ctx, victim, amount, {
							Kind = "Melee",
							Position = center,
							HitStun = 0.3,
							Knockback = if i == TICKS then AbilityKit.awayFrom(center, victim, 55, 20) else nil,
						})
					end
				end
				AbilityKit.Hooks.structureDamageSphere(center, radius * 0.6, 60, 600, ctx.Character)
				task.wait(duration / TICKS)
			end
			AbilityKit.stopPose(ctx)
		end)
		return true
	end,
}

return NaniteBlades
