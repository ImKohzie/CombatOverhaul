--!strict
-- Thornwild: character definition. Numbers live in Config/BalanceConfig.

local Types = require(script.Parent.Parent.Parent.Types)

local config: Types.CharacterConfig = {
	Id = "Thornwild",
	DisplayName = "Thornwild",
	Role = "Tank",
	Difficulty = 2,
	Order = 18,
	Tagline = "A walking forest that is taking the city back.",
	Movement = "Ground",
	Palette = {
		Primary = Color3.fromRGB(70, 92, 42),
		Secondary = Color3.fromRGB(92, 62, 40),
		Glow = Color3.fromRGB(160, 255, 80),
	},
	Abilities = {
		Ability1 = {
			Id = "ThornLash",
			Name = "Thorn Lash",
			Input = "Instant",
			Description = "Whip a cone of thorns that snare enemies in place.",
		},
		Ability2 = {
			Id = "BrambleLine",
			Name = "Bramble Line",
			Input = "Instant",
			Description = "Thorny roots burst from the ground in a line.",
		},
		Ability3 = {
			Id = "Barkskin",
			Name = "Barkskin",
			Input = "Instant",
			Description = "Harden into bark: take far less damage and regrow health for 4s.",
		},
		Ultimate = {
			Id = "Overgrowth",
			Name = "Overgrowth",
			Input = "Instant",
			Description = "Vines erupt everywhere around you, binding and crushing enemies and buildings.",
		},
	},
	Animations = {},
	Sounds = {},
}

return config
