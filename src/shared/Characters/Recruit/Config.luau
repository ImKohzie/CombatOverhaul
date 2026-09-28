--!strict
-- Recruit (Test): character definition. Numbers live in Config/BalanceConfig.

local Types = require(script.Parent.Parent.Parent.Types)

local config: Types.CharacterConfig = {
	Id = "Recruit",
	DisplayName = "Recruit (Test)",
	Role = "Balanced",
	Difficulty = 1,
	Order = 0,
	Tagline = "Pipeline test dummy. Removed before release.",
	Movement = "Ground",
	Palette = {
		Primary = Color3.fromRGB(90, 90, 100),
		Secondary = Color3.fromRGB(40, 40, 48),
		Glow = Color3.fromRGB(0, 170, 255),
	},
	Abilities = {
		Ability1 = {
			Id = "Pulse",
			Name = "Test Pulse",
			Input = "Instant",
			Description = "Emits a test energy ring. Proves the ability pipeline end to end.",
		},
		Ability2 = {
			Id = "Placeholder",
			Name = "Placeholder",
			Input = "Instant",
			Description = "Not implemented.",
		},
		Ability3 = {
			Id = "Placeholder",
			Name = "Placeholder",
			Input = "Instant",
			Description = "Not implemented.",
		},
		Ultimate = {
			Id = "Placeholder",
			Name = "Placeholder",
			Input = "Instant",
			Description = "Not implemented.",
		},
	},
	Animations = {},
	Sounds = {},
	Hidden = true,
}

return config
