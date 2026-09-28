--!strict
-- Rampage R: Rip & Throw. Tear a chunk out of a nearby building (or the
-- ground) and hurl it.

local AbilityTypes = require(script.Parent.Parent.Parent.AbilityTypes)
local AbilityKit = require(script.Parent.Parent.Parent.AbilityKit)

local GRAB_REACH = 14
local SPLASH = 11

local RipAndThrow: AbilityTypes.AbilityModule = {
	Begin = function(ctx)
		local windUp = ctx.Balance.WindUp or 0.7
		-- Source material: a structure chunk within reach, else the ground.
		local color = Color3.fromRGB(110, 100, 90)
		local material = Enum.Material.Slate
		local params = AbilityKit.worldParams()
		local probe = workspace:Raycast(ctx.Root.Position, ctx.Root.CFrame.LookVector * GRAB_REACH, params)
			or workspace:Raycast(ctx.Root.Position, Vector3.new(0, -10, 0), params)
		if probe and probe.Instance:IsA("BasePart") then
			if AbilityKit.Hooks.isStructure(probe.Instance) then
				local ripColor, ripMaterial = AbilityKit.Hooks.ripChunk(probe.Instance)
				color = ripColor or probe.Instance.Color
				material = ripMaterial or probe.Instance.Material
			else
				color = probe.Instance.Color
				material = probe.Material
			end
		end
		AbilityKit.pose(ctx, "Grab")
		-- Held chunk over the head during the wind-up
		local head = ctx.Character:FindFirstChild("Head")
		local held = AbilityKit.serverPart(Vector3.new(5, 4, 5), ctx.Root.CFrame * CFrame.new(0, 6, 0), color, material)
		held.Anchored = false
		held.Massless = true
		if head and head:IsA("BasePart") then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = head
			weld.Part1 = held
			weld.Parent = held
		end
		task.delay(windUp, function()
			held:Destroy()
			if not AbilityKit.isAlive(ctx.Character) then
				return
			end
			AbilityKit.pose(ctx, "Throw")
			local origin = ctx.Root.Position + Vector3.new(0, 7, 0)
			AbilityKit.projectile({
				Origin = origin,
				Direction = (ctx.AimPoint + Vector3.new(0, 6, 0)) - origin,
				Speed = 170,
				Range = ctx.Balance.Range or 200,
				Radius = 2.5,
				Gravity = 30,
				Owner = ctx.Character,
				Visual = "Rock",
				VisualData = { Color = color, Width = 5 },
				OnHit = function(position, character, part)
					if character then
						AbilityKit.damage(ctx, character, ctx.Balance.Damage, {
							Kind = "Projectile",
							Position = position,
							Knockback = AbilityKit.awayFrom(origin, character, 80, 30),
							Ragdoll = 1,
							HitStun = 0.8,
						})
					end
					AbilityKit.blast(ctx, position, SPLASH, ctx.Balance.Damage * 0.4, 50, 25, nil, 320)
					if part then
						AbilityKit.Hooks.structureDamageAt(part, position, 400, 4000, ctx.Character)
					end
					AbilityKit.fx("Explosion", position, { Position = position, Radius = SPLASH, Kind = "Fire", Color = color })
				end,
			})
		end)
		return true
	end,
}

return RipAndThrow
