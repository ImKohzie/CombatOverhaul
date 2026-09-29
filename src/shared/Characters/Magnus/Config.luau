--!strict
-- Magnus: character definition. Numbers live in Config/BalanceConfig.

local Types = require(script.Parent.Parent.Parent.Types)

local config: Types.CharacterConfig = {
	Id = "Magnus",
	DisplayName = "Magnus",
	Role = "Bruiser",
	Difficulty = 3,
	Order = 15,
	Tagline = "A magnetic powerhouse who bends steel to his will.",
	Movement = "Flight",
	FlightProfile = "Standard",
	Palette = {
		Primary = Color3.fromRGB(120, 20, 40),
		Secondary = Color3.fromRGB(60, 60, 70),
		Glow = Color3.fromRGB(255, 70, 90),
	},
	Abilities = {
		Ability1 = {
			Id = "ScrapVolley",
			Name = "Scrap Volley",
			Input = "Instant",
			Description = "Tear up scrap metal and fling it in a spread.",
		},
		Ability2 = {
			Id = "PolarityPull",
			Name = "Polarity Pull",
			Input = "Instant",
			Description = "Magnetically yank the enemy under your crosshair to you.",
		},
		Ability3 = {
			Id = "Repulse",
			Name = "Repulse",
			Input = "Instant",
			Description = "A magnetic shockwave that hurls enemies and debris away.",
		},
		Ultimate = {
			Id = "IronStorm",
			Name = "Iron Storm",
			Input = "Instant",
			Description = "Rain a storm of wreckage down on the target area.",
		},
	},
	Animations = {},
	Sounds = {},
}

return config
