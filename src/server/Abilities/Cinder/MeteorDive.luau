--!strict
-- Cinder R: Meteor Dive. Rocket up, then crash down on the crosshair in a fireball.

local AbilityTypes = require(script.Parent.Parent.Parent.AbilityTypes)
local AbilityKit = require(script.Parent.Parent.Parent.AbilityKit)
local MovementService = require(script.Parent.Parent.Parent.Services.MovementService)

local function groundAt(point: Vector3): Vector3
	local ground = AbilityKit.groundBelow(point + Vector3.new(0, 20, 0), 200)
	return if ground then ground.Position else point
end

local MeteorDive: AbilityTypes.AbilityModule = {
	Begin = function(ctx)
		local windUp = ctx.Balance.WindUp or 0.35
		local radius = AbilityKit.param(ctx, "Radius", 16)
		local target = groundAt(ctx.AimPoint)
		MovementService.exempt(ctx.Player, 3)
		AbilityKit.Status.apply(ctx.Character, "Unstoppable", "Flag", windUp + 1.2)
		AbilityKit.pose(ctx, "DiveSlam", { Duration = windUp + 1 })
		AbilityKit.impulseSelf(ctx, Vector3.new(0, 90, 0), windUp)
		AbilityKit.fx("Explosion", ctx.Root.Position, { Position = ctx.Root.Position, Radius = 5, Kind = "Fire" })
		task.delay(windUp, function()
			if not AbilityKit.isAlive(ctx.Character) then
				return
			end
			local offset = target - ctx.Root.Position
			if offset.Magnitude < 1 then
				offset = Vector3.new(0, -1, 0)
			end
			AbilityKit.impulseSelf(ctx, offset.Unit * 230, math.min(offset.Magnitude / 230, 0.9))
			local started = os.clock()
			while os.clock() - started < 1 and AbilityKit.isAlive(ctx.Character) do
				task.wait(0.03)
				local below = AbilityKit.groundBelow(ctx.Root.Position, 6)
				if below or (ctx.Root.Position - target).Magnitude < 8 then
					break
				end
			end
			if not AbilityKit.isAlive(ctx.Character) then
				return
			end
			local center = ctx.Root.Position
			AbilityKit.falloffBlast(ctx, center, radius, radius * 0.4, ctx.Balance.Damage, 0.5, 90, 45, 1)
			AbilityKit.Hooks.structureDamageSphere(center, radius * 0.7, 600, 5000, ctx.Character)
			AbilityKit.fx("Explosion", center, { Position = center, Radius = radius * 0.8, Kind = "Fire" })
			AbilityKit.fx("Crater", center, { Position = center, Strength = 0.8, Source = ctx.Character, Color = Color3.fromRGB(255, 130, 40) })
			AbilityKit.fx("TraversalImpact", center, { Kind = "Blast", Position = center, Direction = Vector3.yAxis, Color = Color3.fromRGB(255, 130, 40), Source = ctx.Character, Strength = 1 })
		end)
		return true
	end,
}

return MeteorDive
