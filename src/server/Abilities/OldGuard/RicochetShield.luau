--!strict
-- Old Guard Q: Ricochet Shield. Throw the shield; it bounces between up to
-- 3 targets or surfaces, then flies back.

local AbilityTypes = require(script.Parent.Parent.Parent.AbilityTypes)
local AbilityKit = require(script.Parent.Parent.Parent.AbilityKit)

local SPEED = 150
local BOUNCE_SEARCH = 45

local function returnHome(ctx: AbilityTypes.AbilityContext, from: Vector3)
	AbilityKit.projectile({
		Origin = from,
		Direction = ctx.Root.Position - from,
		Speed = SPEED,
		Range = 300,
		Radius = 1,
		Owner = ctx.Character,
		Homing = ctx.Character,
		HomingStrength = 12,
		Visual = "Shield",
		OnHit = function()
			AbilityKit.Status.remove(ctx.Character, "ShieldOut")
		end,
	})
	-- Safety: shield is "back" after a moment even if the return misses.
	task.delay(3, function()
		AbilityKit.Status.remove(ctx.Character, "ShieldOut")
	end)
end

local function throw(ctx: AbilityTypes.AbilityContext, origin: Vector3, direction: Vector3, bouncesLeft: number, alreadyHit: { [Model]: boolean }, damage: number)
	AbilityKit.projectile({
		Origin = origin,
		Direction = direction,
		Speed = SPEED,
		Range = ctx.Balance.Range or 120,
		Radius = 1.3,
		Owner = ctx.Character,
		Light = true,
		ReflectDamage = 50,
		Visual = "Shield",
		OnHit = function(position, character, part)
			if character and not alreadyHit[character] then
				alreadyHit[character] = true
				AbilityKit.damage(ctx, character, damage, {
					Kind = "Projectile",
					Position = position,
					Knockback = direction.Unit * 45 + Vector3.new(0, 15, 0),
					HitStun = 0.5,
				})
			elseif part then
				AbilityKit.Hooks.structureDamageAt(part, position, 60, 800, ctx.Character)
			end
			AbilityKit.fx("Explosion", position, { Position = position, Radius = 3, Kind = "Electric", Color = Color3.fromRGB(220, 220, 230) })
			if bouncesLeft <= 0 then
				returnHome(ctx, position)
				return
			end
			-- Next bounce: nearest target not hit yet, else reflect off the surface
			local candidates = {}
			for _, other in AbilityKit.inSphere(position, BOUNCE_SEARCH, { ctx.Character }) do
				if not alreadyHit[other] then
					table.insert(candidates, other)
				end
			end
			local nextTarget = AbilityKit.nearest(candidates, position)
			local nextRoot = nextTarget and AbilityKit.rootOf(nextTarget)
			local newDirection: Vector3
			if nextRoot then
				newDirection = nextRoot.Position - position
			else
				local d = direction.Unit
				local normal = if character then -d else Vector3.yAxis
				if part then
					local probe = workspace:Raycast(position - d * 2, d * 4, AbilityKit.worldParams())
					if probe then
						normal = probe.Normal
					end
				end
				newDirection = d - 2 * d:Dot(normal) * normal
			end
			throw(ctx, position + newDirection.Unit * 1.5, newDirection, bouncesLeft - 1, alreadyHit, damage * 0.8)
		end,
	})
end

local RicochetShield: AbilityTypes.AbilityModule = {
	Begin = function(ctx)
		AbilityKit.pose(ctx, "Throw")
		AbilityKit.Status.apply(ctx.Character, "ShieldOut", "Flag", 6)
		task.delay(0.15, function()
			local origin = ctx.Root.Position + Vector3.new(0, 1, 0) + ctx.Root.CFrame.LookVector * 2
			throw(ctx, origin, ctx.AimPoint - origin, AbilityKit.param(ctx, "Bounces", 3), {}, ctx.Balance.Damage)
		end)
		return true
	end,
}

return RicochetShield
