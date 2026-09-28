--!strict
-- Echo Q: Sonic Scream. A forward cone blast that shatters glass across
-- whole building faces.

local AbilityTypes = require(script.Parent.Parent.Parent.AbilityTypes)
local AbilityKit = require(script.Parent.Parent.Parent.AbilityKit)

local SonicScream: AbilityTypes.AbilityModule = {
	Begin = function(ctx)
		AbilityKit.pose(ctx, "Scream")
		task.delay(0.15, function()
			if not AbilityKit.isAlive(ctx.Character) then
				return
			end
			local range = ctx.Balance.Range or 60
			local halfAngle = AbilityKit.param(ctx, "ConeDegrees", 50) / 2
			local origin = ctx.Root.Position + Vector3.new(0, 1.5, 0)
			local dir = ctx.AimPoint - origin
			dir = if dir.Magnitude > 1e-3 then dir.Unit else ctx.Root.CFrame.LookVector
			for _, victim in AbilityKit.inCone(origin, dir, range, halfAngle, { ctx.Character }) do
				AbilityKit.damage(ctx, victim, ctx.Balance.Damage, {
					Kind = "AoE",
					Knockback = dir * 65 + Vector3.new(0, 15, 0),
					HitStun = 0.5,
				})
			end
			-- Glass across whole facades, plus a weaker push on everything else
			AbilityKit.Hooks.shatterGlassCone(origin, dir, range * 2, halfAngle + 10, ctx.Character)
			for i = 1, 3 do
				local distance = range * i / 3
				AbilityKit.Hooks.structureDamageSphere(origin + dir * distance, 3 + distance * 0.4, 70, 1500, ctx.Character)
			end
			AbilityKit.fx("Shockwave", origin, { Position = origin, Direction = dir, Range = range, Angle = halfAngle * 2, Color = Color3.fromRGB(255, 110, 220) })
		end)
		return true
	end,
}

return SonicScream
