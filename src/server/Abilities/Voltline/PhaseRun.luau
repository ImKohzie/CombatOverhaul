--!strict
-- Voltline Q: Phase Run. Vibrate through walls, structures and players for
-- 3-5s (scales with stamina at cast). The client moves through geometry
-- (ApexPhasing); the server damages everything passed through and cracks
-- structures behind you.

local RunService = game:GetService("RunService")

local AbilityTypes = require(script.Parent.Parent.Parent.AbilityTypes)
local AbilityKit = require(script.Parent.Parent.Parent.AbilityKit)
local PlayerStateService = require(script.Parent.Parent.Parent.Services.PlayerStateService)
local MovementService = require(script.Parent.Parent.Parent.Services.MovementService)

local TICK = 0.1
local PER_TARGET_HIT = 20
local RETRIGGER = 0.5

local PhaseRun: AbilityTypes.AbilityModule = {
	Begin = function(ctx)
		local minDuration = AbilityKit.param(ctx, "MinDuration", 3)
		local maxDuration = ctx.Balance.Duration or 5
		local state = PlayerStateService.get(ctx.Player)
		local staminaFraction = if state then state.Stamina / 100 else 0.5
		local duration = minDuration + (maxDuration - minDuration) * math.clamp(staminaFraction, 0, 1)

		AbilityKit.Status.apply(ctx.Character, "Phasing", "Flag", duration)
		AbilityKit.Status.apply(ctx.Character, "PhaseRun", "Speed", duration, 1.25)
		MovementService.exempt(ctx.Player, duration + 0.5)

		task.spawn(function()
			local lastHit: { [Model]: number } = {}
			local total: { [Model]: number } = {}
			local elapsed = 0
			local accumulator = 0
			while elapsed < duration and AbilityKit.isAlive(ctx.Character) do
				local dt = RunService.Heartbeat:Wait()
				elapsed += dt
				accumulator += dt
				if accumulator < TICK then
					continue
				end
				accumulator = 0
				local root = ctx.Root
				local now = os.clock()
				for _, victim in AbilityKit.inBox(root.CFrame, Vector3.new(6, 7, 6), { ctx.Character }) do
					if (total[victim] or 0) < ctx.Balance.Damage and now - (lastHit[victim] or 0) >= RETRIGGER then
						lastHit[victim] = now
						local amount = math.min(PER_TARGET_HIT, ctx.Balance.Damage - (total[victim] or 0))
						local dealt = AbilityKit.damage(ctx, victim, amount, {
							Kind = "AoE",
							Position = root.Position,
							HitStun = 0.25,
							Knockback = root.CFrame.RightVector * (if math.random() < 0.5 then -30 else 30),
						})
						total[victim] = (total[victim] or 0) + dealt
					end
				end
				-- Crack whatever we are inside of.
				AbilityKit.Hooks.structureDamageSphere(root.Position, 4, 35, 0, ctx.Character)
			end
		end)
		return true
	end,
}

return PhaseRun
