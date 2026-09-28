--!strict
-- Voltline G (Ultimate): Velocity Rift. For 6s everyone else nearby moves at
-- 15% speed (TimeSlow status: their clients slow movement, animations and
-- show the rift), while Voltline moves and attacks at full speed with a
-- desaturated, frozen-world view.

local RunService = game:GetService("RunService")

local AbilityTypes = require(script.Parent.Parent.Parent.AbilityTypes)
local AbilityKit = require(script.Parent.Parent.Parent.AbilityKit)

local RADIUS = 220
local REFRESH = 0.25

local VelocityRift: AbilityTypes.AbilityModule = {
	Begin = function(ctx)
		local duration = ctx.Balance.Duration or 6
		local scale = AbilityKit.param(ctx, "WorldTimeScale", 0.15)
		AbilityKit.Status.apply(ctx.Character, "RiftRunner", "Speed", duration, 1.35)
		ctx.Character:SetAttribute("ApexRiftUntil", workspace:GetServerTimeNow() + duration)
		AbilityKit.fx("Rift", ctx.Root.Position, { Source = ctx.Character, Duration = duration, Radius = RADIUS })
		task.spawn(function()
			local elapsed = 0
			local accumulator = REFRESH
			while elapsed < duration and AbilityKit.isAlive(ctx.Character) do
				local dt = RunService.Heartbeat:Wait()
				elapsed += dt
				accumulator += dt
				if accumulator >= REFRESH then
					accumulator = 0
					for _, other in AbilityKit.inSphere(ctx.Root.Position, RADIUS, { ctx.Character }) do
						AbilityKit.Status.apply(other, "TimeSlow", "Speed", REFRESH + 0.15, scale, ctx.Player)
					end
				end
			end
			ctx.Character:SetAttribute("ApexRiftUntil", nil)
		end)
		return true
	end,
}

return VelocityRift
