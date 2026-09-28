--!strict
-- Late-bound cross-service hooks. Services that would otherwise require each
-- other in a cycle (damage <-> reactions <-> destruction) publish functions
-- here during init(). Defaults are safe no-ops so load order never crashes.

export type DamageKind = "Melee" | "Heavy" | "Beam" | "Projectile" | "AoE" | "DoT" | "Splat"

export type DamageInfo = {
	Amount: number,
	Attacker: Player?,
	AttackerCharacter: Model?,
	Kind: DamageKind,
	Position: Vector3?,
	Knockback: Vector3?, -- world-space velocity applied to the victim
	Ragdoll: number?,
	HitStun: number?,
	Unblockable: boolean?,
	CanParry: boolean?,
	Tag: string?, -- ability / attack name for the kill feed
	NoReaction: boolean?,
	IgnoreModifiers: boolean?,
}

local Hooks = {}

-- DamageService.apply
Hooks.applyDamage = function(_victim: Model, _info: DamageInfo): number
	return 0
end

-- DestructionService: a body / object slammed into a structure part.
-- Returns true when the part broke (the body should keep flying through).
Hooks.structureImpact = function(_part: BasePart, _position: Vector3, _force: number, _source: Model?): boolean
	return false
end

-- DestructionService: damage one structure part at a point.
Hooks.structureDamageAt = function(_part: BasePart, _position: Vector3, _damage: number, _force: number, _source: Model?): boolean
	return false
end

-- DestructionService: damage every structure part in a sphere.
Hooks.structureDamageSphere = function(_center: Vector3, _radius: number, _damage: number, _force: number, _source: Model?) end

-- DestructionService: is this part a destructible structure chunk?
Hooks.isStructure = function(_part: BasePart): boolean
	return false
end

return Hooks
