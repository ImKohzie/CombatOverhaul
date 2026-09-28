--!strict
-- Argent: character definition. Numbers live in Config/BalanceConfig.

local Types = require(script.Parent.Parent.Parent.Types)

local config: Types.CharacterConfig = {
	Id = "Argent",
	DisplayName = "Argent",
	Role = "Balanced",
	Difficulty = 3,
	Order = 7,
	Tagline = "A mirror-chrome cosmic rider on a chrome board.",
	Movement = "Board",
	FlightProfile = "Board",
	Palette = {
		Primary = Color3.fromRGB(220, 225, 235),
		Secondary = Color3.fromRGB(150, 160, 180),
		Glow = Color3.fromRGB(140, 200, 255),
	},
	Abilities = {
		Ability1 = {
			Id = "CosmicLance",
			Name = "Cosmic Lance",
			Input = "Hold",
			Description = "A white-blue energy beam fired from the hands.",
		},
		Ability2 = {
			Id = "MatterReshape",
			Name = "Matter Reshape",
			Input = "Instant",
			Description = "Turn a targeted building section into a shield wall or launch it as shrapnel.",
		},
		Ability3 = {
			Id = "BoardStrike",
			Name = "Board Strike",
			Input = "Instant",
			Description = "Your board orbits you, ramming enemies, then returns.",
		},
		Ultimate = {
			Id = "NovaCollapse",
			Name = "Nova Collapse",
			Input = "Instant",
			Description = "Absorb the light around you, then release a starburst that disintegrates structures.",
		},
	},
	Animations = {},
	Sounds = {},
}

return config
