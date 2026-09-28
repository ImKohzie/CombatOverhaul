--!strict
-- Graven E: Float. Lift everything loose and everyone nearby into the air,
-- then slam them down.

local AbilityTypes = require(script.Parent.Parent.Parent.AbilityTypes)
local AbilityKit = require(script.Parent.Parent.Parent.AbilityKit)

local Float: AbilityTypes.AbilityModule = {
	Begin = function(ctx)
		local radius = ctx.Balance.Range or 35
		local hang = ctx.Balance.Duration or 2
		local center = ctx.Root.Position
		AbilityKit.pose(ctx, "CastBoth")
		local lifted = AbilityKit.inSphere(center, radius, { ctx.Character })
		for _, victim in lifted do
			AbilityKit.Status.apply(victim, "Float", "Control", hang + 0.4, 1, ctx.Player)
			AbilityKit.Reaction.knockback(victim, Vector3.new(0, 55, 0), nil, ctx.Player, ctx.Character)
		end
		AbilityKit.Hooks.pullDebris(center + Vector3.new(0, 40, 0), radius, 40)
		AbilityKit.fx("Shockwave", center, { Position = center, Direction = Vector3.yAxis, Range = radius, Angle = 360, Color = Color3.fromRGB(170, 110, 255) })
		task.delay(hang * 0.6, function()
			for _, victim in lifted do
				AbilityKit.Reaction.knockback(victim, Vector3.new(0, -160, 0), nil, ctx.Player, ctx.Character)
			end
			AbilityKit.Hooks.pullDebris(center - Vector3.new(0, 60, 0), radius, 120)
		end)
		task.delay(hang * 0.6 + 0.35, function()
			for _, victim in lifted do
				local root = AbilityKit.rootOf(victim)
				if root then
					AbilityKit.damage(ctx, victim, ctx.Balance.Damage, {
						Kind = "AoE",
						Unblockable = true,
						Position = root.Position,
						Ragdoll = 0.8,
						HitStun = 0.6,
					})
					AbilityKit.fx("Crater", root.Position, { Position = root.Position - Vector3.new(0, 3, 0), Strength = 0.5, Color = Color3.fromRGB(170, 110, 255) })
				end
			end
		end)
		return true
	end,
}

return Float
