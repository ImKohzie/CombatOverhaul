--!strict
-- Glitch: character definition. Numbers live in Config/BalanceConfig.

local Types = require(script.Parent.Parent.Parent.Types)

local config: Types.CharacterConfig = {
	Id = "Glitch",
	DisplayName = "Glitch",
	Role = "Agile",
	Difficulty = 4,
	Order = 19,
	Tagline = "A hacker who jumped into the network and came back wrong.",
	Movement = "Ground",
	Palette = {
		Primary = Color3.fromRGB(22, 22, 30),
		Secondary = Color3.fromRGB(0, 255, 170),
		Glow = Color3.fromRGB(255, 40, 200),
	},
	Abilities = {
		Ability1 = {
			Id = "LagSpike",
			Name = "Lag Spike",
			Input = "Instant",
			Description = "Teleport-strike the enemy under your crosshair.",
		},
		Ability2 = {
			Id = "Buffer",
			Name = "Buffer",
			Input = "Instant",
			Description = "Vanish from sight and move faster for 3s.",
		},
		Ability3 = {
			Id = "PixelStorm",
			Name = "Pixel Storm",
			Input = "Instant",
			Description = "Spray a burst of corrupted data bolts.",
		},
		Ultimate = {
			Id = "SystemCrash",
			Name = "System Crash",
			Input = "Instant",
			Description = "Crash every enemy nearby: they freeze solid and take heavy damage.",
		},
	},
	Animations = {},
	Sounds = {},
}

return config
