--!strict
-- APEX CITY balance sheet. EVERY tunable gameplay number lives here.
--
-- Rules this file is built around:
--   * Average HP across tiers ~= 1325. Basic M1 ~= 3% of that, full combo ~= 160.
--   * Abilities 100-190 damage with 6-14s cooldowns (more damage = longer CD / wind-up).
--   * Ultimates 350-480 and must never kill a full-HP Balanced (1150) character alone.
--   * Tanks take 15% less damage but move slower. Agile characters are fast and fragile.

local Types = require(script.Parent.Parent.Types)

type AbilityBalance = Types.AbilityBalance
type RoleBalance = Types.RoleBalance

local BalanceConfig = {}

--------------------------------------------------------------------------------
-- Roles / health tiers
--------------------------------------------------------------------------------
BalanceConfig.Roles = {
	Tank = { Health = 1800, DamageReduction = 0.15, WalkSpeed = 15, KnockbackResistance = 0.5 },
	Bruiser = { Health = 1400, DamageReduction = 0.0, WalkSpeed = 16, KnockbackResistance = 0.25 },
	Balanced = { Health = 1150, DamageReduction = 0.0, WalkSpeed = 17, KnockbackResistance = 0.1 },
	Agile = { Health = 950, DamageReduction = 0.0, WalkSpeed = 19, KnockbackResistance = 0.0 },
} :: { [Types.Role]: RoleBalance }

--------------------------------------------------------------------------------
-- Stamina
--------------------------------------------------------------------------------
BalanceConfig.Stamina = {
	Max = 100,
	RegenDelay = 1.2, -- seconds with no drain before regen starts
	RegenPerSecond = 28,
	SprintDrainPerSecond = 8,
	BoostDrainPerSecond = 18,
	DashCost = 20,
	DashCooldown = 0.6,
}

--------------------------------------------------------------------------------
-- Ground movement
--------------------------------------------------------------------------------
BalanceConfig.Movement = {
	SprintMultiplier = 1.6,
	DashDistance = 22,
	DashDuration = 0.18,
	JumpPower = 50,
	-- Server anti-cheat: max horizontal speed allowed = expected * tolerance.
	SpeedTolerance = 1.35,
}

--------------------------------------------------------------------------------
-- Flight (used by Phase 2 FlightController). Speeds in studs/second.
--------------------------------------------------------------------------------
export type FlightProfile = {
	Hover: number,
	Cruise: number,
	Boost: number,
	AccelTime: number, -- seconds to reach target speed
	DecelTime: number, -- seconds to stop
	MaxBankDegrees: number,
	TurnResponsiveness: number, -- AlignOrientation responsiveness
	BoostFOV: number,
}

BalanceConfig.Flight = {
	BaseFOV = 70,
	DoubleJumpWindow = 0.3,
	Profiles = {
		Standard = {
			Hover = 28, Cruise = 110, Boost = 220,
			AccelTime = 0.15, DecelTime = 0.3,
			MaxBankDegrees = 35, TurnResponsiveness = 45, BoostFOV = 90,
		},
		Sovereign = { -- best flight in the game
			Hover = 32, Cruise = 130, Boost = 320,
			AccelTime = 0.12, DecelTime = 0.28,
			MaxBankDegrees = 40, TurnResponsiveness = 55, BoostFOV = 92,
		},
		Board = { -- Argent: fastest top speed, least agile
			Hover = 36, Cruise = 150, Boost = 300,
			AccelTime = 0.25, DecelTime = 0.45,
			MaxBankDegrees = 28, TurnResponsiveness = 25, BoostFOV = 92,
		},
		Glider = { -- Nightwing Goblin: tighter banking, trick spin dodge
			Hover = 30, Cruise = 120, Boost = 230,
			AccelTime = 0.15, DecelTime = 0.3,
			MaxBankDegrees = 55, TurnResponsiveness = 70, BoostFOV = 88,
		},
	} :: { [string]: FlightProfile },
	-- Superhero landing when touching down faster than this.
	HardLandingSpeed = 90,
}

