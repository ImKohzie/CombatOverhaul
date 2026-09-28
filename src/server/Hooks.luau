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

-- DestructionService: break every glass chunk in a cone (Sonic Scream).
Hooks.shatterGlassCone = function(_origin: Vector3, _direction: Vector3, _range: number, _halfAngle: number, _source: Model?) end

-- DestructionService: destroy the lowest supports of structures in a radius
-- so they collapse under their own weight (Frequency Collapse).
Hooks.collapseFromBase = function(_center: Vector3, _radius: number, _source: Model?) end

-- DestructionService: structures in the sphere break from any hit (Absolute Zero).
Hooks.setBrittle = function(_center: Vector3, _radius: number, _duration: number) end

-- DestructionService: pull loose debris toward a point (gravity abilities).
Hooks.pullDebris = function(_center: Vector3, _radius: number, _strength: number) end

-- DestructionService: remove one chunk and return its look (Rip & Throw).
Hooks.ripChunk = function(_part: BasePart): (Color3?, Enum.Material?)
	return nil, nil
end

return Hooks
