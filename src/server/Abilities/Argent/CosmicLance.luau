--!strict
-- Argent Q: Cosmic Lance. Hold for a white-blue energy beam from the hands.

local AbilityTypes = require(script.Parent.Parent.Parent.AbilityTypes)
local AbilityKit = require(script.Parent.Parent.Parent.AbilityKit)
local BeamService = require(script.Parent.Parent.Parent.Services.BeamService)

local BEAM_ID = "CosmicLance"

local CosmicLance: AbilityTypes.AbilityModule = {
	Begin = function(ctx)
		if not BeamService.canFire(ctx.Player) then
			AbilityKit.notify(ctx, "Overheated!")
			return false
		end
		local beam = BeamService.start(ctx.Player, ctx.Character, {
			Id = BEAM_ID,
			Dps = AbilityKit.param(ctx, "Dps", 55),
			Range = ctx.Balance.Range or 300,
			Width = 0.9,
			Radius = 1.4,
			Color = Color3.fromRGB(150, 205, 255),
			Source = "Hands",
			StructureDps = 260,
			Pierce = 1,
			MaxDamagePerTarget = ctx.Balance.Damage,
			Tag = ctx.Def.Name,
		}, ctx.AimPoint)
		if not beam then
			return false
		end
		AbilityKit.pose(ctx, "Channel", { Loop = true })
		return true
	end,
	End = function(ctx)
		BeamService.stop(ctx.Player, BEAM_ID)
		AbilityKit.stopPose(ctx)
	end,
}

return CosmicLance
