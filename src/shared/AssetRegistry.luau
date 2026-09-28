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
	Content: string?, -- built-in "rbxasset://" content used when Id is 0
	Kind: "Animation" | "Sound" | "Texture" | "Mesh" | "Decal" | "Model",
	Status: "Procedural" | "Placeholder" | "Verified",
	Notes: string,
}

local Registry: { [string]: AssetEntry } = {
	-- Phase 1: pipeline test effect.
	["VFX.Pulse"] = { Id = 0, Kind = "Model", Status = "Procedural", Notes = "Neon ring + tween, built in EffectsController" },

	-- Phase 2: movement / flight.
	["Sound.Flight.Wind"] = {
		Id = 0,
		Content = "rbxasset://sounds/action_falling.ogg",
		Kind = "Sound",
		Status = "Placeholder",
		Notes = "Built-in Roblox free-fall wind. Looped; volume/pitch scale with flight speed. Swap for a better wind loop.",
	},
	["Sound.Flight.Land"] = {
		Id = 0,
		Content = "rbxasset://sounds/action_jump_land.mp3",
		Kind = "Sound",
		Status = "Placeholder",
		Notes = "Built-in landing thump, pitched down for hard landings.",
	},
	["VFX.SonicBoom"] = { Id = 0, Kind = "Model", Status = "Procedural", Notes = "Expanding neon ring perpendicular to flight direction" },
	["VFX.Crater"] = { Id = 0, Kind = "Model", Status = "Procedural", Notes = "Scorch disc + rock ring + debris chunks, no decal asset" },
	["VFX.SpeedLines"] = { Id = 0, Kind = "Model", Status = "Procedural", Notes = "Screen-edge UI streaks in CameraController" },
	["Model.Board"] = { Id = 0, Kind = "Model", Status = "Procedural", Notes = "Argent chrome board built from parts in MovementService" },
	["Model.Glider"] = { Id = 0, Kind = "Model", Status = "Procedural", Notes = "Nightwing Goblin glider built from parts in MovementService" },
}

local AssetRegistry = {}

function AssetRegistry.get(key: string): AssetEntry?
	return Registry[key]
end

-- Returns "rbxassetid://<id>", the built-in fallback content, or nil.
function AssetRegistry.contentId(key: string): string?
	local entry = Registry[key]
	if not entry then
		return nil
	end
	if entry.Id ~= 0 then
		return "rbxassetid://" .. tostring(entry.Id)
	end
	return entry.Content
end

function AssetRegistry.all(): { [string]: AssetEntry }
	return Registry
end

return AssetRegistry
