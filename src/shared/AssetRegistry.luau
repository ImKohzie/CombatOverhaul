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
	CharacterSound: string?, -- fallback: copy the SoundId of this default character sound (e.g. "Landing")
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

	-- Phase 3: combat. Id 0 = placeholder; the fallback plays a built-in
	-- Roblox character sound re-pitched so every hit still has audio.
	["Sound.Hit.Light"] = { Id = 0, CharacterSound = "Landing", Kind = "Sound", Status = "Placeholder", Notes = "Layer 1 thump. Replace with a punch impact." },
	["Sound.Hit.Heavy"] = { Id = 0, CharacterSound = "Landing", Kind = "Sound", Status = "Placeholder", Notes = "Heavy thump + crunch. Replace with a layered heavy impact." },
	["Sound.Hit.Block"] = { Id = 0, CharacterSound = "Jumping", Kind = "Sound", Status = "Placeholder", Notes = "Blocked hit clack." },
	["Sound.Parry"] = { Id = 0, CharacterSound = "Jumping", Kind = "Sound", Status = "Placeholder", Notes = "Perfect parry ring (pitched up)." },
	["Sound.Whoosh"] = { Id = 0, CharacterSound = "Jumping", Kind = "Sound", Status = "Placeholder", Notes = "Swing whoosh." },
	["Sound.Beam.Hum"] = { Id = 0, CharacterSound = "FreeFalling", Kind = "Sound", Status = "Placeholder", Notes = "Looped beam hum (wind loop pitched up)." },
	["Sound.Ult.Sting"] = { Id = 0, CharacterSound = "GettingUp", Kind = "Sound", Status = "Placeholder", Notes = "Ultimate music sting. Needs a real stinger." },
	["Sound.Explosion"] = { Id = 0, Kind = "Sound", Status = "Procedural", Notes = "Uses the built-in Explosion instance sound (Visible = false)." },
	["VFX.Hit"] = { Id = 0, Kind = "Model", Status = "Procedural", Notes = "Pooled spark/flash emitter + damage number billboards" },
	["VFX.Beam"] = { Id = 0, Kind = "Model", Status = "Procedural", Notes = "Core + glow Beam objects, impact particles, PointLight, scorch marks" },
	-- Phase 6: destruction
	["Sound.Glass.Shatter"] = { Id = 0, CharacterSound = "Jumping", Kind = "Sound", Status = "Placeholder", Notes = "Glass break. Replace with a real shatter." },
	["Sound.Crumble"] = { Id = 0, CharacterSound = "Landing", Kind = "Sound", Status = "Placeholder", Notes = "Concrete/brick crunch (pitched down)." },
	["Sound.Metal.Clang"] = { Id = 0, CharacterSound = "Jumping", Kind = "Sound", Status = "Placeholder", Notes = "Steel bend/break clang." },
	["Sound.Collapse"] = { Id = 0, CharacterSound = "Landing", Kind = "Sound", Status = "Placeholder", Notes = "Building section collapse rumble." },
	["VFX.Debris"] = { Id = 0, Kind = "Model", Status = "Procedural", Notes = "Pooled client micro-debris, shards, dust, sparks" },
	-- Phase 7: ambience. Id 0 = silent until you add a licensed asset ID.
	-- Entries with CharacterSound play a re-pitched built-in loop meanwhile.
	["Ambience.City.Traffic"] = { Id = 0, CharacterSound = "FreeFalling", Kind = "Sound", Status = "Placeholder", Notes = "City traffic hum loop (fallback: wind loop pitched very low)." },
	["Ambience.City.Horns"] = { Id = 0, Kind = "Sound", Status = "Placeholder", Notes = "Distant car horns one-shots. Needs asset." },
	["Ambience.City.Sirens"] = { Id = 0, Kind = "Sound", Status = "Placeholder", Notes = "Distant sirens one-shots. Needs asset." },
	["Ambience.City.Crowd"] = { Id = 0, Kind = "Sound", Status = "Placeholder", Notes = "Crowd chatter loop near the park and diner. Needs asset." },
	["Ambience.City.Pigeons"] = { Id = 0, Kind = "Sound", Status = "Placeholder", Notes = "Pigeons near the park. Needs asset." },
	["Ambience.Subway.Rumble"] = { Id = 0, CharacterSound = "FreeFalling", Kind = "Sound", Status = "Placeholder", Notes = "Subway rumble at the station (fallback: wind loop pitched low)." },
	["Ambience.Forest.Birds"] = { Id = 0, Kind = "Sound", Status = "Placeholder", Notes = "Daytime birdsong loop. Needs asset." },
	["Ambience.Forest.Night"] = { Id = 0, Kind = "Sound", Status = "Placeholder", Notes = "Crickets + owls loop at night. Needs asset." },
	["Ambience.Forest.Wind"] = { Id = 0, CharacterSound = "FreeFalling", Kind = "Sound", Status = "Placeholder", Notes = "Wind in the trees (fallback: wind loop)." },
	["Ambience.River"] = { Id = 0, CharacterSound = "Swimming", Kind = "Sound", Status = "Placeholder", Notes = "River flow near the river and lake (fallback: swim loop pitched low)." },
	["Ambience.Rain"] = { Id = 0, CharacterSound = "FreeFalling", Kind = "Sound", Status = "Placeholder", Notes = "Rain loop (fallback: wind loop pitched high)." },
	["Sound.SonicBoom"] = { Id = 0, CharacterSound = "Landing", Kind = "Sound", Status = "Placeholder", Notes = "Boost sonic boom (fallback: thump pitched down)." },
	["Animation.Combat"] = { Id = 0, Kind = "Animation", Status = "Procedural", Notes = "All combat/ability poses are procedural keyframes in PoseLibrary. Add real animation IDs per character and match BalanceConfig WindUp to their 'Hit' markers." },
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
