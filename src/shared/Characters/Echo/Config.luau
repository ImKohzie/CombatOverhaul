--!strict
-- Echo: character definition. Numbers live in Config/BalanceConfig.

local Types = require(script.Parent.Parent.Parent.Types)

local config: Types.CharacterConfig = {
	Id = "Echo",
	DisplayName = "Echo",
	Role = "Agile",
	Difficulty = 3,
	Order = 11,
	Tagline = "A sonic manipulator whose voice breaks buildings.",
	Movement = "Ground",
	Palette = {
		Primary = Color3.fromRGB(60, 40, 90),
		Secondary = Color3.fromRGB(20, 20, 30),
		Glow = Color3.fromRGB(255, 80, 200),
	},
	Abilities = {
		Ability1 = {
			Id = "SonicScream",
			Name = "Sonic Scream",
			Input = "Instant",
			Description = "A forward cone that shatters glass across whole building faces.",
		},
		Ability2 = {
			Id = "SoundBarrierDash",
			Name = "Sound Barrier Dash",
			Input = "Instant",
			Description = "A supersonic dash with sonic boom damage along the path.",
		},
		Ability3 = {
			Id = "ResonanceMark",
			Name = "Resonance Mark",
			Input = "Instant",
			Description = "Mark a target. Your next hit detonates it for heavy damage.",
		},
		Ultimate = {
			Id = "FrequencyCollapse",
			Name = "Frequency Collapse",
			Input = "Instant",
			Description = "A resonant pulse that makes buildings vibrate and crumble from the base.",
		},
	},
	Animations = {},
	Sounds = {},
}

return config
