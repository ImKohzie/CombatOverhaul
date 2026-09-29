--!strict
-- Rebound: character definition. Numbers live in Config/BalanceConfig.

local Types = require(script.Parent.Parent.Parent.Types)

local config: Types.CharacterConfig = {
	Id = "Rebound",
	DisplayName = "Rebound",
	Role = "Balanced",
	Difficulty = 2,
	Order = 16,
	Tagline = "A rubber-bodied brawler who never stops bouncing.",
	Movement = "Ground",
	Palette = {
		Primary = Color3.fromRGB(255, 200, 40),
		Secondary = Color3.fromRGB(230, 60, 120),
		Glow = Color3.fromRGB(255, 240, 120),
	},
	Abilities = {
		Ability1 = {
			Id = "SlingshotPunch",
			Name = "Slingshot Punch",
			Input = "Instant",
			Description = "Stretch your arm across the street for a long-range haymaker.",
		},
		Ability2 = {
			Id = "BounceHouse",
			Name = "Bounce House",
			Input = "Instant",
			Description = "Slam the ground and bounce every nearby enemy into the air.",
		},
		Ability3 = {
			Id = "RubberGuard",
			Name = "Rubber Guard",
			Input = "Instant",
			Description = "Go fully elastic for 3s: take less damage and bounce projectiles back.",
		},
		Ultimate = {
			Id = "PinballFrenzy",
			Name = "Pinball Frenzy",
			Input = "Instant",
			Description = "Ricochet between every nearby enemy in a flurry of slams.",
		},
	},
	Animations = {},
	Sounds = {},
}

return config
