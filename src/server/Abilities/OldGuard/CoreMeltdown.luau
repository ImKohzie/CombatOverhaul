--!strict
-- Old Guard G (Ultimate): Core Meltdown. Channel unstable chest energy for
-- 2s, then release a green-white radiation blast that leaves a lingering
-- radiation zone (damage over time + heat-shimmer post effect).

local RunService = game:GetService("RunService")

local AbilityTypes = require(script.Parent.Parent.Parent.AbilityTypes)
local AbilityKit = require(script.Parent.Parent.Parent.AbilityKit)

local ZONE_RADIUS = 30

local CoreMeltdown: AbilityTypes.AbilityModule = {
	Begin = function(ctx)
		local windUp = ctx.Balance.WindUp or 2
		AbilityKit.pose(ctx, "Crouch", { Loop = true })
		AbilityKit.Status.apply(ctx.Character, "Meltdown", "Speed", windUp, 0.15)
		AbilityKit.fx("ChargeAura", ctx.Root.Position, { Source = ctx.Character, Color = Color3.fromRGB(170, 255, 150), Duration = windUp })
		task.delay(windUp, function()
			if not AbilityKit.isAlive(ctx.Character) then
				return
			end
			AbilityKit.pose(ctx, "Release")
			local center = ctx.Root.Position
			local radius = ctx.Balance.Range or 70
			local zoneDps = AbilityKit.param(ctx, "ZoneDps", 15)
			local zoneTime = AbilityKit.param(ctx, "ZoneDuration", 6)
			-- Blast carries most of the budget; the zone adds the rest.
			local blastDamage = ctx.Balance.Damage - zoneDps * 2
			AbilityKit.falloffBlast(ctx, center, radius, 20, blastDamage, 0.5, 95, 40, 1.4)
			AbilityKit.Hooks.structureDamageSphere(center, radius * 0.55, 700, 5000, ctx.Character)
			AbilityKit.fx("Explosion", center, { Position = center, Radius = radius * 0.6, Kind = "Radiation" })
			AbilityKit.fx("Shockwave", center, { Position = center, Direction = Vector3.xAxis, Range = radius, Angle = 360, Color = Color3.fromRGB(210, 255, 200) })
			AbilityKit.fx("Radiation", center, { Position = center, Radius = ZONE_RADIUS, Duration = zoneTime })
			local elapsed = 0
			local accumulator = 0
			while elapsed < zoneTime do
				local dt = RunService.Heartbeat:Wait()
				elapsed += dt
				accumulator += dt
				if accumulator >= 0.5 then
					accumulator = 0
					for _, victim in AbilityKit.inSphere(center, ZONE_RADIUS, { ctx.Character }) do
						AbilityKit.damage(ctx, victim, zoneDps * 0.5, { Kind = "DoT", NoReaction = true, Unblockable = true })
					end
				end
			end
		end)
		return true
	end,
}

return CoreMeltdown
