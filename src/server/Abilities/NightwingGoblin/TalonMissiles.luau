--!strict
-- Nightwing Goblin R: Talon Missiles. Fire homing missiles from the glider.

local AbilityTypes = require(script.Parent.Parent.Parent.AbilityTypes)
local AbilityKit = require(script.Parent.Parent.Parent.AbilityKit)

local RADIUS = 7

local TalonMissiles: AbilityTypes.AbilityModule = {
	Begin = function(ctx)
		local count = AbilityKit.param(ctx, "Missiles", 4)
		local perMissile = ctx.Balance.Damage / count
		local budget = AbilityKit.budget(ctx.Balance.Damage)
		local target = AbilityKit.aimTarget(ctx, ctx.Balance.Range or 250, 25)
		AbilityKit.pose(ctx, "CastBoth")
		for i = 1, count do
			task.delay((i - 1) * 0.12, function()
				if not AbilityKit.isAlive(ctx.Character) then
					return
				end
				local side = if i % 2 == 0 then 1 else -1
				local origin = (ctx.Root.CFrame * CFrame.new(side * 2.8, -1.5, -1)).Position
				local initial = (ctx.AimPoint - origin).Unit + ctx.Root.CFrame.RightVector * side * 0.35 + Vector3.new(0, 0.25, 0)
				AbilityKit.projectile({
					Origin = origin,
					Direction = initial,
					Speed = 130,
					Range = ctx.Balance.Range or 250,
					Radius = 0.8,
					Owner = ctx.Character,
					Homing = target,
					HomingStrength = 2.8,
					Light = true,
					ReflectDamage = 25,
					Visual = "Missile",
					OnHit = function(position)
						for _, victim in AbilityKit.inSphere(position, RADIUS, { ctx.Character }) do
							local amount = budget(victim, perMissile)
							if amount > 0 then
								AbilityKit.damage(ctx, victim, amount, {
									Kind = "Projectile",
									Position = position,
									Knockback = AbilityKit.awayFrom(position, victim, 35, 20),
									HitStun = 0.35,
								})
							end
						end
						AbilityKit.Hooks.structureDamageSphere(position, RADIUS * 0.8, 150, 2000, ctx.Character)
						AbilityKit.fx("Explosion", position, { Position = position, Radius = RADIUS, Kind = "Fire" })
					end,
				})
			end)
		end
		return true
	end,
}

return TalonMissiles
