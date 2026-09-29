--!strict
-- Glitch G (Ultimate): System Crash. Every enemy nearby freezes and takes heavy damage.

local AbilityTypes = require(script.Parent.Parent.Parent.AbilityTypes)
local AbilityKit = require(script.Parent.Parent.Parent.AbilityKit)


local SystemCrash: AbilityTypes.AbilityModule = {
	Begin = function(ctx)
		local windUp = ctx.Balance.WindUp or 0.5
		local radius = ctx.Balance.Range or 80
		local freezeTime = AbilityKit.param(ctx, "FreezeTime", 1.5)
		AbilityKit.pose(ctx, "Charge", { Duration = windUp })
		AbilityKit.fx("ChargeAura", ctx.Root.Position, { Source = ctx.Character, Color = Color3.fromRGB(255, 40, 200), Duration = windUp })
		task.delay(windUp, function()
			if not AbilityKit.isAlive(ctx.Character) then
				return
			end
			local center = ctx.Root.Position
			local hits = AbilityKit.falloffBlast(ctx, center, radius, 25, ctx.Balance.Damage, 0.6, 15, 10, nil, { NoReaction = true })
			for _, victim in hits do
				local root = AbilityKit.rootOf(victim)
				if root then
					AbilityKit.fx("PixelBurst", root.Position, { Position = root.Position, Radius = 5, Color = Color3.fromRGB(0, 255, 170) })
				end
				if AbilityKit.isAlive(victim) then
					AbilityKit.Status.apply(victim, "Freeze", "Control", freezeTime, 1, ctx.Player)
				end
			end
			AbilityKit.fx("PixelBurst", center, { Position = center, Radius = 18, Color = Color3.fromRGB(255, 40, 200) })
			AbilityKit.fx("Shockwave", center, { Position = center, Direction = Vector3.xAxis, Range = radius, Angle = 360, Color = Color3.fromRGB(0, 255, 170) })
			AbilityKit.fx("TraversalImpact", center, { Kind = "Blast", Position = center, Direction = Vector3.yAxis, Color = Color3.fromRGB(255, 40, 200), Source = ctx.Character, Strength = 1 })
		end)
		return true
	end,
}

return SystemCrash
