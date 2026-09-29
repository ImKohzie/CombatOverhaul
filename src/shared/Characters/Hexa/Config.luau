--!strict
-- Hexa: character definition. Numbers live in Config/BalanceConfig.

local Types = require(script.Parent.Parent.Parent.Types)

local config: Types.CharacterConfig = {
	Id = "Hexa",
	DisplayName = "Hexa",
	Role = "Agile",
	Difficulty = 4,
	Order = 17,
	Tagline = "A street sorceress who writes spells in light.",
	Movement = "Ground",
	Palette = {
		Primary = Color3.fromRGB(50, 22, 80),
		Secondary = Color3.fromRGB(230, 200, 90),
		Glow = Color3.fromRGB(200, 120, 255),
	},
	Abilities = {
		Ability1 = {
			Id = "ArcaneBolts",
			Name = "Arcane Bolts",
			Input = "Instant",
			Description = "Three homing bolts of arcane energy.",
		},
		Ability2 = {
			Id = "HexSnare",
			Name = "Hex Snare",
			Input = "Instant",
			Description = "A rune under the crosshair roots every enemy standing in it.",
		},
		Ability3 = {
			Id = "Blink",
			Name = "Blink",
			Input = "Instant",
			Description = "Teleport to the crosshair, leaving an arcane blast behind.",
		},
		Ultimate = {
			Id = "RuneCircle",
			Name = "Rune Circle",
			Input = "Instant",
			Description = "A giant rune that erupts again and again, slowing and burning enemies inside.",
		},
	},
	Animations = {},
	Sounds = {},
}

return config
