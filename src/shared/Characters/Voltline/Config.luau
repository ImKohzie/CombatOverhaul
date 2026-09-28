--!strict
-- Voltline: character definition. Numbers live in Config/BalanceConfig.

local Types = require(script.Parent.Parent.Parent.Types)

local config: Types.CharacterConfig = {
	Id = "Voltline",
	DisplayName = "Voltline",
	Role = "Agile",
	Difficulty = 4,
	Order = 2,
	Tagline = "A speedster who turns momentum into lightning.",
	Movement = "Ground",
	Palette = {
		Primary = Color3.fromRGB(255, 205, 40),
		Secondary = Color3.fromRGB(170, 20, 20),
		Glow = Color3.fromRGB(255, 240, 120),
	},
	Passive = { Name = "Momentum", Description = "Speed builds through 4 tiers over ~6s of running. Hitting a wall or taking a heavy hit resets it." },
	Abilities = {
		Ability1 = {
			Id = "PhaseRun",
			Name = "Phase Run",
			Input = "Instant",
			Description = "Vibrate through walls, buildings and players for 3-5s (scales with stamina). Everything you pass through takes light damage.",
		},
		Ability2 = {
			Id = "LightningHurl",
			Name = "Lightning Hurl",
			Input = "Charge",
			Description = "A spinning run that charges a thrown lightning bolt. Damage scales with momentum tier.",
		},
		Ability3 = {
			Id = "BlitzBarrage",
			Name = "Blitz Barrage",
			Input = "Instant",
			Description = "Teleport-like dash that hits up to 10 times in 1s, leaving afterimages.",
		},
		Ultimate = {
			Id = "VelocityRift",
			Name = "Velocity Rift",
			Input = "Instant",
			Description = "For 6s the world slows to 15% for everyone else while you move and attack at full speed.",
		},
	},
	Animations = {},
	Sounds = {},
}

return config
