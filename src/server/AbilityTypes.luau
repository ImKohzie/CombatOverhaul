--!strict
-- Contract for server ability modules:
--   ServerScriptService.ApexCity.Abilities.<CharacterId>.<AbilityId>
-- The shared AbilityService validates input, cooldown, stamina and ultimate
-- meter BEFORE calling Begin, so modules only implement the ability itself.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Types = require(ReplicatedStorage:WaitForChild("ApexCity").Types)

export type AbilityContext = {
	Player: Player,
	Character: Model,
	Humanoid: Humanoid,
	Root: BasePart,
	CharacterId: string,
	Slot: string, -- Types.AbilitySlot
	Def: Types.AbilityDef,
	Balance: Types.AbilityBalance,
	AimOrigin: Vector3, -- validated
	AimPoint: Vector3, -- validated, clamped to ability range when it has one
	StartTime: number, -- workspace:GetServerTimeNow()
}

export type AbilityModule = {
	-- Return false if the ability could not fire (no cooldown is spent).
	Begin: (ctx: AbilityContext) -> boolean,
	-- Called on key release for Hold/Charge abilities, or when Duration expires.
	End: ((ctx: AbilityContext) -> ())?,
}

return nil
