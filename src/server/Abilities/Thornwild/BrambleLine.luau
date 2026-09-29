--!strict
-- Thornwild E: Bramble Line. Thorny roots burst from the ground in a line.

local AbilityTypes = require(script.Parent.Parent.Parent.AbilityTypes)
local AbilityKit = require(script.Parent.Parent.Parent.AbilityKit)


local STEP = 6

local BrambleLine: AbilityTypes.AbilityModule = {
	Begin = function(ctx)
		local windUp = ctx.Balance.WindUp or 0.3
		local range = ctx.Balance.Range or 90
		AbilityKit.pose(ctx, "Stomp")
		local aim = ctx.AimPoint - ctx.Root.Position
		local flat = Vector3.new(aim.X, 0, aim.Z)
		local dir = if flat.Magnitude > 1e-3 then flat.Unit else ctx.Root.CFrame.LookVector
		local start = ctx.Root.Position
		task.delay(windUp, function()
			local hit: { [Model]: boolean } = {}
			for distance = STEP, range, STEP do
				local ground = AbilityKit.groundBelow(start + dir * distance + Vector3.new(0, 15, 0), 60)
				if ground then
					local spot = ground.Position
					AbilityKit.fx("IceSpike", spot, { Position = spot, Height = 8 + distance * 0.04, Color = Color3.fromRGB(96, 120, 52), Material = Enum.Material.Wood })
					for _, victim in AbilityKit.inSphere(spot + Vector3.new(0, 3, 0), 5.5, { ctx.Character }) do
						if not hit[victim] then
							hit[victim] = true
							AbilityKit.damage(ctx, victim, ctx.Balance.Damage, { Kind = "AoE", Position = spot, Knockback = Vector3.new(0, 60, 0) + dir * 12, Ragdoll = 0.6, HitStun = 0.6 })
						end
					end
					AbilityKit.Hooks.structureDamageSphere(spot, 5.5, 170, 1800, ctx.Character)
				end
				task.wait(0.035)
			end
		end)
		return true
	end,
}

return BrambleLine
