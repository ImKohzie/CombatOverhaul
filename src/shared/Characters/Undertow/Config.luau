--!strict
-- Undertow: character definition. Numbers live in Config/BalanceConfig.

local Types = require(script.Parent.Parent.Parent.Types)

local config: Types.CharacterConfig = {
	Id = "Undertow",
	DisplayName = "Undertow",
	Role = "Balanced",
	Difficulty = 3,
	Order = 20,
	Tagline = "A tide-shaper who drowns the streets on command.",
	Movement = "Ground",
	Palette = {
		Primary = Color3.fromRGB(20, 60, 110),
		Secondary = Color3.fromRGB(230, 240, 245),
		Glow = Color3.fromRGB(60, 200, 255),
	},
	Abilities = {
		Ability1 = {
			Id = "HydroJet",
			Name = "Hydro Jet",
			Input = "Instant",
			Description = "A pressurised water blast that shoves enemies down the street.",
		},
		Ability2 = {
			Id = "TidalWave",
			Name = "Tidal Wave",
			Input = "Instant",
			Description = "Send a rolling wave crashing along the ground.",
		},
		Ability3 = {
			Id = "Whirlpool",
			Name = "Whirlpool",
			Input = "Instant",
			Description = "A vortex that drags enemies in and spins them.",
		},
		Ultimate = {
			Id = "Tsunami",
			Name = "Tsunami",
			Input = "Instant",
			Description = "Summon a colossal wave that sweeps the whole block.",
		},
	},
	Animations = {},
	Sounds = {},
}

return config
