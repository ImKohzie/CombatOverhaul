--!strict
-- Nightwing Goblin Q: Shade Bombs. Toss 3 black spherical grenades that
-- burst into dark smoke and fire.

local AbilityTypes = require(script.Parent.Parent.Parent.AbilityTypes)
local AbilityKit = require(script.Parent.Parent.Parent.AbilityKit)

local RADIUS = 10
local SPREAD = math.rad(9)

local ShadeBombs: AbilityTypes.AbilityModule = {
	Begin = function(ctx)
		AbilityKit.pose(ctx, "Throw")
		local count = AbilityKit.param(ctx, "Bombs", 3)
		local budget = AbilityKit.budget(ctx.Balance.Damage)
		local perBomb = ctx.Balance.Damage / count
		local origin = ctx.Root.Position + Vector3.new(0, 1.5, 0)
		local aim = ctx.AimPoint - origin
		for i = 1, count do
			local yaw = (i - (count + 1) / 2) * SPREAD
			local dir = CFrame.fromAxisAngle(Vector3.yAxis, yaw):VectorToWorldSpace(aim.Unit) + Vector3.new(0, 0.15, 0)
			task.delay((i - 1) * 0.08, function()
				AbilityKit.projectile({
					Origin = origin,
					Direction = dir,
					Speed = 95,
					Range = ctx.Balance.Range or 90,
					Radius = 0.6,
					Gravity = 60,
					Owner = ctx.Character,
					Light = true,
					ReflectDamage = 30,
					Visual = "Bomb",
					VisualData = { Color = Color3.fromRGB(140, 255, 60) },
					OnHit = function(position)
						for _, victim in AbilityKit.inSphere(position, RADIUS, { ctx.Character }) do
							local amount = budget(victim, perBomb)
							if amount > 0 then
								AbilityKit.damage(ctx, victim, amount, {
									Kind = "AoE",
									Position = position,
									Knockback = AbilityKit.awayFrom(position, victim, 45, 20),
									HitStun = 0.4,
								})
							end
						end
						AbilityKit.Hooks.structureDamageSphere(position, RADIUS * 0.8, 160, 2000, ctx.Character)
						AbilityKit.fx("Explosion", position, { Position = position, Radius = RADIUS, Kind = "Fire" })
						AbilityKit.fx("SmokeCloud", position, { Position = position, Radius = RADIUS, Duration = 4, Color = Color3.fromRGB(20, 20, 24) })
					end,
				})
			end)
		end
		return true
	end,
}

return ShadeBombs
