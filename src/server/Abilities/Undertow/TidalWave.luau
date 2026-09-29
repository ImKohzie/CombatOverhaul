--!strict
-- Undertow E: Tidal Wave. A rolling wave down the street.

local AbilityTypes = require(script.Parent.Parent.Parent.AbilityTypes)
local AbilityKit = require(script.Parent.Parent.Parent.AbilityKit)

-- Sweep a wall forward along the ground, hitting each enemy once.
local function sweep(ctx: AbilityTypes.AbilityContext, start: Vector3, dir: Vector3, width: number, height: number, distance: number, duration: number, damage: number, push: number, lift: number, structure: number)
	local hit: { [Model]: boolean } = {}
	local steps = math.max(math.floor(duration / 0.08), 1)
	local right = Vector3.yAxis:Cross(dir)
	for i = 1, steps do
		local front = start + dir * (distance * i / steps)
		local box = CFrame.lookAt(front + Vector3.new(0, height / 2 - 2, 0), front + Vector3.new(0, height / 2 - 2, 0) + dir)
		for _, victim in AbilityKit.inBox(box, Vector3.new(width, height, 12), { ctx.Character }) do
			if not hit[victim] then
				hit[victim] = true
				AbilityKit.damage(ctx, victim, damage, { Kind = "AoE", Position = front, Knockback = dir * push + Vector3.new(0, lift, 0), Ragdoll = 1, HitStun = 0.8 })
			end
		end
		if structure > 0 and i % 2 == 0 then
			for _, side in { -0.35, 0, 0.35 } do
				AbilityKit.Hooks.structureDamageSphere(front + right * width * side + Vector3.new(0, height * 0.4, 0), math.min(height * 0.5, 14), structure, 4000, ctx.Character)
			end
		end
		task.wait(duration / steps)
	end
end

local TidalWave: AbilityTypes.AbilityModule = {
	Begin = function(ctx)
		AbilityKit.pose(ctx, "Slam")
		local range = ctx.Balance.Range or 110
		local aim = ctx.AimPoint - ctx.Root.Position
		local flat = Vector3.new(aim.X, 0, aim.Z)
		local dir = if flat.Magnitude > 1e-3 then flat.Unit else ctx.Root.CFrame.LookVector
		local start = ctx.Root.Position + dir * 4 - Vector3.new(0, 2.5, 0)
		local duration = range / 110
		AbilityKit.fx("Wave", start, { Position = start, Direction = dir, Width = 28, Height = 12, Distance = range, Duration = duration, Color = Color3.fromRGB(40, 140, 210) })
		task.spawn(sweep, ctx, start, dir, 28, 12, range, duration, ctx.Balance.Damage, 110, 30, 150)
		return true
	end,
}

return TidalWave
