--!strict
-- Graven: character definition. Numbers live in Config/BalanceConfig.

local Types = require(script.Parent.Parent.Parent.Types)

local config: Types.CharacterConfig = {
	Id = "Graven",
	DisplayName = "Graven",
	Role = "Balanced",
	Difficulty = 4,
	Order = 8,
	Tagline = "A gravity manipulator who bends the ground under you.",
	Movement = "Ground",
	Palette = {
		Primary = Color3.fromRGB(40, 30, 60),
		Secondary = Color3.fromRGB(90, 70, 130),
		Glow = Color3.fromRGB(170, 110, 255),
	},
	Abilities = {
		Ability1 = {
			Id = "Singularity",
			Name = "Singularity",
			Input = "Instant",
			Description = "A small black hole that pulls players and debris in, then detonates.",
		},
		Ability2 = {
			Id = "Float",
			Name = "Float",
			Input = "Instant",
			Description = "Lift everything loose in an area into the air, then slam it down.",
		},
		Ability3 = {
			Id = "Weight",
			Name = "Weight",
			Input = "Instant",
			Description = "Multiply one target's gravity, grounding flyers and slowing them heavily.",
		},
		Ultimate = {
			Id = "EventHorizon",
			Name = "Event Horizon",
			Input = "Instant",
			Description = "A massive gravity well that tears buildings apart into its centre.",
		},
	},
	Animations = {},
	Sounds = {},
}

return config
