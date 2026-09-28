--!strict
-- Shared type definitions used by configs, services and controllers.

export type Role = "Tank" | "Bruiser" | "Balanced" | "Agile"

export type AbilitySlot = "Ability1" | "Ability2" | "Ability3" | "Ultimate"

-- How the character travels when not on foot.
export type MovementKind = "Ground" | "Flight" | "Board" | "Glider"

-- How an ability reacts to its input key.
--  Instant: fires once on press.
--  Hold:    starts on press, ends on release (channels, braces).
--  Charge:  charges while held, releases on key up.
export type InputKind = "Instant" | "Hold" | "Charge"

export type AbilityDef = {
	Id: string, -- module name under ServerScriptService.ApexCity.Abilities.<Character>
	Name: string,
	Description: string,
	Input: InputKind,
}

export type PassiveDef = {
	Name: string,
	Description: string,
}

export type Palette = {
	Primary: Color3,
	Secondary: Color3,
	Glow: Color3,
}

export type CharacterConfig = {
	Id: string,
	DisplayName: string,
	Role: Role,
	Difficulty: number, -- 1 (easy) .. 5 (hard)
	Order: number, -- sort order in character select
	Tagline: string,
	Movement: MovementKind,
	FlightProfile: string?, -- key into BalanceConfig.Flight.Profiles
	Palette: Palette,
	Passive: PassiveDef?,
	Abilities: { [AbilitySlot]: AbilityDef },
	-- AssetRegistry keys (animations / sounds / vfx). Filled in per phase.
	Animations: { [string]: string },
	Sounds: { [string]: string },
	Hidden: boolean?, -- hidden from character select (test characters)
}

-- Numbers for a single ability. Damage is the expected total damage to one
-- target over the full ability (used by the TTK simulator).
export type AbilityBalance = {
	Damage: number,
	Cooldown: number,
	WindUp: number?,
	Range: number?,
	Duration: number?,
	StaminaCost: number?,
	Params: { [string]: number }?,
}

export type RoleBalance = {
	Health: number,
	DamageReduction: number, -- 0..1
	WalkSpeed: number,
	KnockbackResistance: number, -- 0..1
}

return nil