--------------------------------------------------------------------------------
-- Melee / defence
--------------------------------------------------------------------------------
export type AttackTiming = {
	WindUp: number, -- seconds before the hitbox is active (animation "Hit" marker)
	Active: number, -- hitbox lifetime
	Recovery: number, -- time after the active frames before the next action
	Knockback: number, -- studs/second applied along the attacker's facing
	Lift: number?, -- upward studs/second
	Ragdoll: number?, -- seconds of ragdoll on hit
	HitStun: number, -- seconds the victim can't act
}

BalanceConfig.Melee = {
	ComboDamage = { 35, 35, 40, 50 }, -- = 160 full combo
	ComboInputWindow = 0.35,
	ComboResetTime = 0.9,
	HeavyDamage = 70,
	HeavyChargeTime = 0.45,
	AerialDamage = 40,
	DiveSlamDamage = 75,
	HitStopMin = 0.05,
	HitStopMax = 0.08,
	HitRange = 7, -- hitbox forward reach (studs)
	HitboxSize = Vector3.new(6, 6.5, 7),
	MaxServerReach = 14, -- server rejects hits further than this from attacker
	ComboSteps = {
		{ WindUp = 0.1, Active = 0.08, Recovery = 0.16, Knockback = 6, HitStun = 0.4 },
		{ WindUp = 0.1, Active = 0.08, Recovery = 0.16, Knockback = 6, HitStun = 0.4 },
		{ WindUp = 0.12, Active = 0.08, Recovery = 0.2, Knockback = 10, HitStun = 0.45 },
		{ WindUp = 0.16, Active = 0.1, Recovery = 0.45, Knockback = 55, Lift = 18, HitStun = 0.6 },
	} :: { AttackTiming },
	Heavy = { WindUp = 0.22, Active = 0.1, Recovery = 0.5, Knockback = 75, Lift = 25, Ragdoll = 1.1, HitStun = 0.8 } :: AttackTiming,
	Aerial = { WindUp = 0.08, Active = 0.08, Recovery = 0.18, Knockback = 8, Lift = 22, HitStun = 0.45 } :: AttackTiming,
	DiveSlam = {
		DiveSpeed = 170,
		Radius = 13,
		Knockback = 60,
		Lift = 35,
		Ragdoll = 0.9,
		MaxDiveTime = 1.5,
	},
}

BalanceConfig.Reactions = {
	RagdollGetUpTime = 0.6,
	LaunchSpeedForWallSplat = 55, -- victim speed needed to splat into a wall
	WallSplatDamage = 25,
	WallSplatStun = 0.8,
	WallSplatWindow = 1.2, -- seconds after a launch that splats are checked
	HeavyHitThreshold = 60, -- hits this big count as "heavy" (resets momentum, bigger shake)
}

BalanceConfig.Beam = {
	TickRate = 10, -- server damage checks per second
	HeatMax = 100,
	HeatPerSecond = 30, -- ~3.3s of continuous channel
	HeatCoolPerSecond = 25,
	OverheatLockout = 2,
	MaxAimTurnDegreesPerSecond = 720, -- server clamps aim changes faster than this
	ScorchInterval = 0.12,
}

BalanceConfig.Momentum = { -- Voltline passive
	TierTime = 0.9, -- seconds of sustained running per tier (tier 4 at ~2.7s)
	-- Multiplies Voltline's whole move speed (walk and sprint). Agile walk 19,
	-- sprint x1.6: tier 1 ~41 sprinting, tier 4 ~128 studs/second.
	SpeedMultipliers = { 1.35, 2.1, 3.0, 4.2 },
	FovBonus = { 4, 10, 17, 26 },
	DropGrace = 0.5, -- slowing down for longer than this resets momentum
	MinSpeedFraction = 0.6, -- of base sprint speed to count as "running"
	DashMultiplier = 2.5, -- Voltline's dash goes this much further
}

--------------------------------------------------------------------------------
-- F: signature movement per character. Speeds are Distance / Duration
-- (most are 300-500 studs/second bursts).
--   Kind  Dash   - burst along the camera (flat on the ground)
--         Flight - flyers: take off with a burst / burst while flying
--         Leap   - huge ballistic bound
--         Pull   - yank yourself to the surface under the crosshair
--         Bounce - dash that ricochets off walls
--   Phase  - pass through walls, cracking what you pass
--   Smash  - break through structures in the path
--------------------------------------------------------------------------------
export type Traversal = {
	Name: string,
	Kind: "Dash" | "Flight" | "Leap" | "Pull" | "Bounce",
	Distance: number,
	Duration: number,
	Cooldown: number,
	Stamina: number,
	HitDamage: number,
	Phase: boolean?,
	Smash: boolean?,
	Shatter: boolean?,
	IceTrail: boolean?,
	Invisible: boolean?,
	Unstoppable: boolean?,
	EndBlast: number?, -- radius of a landing / arrival blast
	Bounces: number?,
}

