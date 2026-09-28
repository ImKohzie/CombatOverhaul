--!strict
-- Bastion: character definition. Numbers live in Config/BalanceConfig.

local Types = require(script.Parent.Parent.Parent.Types)

local config: Types.CharacterConfig = {
	Id = "Bastion",
	DisplayName = "Bastion",
	Role = "Tank",
	Difficulty = 2,
	Order = 1,
	Tagline = "A lean human who erupts into a plated stone colossus.",
	Movement = "Ground",
	Palette = {
		Primary = Color3.fromRGB(70, 64, 58),
		Secondary = Color3.fromRGB(35, 32, 30),
		Glow = Color3.fromRGB(255, 120, 40),
	},
	Abilities = {
		Ability1 = {
			Id = "PlatedCharge",
			Name = "Plated Charge",
			Input = "Instant",
			Description = "Shoulder-first charge that smashes through buildings and players. Can't be stopped by knockback.",
		},
		Ability2 = {
			Id = "Harden",
			Name = "Harden",
			Input = "Instant",
			Description = "Crystallise your armour for 4s: 60% damage reduction, reflects light projectiles, slower movement.",
		},
		Ability3 = {
			Id = "SeismicHammer",
			Name = "Seismic Hammer",
			Input = "Instant",
			Description = "Double-fist ground slam with a radial shockwave and ground cracks.",
		},
		Ultimate = {
			Id = "ColossalForm",
			Name = "Colossal Form",
			Input = "Instant",
			Description = "Grow to 3x size for 15s with bonus armour. Every step shakes the ground; attacks gain huge area.",
		},
	},
	Animations = {},
	Sounds = {},
}

return config
