--!strict
-- Cinder E: Heat Wave. A wide cone of heat: knockback now, burning after.

local AbilityTypes = require(script.Parent.Parent.Parent.AbilityTypes)
local AbilityKit = require(script.Parent.Parent.Parent.AbilityKit)

-- Damage over time (burning, bleeding): ticks every 0.5s.
local function burn(ctx: AbilityTypes.AbilityContext, victim: Model, dps: number, duration: number)
	task.spawn(function()
		local ticks = math.floor(duration / 0.5)
		for _ = 1, ticks do
			task.wait(0.5)
			if not AbilityKit.isAlive(victim) then
				return
			end
			AbilityKit.damage(ctx, victim, dps * 0.5, { Kind = "DoT", NoReaction = true, Tag = ctx.Def.Name .. " (Burn)" })
		end
	end)
end

local HeatWave: AbilityTypes.AbilityModule = {
	Begin = function(ctx)
		AbilityKit.pose(ctx, "CastBoth")
		local range = ctx.Balance.Range or 45
		local halfAngle = AbilityKit.param(ctx, "ConeDegrees", 70) / 2
		local origin = ctx.Root.Position + Vector3.new(0, 1.5, 0)
		local dir = ctx.AimPoint - origin
		dir = if dir.Magnitude > 1e-3 then dir.Unit else ctx.Root.CFrame.LookVector
		local instant = ctx.Balance.Damage * 0.6
		local burnTotal = ctx.Balance.Damage - instant
		for _, victim in AbilityKit.inCone(origin, dir, range, halfAngle, { ctx.Character }) do
			AbilityKit.damage(ctx, victim, instant, { Kind = "AoE", Knockback = dir * 80 + Vector3.new(0, 20, 0), HitStun = 0.5 })
			burn(ctx, victim, burnTotal / 2, 2)
		end
		AbilityKit.Hooks.shatterGlassCone(origin, dir, range * 1.5, halfAngle, ctx.Character)
		AbilityKit.Hooks.structureDamageSphere(origin + dir * range * 0.5, range * 0.3, 90, 1500, ctx.Character)
		AbilityKit.fx("Shockwave", origin, { Position = origin, Direction = dir, Range = range, Angle = halfAngle * 2, Color = Color3.fromRGB(255, 140, 40) })
		AbilityKit.fx("Explosion", origin + dir * 8, { Position = origin + dir * 8, Radius = 6, Kind = "Fire" })
		return true
	end,
}

return HeatWave
