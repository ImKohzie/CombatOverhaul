--!strict
-- Thornwild R: Barkskin. Harden into bark and regrow health.

local AbilityTypes = require(script.Parent.Parent.Parent.AbilityTypes)
local AbilityKit = require(script.Parent.Parent.Parent.AbilityKit)


local Barkskin: AbilityTypes.AbilityModule = {
	Begin = function(ctx)
		local duration = ctx.Balance.Duration or 4
		local heal = AbilityKit.param(ctx, "Heal", 200)
		AbilityKit.Status.apply(ctx.Character, "BarkArmor", "Reduction", duration, AbilityKit.param(ctx, "DamageReduction", 0.5))
		AbilityKit.Status.apply(ctx.Character, "Unstoppable", "Flag", duration)
		AbilityKit.fx("ChargeAura", ctx.Root.Position, { Source = ctx.Character, Color = Color3.fromRGB(140, 220, 80), Duration = duration })
		AbilityKit.fx("GroundCracks", ctx.Root.Position, { Position = ctx.Root.Position - Vector3.new(0, 3, 0), Radius = 10, Color = Color3.fromRGB(120, 200, 70) })
		task.spawn(function()
			local ticks = 8
			for _ = 1, ticks do
				task.wait(duration / ticks)
				if not AbilityKit.isAlive(ctx.Character) then
					return
				end
				ctx.Humanoid.Health = math.min(ctx.Humanoid.MaxHealth, ctx.Humanoid.Health + heal / ticks)
			end
		end)
		return true
	end,
}

return Barkskin
