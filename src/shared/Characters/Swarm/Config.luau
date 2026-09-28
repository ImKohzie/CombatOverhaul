--!strict
-- Swarm: character definition. Numbers live in Config/BalanceConfig.

local Types = require(script.Parent.Parent.Parent.Types)

local config: Types.CharacterConfig = {
	Id = "Swarm",
	DisplayName = "Swarm",
	Role = "Balanced",
	Difficulty = 4,
	Order = 10,
	Tagline = "A nanite technopath wrapped in a living metal cloud.",
	Movement = "Ground",
	Palette = {
		Primary = Color3.fromRGB(110, 115, 125),
		Secondary = Color3.fromRGB(40, 45, 55),
		Glow = Color3.fromRGB(80, 255, 220),
	},
	Abilities = {
		Ability1 = {
			Id = "NaniteBlades",
			Name = "Nanite Blades",
			Input = "Instant",
			Description = "Form blades from the swarm for a spinning melee.",
		},
		Ability2 = {
			Id = "Disassemble",
			Name = "Disassemble",
			Input = "Hold",
			Description = "The swarm eats through a targeted structure, deleting it gradually.",
		},
		Ability3 = {
			Id = "DecoyMass",
			Name = "Decoy Mass",
			Input = "Instant",
			Description = "Create 2 nanite clones that mimic your movement.",
		},
		Ultimate = {
			Id = "GreyTide",
			Name = "Grey Tide",
			Input = "Instant",
			Description = "A huge wave of nanites engulfs the area, damaging over time and consuming structures.",
		},
	},
	Animations = {},
	Sounds = {},
}

return config
