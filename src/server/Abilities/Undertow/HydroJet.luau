--!strict
-- Undertow Q: Hydro Jet. A pressurised water blast that shoves enemies far.

local AbilityTypes = require(script.Parent.Parent.Parent.AbilityTypes)
local AbilityKit = require(script.Parent.Parent.Parent.AbilityKit)


local HydroJet: AbilityTypes.AbilityModule = {
	Begin = function(ctx)
		AbilityKit.pose(ctx, "CastBoth")
		local origin = ctx.Root.Position + Vector3.new(0, 1.5, 0) + ctx.Root.CFrame.LookVector * 2
		local dir = ctx.AimPoint - origin
		dir = if dir.Magnitude > 1e-3 then dir.Unit else ctx.Root.CFrame.LookVector
		AbilityKit.projectile({
			Origin = origin,
			Direction = dir,
			Speed = 270,
			Range = ctx.Balance.Range or 160,
			Radius = 2,
			Owner = ctx.Character,
			Visual = "Orb",
			VisualData = { Color = Color3.fromRGB(60, 170, 255), Width = 2.2 },
			OnHit = function(position, character)
				if character then
					AbilityKit.damage(ctx, character, ctx.Balance.Damage, { Kind = "Projectile", Position = position, Knockback = dir * 140 + Vector3.new(0, 25, 0), Ragdoll = 0.7, HitStun = 0.6 })
				end
				AbilityKit.Hooks.structureDamageSphere(position, 5, 260, 3500, ctx.Character)
				AbilityKit.fx("Explosion", position, { Position = position, Radius = 6, Kind = "Ice" })
			end,
		})
		return true
	end,
}

return HydroJet
