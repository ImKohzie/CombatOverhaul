--!strict
-- Recruit / Test Pulse: proves input -> validation -> cooldown -> effect
-- broadcast end to end. Visual only until the Phase 3 damage pipeline.

local AbilityTypes = require(script.Parent.Parent.Parent.AbilityTypes)
local NetService = require(script.Parent.Parent.Parent.Services.NetService)

local EFFECT_RADIUS = 400 -- players further away don't receive the effect

local Pulse: AbilityTypes.AbilityModule = {
	Begin = function(ctx)
		local range = ctx.Balance.Range or 18
		NetService.fireNear("Effect", ctx.Root.Position, EFFECT_RADIUS, "Pulse", {
			Position = ctx.Root.Position,
			Radius = range,
			Source = ctx.Character,
		})
		return true
	end,
}

return Pulse
