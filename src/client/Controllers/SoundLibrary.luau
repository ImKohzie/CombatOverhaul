--!strict
-- Resolves AssetRegistry sound keys to playable SoundIds and plays them
-- (2D or at a position). Placeholders fall back to built-in character
-- sounds copied from the local character so something always plays.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local AssetRegistry = require(ReplicatedStorage:WaitForChild("ApexCity").AssetRegistry)

local player = Players.LocalPlayer

local SoundLibrary = {}

local cache: { [string]: string } = {}

local function characterSoundId(name: string): string?
	local cached = cache["char:" .. name]
	if cached then
		return cached
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local sound = root and root:FindFirstChild(name)
	if sound and sound:IsA("Sound") and sound.SoundId ~= "" then
		cache["char:" .. name] = sound.SoundId
		return sound.SoundId
	end
	return nil
end

function SoundLibrary.resolve(key: string): string?
	local entry = AssetRegistry.get(key)
	if not entry then
		return nil
	end
	local id = AssetRegistry.contentId(key)
	if id then
		return id
	end
	if entry.CharacterSound then
		return characterSoundId(entry.CharacterSound)
	end
	return nil
end

export type PlayOptions = {
	Volume: number?,
	Pitch: number?,
	Position: Vector3?,
	Parent: Instance?,
	Looped: boolean?,
	MaxDistance: number?,
}

-- Plays a sound; returns it (looped sounds must be destroyed by the caller).
function SoundLibrary.play(key: string, options: PlayOptions?): Sound?
	local id = SoundLibrary.resolve(key)
	if not id then
		return nil
	end
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = if options and options.Volume then options.Volume else 0.7
	sound.PlaybackSpeed = if options and options.Pitch then options.Pitch else 1
	sound.Looped = if options and options.Looped then true else false
	sound.RollOffMaxDistance = if options and options.MaxDistance then options.MaxDistance else 220
	local holder: Instance? = options and options.Parent
	local anchor: Attachment? = nil
	if not holder and options and options.Position then
		local attachment = Instance.new("Attachment")
		attachment.WorldPosition = options.Position
		attachment.Parent = workspace.Terrain
		anchor = attachment
		holder = attachment
	end
	sound.Parent = holder or SoundService
	sound:Play()
	if not sound.Looped then
		sound.Ended:Connect(function()
			sound:Destroy()
			if anchor then
				anchor:Destroy()
			end
		end)
		task.delay(10, function()
			if sound.Parent then
				sound:Destroy()
			end
			if anchor and anchor.Parent then
				anchor:Destroy()
			end
		end)
	end
	return sound
end

-- Let EffectsController play sounds without requiring us (no cycle).
task.defer(function()
	local ok, effects = pcall(require, script.Parent.EffectsController)
	if ok then
		(effects :: any).setSoundPlayer(function(key: string, options: { [string]: any })
			SoundLibrary.play(key, options :: any)
		end)
	end
end)

-- Built-in explosion boom (no visual, no physics).
function SoundLibrary.explosion(position: Vector3)
	local explosion = Instance.new("Explosion")
	explosion.Position = position
	explosion.BlastPressure = 0
	explosion.BlastRadius = 0
	explosion.DestroyJointRadiusPercent = 0
	explosion.Visible = false
	explosion.Parent = workspace
end

return SoundLibrary
