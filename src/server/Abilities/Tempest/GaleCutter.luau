--!strict
-- Tempest Q: Gale Cutter. Three razor wind blades in a fan.

local AbilityTypes = require(script.Parent.Parent.Parent.AbilityTypes)
local AbilityKit = require(script.Parent.Parent.Parent.AbilityKit)


local GaleCutter: AbilityTypes.AbilityModule = {
	Begin = function(ctx)
		AbilityKit.pose(ctx, "CastRight")
		local blades = math.floor(AbilityKit.param(ctx, "Blades", 3))
		local each = ctx.Balance.Damage / blades
		local origin = ctx.Root.Position + Vector3.new(0, 1.5, 0) + ctx.Root.CFrame.LookVector * 2
		local aim = ctx.AimPoint - origin
		aim = if aim.Magnitude > 1e-3 then aim.Unit else ctx.Root.CFrame.LookVector
		for i = 1, blades do
			local spread = (i - (blades + 1) / 2) * math.rad(7)
			local dir = CFrame.fromAxisAngle(Vector3.yAxis, spread):VectorToWorldSpace(aim)
			AbilityKit.projectile({
				Origin = origin,
				Direction = dir,
				Speed = 330,
				Range = ctx.Balance.Range or 220,
				Radius = 1.2,
				Owner = ctx.Character,
				Light = true,
				ReflectDamage = 25,
				Visual = "Bolt",
				VisualData = { Color = Color3.fromRGB(170, 255, 235), Width = 0.6 },
				OnHit = function(position, character)
					if character then
						AbilityKit.damage(ctx, character, each, { Kind = "Projectile", Position = position, Knockback = dir * 30 + Vector3.new(0, 10, 0), HitStun = 0.3 })
					end
					AbilityKit.Hooks.structureDamageSphere(position, 3, 90, 900, ctx.Character)
				end,
			})
		end
		return true
	end,
}

return GaleCutter
