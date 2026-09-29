--!strict
-- Rebound E: Bounce House. Slam the ground and bounce every nearby enemy skyward.

local AbilityTypes = require(script.Parent.Parent.Parent.AbilityTypes)
local AbilityKit = require(script.Parent.Parent.Parent.AbilityKit)
local MovementService = require(script.Parent.Parent.Parent.Services.MovementService)


local BounceHouse: AbilityTypes.AbilityModule = {
	Begin = function(ctx)
		AbilityKit.pose(ctx, "Slam")
		task.delay(0.2, function()
			if not AbilityKit.isAlive(ctx.Character) then
				return
			end
			local radius = ctx.Balance.Range or 30
			local center = ctx.Root.Position
			for _, victim in AbilityKit.inSphere(center, radius, { ctx.Character }) do
				AbilityKit.damage(ctx, victim, ctx.Balance.Damage, { Kind = "AoE", Position = center, Knockback = AbilityKit.awayFrom(center, victim, 25, 125), Ragdoll = 1, HitStun = 0.8 })
			end
			MovementService.exempt(ctx.Player, 2)
			AbilityKit.impulseSelf(ctx, Vector3.new(0, 85, 0), 0.2)
			AbilityKit.Hooks.structureDamageSphere(center, radius * 0.4, 200, 3000, ctx.Character)
			AbilityKit.fx("Stomp", center, { Position = center, Radius = radius })
			AbilityKit.fx("GroundCracks", center, { Position = center, Radius = radius * 0.6, Color = Color3.fromRGB(255, 200, 40) })
			AbilityKit.fx("Shockwave", center, { Position = center, Direction = Vector3.xAxis, Range = radius, Angle = 360, Color = Color3.fromRGB(255, 120, 180) })
		end)
		return true
	end,
}

return BounceHouse
