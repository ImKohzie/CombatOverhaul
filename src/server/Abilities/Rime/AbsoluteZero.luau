--!strict
-- Rime G (Ultimate): Absolute Zero. Freeze the whole area: enemies are
-- frozen and chilled, and structures turn brittle (shatter from any hit)
-- for 8s.

local RunService = game:GetService("RunService")

local AbilityTypes = require(script.Parent.Parent.Parent.AbilityTypes)
local AbilityKit = require(script.Parent.Parent.Parent.AbilityKit)

local AbsoluteZero: AbilityTypes.AbilityModule = {
	Begin = function(ctx)
		local radius = ctx.Balance.Range or 150
		local duration = ctx.Balance.Duration or 8
		local center = ctx.Root.Position
		AbilityKit.pose(ctx, "Release")
		local budget = AbilityKit.budget(ctx.Balance.Damage)
		AbilityKit.Hooks.setBrittle(center, radius, duration)
		AbilityKit.fx("Frost", center, { Position = center, Radius = radius, Duration = duration })
		AbilityKit.fx("Explosion", center, { Position = center, Radius = 30, Kind = "Ice" })
		-- Initial flash freeze of everyone in the area
		for _, victim in AbilityKit.inSphere(center, radius, { ctx.Character }) do
			local amount = budget(victim, 180)
			AbilityKit.damage(ctx, victim, amount, { Kind = "AoE", Position = center, NoReaction = true, Tag = "Flash Freeze" })
			if AbilityKit.isAlive(victim) then
				AbilityKit.Status.apply(victim, "Freeze", "Control", 2, 1, ctx.Player)
			end
		end
		-- Chill over time + slow
		task.spawn(function()
			local elapsed = 0
			local accumulator = 0
			while elapsed < duration do
				local dt = RunService.Heartbeat:Wait()
				elapsed += dt
				accumulator += dt
				if accumulator >= 0.5 then
					accumulator = 0
					for _, victim in AbilityKit.inSphere(center, radius, { ctx.Character }) do
						AbilityKit.Status.apply(victim, "Chill", "Speed", 0.7, 0.6, ctx.Player)
						local amount = budget(victim, 12)
						if amount > 0 then
							AbilityKit.damage(ctx, victim, amount, { Kind = "DoT", NoReaction = true, Unblockable = true, Tag = "Flash Freeze" })
						end
					end
				end
			end
		end)
		return true
	end,
}

return AbsoluteZero
