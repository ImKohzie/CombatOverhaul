--!strict
-- Graven R: Weight. Multiply one target's gravity: flyers are forced down,
-- everyone is heavily slowed and crushed over time.

local AbilityTypes = require(script.Parent.Parent.Parent.AbilityTypes)
local AbilityKit = require(script.Parent.Parent.Parent.AbilityKit)
local MovementService = require(script.Parent.Parent.Parent.Services.MovementService)

local Players = game:GetService("Players")

local Weight: AbilityTypes.AbilityModule = {
	Begin = function(ctx)
		local target = AbilityKit.aimTarget(ctx, ctx.Balance.Range or 150, 12)
		if not target then
			AbilityKit.notify(ctx, "No target under the crosshair")
			return false
		end
		local duration = ctx.Balance.Duration or 4
		AbilityKit.pose(ctx, "CastRight")
		AbilityKit.Status.apply(target, "Weight", "Speed", duration, AbilityKit.param(ctx, "SpeedMultiplier", 0.5), ctx.Player)
		AbilityKit.Status.apply(target, "Grounded", "Flag", duration, 1, ctx.Player)
		local victimPlayer = Players:GetPlayerFromCharacter(target)
		if victimPlayer then
			MovementService.forceLand(victimPlayer)
		end
		AbilityKit.Reaction.knockback(target, Vector3.new(0, -120, 0), nil, ctx.Player, ctx.Character)
		AbilityKit.fx("GravityRings", target:GetPivot().Position, { Source = target, Duration = duration, Color = Color3.fromRGB(170, 110, 255) })
		task.spawn(function()
			local ticks = 4
			for _ = 1, ticks do
				if not AbilityKit.isAlive(target) then
					break
				end
				AbilityKit.damage(ctx, target, ctx.Balance.Damage / ticks, { Kind = "DoT", NoReaction = true, Unblockable = true })
				task.wait(duration / ticks)
			end
		end)
		return true
	end,
}

return Weight
