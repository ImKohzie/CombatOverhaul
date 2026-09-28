--!strict
-- Umbra Q: Shadow Step. Teleport to any shadowed spot within 150 studs. A
-- spot counts as shadow if the sun is blocked from it, it's night, or
-- Umbra's Eclipse is active.

local Lighting = game:GetService("Lighting")

local AbilityTypes = require(script.Parent.Parent.Parent.AbilityTypes)
local AbilityKit = require(script.Parent.Parent.Parent.AbilityKit)
local MovementService = require(script.Parent.Parent.Parent.Services.MovementService)

local ShadowStep = {}

function ShadowStep.isShadowed(position: Vector3, caster: Model): boolean
	if caster:GetAttribute("ApexEclipse") == true then
		return true
	end
	local clock = Lighting.ClockTime
	if clock < 6.3 or clock > 17.7 then
		return true
	end
	local sun = Lighting:GetSunDirection()
	if sun.Y <= 0.05 then
		return true
	end
	local blocked = workspace:Raycast(position + Vector3.new(0, 2.5, 0), sun * 600, AbilityKit.worldParams({ caster :: Instance }))
	return blocked ~= nil
end

ShadowStep.module = {
	Begin = function(ctx)
		local dir = ctx.AimPoint - ctx.AimOrigin
		local hit = workspace:Raycast(ctx.AimOrigin, dir.Unit * (ctx.Balance.Range or 150), AbilityKit.worldParams())
		if not hit then
			AbilityKit.notify(ctx, "No surface to step to")
			return false
		end
		local spot = hit.Position + hit.Normal * 3
		if hit.Normal.Y < 0.5 then
			-- Wall: drop to the floor at its base
			local ground = AbilityKit.groundBelow(spot, 80)
			if ground then
				spot = ground.Position + Vector3.new(0, 3, 0)
			end
		end
		if not ShadowStep.isShadowed(spot, ctx.Character) then
			AbilityKit.notify(ctx, "That spot is in the light")
			return false
		end
		local from = ctx.Root.Position
		AbilityKit.fx("ShadowPuff", from, { Position = from })
		MovementService.exempt(ctx.Player, 1)
		local look = Vector3.new(dir.X, 0, dir.Z)
		look = if look.Magnitude > 1e-3 then look.Unit else ctx.Root.CFrame.LookVector
		ctx.Character:PivotTo(CFrame.lookAt(spot, spot + look))
		AbilityKit.fx("ShadowPuff", spot, { Position = spot })
		return true
	end,
} :: AbilityTypes.AbilityModule

return ShadowStep.module
