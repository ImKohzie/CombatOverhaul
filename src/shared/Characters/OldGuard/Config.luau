--!strict
-- Old Guard: character definition. Numbers live in Config/BalanceConfig.

local Types = require(script.Parent.Parent.Parent.Types)

local config: Types.CharacterConfig = {
	Id = "OldGuard",
	DisplayName = "Old Guard",
	Role = "Bruiser",
	Difficulty = 2,
	Order = 3,
	Tagline = "A battered veteran super-soldier with a round metal shield.",
	Movement = "Ground",
	Palette = {
		Primary = Color3.fromRGB(70, 80, 60),
		Secondary = Color3.fromRGB(120, 110, 95),
		Glow = Color3.fromRGB(120, 255, 140),
	},
	Abilities = {
		Ability1 = {
			Id = "RicochetShield",
			Name = "Ricochet Shield",
			Input = "Instant",
			Description = "Throw your shield. It bounces between up to 3 targets or surfaces, then returns.",
		},
		Ability2 = {
			Id = "ShieldBash",
			Name = "Shield Bash & Brace",
			Input = "Hold",
			Description = "Tap for a staggering bash. Hold to brace, blocking beams from the front.",
		},
		Ability3 = {
			Id = "BrawlersFury",
			Name = "Brawler's Fury",
			Input = "Instant",
			Description = "A fast 6-hit brutality combo ending in a launcher.",
		},
		Ultimate = {
			Id = "CoreMeltdown",
			Name = "Core Meltdown",
			Input = "Instant",
			Description = "Channel unstable chest energy for 2s, then release a radiation blast that leaves a lingering zone.",
		},
	},
	Animations = {},
	Sounds = {},
}

return config
