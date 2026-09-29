--!strict
-- Rebound G (Ultimate): Pinball Frenzy. Ricochet between every nearby enemy.

local AbilityTypes = require(script.Parent.Parent.Parent.AbilityTypes)
local AbilityKit = require(script.Parent.Parent.Parent.AbilityKit)


local PinballFrenzy: AbilityTypes.AbilityModule = {
	Begin = function(ctx)
		local radius = ctx.Balance.Range or 70
		local targets = AbilityKit.inSphere(ctx.Root.Position, radius, { ctx.Character })
		if #targets == 0 then
			AbilityKit.notify(ctx, "No one nearby to bounce off")
			return false
		end
		local hits = math.floor(AbilityKit.param(ctx, "Hits", 6))
		local each = ctx.Balance.Damage / hits
		local budget = AbilityKit.budget(ctx.Balance.Damage)
		if not AbilityKit.takeControl(ctx.Character) then
			return false
		end
		AbilityKit.Status.apply(ctx.Character, "Unstoppable", "Flag", hits * 0.3 + 0.5)
		task.spawn(function()
			local ok, err = pcall(function()
				for i = 1, hits do
					local victim = targets[(i - 1) % #targets + 1]
					local root = AbilityKit.rootOf(victim)
					if root and AbilityKit.isAlive(victim) then
						local from = ctx.Root.Position
						local side = CFrame.Angles(0, math.random() * math.pi * 2, 0).LookVector
						local stop = root.Position + side * 4
						AbilityKit.glide(ctx.Character, CFrame.lookAt(stop, root.Position), 0.1)
						AbilityKit.fx("Afterimage", stop, { Source = ctx.Character, From = from, To = stop, Color = Color3.fromRGB(255, 200, 40) })
						local amount = budget(victim, each)
						if amount > 0 then
							AbilityKit.damage(ctx, victim, amount, { Kind = "Melee", CanParry = false, Position = root.Position, Knockback = -side * 40 + Vector3.new(0, 30, 0), HitStun = 0.6 })
						end
						AbilityKit.fx("TraversalImpact", root.Position, { Kind = "Hit", Position = root.Position, Direction = -side, Color = Color3.fromRGB(255, 200, 40), Source = ctx.Character, Target = victim, Strength = 0.7 })
					end
					task.wait(0.18)
				end
			end)
			if not ok then
				warn("[PinballFrenzy] " .. tostring(err))
			end
			AbilityKit.releaseControl(ctx.Character, Vector3.new(0, 40, 0))
		end)
		return true
	end,
}

return PinballFrenzy
