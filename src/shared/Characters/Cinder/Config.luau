--!strict
-- Cinder: character definition. Numbers live in Config/BalanceConfig.

local Types = require(script.Parent.Parent.Parent.Types)

local config: Types.CharacterConfig = {
	Id = "Cinder",
	DisplayName = "Cinder",
	Role = "Balanced",
	Difficulty = 3,
	Order = 13,
	Tagline = "A living furnace who flies on jets of flame.",
	Movement = "Flight",
	FlightProfile = "Standard",
	Palette = {
		Primary = Color3.fromRGB(60, 22, 16),
		Secondary = Color3.fromRGB(255, 120, 30),
		Glow = Color3.fromRGB(255, 150, 40),
	},
	Abilities = {
		Ability1 = {
			Id = "FlameBurst",
			Name = "Flame Burst",
			Input = "Instant",
			Description = "Hurl an exploding fireball that leaves the target burning.",
		},
		Ability2 = {
			Id = "HeatWave",
			Name = "Heat Wave",
			Input = "Instant",
			Description = "A wide cone of blistering heat that blows enemies back and burns them.",
		},
		Ability3 = {
			Id = "MeteorDive",
			Name = "Meteor Dive",
			Input = "Instant",
			Description = "Wreathe yourself in fire and crash down on the crosshair.",
		},
		Ultimate = {
			Id = "Supernova",
			Name = "Supernova",
			Input = "Instant",
			Description = "Charge up, then detonate like a star and level the block.",
		},
	},
	Animations = {},
	Sounds = {},
}

return config
