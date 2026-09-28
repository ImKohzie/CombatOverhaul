--!strict
-- Sovereign E: Sonic Clap. Forward cone shockwave: damage, stun, knockback,
-- and it shatters glass (and weakens anything else) along the cone.

local AbilityTypes = require(script.Parent.Parent.Parent.AbilityTypes)
local AbilityKit = require(script.Parent.Parent.Parent.AbilityKit)

local WIND_UP = 0.18

local SonicClap: AbilityTypes.AbilityModule = {
	Begin = function(ctx)
		AbilityKit.pose(ctx, "Clap")
		task.delay(WIND_UP, function()
			if not AbilityKit.isAlive(ctx.Character) then
				return
			end
			local range = ctx.Balance.Range or 40
			local cone = AbilityKit.param(ctx, "ConeDegrees", 70)
			local origin = ctx.Root.Position
			local look = ctx.AimPoint - ctx.AimOrigin
			local direction = if look.Magnitude > 1e-3 then look.Unit else ctx.Root.CFrame.LookVector
			for _, victim in AbilityKit.inCone(origin, direction, range, cone / 2, { ctx.Character }) do
				AbilityKit.damage(ctx, victim, ctx.Balance.Damage, {
					Kind = "AoE",
					Knockback = direction * 80 + Vector3.new(0, 20, 0),
					HitStun = AbilityKit.param(ctx, "StunTime", 0.9),
				})
				AbilityKit.Status.stun(victim, AbilityKit.param(ctx, "StunTime", 0.9), ctx.Player)
			end
			-- Structures: a chain of spheres down the cone. Glass breaks
			-- instantly, stronger materials are only cracked.
			for i = 1, 4 do
				local distance = range * i / 4
				local width = math.tan(math.rad(cone / 2)) * distance
				AbilityKit.Hooks.structureDamageSphere(origin + direction * distance, math.max(5, width), 45, 1500, ctx.Character)
			end
			AbilityKit.fx("Shockwave", origin, {
				Position = origin,
				Direction = direction,
				Range = range,
				Angle = cone,
				Color = Color3.fromRGB(220, 235, 255),
			})
		end)
		return true
	end,
}

return SonicClap
