--!strict
-- Undertow G (Ultimate): Tsunami. A colossal wave sweeps the whole block.

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

local Tsunami: AbilityTypes.AbilityModule = {
	Begin = function(ctx)
		local windUp = ctx.Balance.WindUp or 0.8
		local range = ctx.Balance.Range or 180
		AbilityKit.pose(ctx, "Channel", { Duration = windUp + 0.5 })
		AbilityKit.Status.apply(ctx.Character, "Unstoppable", "Flag", windUp + 0.5)
		AbilityKit.fx("ChargeAura", ctx.Root.Position, { Source = ctx.Character, Color = Color3.fromRGB(60, 200, 255), Duration = windUp })
		local aim = ctx.AimPoint - ctx.Root.Position
		local flat = Vector3.new(aim.X, 0, aim.Z)
		local dir = if flat.Magnitude > 1e-3 then flat.Unit else ctx.Root.CFrame.LookVector
		task.delay(windUp, function()
			if not AbilityKit.isAlive(ctx.Character) then
				return
			end
			local start = ctx.Root.Position - dir * 10 - Vector3.new(0, 3, 0)
			local duration = 2
			AbilityKit.fx("Wave", start, { Position = start, Direction = dir, Width = 90, Height = 45, Distance = range, Duration = duration, Color = Color3.fromRGB(30, 120, 190) })
			sweep(ctx, start, dir, 90, 45, range, duration, ctx.Balance.Damage, 160, 50, 520)
		end)
		return true
	end,
}

return Tsunami
