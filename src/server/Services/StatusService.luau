--!strict
-- Timed status effects on any character model (players and NPCs).
-- Effects are named and replicate as character attributes:
--   ApexStunned          any control-loss effect active (Stun, Freeze, Bind, Grab, ...)
--   ApexFrozen / ApexBound / ApexGrounded / ApexPhasing / ApexMarked / ApexTimeSlowed
--   ApexSpeedMultiplier  product of all speed modifiers
--   ApexExtraReduction   sum of damage-reduction modifiers (capped)
-- Applying the same name refreshes it (longest remaining wins, value replaced).

local RunService = game:GetService("RunService")

export type Kind = "Control" | "Speed" | "Reduction" | "Flag"

type Effect = {
	kind: Kind,
	value: number,
	expires: number,
	source: Player?,
}

local StatusService = {}

-- Which attribute flag each named control/flag effect sets.
local FLAG_ATTRIBUTES: { [string]: string } = {
	Freeze = "ApexFrozen",
	Bind = "ApexBound",
	Grounded = "ApexGrounded",
	Phasing = "ApexPhasing",
	Marked = "ApexMarked",
	TimeSlow = "ApexTimeSlowed",
	Invisible = "ApexInvisible",
	ServerMotion = "ApexServerMotion",
	Hardened = "ApexHardened",
	BraceBeam = "ApexBraceBeam",
	Colossal = "ApexColossal",
}

local MAX_EXTRA_REDUCTION = 0.8

local effects: { [Model]: { [string]: Effect } } = {}
local npcBaseSpeed: { [Model]: number } = {}

local function refresh(character: Model)
	local list = effects[character]
	local stunned = false
	local speed = 1
	local reduction = 0
	local flags: { [string]: boolean } = {}
	if list then
		for name, effect in list do
			if effect.kind == "Control" then
				stunned = true
			elseif effect.kind == "Speed" then
				speed *= effect.value
			elseif effect.kind == "Reduction" then
				reduction += effect.value
			end
			local flag = FLAG_ATTRIBUTES[name]
			if flag then
				flags[flag] = true
			end
		end
	end
	character:SetAttribute("ApexStunned", stunned)
	character:SetAttribute("ApexSpeedMultiplier", speed)
	character:SetAttribute("ApexExtraReduction", math.min(reduction, MAX_EXTRA_REDUCTION))
	for _, attribute in FLAG_ATTRIBUTES do
		local value = flags[attribute] == true
		if character:GetAttribute(attribute) ~= value then
			character:SetAttribute(attribute, value)
		end
	end

	-- NPCs have no client controlling them: apply speed / stun directly.
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid and character:GetAttribute("ApexNPC") == true then
		local base = npcBaseSpeed[character]
		if not base then
			base = humanoid.WalkSpeed
			npcBaseSpeed[character] = base
		end
		humanoid.WalkSpeed = if stunned then 0 else base * speed
	end
end

-- Apply or refresh a named effect for `duration` seconds.
function StatusService.apply(character: Model, name: string, kind: Kind, duration: number, value: number?, source: Player?)
	local list = effects[character]
	if not list then
		list = {}
		effects[character] = list
		character.AncestryChanged:Connect(function(_, parent)
			if parent == nil then
				effects[character] = nil
				npcBaseSpeed[character] = nil
			end
		end)
	end
	local expires = os.clock() + duration
	local existing = list[name]
	if existing and existing.expires > expires then
		expires = existing.expires
	end
	list[name] = {
		kind = kind,
		value = value or 1,
		expires = expires,
		source = source,
	}
	refresh(character)
end

function StatusService.remove(character: Model, name: string)
	local list = effects[character]
	if list and list[name] then
		list[name] = nil
		refresh(character)
	end
end

function StatusService.has(character: Model, name: string): boolean
	local list = effects[character]
	local effect = list and list[name]
	return effect ~= nil and effect.expires > os.clock()
end

function StatusService.source(character: Model, name: string): Player?
	local list = effects[character]
	local effect = list and list[name]
	return if effect then effect.source else nil
end

function StatusService.isStunned(character: Model): boolean
	return character:GetAttribute("ApexStunned") == true
end

-- Remove all control effects (e.g. on death or respawn).
function StatusService.clear(character: Model)
	effects[character] = nil
	refresh(character)
end

-- Convenience wrappers
function StatusService.stun(character: Model, duration: number, source: Player?)
	StatusService.apply(character, "Stun", "Control", duration, 1, source)
end

function StatusService.slow(character: Model, name: string, multiplier: number, duration: number, source: Player?)
	StatusService.apply(character, name, "Speed", duration, multiplier, source)
end

function StatusService.init()
	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		for character, list in effects do
			local changed = false
			for name, effect in list do
				if effect.expires <= now then
					list[name] = nil
					changed = true
				end
			end
			if changed then
				refresh(character)
			end
		end
	end)
end

return StatusService
