--!strict
-- Cinder Q: Flame Burst. An exploding fireball that leaves targets burning.

local AbilityTypes = require(script.Parent.Parent.Parent.AbilityTypes)
local AbilityKit = require(script.Parent.Parent.Parent.AbilityKit)

-- Damage over time (burning, bleeding): ticks every 0.5s.
local function burn(ctx: AbilityTypes.AbilityContext, victim: Model, dps: number, duration: number)
	task.spawn(function()
		local ticks = math.floor(duration / 0.5)
		for _ = 1, ticks do
			task.wait(0.5)
			if not AbilityKit.isAlive(victim) then
				return
			end
			AbilityKit.damage(ctx, victim, dps * 0.5, { Kind = "DoT", NoReaction = true, Tag = ctx.Def.Name .. " (Burn)" })
		end
	end)
end

local FlameBurst: AbilityTypes.AbilityModule = {
	Begin = function(ctx)
		AbilityKit.pose(ctx, "CastRight")
		local burnDps = AbilityKit.param(ctx, "BurnDps", 10)
		local burnTime = AbilityKit.param(ctx, "BurnTime", 3)
		local direct = math.max(ctx.Balance.Damage - burnDps * burnTime, 0)
		local origin = ctx.Root.Position + Vector3.new(0, 1.5, 0) + ctx.Root.CFrame.LookVector * 2
		AbilityKit.projectile({
			Origin = origin,
			Direction = ctx.AimPoint - origin,
			Speed = 210,
			Range = ctx.Balance.Range or 200,
			Radius = 1.6,
			Owner = ctx.Character,
			Light = true,
			ReflectDamage = 40,
			Visual = "Orb",
			VisualData = { Color = Color3.fromRGB(255, 130, 40), Width = 1.8 },
			OnHit = function(position)
				for _, victim in AbilityKit.blast(ctx, position, 10, direct, 55, 20, nil, 320) do
					burn(ctx, victim, burnDps, burnTime)
				end
				AbilityKit.fx("Explosion", position, { Position = position, Radius = 9, Kind = "Fire" })
			end,
		})
		return true
	end,
}

return FlameBurst
