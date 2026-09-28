--!strict
-- Sovereign Q: Ocular Beam. Hold for twin red heat-vision beams from the
-- eyes. Full beam system: client renders per frame, server damages at 10Hz,
-- carves through structures, limited by heat and the ability's max channel.

local AbilityTypes = require(script.Parent.Parent.Parent.AbilityTypes)
local AbilityKit = require(script.Parent.Parent.Parent.AbilityKit)
local BeamService = require(script.Parent.Parent.Parent.Services.BeamService)

local BEAM_ID = "OcularBeam"

local OcularBeam: AbilityTypes.AbilityModule = {
	Begin = function(ctx)
		if not BeamService.canFire(ctx.Player) then
			AbilityKit.notify(ctx, "Overheated!")
			return false
		end
		local beam = BeamService.start(ctx.Player, ctx.Character, {
			Id = BEAM_ID,
			Dps = AbilityKit.param(ctx, "Dps", 60),
			Range = ctx.Balance.Range or 300,
			Width = 0.35,
			Radius = 1,
			Color = Color3.fromRGB(255, 40, 30),
			Source = "Eyes",
			Twin = true,
			StructureDps = 320,
			Pierce = 1,
			MaxDamagePerTarget = ctx.Balance.Damage,
			Tag = ctx.Def.Name,
		}, ctx.AimPoint)
		if not beam then
			return false
		end
		AbilityKit.pose(ctx, "EyeBeam", { Loop = true })
		return true
	end,
	End = function(ctx)
		BeamService.stop(ctx.Player, BEAM_ID)
		AbilityKit.stopPose(ctx)
	end,
}

return OcularBeam
