--!strict
-- Rampage Q: Thunderclap. A clap that sends a devastating forward pressure
-- wave.

local AbilityTypes = require(script.Parent.Parent.Parent.AbilityTypes)
local AbilityKit = require(script.Parent.Parent.Parent.AbilityKit)

local HALF_ANGLE = 30

local Thunderclap: AbilityTypes.AbilityModule = {
	Begin = function(ctx)
		local windUp = ctx.Balance.WindUp or 0.4
		AbilityKit.pose(ctx, "Clap")
		task.delay(windUp, function()
			if not AbilityKit.isAlive(ctx.Character) then
				return
			end
			local range = ctx.Balance.Range or 50
			local origin = ctx.Root.Position
			local aim = ctx.AimPoint - origin
			local flat = Vector3.new(aim.X, 0, aim.Z)
			local dir = if flat.Magnitude > 1e-3 then flat.Unit else ctx.Root.CFrame.LookVector
			for _, victim in AbilityKit.inCone(origin, dir, range, HALF_ANGLE, { ctx.Character }) do
				AbilityKit.damage(ctx, victim, ctx.Balance.Damage, {
					Kind = "AoE",
					Knockback = dir * 115 + Vector3.new(0, 25, 0),
					Ragdoll = 1,
					HitStun = 0.8,
				})
			end
			for i = 1, 4 do
				local distance = range * i / 4
				AbilityKit.Hooks.structureDamageSphere(origin + dir * distance, 4 + distance * 0.45, 260, 3500, ctx.Character)
			end
			AbilityKit.fx("Shockwave", origin, { Position = origin, Direction = dir, Range = range, Angle = HALF_ANGLE * 2, Color = Color3.fromRGB(170, 255, 120) })
		end)
		return true
	end,
}

return Thunderclap
