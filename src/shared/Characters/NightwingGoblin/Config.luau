--!strict
-- Nightwing Goblin: character definition. Numbers live in Config/BalanceConfig.

local Types = require(script.Parent.Parent.Parent.Types)

local config: Types.CharacterConfig = {
	Id = "NightwingGoblin",
	DisplayName = "Nightwing Goblin",
	Role = "Balanced",
	Difficulty = 3,
	Order = 6,
	Tagline = "A black-armoured glider villain with an insect mask.",
	Movement = "Glider",
	FlightProfile = "Glider",
	Palette = {
		Primary = Color3.fromRGB(20, 20, 24),
		Secondary = Color3.fromRGB(60, 60, 70),
		Glow = Color3.fromRGB(140, 255, 60),
	},
	Abilities = {
		Ability1 = {
			Id = "ShadeBombs",
			Name = "Shade Bombs",
			Input = "Instant",
			Description = "Throw 3 black grenades that burst into dark smoke and fire.",
		},
		Ability2 = {
			Id = "BladeSwoop",
			Name = "Blade Swoop",
			Input = "Instant",
			Description = "Extend the glider's wing blades and slash through targets at speed.",
		},
		Ability3 = {
			Id = "TalonMissiles",
			Name = "Talon Missiles",
			Input = "Instant",
			Description = "Fire homing missiles from the glider.",
		},
		Ultimate = {
			Id = "CarpetRun",
			Name = "Carpet Run",
			Input = "Instant",
			Description = "Fly a straight line dropping a continuous chain of explosives.",
		},
	},
	Animations = {},
	Sounds = {},
}

return config
