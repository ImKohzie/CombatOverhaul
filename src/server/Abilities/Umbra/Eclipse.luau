--!strict
-- Umbra G (Ultimate): Eclipse. Darken a huge area (local lighting override
-- for everyone inside). Umbra turns invisible, strikes harder, and can
-- Shadow Step anywhere. Opens with a burst of tendrils on nearby enemies.

local AbilityTypes = require(script.Parent.Parent.Parent.AbilityTypes)
local AbilityKit = require(script.Parent.Parent.Parent.AbilityKit)
local PlayerStateService = require(script.Parent.Parent.Parent.Services.PlayerStateService)

local BURST_RADIUS = 60

local Eclipse: AbilityTypes.AbilityModule = {
	Begin = function(ctx)
		local duration = ctx.Balance.Duration or 8
		local radius = ctx.Balance.Range or 200
		local center = ctx.Root.Position
		AbilityKit.pose(ctx, "Release")
		AbilityKit.Status.apply(ctx.Character, "Eclipse", "Flag", duration)
		AbilityKit.Status.apply(ctx.Character, "Invisible", "Flag", duration)
		ctx.Character:SetAttribute("ApexDamageBonus", 0.5)
		PlayerStateService.startCooldown(ctx.Player, "Ability1", 0) -- Shadow Step ready now
		AbilityKit.fx("Eclipse", center, { Position = center, Radius = radius, Duration = duration })
		-- Opening burst: bind + damage everyone close
		for _, victim in AbilityKit.inSphere(center, BURST_RADIUS, { ctx.Character }) do
			AbilityKit.damage(ctx, victim, ctx.Balance.Damage * 0.45, { Kind = "AoE", Position = center, HitStun = 0.8, Unblockable = true })
			AbilityKit.Status.apply(victim, "Bind", "Control", 1.2, 1, ctx.Player)
		end
		task.delay(duration, function()
			if ctx.Character.Parent then
				ctx.Character:SetAttribute("ApexDamageBonus", nil)
			end
		end)
		return true
	end,
}

return Eclipse
