--!strict
-- Non-balance game settings: networking limits, anti-cheat, world numbers.

local GameConfig = {}

GameConfig.DefaultCharacter = "Recruit"

GameConfig.Net = {
	-- Invalid or rate-limited requests add a strike. Too many strikes in the
	-- window kicks the player (exploit protection). Set KickEnabled = false
	-- while debugging if needed.
	StrikeWindow = 60,
	StrikesToKick = 40,
	KickEnabled = true,
	MaxStringLength = 48,
	MaxAimDistance = 1200, -- aim point must be this close to the character
	MaxAimOriginOffset = 20, -- aim origin must be this close to the character's head
}

GameConfig.World = {
	CityHalfSize = 1250, -- 2500 x 2500 city
	BorderRadius = 3500,
	BorderWarnDistance = 250,
}

GameConfig.Debris = {
	MaxLooseParts = 1200,
	FadeMin = 20,
	FadeMax = 40,
	RebuildTime = 120,
}

GameConfig.Debug = {
	ShowDebugHud = true, -- temporary HUD until Phase 8 UI
	VerboseNet = false, -- print every rejected remote request
}

return GameConfig
