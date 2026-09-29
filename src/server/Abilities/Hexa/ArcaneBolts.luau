--!strict
-- Hexa Q: Arcane Bolts. Three homing bolts.

local AbilityTypes = require(script.Parent.Parent.Parent.AbilityTypes)
local AbilityKit = require(script.Parent.Parent.Parent.AbilityKit)


local ArcaneBolts: AbilityTypes.AbilityModule = {
	Begin = function(ctx)
		AbilityKit.pose(ctx, "CastRight")
		local bolts = math.floor(AbilityKit.param(ctx, "Bolts", 3))
		local each = ctx.Balance.Damage / bolts
		local target = AbilityKit.aimTarget(ctx, ctx.Balance.Range or 200, 25)
		for i = 1, bolts do
			task.delay((i - 1) * 0.1, function()
				if not AbilityKit.isAlive(ctx.Character) then
					return
				end
				local origin = ctx.Root.Position + Vector3.new(0, 2, 0) + ctx.Root.CFrame.RightVector * (i - 2) * 2
				local dir = (ctx.AimPoint - origin).Unit + Vector3.new(0, 0.25, 0) + ctx.Root.CFrame.RightVector * (i - 2) * 0.3
				AbilityKit.projectile({
					Origin = origin,
					Direction = dir,
					Speed = 170,
					Range = ctx.Balance.Range or 200,
					Radius = 1.2,
					Owner = ctx.Character,
					Homing = target,
					HomingStrength = 4.5,
					Light = true,
					ReflectDamage = 25,
					Visual = "Orb",
					VisualData = { Color = Color3.fromRGB(200, 120, 255), Width = 1 },
					OnHit = function(position, character)
						if character then
							AbilityKit.damage(ctx, character, each, { Kind = "Projectile", Position = position, Knockback = dir.Unit * 20, HitStun = 0.3 })
						end
						AbilityKit.fx("Explosion", position, { Position = position, Radius = 3, Kind = "Nova" })
					end,
				})
			end)
		end
		return true
	end,
}

return ArcaneBolts
