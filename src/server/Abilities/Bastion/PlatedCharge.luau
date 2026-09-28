--!strict
-- Bastion Q: Plated Charge. Shoulder-first charge that smashes through
-- structures and players and can't be stopped by knockback.

local RunService = game:GetService("RunService")

local AbilityTypes = require(script.Parent.Parent.Parent.AbilityTypes)
local AbilityKit = require(script.Parent.Parent.Parent.AbilityKit)
local MovementService = require(script.Parent.Parent.Parent.Services.MovementService)

local PlatedCharge: AbilityTypes.AbilityModule = {
	Begin = function(ctx)
		local windUp = ctx.Balance.WindUp or 0.35
		local speed = AbilityKit.param(ctx, "Speed", 90)
		local range = ctx.Balance.Range or 60
		local duration = range / speed
		AbilityKit.pose(ctx, "ShoulderCharge", { Duration = windUp + duration })
		AbilityKit.Status.apply(ctx.Character, "Unstoppable", "Flag", windUp + duration + 0.2)
		MovementService.exempt(ctx.Player, windUp + duration + 1)
		task.delay(windUp, function()
			if not AbilityKit.isAlive(ctx.Character) then
				return
			end
			local look = ctx.AimPoint - ctx.Root.Position
			local flat = Vector3.new(look.X, 0, look.Z)
			local dir = if flat.Magnitude > 1e-3 then flat.Unit else ctx.Root.CFrame.LookVector
			ctx.Root.CFrame = CFrame.lookAt(ctx.Root.Position, ctx.Root.Position + dir)
			AbilityKit.impulseSelf(ctx, dir * speed, duration)
			local hit: { [Model]: boolean } = {}
			local elapsed = 0
			while elapsed < duration and AbilityKit.isAlive(ctx.Character) do
				elapsed += RunService.Heartbeat:Wait()
				local front = ctx.Root.CFrame * CFrame.new(0, 0, -3)
				for _, victim in AbilityKit.inBox(front, Vector3.new(7, 7, 6), { ctx.Character }) do
					if not hit[victim] then
						hit[victim] = true
						AbilityKit.damage(ctx, victim, ctx.Balance.Damage, {
							Kind = "Heavy",
							Knockback = dir * 95 + Vector3.new(0, 25, 0),
							Ragdoll = 1,
							HitStun = 0.8,
						})
					end
				end
				AbilityKit.Hooks.structureDamageSphere(front.Position, 6, 450, 3000, ctx.Character)
			end
		end)
		return true
	end,
}

return PlatedCharge
