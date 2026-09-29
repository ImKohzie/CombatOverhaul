--!strict
-- Glitch Q: Lag Spike. Teleport behind the target and strike.

local AbilityTypes = require(script.Parent.Parent.Parent.AbilityTypes)
local AbilityKit = require(script.Parent.Parent.Parent.AbilityKit)
local MovementService = require(script.Parent.Parent.Parent.Services.MovementService)


local LagSpike: AbilityTypes.AbilityModule = {
	Begin = function(ctx)
		local target = AbilityKit.aimTarget(ctx, ctx.Balance.Range or 80, 15)
		local targetRoot = target and AbilityKit.rootOf(target)
		if not target or not targetRoot then
			AbilityKit.notify(ctx, "No target in range")
			return false
		end
		local from = ctx.Root.Position
		AbilityKit.fx("PixelBurst", from, { Position = from, Radius = 5, Color = Color3.fromRGB(255, 40, 200) })
		MovementService.exempt(ctx.Player, 1)
		local behind = targetRoot.CFrame * CFrame.new(0, 0, 4)
		ctx.Character:PivotTo(CFrame.lookAt(behind.Position, targetRoot.Position))
		AbilityKit.pose(ctx, "Combo4")
		local dir = (targetRoot.Position - behind.Position)
		dir = if dir.Magnitude > 1e-3 then dir.Unit else Vector3.zAxis
		AbilityKit.damage(ctx, target, ctx.Balance.Damage, { Kind = "Melee", CanParry = false, Position = targetRoot.Position, Knockback = dir * 70 + Vector3.new(0, 35, 0), HitStun = 0.7 })
		AbilityKit.fx("PixelBurst", targetRoot.Position, { Position = targetRoot.Position, Radius = 6, Color = Color3.fromRGB(0, 255, 170) })
		AbilityKit.fx("TraversalImpact", targetRoot.Position, { Kind = "Hit", Position = targetRoot.Position, Direction = dir, Color = Color3.fromRGB(255, 40, 200), Source = ctx.Character, Target = target, Strength = 0.8 })
		return true
	end,
}

return LagSpike
