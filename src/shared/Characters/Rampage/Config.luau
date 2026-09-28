--!strict
-- Rampage: character definition. Numbers live in Config/BalanceConfig.

local Types = require(script.Parent.Parent.Parent.Types)

local config: Types.CharacterConfig = {
	Id = "Rampage",
	DisplayName = "Rampage",
	Role = "Tank",
	Difficulty = 1,
	Order = 5,
	Tagline = "A gamma-mutated brute whose rage makes him bigger.",
	Movement = "Ground",
	Palette = {
		Primary = Color3.fromRGB(70, 140, 60),
		Secondary = Color3.fromRGB(60, 50, 70),
		Glow = Color3.fromRGB(120, 255, 80),
	},
	Passive = { Name = "Rage", Description = "Taking damage fills rage: up to +20% size, more damage and more knockback resistance." },
	Abilities = {
		Ability1 = {
			Id = "Thunderclap",
			Name = "Thunderclap",
			Input = "Instant",
			Description = "A hand clap that sends a devastating forward pressure wave.",
		},
		Ability2 = {
			Id = "GammaLeap",
			Name = "Gamma Leap",
			Input = "Instant",
			Description = "A huge arcing jump that lands with a crater slam.",
		},
		Ability3 = {
			Id = "RipAndThrow",
			Name = "Rip & Throw",
			Input = "Instant",
			Description = "Tear a chunk from a building, car or the ground and hurl it.",
		},
		Ultimate = {
			Id = "WorldBreaker",
			Name = "World Breaker",
			Input = "Instant",
			Description = "Repeated ground punches fracture everything in a large radius with gamma eruptions.",
		},
	},
	Animations = {},
	Sounds = {},
}

return config
