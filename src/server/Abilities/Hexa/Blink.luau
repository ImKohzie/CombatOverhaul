--!strict
-- Hexa R: Blink. Teleport to the crosshair, leaving an arcane blast behind.

local AbilityTypes = require(script.Parent.Parent.Parent.AbilityTypes)
local AbilityKit = require(script.Parent.Parent.Parent.AbilityKit)
local MovementService = require(script.Parent.Parent.Parent.Services.MovementService)


local Blink: AbilityTypes.AbilityModule = {
	Begin = function(ctx)
		local range = ctx.Balance.Range or 90
		local dir = ctx.AimPoint - ctx.AimOrigin
		if dir.Magnitude < 1e-3 then
			return false
		end
		local hit = workspace:Raycast(ctx.AimOrigin, dir.Unit * range, AbilityKit.worldParams())
		local spot = if hit then hit.Position + hit.Normal * 3 else ctx.AimOrigin + dir.Unit * range
		local ground = AbilityKit.groundBelow(spot, 80)
		if ground then
			spot = ground.Position + Vector3.new(0, 3, 0)
		end
		local from = ctx.Root.Position
		AbilityKit.blast(ctx, from, 14, ctx.Balance.Damage, 70, 30, nil, 150)
		AbilityKit.fx("Explosion", from, { Position = from, Radius = 8, Kind = "Nova" })
		AbilityKit.fx("Rune", from, { Position = from - Vector3.new(0, 2.8, 0), Radius = 10, Duration = 0.6, Color = Color3.fromRGB(200, 120, 255) })
		MovementService.exempt(ctx.Player, 1)
		local look = Vector3.new(dir.X, 0, dir.Z)
		look = if look.Magnitude > 1e-3 then look.Unit else ctx.Root.CFrame.LookVector
		ctx.Character:PivotTo(CFrame.lookAt(spot, spot + look))
		AbilityKit.fx("Afterimage", spot, { Source = ctx.Character, From = from, To = spot, Color = Color3.fromRGB(200, 120, 255) })
		return true
	end,
}

return Blink
