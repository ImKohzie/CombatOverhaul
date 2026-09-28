--!strict
-- Swarm G (Ultimate): Grey Tide. A huge wave of nanites rolls outward and
-- lingers, damaging everyone inside over time and consuming structures.

local RunService = game:GetService("RunService")

local AbilityTypes = require(script.Parent.Parent.Parent.AbilityTypes)
local AbilityKit = require(script.Parent.Parent.Parent.AbilityKit)

local GreyTide: AbilityTypes.AbilityModule = {
	Begin = function(ctx)
		local duration = ctx.Balance.Duration or 6
		local maxRadius = ctx.Balance.Range or 110
		local center = ctx.Root.Position
		local dps = ctx.Balance.Damage / duration
		local budget = AbilityKit.budget(ctx.Balance.Damage)
		AbilityKit.pose(ctx, "Release")
		AbilityKit.fx("GreyTide", center, { Position = center, Radius = maxRadius, Duration = duration })
		task.spawn(function()
			local elapsed = 0
			local accumulator = 0
			local consume = 0
			while elapsed < duration do
				local dt = RunService.Heartbeat:Wait()
				elapsed += dt
				accumulator += dt
				consume += dt
				local radius = maxRadius * math.clamp(elapsed / (duration * 0.5), 0.1, 1)
				if accumulator >= 0.25 then
					accumulator = 0
					for _, victim in AbilityKit.inSphere(center, radius, { ctx.Character }) do
						local amount = budget(victim, dps * 0.25)
						if amount > 0 then
							AbilityKit.damage(ctx, victim, amount, { Kind = "DoT", NoReaction = true, Unblockable = true, Position = center })
							AbilityKit.Status.apply(victim, "Tide", "Speed", 0.4, 0.7, ctx.Player)
						end
					end
				end
				if consume >= 0.4 then
					consume = 0
					AbilityKit.Hooks.structureDamageSphere(center, radius, 110, 0, ctx.Character)
				end
			end
		end)
		return true
	end,
}

return GreyTide
