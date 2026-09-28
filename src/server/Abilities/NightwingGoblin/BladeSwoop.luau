--!strict
-- Nightwing Goblin E: Blade Swoop. The glider's wing blades extend and you
-- slash through everything along a high-speed swoop.

local RunService = game:GetService("RunService")

local AbilityTypes = require(script.Parent.Parent.Parent.AbilityTypes)
local AbilityKit = require(script.Parent.Parent.Parent.AbilityKit)
local MovementService = require(script.Parent.Parent.Parent.Services.MovementService)

local SPEED = 150

local BladeSwoop: AbilityTypes.AbilityModule = {
	Begin = function(ctx)
		local range = ctx.Balance.Range or 80
		local duration = range / SPEED
		local dir = (ctx.AimPoint - ctx.Root.Position)
		dir = if dir.Magnitude > 1e-3 then dir.Unit else ctx.Root.CFrame.LookVector
		MovementService.exempt(ctx.Player, duration + 1)
		AbilityKit.impulseSelf(ctx, dir * SPEED, duration)
		AbilityKit.fx("BladeTrail", ctx.Root.Position, { Source = ctx.Character, Duration = duration + 0.1, Color = Color3.fromRGB(140, 255, 60) })
		task.spawn(function()
			local hit: { [Model]: boolean } = {}
			local elapsed = 0
			while elapsed < duration and AbilityKit.isAlive(ctx.Character) do
				elapsed += RunService.Heartbeat:Wait()
				for _, victim in AbilityKit.inBox(ctx.Root.CFrame, Vector3.new(13, 5, 8), { ctx.Character }) do
					if not hit[victim] then
						hit[victim] = true
						local side = if (AbilityKit.rootOf(victim) :: BasePart).Position:Dot(ctx.Root.CFrame.RightVector) > ctx.Root.Position:Dot(ctx.Root.CFrame.RightVector) then 1 else -1
						AbilityKit.damage(ctx, victim, ctx.Balance.Damage, {
							Kind = "Melee",
							CanParry = true,
							Knockback = ctx.Root.CFrame.RightVector * side * 45 + Vector3.new(0, 20, 0),
							HitStun = 0.6,
						})
					end
				end
				AbilityKit.Hooks.structureDamageSphere(ctx.Root.Position, 6, 140, 1500, ctx.Character)
			end
		end)
		return true
	end,
}

return BladeSwoop
