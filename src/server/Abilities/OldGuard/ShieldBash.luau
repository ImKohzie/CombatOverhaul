--!strict
-- Old Guard E: Shield Bash & Brace. Tap: forward bash that staggers.
-- Keep holding: brace behind the shield, blocking beams from the front.

local AbilityTypes = require(script.Parent.Parent.Parent.AbilityTypes)
local AbilityKit = require(script.Parent.Parent.Parent.AbilityKit)
local DamageService = require(script.Parent.Parent.Parent.Services.DamageService)

local ShieldBash: AbilityTypes.AbilityModule = {
	Begin = function(ctx)
		AbilityKit.pose(ctx, "CastRight")
		local front = ctx.Root.CFrame * CFrame.new(0, 0, -(ctx.Balance.Range or 10) / 2)
		for _, victim in AbilityKit.inBox(front, Vector3.new(7, 7, ctx.Balance.Range or 10), { ctx.Character }) do
			AbilityKit.damage(ctx, victim, ctx.Balance.Damage, {
				Kind = "Melee",
				Knockback = ctx.Root.CFrame.LookVector * 45 + Vector3.new(0, 10, 0),
				HitStun = AbilityKit.param(ctx, "StaggerTime", 0.8),
				CanParry = false,
			})
			AbilityKit.Status.stun(victim, AbilityKit.param(ctx, "StaggerTime", 0.8), ctx.Player)
		end
		AbilityKit.Hooks.structureDamageSphere(front.Position, 5, 120, 1500, ctx.Character)
		-- Brace while held (ends on release or after the channel cap)
		task.delay(0.25, function()
			if AbilityKit.isAlive(ctx.Character) then
				AbilityKit.Status.apply(ctx.Character, "BraceBeam", "Flag", 3)
				DamageService.setBlocking(ctx.Character, true)
			end
		end)
		return true
	end,
	End = function(ctx)
		task.delay(0.26, function()
			AbilityKit.Status.remove(ctx.Character, "BraceBeam")
			DamageService.setBlocking(ctx.Character, false)
		end)
	end,
}

return ShieldBash