BalanceConfig.Traversal = {
	Voltline = { Name = "Lightning Dash", Kind = "Dash", Distance = 150, Duration = 0.28, Cooldown = 1.8, Stamina = 12, HitDamage = 25, Phase = true },
	Sovereign = { Name = "Sonic Launch", Kind = "Flight", Distance = 190, Duration = 0.45, Cooldown = 2.2, Stamina = 14, HitDamage = 35, Smash = true },
	Argent = { Name = "Cosmic Surge", Kind = "Flight", Distance = 210, Duration = 0.45, Cooldown = 2.2, Stamina = 14, HitDamage = 25, Phase = true },
	NightwingGoblin = { Name = "Afterburner", Kind = "Flight", Distance = 170, Duration = 0.4, Cooldown = 2.2, Stamina = 14, HitDamage = 30, Smash = true, Shatter = true },
	Bastion = { Name = "Boulder Rush", Kind = "Dash", Distance = 100, Duration = 0.45, Cooldown = 3, Stamina = 20, HitDamage = 45, Smash = true, Unstoppable = true, EndBlast = 12 },
	OldGuard = { Name = "Shield Slide", Kind = "Bounce", Distance = 120, Duration = 0.45, Cooldown = 2.5, Stamina = 15, HitDamage = 35, Smash = true, Bounces = 2 },
	Rampage = { Name = "Wrecking Leap", Kind = "Leap", Distance = 170, Duration = 1, Cooldown = 3, Stamina = 20, HitDamage = 40, Smash = true, EndBlast = 16 },
	Graven = { Name = "Gravity Sling", Kind = "Pull", Distance = 180, Duration = 0.5, Cooldown = 2.5, Stamina = 15, HitDamage = 25, EndBlast = 12 },
	Rime = { Name = "Frost Slide", Kind = "Dash", Distance = 140, Duration = 0.38, Cooldown = 2, Stamina = 12, HitDamage = 20, IceTrail = true, Shatter = true },
	Swarm = { Name = "Disperse", Kind = "Dash", Distance = 120, Duration = 0.32, Cooldown = 2.3, Stamina = 14, HitDamage = 20, Phase = true, Invisible = true },
	Echo = { Name = "Sonic Hop", Kind = "Dash", Distance = 130, Duration = 0.28, Cooldown = 2, Stamina = 12, HitDamage = 25, Shatter = true, Smash = true },
	Umbra = { Name = "Shadow Dash", Kind = "Dash", Distance = 120, Duration = 0.28, Cooldown = 2, Stamina = 12, HitDamage = 20, Phase = true, Invisible = true },
	Recruit = { Name = "Dash", Kind = "Dash", Distance = 60, Duration = 0.3, Cooldown = 2, Stamina = 12, HitDamage = 0 },
	Cinder = { Name = "Jet Burst", Kind = "Flight", Distance = 200, Duration = 0.45, Cooldown = 2.2, Stamina = 14, HitDamage = 30, Smash = true },
	Tempest = { Name = "Gust Step", Kind = "Dash", Distance = 170, Duration = 0.3, Cooldown = 1.8, Stamina = 12, HitDamage = 20, Shatter = true },
	Magnus = { Name = "Mag Rail", Kind = "Flight", Distance = 190, Duration = 0.45, Cooldown = 2.2, Stamina = 14, HitDamage = 35, Smash = true },
	Rebound = { Name = "Pinball", Kind = "Bounce", Distance = 150, Duration = 0.55, Cooldown = 2.3, Stamina = 15, HitDamage = 35, Smash = true, Bounces = 4 },
	Hexa = { Name = "Blink Stride", Kind = "Dash", Distance = 130, Duration = 0.22, Cooldown = 1.8, Stamina = 12, HitDamage = 20, Phase = true, Invisible = true },
	Thornwild = { Name = "Vine Swing", Kind = "Pull", Distance = 170, Duration = 0.5, Cooldown = 2.5, Stamina = 15, HitDamage = 30, EndBlast = 12 },
	Glitch = { Name = "Packet Jump", Kind = "Dash", Distance = 140, Duration = 0.2, Cooldown = 1.6, Stamina = 10, HitDamage = 20, Phase = true, Invisible = true },
	Undertow = { Name = "Wave Ride", Kind = "Dash", Distance = 150, Duration = 0.4, Cooldown = 2, Stamina = 12, HitDamage = 30, Smash = true, Shatter = true },
} :: { [string]: Traversal }

