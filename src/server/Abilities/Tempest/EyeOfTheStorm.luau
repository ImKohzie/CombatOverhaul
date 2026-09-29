--!strict
-- Tempest G (Ultimate): Eye of the Storm. A hurricane follows you, shredding everything nearby.

local AbilityTypes = require(script.Parent.Parent.Parent.AbilityTypes)
local AbilityKit = require(script.Parent.Parent.Parent.AbilityKit)


local TICK = 0.25

local EyeOfTheStorm: AbilityTypes.AbilityModule = {
	Begin = function(ctx)
		local duration = ctx.Balance.Duration or 5
		local radius = ctx.Balance.Range or 60
		local budget = AbilityKit.budget(ctx.Balance.Damage)
		local perTick = ctx.Balance.Damage / (duration / TICK) * 1.5
		AbilityKit.Status.apply(ctx.Character, "StormRider", "Speed", duration, 1.35)
		AbilityKit.fx("ChargeAura", ctx.Root.Position, { Source = ctx.Character, Color = Color3.fromRGB(150, 255, 230), Duration = 0.6 })
		AbilityKit.fx("Vortex", ctx.Root.Position, { Position = ctx.Root.Position, Source = ctx.Character, Radius = radius * 0.45, Height = 90, Duration = duration, Color = Color3.fromRGB(150, 170, 185) })
		task.spawn(function()
			local elapsed = 0
			while elapsed < duration and AbilityKit.isAlive(ctx.Character) do
				task.wait(TICK)
				elapsed += TICK
				local center = ctx.Root.Position
				AbilityKit.pull(ctx, center, radius, 28)
				for _, victim in AbilityKit.inSphere(center, radius * 0.5, { ctx.Character }) do
					local amount = budget(victim, perTick)
					if amount > 0 then
						AbilityKit.damage(ctx, victim, amount, { Kind = "DoT", Position = center, Knockback = Vector3.new(0, 30, 0), HitStun = 0.3 })
					end
				end
				local angle = elapsed * 3
				local spot = center + Vector3.new(math.cos(angle), 0, math.sin(angle)) * radius * 0.4
				AbilityKit.Hooks.structureDamageSphere(spot, 10, 120, 2500, ctx.Character)
				AbilityKit.Hooks.shatterGlassCone(center, Vector3.new(math.cos(angle), 0, math.sin(angle)), radius, 40, ctx.Character)
			end
		end)
		return true
	end,
}

return EyeOfTheStorm
