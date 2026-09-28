--!strict
-- Echo E: Sound Barrier Dash. A supersonic dash; everything along the path
-- is hit by the sonic boom.

local RunService = game:GetService("RunService")

local AbilityTypes = require(script.Parent.Parent.Parent.AbilityTypes)
local AbilityKit = require(script.Parent.Parent.Parent.AbilityKit)
local MovementService = require(script.Parent.Parent.Parent.Services.MovementService)

local SPEED = 220

local SoundBarrierDash: AbilityTypes.AbilityModule = {
	Begin = function(ctx)
		local range = ctx.Balance.Range or 80
		local duration = range / SPEED
		local aim = ctx.AimPoint - ctx.Root.Position
		local flat = Vector3.new(aim.X, 0, aim.Z)
		local dir = if flat.Magnitude > 1e-3 then flat.Unit else ctx.Root.CFrame.LookVector
		MovementService.exempt(ctx.Player, duration + 1)
		AbilityKit.fx("SonicBoom", ctx.Root.Position, { Position = ctx.Root.Position, Direction = dir, Color = Color3.fromRGB(255, 110, 220) })
		AbilityKit.impulseSelf(ctx, dir * SPEED, duration)
		task.spawn(function()
			local hit: { [Model]: boolean } = {}
			local elapsed = 0
			while elapsed < duration + 0.1 and AbilityKit.isAlive(ctx.Character) do
				elapsed += RunService.Heartbeat:Wait()
				for _, victim in AbilityKit.inBox(ctx.Root.CFrame, Vector3.new(9, 7, 9), { ctx.Character }) do
					if not hit[victim] then
						hit[victim] = true
						local side = ctx.Root.CFrame.RightVector * (if math.random() < 0.5 then -1 else 1)
						AbilityKit.damage(ctx, victim, ctx.Balance.Damage, {
							Kind = "AoE",
							Knockback = side * 50 + Vector3.new(0, 25, 0),
							HitStun = 0.5,
						})
					end
				end
				AbilityKit.Hooks.shatterGlassCone(ctx.Root.Position, dir, 12, 80, ctx.Character)
			end
			AbilityKit.fx("SonicBoom", ctx.Root.Position, { Position = ctx.Root.Position, Direction = dir, Color = Color3.fromRGB(255, 110, 220) })
		end)
		return true
	end,
}

return SoundBarrierDash
