--!strict
-- Old Guard R: Brawler's Fury. Fast 6-hit grounded combo ending in a
-- launcher.

local AbilityTypes = require(script.Parent.Parent.Parent.AbilityTypes)
local AbilityKit = require(script.Parent.Parent.Parent.AbilityKit)

local POSES = { "Combo1", "Combo2", "Combo3", "Combo1", "Combo2", "Combo4" }

local BrawlersFury: AbilityTypes.AbilityModule = {
	Begin = function(ctx)
		local hits = AbilityKit.param(ctx, "Hits", 6)
		local duration = ctx.Balance.Duration or 1.4
		local interval = duration / hits
		local perHit = ctx.Balance.Damage / hits
		AbilityKit.Status.apply(ctx.Character, "Fury", "Speed", duration, 0.35)
		task.spawn(function()
			for i = 1, hits do
				if not AbilityKit.isAlive(ctx.Character) or AbilityKit.Status.isStunned(ctx.Character) then
					break
				end
				AbilityKit.pose(ctx, POSES[((i - 1) % #POSES) + 1], { Speed = 1.8 })
				task.wait(interval * 0.4)
				local final = i == hits
				local front = ctx.Root.CFrame * CFrame.new(0, 0, -3.5)
				for _, victim in AbilityKit.inBox(front, Vector3.new(6, 6.5, 7), { ctx.Character }) do
					AbilityKit.damage(ctx, victim, perHit, {
						Kind = "Melee",
						HitStun = 0.4,
						Knockback = if final then ctx.Root.CFrame.LookVector * 30 + Vector3.new(0, 75, 0) else ctx.Root.CFrame.LookVector * 4,
						Ragdoll = if final then 1.1 else nil,
					})
				end
				task.wait(interval * 0.6)
			end
		end)
		return true
	end,
}

return BrawlersFury