--------------------------------------------------------------------------------
-- AI rivals (BotService). Difficulty picked by GameConfig.Bots.Difficulty.
--------------------------------------------------------------------------------
export type BotProfile = {
	Reaction: number, -- seconds before reacting to a hit / threat
	BlockChance: number, -- chance to guard when an enemy is in melee range
	DodgeChance: number, -- chance to side-dash after being hit
	AimError: number, -- studs of spread on ranged shots
	ComboLength: number, -- light hits per string
	ShotCooldown: number,
	SlamCooldown: number,
	DashCooldown: number,
	DamageScale: number, -- multiplies all bot damage
}

BalanceConfig.Bots = {
	Profiles = {
		Easy = { Reaction = 0.45, BlockChance = 0.15, DodgeChance = 0.1, AimError = 7, ComboLength = 2, ShotCooldown = 4.5, SlamCooldown = 14, DashCooldown = 6, DamageScale = 0.7 },
		Normal = { Reaction = 0.25, BlockChance = 0.35, DodgeChance = 0.25, AimError = 3.5, ComboLength = 3, ShotCooldown = 3, SlamCooldown = 10, DashCooldown = 4.5, DamageScale = 0.85 },
		Hard = { Reaction = 0.12, BlockChance = 0.55, DodgeChance = 0.4, AimError = 1.2, ComboLength = 4, ShotCooldown = 2.2, SlamCooldown = 8, DashCooldown = 3, DamageScale = 1 },
	} :: { [string]: BotProfile },
	ShotDamage = 55,
	ShotSpeed = 220,
	ShotRange = 160,
	SlamDamage = 90,
	SlamRadius = 16,
	DashSpeed = 170,
	DashTime = 0.35,
	DashHitDamage = 30,
	MeleeRange = 7.5,
	StrafeRange = 24,
	RetreatHealth = 0.25, -- fraction of HP where rivals back off and kite
	ChaseSpeedMultiplier = 1.5, -- over the role's walk speed
	ThreatDecayPerSecond = 15,
}

BalanceConfig.Rage = { -- Rampage passive
	GainPerDamageTaken = 0.08, -- rage points per damage point (0..100)
	DecayPerSecond = 2.5,
	MaxScaleBonus = 0.2, -- +20% size at full rage
	MaxDamageBonus = 0.25,
	MaxKnockbackResistBonus = 0.4,
}

BalanceConfig.Defence = {
	BlockDamageMultiplier = 0.2, -- damage taken while blocking
	PerfectParryWindow = 0.2,
	ParryStunDuration = 1.2,
	PostureMax = 100,
	PostureDamageMultiplier = 0.8, -- posture lost per point of blocked damage
	PostureRegenPerSecond = 15,
	PostureRegenDelay = 1.5,
	GuardBreakStun = 1.5,
	BlockMoveSpeedMultiplier = 0.5,
}

--------------------------------------------------------------------------------
-- Ultimate meter. Target: 60-90s of active combat to fill.
-- Estimate of active combat: ~20 dmg/s dealt, ~15 dmg/s taken.
-- 75s * (20*0.45 + 15*0.3) ~= 1012 -> fills a 1000 meter in ~75s.
--------------------------------------------------------------------------------
BalanceConfig.Ultimate = {
	Max = 1000,
	GainPerDamageDealt = 0.45,
	GainPerDamageTaken = 0.3,
	CinematicMaxDuration = 1.4,
}

BalanceConfig.Combat = {
	OutOfCombatTime = 5, -- seconds without dealing/taking damage
	CharacterSwitchCooldown = 3,
	RespawnTime = 4,
}

