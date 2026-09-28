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
	MaxServerReach = 14, -- server rejects hits further than this from attacker
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
		Ability3 = { Damage = 150, Cooldown = 13, Duration = 1, Params = { Hits = 10 } }, -- Blitz Barrage
		Ultimate = { Damage = 380, Cooldown = 1, Duration = 6, Params = { WorldTimeScale = 0.15 } }, -- Velocity Rift
	},

	OldGuard = {
		Ability1 = { Damage = 110, Cooldown = 9, Range = 120, Params = { Bounces = 3 } }, -- Ricochet Shield
		Ability2 = { Damage = 90, Cooldown = 8, Range = 10, Params = { StaggerTime = 0.8 } }, -- Shield Bash & Brace
		Ability3 = { Damage = 180, Cooldown = 14, Duration = 1.4, Params = { Hits = 6 } }, -- Brawler's Fury
		Ultimate = { Damage = 400, Cooldown = 1, WindUp = 2, Range = 70, Params = { ZoneDps = 15, ZoneDuration = 6 } }, -- Core Meltdown
	},

	Sovereign = {
		Ability1 = { Damage = 180, Cooldown = 12, Duration = 3, Range = 300, Params = { Dps = 60 } }, -- Ocular Beam
		Ability2 = { Damage = 100, Cooldown = 9, Range = 40, Params = { StunTime = 0.9, ConeDegrees = 70 } }, -- Sonic Clap
		Ability3 = { Damage = 170, Cooldown = 14, WindUp = 0.3, Range = 14, Params = { LiftHeight = 120 } }, -- Skyfall Grab
		Ultimate = { Damage = 450, Cooldown = 1, Duration = 3, Range = 500, Params = { ArcDegrees = 180 } }, -- Judgement
	},

	Rampage = {
		Ability1 = { Damage = 130, Cooldown = 10, WindUp = 0.4, Range = 50 }, -- Thunderclap
		Ability2 = { Damage = 140, Cooldown = 12, Range = 300, Params = { CraterRadius = 22 } }, -- Gamma Leap
		Ability3 = { Damage = 160, Cooldown = 13, WindUp = 0.7, Range = 200 }, -- Rip & Throw
		Ultimate = { Damage = 460, Cooldown = 1, Duration = 4, Range = 80 }, -- World Breaker
	},

	NightwingGoblin = {
		Ability1 = { Damage = 135, Cooldown = 10, Range = 90, Params = { Bombs = 3 } }, -- Shade Bombs
		Ability2 = { Damage = 120, Cooldown = 9, Range = 80 }, -- Blade Swoop
		Ability3 = { Damage = 140, Cooldown = 12, Range = 250, Params = { Missiles = 4 } }, -- Talon Missiles
		Ultimate = { Damage = 420, Cooldown = 1, Duration = 4, Range = 400 }, -- Carpet Run
	},

	Argent = {
		Ability1 = { Damage = 165, Cooldown = 12, Duration = 3, Range = 300, Params = { Dps = 55 } }, -- Cosmic Lance
		Ability2 = { Damage = 110, Cooldown = 11, Range = 120 }, -- Matter Reshape
		Ability3 = { Damage = 130, Cooldown = 10, Duration = 4, Range = 30 }, -- Board Strike
		Ultimate = { Damage = 450, Cooldown = 1, WindUp = 1.2, Range = 90 }, -- Nova Collapse
	},

	Graven = {
		Ability1 = { Damage = 150, Cooldown = 13, Duration = 2.5, Range = 150, Params = { PullRadius = 40 } }, -- Singularity
		Ability2 = { Damage = 110, Cooldown = 12, Duration = 2, Range = 35 }, -- Float
		Ability3 = { Damage = 60, Cooldown = 10, Duration = 4, Range = 150, Params = { GravityMultiplier = 3, SpeedMultiplier = 0.5 } }, -- Weight
		Ultimate = { Damage = 440, Cooldown = 1, Duration = 6, Range = 120 }, -- Event Horizon
	},

	Rime = {
		Ability1 = { Damage = 0, Cooldown = 8, Duration = 6, Params = { SkateSpeed = 70 } }, -- Ice Road
		Ability2 = { Damage = 120, Cooldown = 12, Range = 120, Params = { FreezeTime = 1.5, BaseDamage = 40, ShatterBonus = 80 } }, -- Flash Freeze
		Ability3 = { Damage = 150, Cooldown = 11, WindUp = 0.3, Range = 90 }, -- Glacier Spike
		Ultimate = { Damage = 380, Cooldown = 1, Duration = 8, Range = 150 }, -- Absolute Zero
	},

	Swarm = {
		Ability1 = { Damage = 140, Cooldown = 10, Duration = 1.5, Range = 14 }, -- Nanite Blades
		Ability2 = { Damage = 60, Cooldown = 12, Duration = 4, Range = 100 }, -- Disassemble
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
