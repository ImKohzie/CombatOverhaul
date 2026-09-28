--!strict
-- Voltline E: Lightning Hurl. Hold to spin and charge, release to throw a
-- lightning bolt. Damage scales with charge and Momentum tier.

local AbilityTypes = require(script.Parent.Parent.Parent.AbilityTypes)
local AbilityKit = require(script.Parent.Parent.Parent.AbilityKit)

local FULL_CHARGE = 1.0
local SPLASH_RADIUS = 7

local LightningHurl: AbilityTypes.AbilityModule = {
	Begin = function(ctx)
		AbilityKit.pose(ctx, "Spin", { Loop = true })
		AbilityKit.fx("ChargeAura", ctx.Root.Position, { Source = ctx.Character, Color = Color3.fromRGB(255, 230, 80), Duration = 1.5 })
		return true
	end,
	End = function(ctx)
		if not AbilityKit.isAlive(ctx.Character) then
			return
		end
		AbilityKit.pose(ctx, "Throw")
		local charge = math.clamp((workspace:GetServerTimeNow() - ctx.StartTime) / FULL_CHARGE, 0.3, 1)
		local tierValue = ctx.Character:GetAttribute("ApexMomentumTier")
		local tier = if type(tierValue) == "number" then tierValue else 1
		local damage = ctx.Balance.Damage * (1 + (AbilityKit.param(ctx, "MomentumBonusPerTier", 0.15)) * (tier - 1)) * (0.6 + 0.4 * charge)
		local origin = ctx.Root.Position + Vector3.new(0, 1.5, 0) + ctx.Root.CFrame.LookVector * 2
		local direction = ctx.AimPoint - origin
		if direction.Magnitude < 1 then
			direction = ctx.Root.CFrame.LookVector
		end
		AbilityKit.projectile({
			Origin = origin,
			Direction = direction,
			Speed = 320,
			Range = ctx.Balance.Range or 160,
			Radius = 1.5,
			Owner = ctx.Character,
			Visual = "Bolt",
			VisualData = { Color = Color3.fromRGB(255, 225, 60), Width = 0.6 + 0.4 * charge },
			OnHit = function(position, character, part)
				if character then
					AbilityKit.damage(ctx, character, damage, {
						Kind = "Projectile",
						Position = position,
						Knockback = direction.Unit * 60 + Vector3.new(0, 20, 0),
						HitStun = 0.6,
						Ragdoll = if tier >= 3 then 0.8 else nil,
					})
				end
				for _, other in AbilityKit.inSphere(position, SPLASH_RADIUS, { ctx.Character, character :: any }) do
					AbilityKit.damage(ctx, other, damage * 0.4, {
						Kind = "AoE",
						Position = position,
						Knockback = AbilityKit.awayFrom(position, other, 35, 15),
					})
				end
				if part then
					AbilityKit.Hooks.structureDamageAt(part, position, 60 * charge * tier, 1200, ctx.Character)
				end
				AbilityKit.fx("Explosion", position, { Position = position, Radius = SPLASH_RADIUS, Color = Color3.fromRGB(255, 230, 90), Kind = "Electric" })
			end,
		})
	end,
}

return LightningHurl
