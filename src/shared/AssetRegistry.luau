--!strict
-- Every external asset used by APEX CITY is listed here so nothing is
-- hard-coded elsewhere. Code looks assets up by key: AssetRegistry.get("Sound.Hit.Light").
--
-- Status:
--   "Procedural"  - built in code, no external asset needed.
--   "Placeholder" - Id 0, effect falls back to procedural until a real asset is set.
--   "Verified"    - checked in Studio and working.
--
-- Free-model rule: any model pulled from the Toolbox must have every Script,
-- LocalScript and ModuleScript stripped before it is placed in the game.

export type AssetEntry = {
	Id: number,
	Kind: "Animation" | "Sound" | "Texture" | "Mesh" | "Decal" | "Model",
	Status: "Procedural" | "Placeholder" | "Verified",
	Notes: string,
}

local Registry: { [string]: AssetEntry } = {
	-- Phase 1: pipeline test effect.
	["VFX.Pulse"] = { Id = 0, Kind = "Model", Status = "Procedural", Notes = "Neon ring + tween, built in EffectsController" },
}

local AssetRegistry = {}

function AssetRegistry.get(key: string): AssetEntry?
	return Registry[key]
end

-- Returns "rbxassetid://<id>" or nil when the entry is missing / placeholder.
function AssetRegistry.contentId(key: string): string?
	local entry = Registry[key]
	if entry and entry.Id ~= 0 then
		return "rbxassetid://" .. tostring(entry.Id)
	end
	return nil
end

function AssetRegistry.all(): { [string]: AssetEntry }
	return Registry
end

return AssetRegistry
