--!strict
-- Swarm E: Disassemble. Hold to stream nanites that eat through a targeted
-- structure piece by piece (and gnaw on anyone caught in the stream).

local AbilityTypes = require(script.Parent.Parent.Parent.AbilityTypes)
local AbilityKit = require(script.Parent.Parent.Parent.AbilityKit)
local BeamService = require(script.Parent.Parent.Parent.Services.BeamService)

local BEAM_ID = "Disassemble"

local Disassemble: AbilityTypes.AbilityModule = {
	Begin = function(ctx)
		if not BeamService.canFire(ctx.Player) then
			AbilityKit.notify(ctx, "Overheated!")
			return false
		end
		local duration = ctx.Balance.Duration or 4
		local beam = BeamService.start(ctx.Player, ctx.Character, {
			Id = BEAM_ID,
			Dps = ctx.Balance.Damage / duration,
			Range = ctx.Balance.Range or 100,
			Width = 1.4,
			Radius = 1.2,
			Color = Color3.fromRGB(170, 175, 185),
			Source = "Hands",
			StructureDps = 700,
			HeatPerSecond = 15,
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

return Disassemble
