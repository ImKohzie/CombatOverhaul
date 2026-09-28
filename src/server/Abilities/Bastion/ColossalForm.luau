--!strict
-- Bastion G (Ultimate): Colossal Form. Grow to 3x for 15s with bonus armour.
-- Every step shakes the ground, flattens nearby structures and staggers
-- enemies; melee gains huge area (CombatService reads ApexColossal).

local RunService = game:GetService("RunService")

local AbilityTypes = require(script.Parent.Parent.Parent.AbilityTypes)
local AbilityKit = require(script.Parent.Parent.Parent.AbilityKit)

local BASE_SCALE = 1.25 -- Bastion's costume scale
local STEP_INTERVAL = 0.55
local STEP_RADIUS = 16
local STEP_DAMAGE = 35

local ColossalForm: AbilityTypes.AbilityModule = {
	Begin = function(ctx)
		local duration = ctx.Balance.Duration or 15
		local scale = AbilityKit.param(ctx, "Scale", 3)
		local character = ctx.Character
		AbilityKit.Status.apply(character, "Colossal", "Flag", duration)
		AbilityKit.Status.apply(character, "ColossalArmor", "Reduction", duration, AbilityKit.param(ctx, "BonusReduction", 0.25))
		AbilityKit.Status.apply(character, "Unstoppable", "Flag", duration)
		pcall(function()
			character:ScaleTo(BASE_SCALE * scale)
		end)
		AbilityKit.fx("Explosion", ctx.Root.Position, { Position = ctx.Root.Position, Radius = 20, Kind = "Fire", Color = Color3.fromRGB(255, 140, 60) })
		local budget = AbilityKit.budget(ctx.Balance.Damage)
		task.spawn(function()
			local elapsed = 0
			local sinceStep = 0
			while elapsed < duration and AbilityKit.isAlive(character) do
				local dt = RunService.Heartbeat:Wait()
				elapsed += dt
				sinceStep += dt
				local root = AbilityKit.rootOf(character)
				if not root then
					break
				end
				local velocity = root.AssemblyLinearVelocity
				local moving = Vector3.new(velocity.X, 0, velocity.Z).Magnitude > 4
				if moving and sinceStep >= STEP_INTERVAL then
					sinceStep = 0
					local ground = AbilityKit.groundBelow(root.Position, 60)
					local foot = if ground then ground.Position else root.Position
					for _, victim in AbilityKit.inSphere(foot, STEP_RADIUS, { character }) do
						local amount = budget(victim, STEP_DAMAGE)
						if amount > 0 then
							AbilityKit.damage(ctx, victim, amount, {
								Kind = "AoE",
								Position = foot,
								Knockback = AbilityKit.awayFrom(foot, victim, 40, 30),
								HitStun = 0.4,
							})
						end
					end
					AbilityKit.Hooks.structureDamageSphere(foot, STEP_RADIUS, 260, 3000, character)
					AbilityKit.fx("Stomp", foot, { Position = foot, Radius = STEP_RADIUS })
				end
			end
			if character.Parent then
				pcall(function()
					character:ScaleTo(BASE_SCALE)
				end)
			end
		end)
		return true
	end,
}

return ColossalForm
