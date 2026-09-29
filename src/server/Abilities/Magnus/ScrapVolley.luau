--!strict
-- Magnus Q: Scrap Volley. Fling a spread of torn-up scrap.

local AbilityTypes = require(script.Parent.Parent.Parent.AbilityTypes)
local AbilityKit = require(script.Parent.Parent.Parent.AbilityKit)


local ScrapVolley: AbilityTypes.AbilityModule = {
	Begin = function(ctx)
		AbilityKit.pose(ctx, "CastBoth")
		local pieces = math.floor(AbilityKit.param(ctx, "Pieces", 5))
		local each = ctx.Balance.Damage / pieces
		local origin = ctx.Root.Position + Vector3.new(0, 3, 0)
		local aim = ctx.AimPoint - origin
		aim = if aim.Magnitude > 1e-3 then aim.Unit else ctx.Root.CFrame.LookVector
		for i = 1, pieces do
			task.delay(i * 0.05, function()
				local spread = CFrame.Angles(math.rad(math.random(-5, 5)), math.rad((i - (pieces + 1) / 2) * 5), 0)
				local dir = (CFrame.lookAt(Vector3.zero, aim) * spread).LookVector
				AbilityKit.projectile({
					Origin = origin + Vector3.new(math.random() * 4 - 2, math.random() * 2, math.random() * 4 - 2),
					Direction = dir,
					Speed = 240,
					Range = ctx.Balance.Range or 180,
					Radius = 1.5,
					Owner = ctx.Character,
					Gravity = 15,
					Visual = "Rock",
					VisualData = { Color = Color3.fromRGB(110, 110, 118), Width = 1.6 },
					OnHit = function(position, character)
						if character then
							AbilityKit.damage(ctx, character, each, { Kind = "Projectile", Position = position, Knockback = dir * 35 + Vector3.new(0, 12, 0), HitStun = 0.35 })
						end
						AbilityKit.Hooks.structureDamageSphere(position, 4, 180, 2000, ctx.Character)
					end,
				})
			end)
		end
		return true
	end,
}

return ScrapVolley
