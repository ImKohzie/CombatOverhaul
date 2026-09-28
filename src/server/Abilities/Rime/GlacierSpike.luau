--!strict
-- Rime R: Glacier Spike. Ice spikes erupt from the ground in a line.

local AbilityTypes = require(script.Parent.Parent.Parent.AbilityTypes)
local AbilityKit = require(script.Parent.Parent.Parent.AbilityKit)

local STEP = 6
local HIT_RADIUS = 5.5

local GlacierSpike: AbilityTypes.AbilityModule = {
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
				local probe = start + dir * distance + Vector3.new(0, 15, 0)
				local ground = AbilityKit.groundBelow(probe, 60)
				if ground then
					local spot = ground.Position
					AbilityKit.fx("IceSpike", spot, { Position = spot, Normal = ground.Normal, Height = 7 + distance * 0.04 })
					for _, victim in AbilityKit.inSphere(spot + Vector3.new(0, 3, 0), HIT_RADIUS, { ctx.Character }) do
						if not hit[victim] then
							hit[victim] = true
							AbilityKit.damage(ctx, victim, ctx.Balance.Damage, {
								Kind = "AoE",
								Position = spot,
								Knockback = Vector3.new(0, 65, 0) + dir * 10,
								Ragdoll = 0.6,
								HitStun = 0.6,
							})
						end
					end
					AbilityKit.Hooks.structureDamageSphere(spot, HIT_RADIUS, 160, 1800, ctx.Character)
				end
				task.wait(0.035)
			end
		end)
		return true
	end,
}

return GlacierSpike
