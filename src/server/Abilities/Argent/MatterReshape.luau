--!strict
-- Argent E: Matter Reshape. Aim at a building section to transmute it into
-- shrapnel fired at enemies; aim at open ground to raise a hardened chrome
-- shield wall that blocks shots and beams.

local Debris = game:GetService("Debris")

local AbilityTypes = require(script.Parent.Parent.Parent.AbilityTypes)
local AbilityKit = require(script.Parent.Parent.Parent.AbilityKit)

local WALL_TIME = 6
local SHARDS = 6

local MatterReshape: AbilityTypes.AbilityModule = {
	Begin = function(ctx)
		AbilityKit.pose(ctx, "CastRight")
		local dir = ctx.AimPoint - ctx.AimOrigin
		local hit = workspace:Raycast(ctx.AimOrigin, dir.Unit * (ctx.Balance.Range or 120), AbilityKit.worldParams())
		if hit and hit.Instance:IsA("BasePart") and AbilityKit.Hooks.isStructure(hit.Instance) then
			-- Shrapnel
			local color = AbilityKit.Hooks.ripChunk(hit.Instance)
			local origin = hit.Position + hit.Normal * 2
			local target = AbilityKit.aimTarget(ctx, 160, 60)
			local budget = AbilityKit.budget(ctx.Balance.Damage)
			for i = 1, SHARDS do
				local aimAt = if target and AbilityKit.rootOf(target) then (AbilityKit.rootOf(target) :: BasePart).Position else ctx.AimPoint
				local spread = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 0.25
				task.delay(i * 0.04, function()
					AbilityKit.projectile({
						Origin = origin,
						Direction = (aimAt - origin).Unit + spread,
						Speed = 200,
						Range = 180,
						Radius = 0.7,
						Owner = ctx.Character,
						Homing = target,
						HomingStrength = 3,
						Visual = "Shard",
						VisualData = { Color = color or Color3.fromRGB(200, 205, 215), Width = 0.7 },
						OnHit = function(position, character)
							if character then
								local amount = budget(character, ctx.Balance.Damage / 3)
								if amount > 0 then
									AbilityKit.damage(ctx, character, amount, { Kind = "Projectile", Position = position, HitStun = 0.3 })
								end
							end
						end,
					})
				end)
			end
			AbilityKit.fx("Explosion", origin, { Position = origin, Radius = 5, Kind = "Nova" })
		else
			-- Shield wall on the ground at the aim point, facing Argent
			local ground = AbilityKit.groundBelow(ctx.AimPoint + Vector3.new(0, 5, 0), 60)
			local base = if ground then ground.Position else ctx.AimPoint
			local toArgent = ctx.Root.Position - base
			local facing = Vector3.new(toArgent.X, 0, toArgent.Z)
			facing = if facing.Magnitude > 1e-3 then facing.Unit else Vector3.zAxis
			local wall = AbilityKit.serverPart(
				Vector3.new(14, 11, 1.4),
				CFrame.lookAt(base + Vector3.new(0, 5.5, 0), base + Vector3.new(0, 5.5, 0) + facing),
				Color3.fromRGB(220, 225, 235),
				Enum.Material.Foil,
				true
			)
			wall.Name = "ApexChromeWall"
			wall.Reflectance = 0.6
			Debris:AddItem(wall, WALL_TIME)
			AbilityKit.fx("ChargeAura", base, { Source = ctx.Character, Color = Color3.fromRGB(150, 205, 255), Duration = 0.5 })
		end
		return true
	end,
}

return MatterReshape
