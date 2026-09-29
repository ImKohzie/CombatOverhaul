--!strict
-- Rebound Q: Slingshot Punch. A stretchy long-range haymaker.

local AbilityTypes = require(script.Parent.Parent.Parent.AbilityTypes)
local AbilityKit = require(script.Parent.Parent.Parent.AbilityKit)


local SlingshotPunch: AbilityTypes.AbilityModule = {
	Begin = function(ctx)
		AbilityKit.pose(ctx, "Combo1")
		local range = ctx.Balance.Range or 45
		local origin = ctx.Root.Position + Vector3.new(0, 1.5, 0)
		local dir = ctx.AimPoint - origin
		dir = if dir.Magnitude > 1e-3 then dir.Unit else ctx.Root.CFrame.LookVector
		local box = CFrame.lookAt(origin + dir * range / 2, origin + dir * range)
		local target: Model? = nil
		local best = math.huge
		for _, victim in AbilityKit.inBox(box, Vector3.new(7, 7, range), { ctx.Character }) do
			local root = AbilityKit.rootOf(victim)
			if root and (root.Position - origin).Magnitude < best then
				best = (root.Position - origin).Magnitude
				target = victim
			end
		end
		local wall = workspace:Raycast(origin, dir * range, AbilityKit.worldParams({ ctx.Character :: Instance }))
		local tip = if wall then wall.Position else origin + dir * range
		if target and best < (tip - origin).Magnitude then
			local root = AbilityKit.rootOf(target)
			tip = if root then root.Position else tip
			AbilityKit.damage(ctx, target, ctx.Balance.Damage, { Kind = "Melee", CanParry = false, Position = tip, Knockback = dir * 130 + Vector3.new(0, 30, 0), Ragdoll = 0.8, HitStun = 0.7 })
			AbilityKit.fx("TraversalImpact", tip, { Kind = "Hit", Position = tip, Direction = dir, Color = Color3.fromRGB(255, 200, 40), Source = ctx.Character, Target = target, Strength = 0.8 })
		elseif wall then
			AbilityKit.Hooks.structureDamageSphere(tip, 5, 320, 3500, ctx.Character)
		end
		AbilityKit.fx("Stretch", origin, { Source = ctx.Character, To = tip, Color = Color3.fromRGB(255, 200, 40) })
		return true
	end,
}

return SlingshotPunch