--------------------------------------------------------------------------------
-- Abilities, keyed by character Id then slot.
-- Damage = expected total single-target damage for the full ability.
--------------------------------------------------------------------------------
local Abilities: { [string]: { [string]: AbilityBalance } } = { -- [characterId][AbilitySlot]
	-- Test character used to prove the ability pipeline (hidden later).
	Recruit = {
		Ability1 = { Damage = 60, Cooldown = 3, Range = 18 },
		Ability2 = { Damage = 0, Cooldown = 6 },
		Ability3 = { Damage = 0, Cooldown = 6 },
		Ultimate = { Damage = 350, Cooldown = 1 },
	},

	Bastion = {
		Ability1 = { Damage = 120, Cooldown = 10, WindUp = 0.35, Range = 60, Params = { Speed = 90 } }, -- Plated Charge
		Ability2 = { Damage = 0, Cooldown = 14, Duration = 4, Params = { DamageReduction = 0.6, SpeedMultiplier = 0.7 } }, -- Harden
		Ability3 = { Damage = 150, Cooldown = 12, WindUp = 0.6, Range = 30 }, -- Seismic Hammer
		Ultimate = { Damage = 420, Cooldown = 1, Duration = 15, Params = { Scale = 3, BonusReduction = 0.25 } }, -- Colossal Form
	},

	Voltline = {
		Ability1 = { Damage = 100, Cooldown = 12, Duration = 5, Params = { MinDuration = 3 } }, -- Phase Run
		Ability2 = { Damage = 110, Cooldown = 9, WindUp = 0.5, Range = 160, Params = { MomentumBonusPerTier = 0.15 } }, -- Lightning Hurl
		Ability3 = { Damage = 150, Cooldown = 13, Duration = 1, Channel = true, Params = { Hits = 10 } }, -- Blitz Barrage
		Ultimate = { Damage = 380, Cooldown = 1, Duration = 6, Params = { WorldTimeScale = 0.15 } }, -- Velocity Rift
	},

	OldGuard = {
		Ability1 = { Damage = 110, Cooldown = 9, Range = 120, Params = { Bounces = 3 } }, -- Ricochet Shield
		Ability2 = { Damage = 90, Cooldown = 8, Range = 10, Params = { StaggerTime = 0.8 } }, -- Shield Bash & Brace
		Ability3 = { Damage = 180, Cooldown = 14, Duration = 1.4, Channel = true, Params = { Hits = 6 } }, -- Brawler's Fury
		Ultimate = { Damage = 400, Cooldown = 1, WindUp = 2, Range = 70, Params = { ZoneDps = 15, ZoneDuration = 6 } }, -- Core Meltdown
	},

	Sovereign = {
		Ability1 = { Damage = 180, Cooldown = 12, Duration = 3, Range = 300, Channel = true, Params = { Dps = 60 } }, -- Ocular Beam
		Ability2 = { Damage = 100, Cooldown = 9, Range = 40, Params = { StunTime = 0.9, ConeDegrees = 70 } }, -- Sonic Clap
		Ability3 = { Damage = 170, Cooldown = 14, WindUp = 0.3, Range = 14, Params = { LiftHeight = 120 } }, -- Skyfall Grab
		Ultimate = { Damage = 450, Cooldown = 1, Duration = 3, Range = 500, Channel = true, Params = { ArcDegrees = 180 } }, -- Judgement
	},

	Rampage = {
		Ability1 = { Damage = 130, Cooldown = 10, WindUp = 0.4, Range = 50 }, -- Thunderclap
		Ability2 = { Damage = 140, Cooldown = 12, Range = 300, Params = { CraterRadius = 22 } }, -- Gamma Leap
		Ability3 = { Damage = 160, Cooldown = 13, WindUp = 0.7, Range = 200 }, -- Rip & Throw
		Ultimate = { Damage = 460, Cooldown = 1, Duration = 4, Range = 80, Channel = true }, -- World Breaker
	},

	NightwingGoblin = {
		Ability1 = { Damage = 135, Cooldown = 10, Range = 90, Params = { Bombs = 3 } }, -- Shade Bombs
		Ability2 = { Damage = 120, Cooldown = 9, Range = 80 }, -- Blade Swoop
		Ability3 = { Damage = 140, Cooldown = 12, Range = 250, Params = { Missiles = 4 } }, -- Talon Missiles
		Ultimate = { Damage = 420, Cooldown = 1, Duration = 4, Range = 400, Channel = true }, -- Carpet Run
	},

	Argent = {
		Ability1 = { Damage = 165, Cooldown = 12, Duration = 3, Range = 300, Channel = true, Params = { Dps = 55 } }, -- Cosmic Lance
		Ability2 = { Damage = 110, Cooldown = 11, Range = 120 }, -- Matter Reshape
		Ability3 = { Damage = 130, Cooldown = 10, Duration = 4, Range = 30 }, -- Board Strike
		Ultimate = { Damage = 450, Cooldown = 1, WindUp = 1.2, Range = 90 }, -- Nova Collapse
	},

	Graven = {
		Ability1 = { Damage = 150, Cooldown = 13, Duration = 2.5, Range = 150, Params = { PullRadius = 40 } }, -- Singularity
		Ability2 = { Damage = 130, Cooldown = 11, Duration = 2, Range = 35 }, -- Float
		Ability3 = { Damage = 90, Cooldown = 10, Duration = 4, Range = 150, Params = { GravityMultiplier = 3, SpeedMultiplier = 0.5 } }, -- Weight
		Ultimate = { Damage = 400, Cooldown = 1, Duration = 6, Range = 120, Channel = true }, -- Event Horizon
	},

	Rime = {
		Ability1 = { Damage = 0, Cooldown = 8, Duration = 6, Params = { SkateSpeed = 70 } }, -- Ice Road
		Ability2 = { Damage = 120, Cooldown = 12, Range = 120, Params = { FreezeTime = 1.5, BaseDamage = 40, ShatterBonus = 80 } }, -- Flash Freeze
		Ability3 = { Damage = 150, Cooldown = 11, WindUp = 0.3, Range = 90 }, -- Glacier Spike
		Ultimate = { Damage = 380, Cooldown = 1, Duration = 8, Range = 150 }, -- Absolute Zero
	},

	Swarm = {
		Ability1 = { Damage = 140, Cooldown = 10, Duration = 1.5, Range = 14, Channel = true }, -- Nanite Blades
		Ability2 = { Damage = 100, Cooldown = 11, Duration = 4, Range = 100 }, -- Disassemble
		Ability3 = { Damage = 0, Cooldown = 14, Duration = 8, Params = { Clones = 2 } }, -- Decoy Mass
		Ultimate = { Damage = 420, Cooldown = 1, Duration = 6, Range = 110 }, -- Grey Tide
	},

	Echo = {
		Ability1 = { Damage = 120, Cooldown = 10, Range = 60, Params = { ConeDegrees = 50 } }, -- Sonic Scream
		Ability2 = { Damage = 100, Cooldown = 8, Range = 80 }, -- Sound Barrier Dash
		Ability3 = { Damage = 170, Cooldown = 14, Duration = 8, Range = 150 }, -- Resonance Mark
		Ultimate = { Damage = 400, Cooldown = 1, WindUp = 0.8, Range = 120 }, -- Frequency Collapse
	},

	Umbra = {
		Ability1 = { Damage = 0, Cooldown = 7, Range = 150 }, -- Shadow Step
		Ability2 = { Damage = 90, Cooldown = 12, Range = 80, Params = { BindTime = 1.5 } }, -- Dark Tendrils
		Ability3 = { Damage = 0, Cooldown = 11, Duration = 6 }, -- Shade Clone
		Ultimate = { Damage = 380, Cooldown = 1, Duration = 8, Range = 200 }, -- Eclipse
	},

	Cinder = {
		Ability1 = { Damage = 130, Cooldown = 9, Range = 200, Params = { BurnDps = 10, BurnTime = 3 } }, -- Flame Burst (100 + burn)
		Ability2 = { Damage = 120, Cooldown = 11, Range = 45, Params = { ConeDegrees = 70 } }, -- Heat Wave
		Ability3 = { Damage = 150, Cooldown = 12, WindUp = 0.35, Range = 160, Params = { Radius = 16 } }, -- Meteor Dive
		Ultimate = { Damage = 410, Cooldown = 1, WindUp = 1.2, Range = 90 }, -- Supernova
	},

	Tempest = {
		Ability1 = { Damage = 110, Cooldown = 7, Range = 220, Params = { Blades = 3 } }, -- Gale Cutter
		Ability2 = { Damage = 130, Cooldown = 12, Duration = 3, Range = 150, Params = { PullRadius = 30 } }, -- Cyclone
		Ability3 = { Damage = 100, Cooldown = 9, Range = 25 }, -- Updraft
		Ultimate = { Damage = 400, Cooldown = 1, Duration = 5, Range = 60 }, -- Eye of the Storm
	},

	Magnus = {
		Ability1 = { Damage = 140, Cooldown = 10, Range = 180, Params = { Pieces = 5 } }, -- Scrap Volley
		Ability2 = { Damage = 100, Cooldown = 11, Range = 120 }, -- Polarity Pull
		Ability3 = { Damage = 120, Cooldown = 10, Range = 40 }, -- Repulse
		Ultimate = { Damage = 400, Cooldown = 1, Duration = 3, Range = 200, Params = { Radius = 35 } }, -- Iron Storm
	},

	Rebound = {
		Ability1 = { Damage = 120, Cooldown = 8, Range = 45 }, -- Slingshot Punch
		Ability2 = { Damage = 130, Cooldown = 11, Range = 30 }, -- Bounce House
		Ability3 = { Damage = 0, Cooldown = 14, Duration = 3, Params = { DamageReduction = 0.5 } }, -- Rubber Guard
		Ultimate = { Damage = 420, Cooldown = 1, Duration = 3, Range = 70, Params = { Hits = 6 } }, -- Pinball Frenzy
	},

	Hexa = {
		Ability1 = { Damage = 120, Cooldown = 8, Range = 200, Params = { Bolts = 3 } }, -- Arcane Bolts
		Ability2 = { Damage = 100, Cooldown = 12, WindUp = 0.4, Range = 120, Params = { BindTime = 1.6, Radius = 12 } }, -- Hex Snare
		Ability3 = { Damage = 110, Cooldown = 9, Range = 90 }, -- Blink
		Ultimate = { Damage = 400, Cooldown = 1, Duration = 5, Range = 120, Params = { Radius = 40 } }, -- Rune Circle
	},

	Thornwild = {
		Ability1 = { Damage = 110, Cooldown = 9, Range = 35, Params = { BindTime = 0.9, ConeDegrees = 60 } }, -- Thorn Lash
		Ability2 = { Damage = 150, Cooldown = 11, WindUp = 0.3, Range = 90 }, -- Bramble Line
		Ability3 = { Damage = 0, Cooldown = 14, Duration = 4, Params = { DamageReduction = 0.5, Heal = 200 } }, -- Barkskin
		Ultimate = { Damage = 400, Cooldown = 1, WindUp = 0.6, Range = 70, Params = { BindTime = 2 } }, -- Overgrowth
	},

	Glitch = {
		Ability1 = { Damage = 130, Cooldown = 9, Range = 80 }, -- Lag Spike
		Ability2 = { Damage = 0, Cooldown = 12, Duration = 3, Params = { SpeedMultiplier = 1.5 } }, -- Buffer
		Ability3 = { Damage = 140, Cooldown = 10, Range = 150, Params = { Bolts = 7 } }, -- Pixel Storm
		Ultimate = { Damage = 420, Cooldown = 1, WindUp = 0.5, Range = 80, Params = { FreezeTime = 1.5 } }, -- System Crash
	},

	Undertow = {
		Ability1 = { Damage = 105, Cooldown = 9, Range = 160 }, -- Hydro Jet
		Ability2 = { Damage = 150, Cooldown = 12, Range = 110 }, -- Tidal Wave
		Ability3 = { Damage = 120, Cooldown = 11, Duration = 3, Range = 120, Params = { PullRadius = 28 } }, -- Whirlpool
		Ultimate = { Damage = 410, Cooldown = 1, WindUp = 0.8, Range = 180 }, -- Tsunami
	},
}
BalanceConfig.Abilities = Abilities

function BalanceConfig.getAbility(characterId: string, slot: string): AbilityBalance?
	local set = Abilities[characterId]
	return if set then set[slot] else nil
end

function BalanceConfig.getRole(role: Types.Role): RoleBalance
	return BalanceConfig.Roles[role]
end

return BalanceConfig
