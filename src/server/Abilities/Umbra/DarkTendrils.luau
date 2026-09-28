--!strict
-- Umbra E: Dark Tendrils. Tendrils burst from the ground and bind a target.

local AbilityTypes = require(script.Parent.Parent.Parent.AbilityTypes)
local AbilityKit = require(script.Parent.Parent.Parent.AbilityKit)
local MovementService = require(script.Parent.Parent.Parent.Services.MovementService)

local Players = game:GetService("Players")

local DarkTendrils: AbilityTypes.AbilityModule = {
	Begin = function(ctx)
		local target = AbilityKit.aimTarget(ctx, ctx.Balance.Range or 80, 15)
		if not target then
			AbilityKit.notify(ctx, "No target under the crosshair")
			return false
		end
		AbilityKit.pose(ctx, "CastBoth")
		local bindTime = AbilityKit.param(ctx, "BindTime", 1.5)
		local victimPlayer = Players:GetPlayerFromCharacter(target)
		if victimPlayer then
			MovementService.forceLand(victimPlayer)
		end
		AbilityKit.Status.apply(target, "Bind", "Control", bindTime, 1, ctx.Player)
		task.spawn(function()
			local ticks = 3
			for _ = 1, ticks do
				if not AbilityKit.isAlive(target) then
					break
				end
				AbilityKit.damage(ctx, target, ctx.Balance.Damage / ticks, { Kind = "DoT", NoReaction = true, Unblockable = true })
				task.wait(bindTime / ticks)
			end
		end)
		return true
	end,
}

return DarkTendrils
