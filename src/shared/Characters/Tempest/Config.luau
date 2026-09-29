--!strict
-- Tempest: character definition. Numbers live in Config/BalanceConfig.

local Types = require(script.Parent.Parent.Parent.Types)

local config: Types.CharacterConfig = {
	Id = "Tempest",
	DisplayName = "Tempest",
	Role = "Agile",
	Difficulty = 3,
	Order = 14,
	Tagline = "A storm-caller who rides the wind itself.",
	Movement = "Ground",
	Palette = {
		Primary = Color3.fromRGB(210, 232, 236),
		Secondary = Color3.fromRGB(40, 90, 110),
		Glow = Color3.fromRGB(140, 255, 230),
	},
	Abilities = {
		Ability1 = {
			Id = "GaleCutter",
			Name = "Gale Cutter",
			Input = "Instant",
			Description = "Fire three razor-sharp wind blades.",
		},
		Ability2 = {
			Id = "Cyclone",
			Name = "Cyclone",
			Input = "Instant",
			Description = "Summon a tornado that drags enemies and debris into it.",
		},
		Ability3 = {
			Id = "Updraft",
			Name = "Updraft",
			Input = "Instant",
			Description = "Blast yourself and every nearby enemy high into the sky.",
		},
		Ultimate = {
			Id = "EyeOfTheStorm",
			Name = "Eye of the Storm",
			Input = "Instant",
			Description = "Become the eye of a hurricane that shreds everything around you.",
		},
	},
	Animations = {},
	Sounds = {},
}

return config
