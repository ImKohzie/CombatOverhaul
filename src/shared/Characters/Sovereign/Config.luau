--!strict
-- Sovereign: character definition. Numbers live in Config/BalanceConfig.

local Types = require(script.Parent.Parent.Parent.Types)

local config: Types.CharacterConfig = {
	Id = "Sovereign",
	DisplayName = "Sovereign",
	Role = "Bruiser",
	Difficulty = 3,
	Order = 4,
	Tagline = "An untouchable flying 'perfect hero' with an eerie calm.",
	Movement = "Flight",
	FlightProfile = "Sovereign",
	Palette = {
		Primary = Color3.fromRGB(25, 45, 130),
		Secondary = Color3.fromRGB(180, 20, 30),
		Glow = Color3.fromRGB(255, 40, 30),
	},
	Abilities = {
		Ability1 = {
			Id = "OcularBeam",
			Name = "Ocular Beam",
			Input = "Hold",
			Description = "Hold for twin red heat-vision beams from the eyes. Carves through buildings.",
		},
		Ability2 = {
			Id = "SonicClap",
			Name = "Sonic Clap",
			Input = "Instant",
			Description = "A forward cone shockwave that shatters glass, stuns and knocks back.",
		},
		Ability3 = {
			Id = "SkyfallGrab",
			Name = "Skyfall Grab",
			Input = "Instant",
			Description = "Grab a target, fly them upward, then slam them into the ground.",
		},
		Ultimate = {
			Id = "Judgement",
			Name = "Judgement",
			Input = "Instant",
			Description = "Hover and sweep an enormous heat-vision beam across a 180 degree arc, slicing buildings in half.",
		},
	},
	Animations = {},
	Sounds = {},
}

return config
