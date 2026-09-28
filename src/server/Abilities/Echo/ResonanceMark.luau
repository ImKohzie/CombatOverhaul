--!strict
-- Echo R: Resonance Mark. Mark a target; Echo's next hit on them detonates
-- the mark for heavy bonus damage (DamageService modifier).

local AbilityTypes = require(script.Parent.Parent.Parent.AbilityTypes)
local AbilityKit = require(script.Parent.Parent.Parent.AbilityKit)
local BalanceConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("ApexCity").Config.BalanceConfig)
local DamageService = require(script.Parent.Parent.Parent.Services.DamageService)
local StatusService = require(script.Parent.Parent.Parent.Services.StatusService)

local TAG = "Resonance Mark"

DamageService.addModifier(function(victim, info)
	if info.Tag == TAG or info.Kind == "DoT" or not StatusService.has(victim, "Marked") then
		return
	end
	local source = StatusService.source(victim, "Marked")
	if not source or source ~= info.Attacker then
		return
	end
	local balance = BalanceConfig.getAbility("Echo", "Ability3")
	info.Amount += if balance then balance.Damage else 170
	info.Tag = TAG
	StatusService.remove(victim, "Marked")
	local root = AbilityKit.rootOf(victim)
	if root then
		AbilityKit.fx("Explosion", root.Position, { Position = root.Position, Radius = 9, Kind = "Sonic" })
	end
end)

local ResonanceMark: AbilityTypes.AbilityModule = {
	Begin = function(ctx)
		local target = AbilityKit.aimTarget(ctx, ctx.Balance.Range or 150, 10)
		if not target then
			AbilityKit.notify(ctx, "No target under the crosshair")
			return false
		end
		AbilityKit.pose(ctx, "CastRight")
		AbilityKit.Status.apply(target, "Marked", "Flag", ctx.Balance.Duration or 8, 1, ctx.Player)
		local root = AbilityKit.rootOf(target)
		if root then
			AbilityKit.fx("Shockwave", root.Position, { Position = root.Position, Direction = Vector3.yAxis, Range = 6, Angle = 360, Color = Color3.fromRGB(255, 80, 200) })
		end
		return true
	end,
}

return ResonanceMark
