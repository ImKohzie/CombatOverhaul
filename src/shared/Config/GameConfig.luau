--!strict
-- Non-balance game settings: networking limits, anti-cheat, world numbers.

local GameConfig = {}

GameConfig.DefaultCharacter = "Sovereign"

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

GameConfig.Environment = {
	DayLengthSeconds = 1200, -- full 24h cycle in 20 real minutes
	StartClockTime = 14,
	DuskClockTime = 18.1, -- city lights on
	DawnClockTime = 6.3, -- city lights off
	RainCheckInterval = { 240, 480 }, -- seconds between weather rolls
	RainChance = 0.35,
	RainDuration = { 120, 240 },
	CityAtmosphereDensity = 0.3,
	ForestAtmosphereDensity = 0.46,
}

GameConfig.Dummies = {
	Enabled = true,
	Roles = { "Tank", "Bruiser", "Balanced", "Agile" },
	RespawnTime = 5,
}

-- AI rival heroes that roam the city and fight players (and each other).
GameConfig.Bots = {
	Enabled = true,
	Count = 4, -- rivals the game keeps alive (lower for weak servers)
	MaxAlive = 10, -- hard cap: never more than this many rivals at once
	RespawnTime = 8,
	AggroRange = 150, -- studs: start hunting a player
	BotVsBotRange = 70, -- rivals only fight each other when this close and no players are near
	LeashRange = 450, -- studs from home before heading back
	SpawnRadius = 160, -- around the spawn
	Difficulty = "Normal", -- "Easy" | "Normal" | "Hard"
}

GameConfig.Debug = {
	ShowDebugHud = false, -- old Phase 1 debug panel (the real HUD replaces it)
	PrintBalanceMatrix = true, -- print the TTK matrix to the output on server start
	VerboseNet = false, -- print every rejected remote request
}

return GameConfig
