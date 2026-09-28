--!strict
-- Rime E: Flash Freeze. Freeze a target solid for 1.5s. Any other hit on a
-- frozen target shatters the ice for bonus damage (registered as a
-- DamageService modifier).

local AbilityTypes = require(script.Parent.Parent.Parent.AbilityTypes)
local AbilityKit = require(script.Parent.Parent.Parent.AbilityKit)
local BalanceConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("ApexCity").Config.BalanceConfig)
local DamageService = require(script.Parent.Parent.Parent.Services.DamageService)
local StatusService = require(script.Parent.Parent.Parent.Services.StatusService)

local TAG = "Flash Freeze"

-- Shatter: a frozen target hit by anything else takes bonus damage.
DamageService.addModifier(function(victim, info)
	if info.Tag == TAG or info.Kind == "DoT" or not StatusService.has(victim, "Freeze") then
		return
	end
	local balance = BalanceConfig.getAbility("Rime", "Ability2")
	local bonus = if balance and balance.Params then balance.Params.ShatterBonus or 80 else 80
	info.Amount += bonus
	info.Tag = (info.Tag or "Hit") .. " (Shatter)"
	StatusService.remove(victim, "Freeze")
	local root = AbilityKit.rootOf(victim)
	if root then
		AbilityKit.fx("Explosion", root.Position, { Position = root.Position, Radius = 6, Kind = "Ice" })
	end
end)

local FlashFreeze: AbilityTypes.AbilityModule = {
	Begin = function(ctx)
		AbilityKit.pose(ctx, "CastRight")
		local origin = ctx.Root.Position + Vector3.new(0, 1.5, 0) + ctx.Root.CFrame.LookVector * 2
		local freezeTime = AbilityKit.param(ctx, "FreezeTime", 1.5)
		AbilityKit.projectile({
			Origin = origin,
			Direction = ctx.AimPoint - origin,
			Speed = 260,
			Range = ctx.Balance.Range or 120,
			Radius = 1.2,
			Owner = ctx.Character,
			Light = true,
			ReflectDamage = 30,
			Visual = "Shard",
			VisualData = { Color = Color3.fromRGB(180, 235, 255), Width = 0.8 },
			OnHit = function(position, character)
				if character then
					AbilityKit.damage(ctx, character, AbilityKit.param(ctx, "BaseDamage", 40), {
						Kind = "Projectile",
						Position = position,
						Tag = TAG,
						NoReaction = true,
					})
					if AbilityKit.isAlive(character) then
						AbilityKit.Status.apply(character, "Freeze", "Control", freezeTime, 1, ctx.Player)
					end
				end
				AbilityKit.fx("Explosion", position, { Position = position, Radius = 4, Kind = "Ice" })
			end,
		})
		return true
	end,
}

return FlashFreeze
