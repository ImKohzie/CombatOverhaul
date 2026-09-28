--!strict
-- Umbra: character definition. Numbers live in Config/BalanceConfig.

local Types = require(script.Parent.Parent.Parent.Types)

local config: Types.CharacterConfig = {
	Id = "Umbra",
	DisplayName = "Umbra",
	Role = "Agile",
	Difficulty = 5,
	Order = 12,
	Tagline = "A shadow teleporter who lives in the dark.",
	Movement = "Ground",
	Palette = {
		Primary = Color3.fromRGB(15, 15, 20),
		Secondary = Color3.fromRGB(45, 40, 55),
		Glow = Color3.fromRGB(120, 60, 255),
	},
	Abilities = {
		Ability1 = {
			Id = "ShadowStep",
			Name = "Shadow Step",
			Input = "Instant",
			Description = "Teleport to any shadowed spot within 150 studs.",
		},
		Ability2 = {
			Id = "DarkTendrils",
			Name = "Dark Tendrils",
			Input = "Instant",
			Description = "Tendrils burst from the ground and bind a target.",
		},
		Ability3 = {
			Id = "ShadeClone",
			Name = "Shade Clone",
			Input = "Instant",
			Description = "Swap places with a shadow decoy.",
		},
		Ultimate = {
			Id = "Eclipse",
			Name = "Eclipse",
			Input = "Instant",
			Description = "Darken a huge area. You turn invisible and strike from any shadow.",
		},
	},
	Animations = {},
	Sounds = {},
}

return config
