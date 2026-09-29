--!strict
-- Thornwild Q: Thorn Lash. A cone of thorns that snares enemies.

local AbilityTypes = require(script.Parent.Parent.Parent.AbilityTypes)
local AbilityKit = require(script.Parent.Parent.Parent.AbilityKit)


local ThornLash: AbilityTypes.AbilityModule = {
	Begin = function(ctx)
		AbilityKit.pose(ctx, "Combo3")
		local range = ctx.Balance.Range or 35
		local halfAngle = AbilityKit.param(ctx, "ConeDegrees", 60) / 2
		local bindTime = AbilityKit.param(ctx, "BindTime", 0.9)
		local origin = ctx.Root.Position
		local dir = ctx.AimPoint - origin
		dir = Vector3.new(dir.X, 0, dir.Z)
		dir = if dir.Magnitude > 1e-3 then dir.Unit else ctx.Root.CFrame.LookVector
		for _, victim in AbilityKit.inCone(origin, dir, range, halfAngle, { ctx.Character }) do
			AbilityKit.damage(ctx, victim, ctx.Balance.Damage, { Kind = "AoE", Position = origin, Knockback = dir * 20, HitStun = 0.4 })
			local root = AbilityKit.rootOf(victim)
			if root and AbilityKit.isAlive(victim) then
				AbilityKit.Status.apply(victim, "Bind", "Control", bindTime, 1, ctx.Player)
				local feet = root.Position - Vector3.new(0, 3, 0)
				AbilityKit.fx("IceSpike", feet, { Position = feet, Height = 5, Color = Color3.fromRGB(96, 120, 52), Material = Enum.Material.Wood })
			end
		end
		AbilityKit.fx("Shockwave", origin, { Position = origin, Direction = dir, Range = range, Angle = halfAngle * 2, Color = Color3.fromRGB(130, 200, 70) })
		return true
	end,
}

return ThornLash
