--!strict
-- Rime: character definition. Numbers live in Config/BalanceConfig.

local Types = require(script.Parent.Parent.Parent.Types)

local config: Types.CharacterConfig = {
	Id = "Rime",
	DisplayName = "Rime",
	Role = "Agile",
	Difficulty = 3,
	Order = 9,
	Tagline = "A cryo-kinetic who skates on roads of ice.",
	Movement = "Ground",
	Palette = {
		Primary = Color3.fromRGB(180, 220, 255),
		Secondary = Color3.fromRGB(60, 90, 140),
		Glow = Color3.fromRGB(170, 240, 255),
	},
	Abilities = {
		Ability1 = {
			Id = "IceRoad",
			Name = "Ice Road",
			Input = "Hold",
			Description = "Create an ice slide path in the air to skate along.",
		},
		Ability2 = {
			Id = "FlashFreeze",
			Name = "Flash Freeze",
			Input = "Instant",
			Description = "Freeze a target solid for 1.5s. Hitting a frozen target shatters it for bonus damage.",
		},
		Ability3 = {
			Id = "GlacierSpike",
			Name = "Glacier Spike",
			Input = "Instant",
			Description = "Ice spikes erupt from the ground in a line.",
		},
		Ultimate = {
			Id = "AbsoluteZero",
			Name = "Absolute Zero",
			Input = "Instant",
			Description = "Freeze the whole area. Structures turn brittle and shatter from any hit for 8s.",
		},
	},
	Animations = {},
	Sounds = {},
}

return config
