--!strict
-- Glitch R: Pixel Storm. A spray of corrupted data bolts.

local AbilityTypes = require(script.Parent.Parent.Parent.AbilityTypes)
local AbilityKit = require(script.Parent.Parent.Parent.AbilityKit)


local PixelStorm: AbilityTypes.AbilityModule = {
	Begin = function(ctx)
		AbilityKit.pose(ctx, "CastBoth")
		local bolts = math.floor(AbilityKit.param(ctx, "Bolts", 7))
		local each = ctx.Balance.Damage / bolts
		local origin = ctx.Root.Position + Vector3.new(0, 1.5, 0) + ctx.Root.CFrame.LookVector * 2
		local aim = ctx.AimPoint - origin
		aim = if aim.Magnitude > 1e-3 then aim.Unit else ctx.Root.CFrame.LookVector
		for i = 1, bolts do
			task.delay(i * 0.03, function()
				local spread = CFrame.Angles(math.rad(math.random(-6, 6)), math.rad(math.random(-14, 14)), 0)
				local dir = (CFrame.lookAt(Vector3.zero, aim) * spread).LookVector
				AbilityKit.projectile({
					Origin = origin,
					Direction = dir,
					Speed = 300,
					Range = ctx.Balance.Range or 150,
					Radius = 1,
					Owner = ctx.Character,
					Light = true,
					ReflectDamage = 15,
					Visual = "Bolt",
					VisualData = { Color = if i % 2 == 0 then Color3.fromRGB(0, 255, 170) else Color3.fromRGB(255, 40, 200), Width = 0.5 },
					OnHit = function(position, character)
						if character then
							AbilityKit.damage(ctx, character, each, { Kind = "Projectile", Position = position, Knockback = dir * 15, HitStun = 0.25 })
						end
						AbilityKit.fx("PixelBurst", position, { Position = position, Radius = 2, Color = Color3.fromRGB(255, 40, 200) })
					end,
				})
			end)
		end
		return true
	end,
}

return PixelStorm
