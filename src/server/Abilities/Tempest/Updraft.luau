--!strict
-- Tempest R: Updraft. Blast yourself and nearby enemies skyward.

local AbilityTypes = require(script.Parent.Parent.Parent.AbilityTypes)
local AbilityKit = require(script.Parent.Parent.Parent.AbilityKit)
local MovementService = require(script.Parent.Parent.Parent.Services.MovementService)


local Updraft: AbilityTypes.AbilityModule = {
	Begin = function(ctx)
		local radius = ctx.Balance.Range or 25
		local center = ctx.Root.Position
		MovementService.exempt(ctx.Player, 2)
		AbilityKit.pose(ctx, "Leap")
		for _, victim in AbilityKit.inSphere(center, radius, { ctx.Character }) do
			AbilityKit.damage(ctx, victim, ctx.Balance.Damage, { Kind = "AoE", Position = center, Knockback = AbilityKit.awayFrom(center, victim, 20, 115), Ragdoll = 1, HitStun = 0.8 })
		end
		AbilityKit.impulseSelf(ctx, Vector3.new(0, 150, 0), 0.25)
		AbilityKit.Hooks.pullDebris(center, radius, -90)
		AbilityKit.fx("Vortex", center, { Position = center - Vector3.new(0, 3, 0), Radius = radius * 0.5, Height = 35, Duration = 0.7, Color = Color3.fromRGB(200, 240, 235) })
		AbilityKit.fx("Shockwave", center, { Position = center, Direction = Vector3.xAxis, Range = radius, Angle = 360, Color = Color3.fromRGB(150, 255, 230) })
		return true
	end,
}

return Updraft
