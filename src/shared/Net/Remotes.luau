--!strict
-- Single declaration of every remote. The server creates the instances
-- (NetService); clients wait for them. Rate limits are per player per remote.

export type RemoteSpec = {
	Kind: "Event" | "Function",
	Direction: "ClientToServer" | "ServerToClient",
	RatePerSecond: number?,
	Burst: number?,
}

local RunService = game:GetService("RunService")

local ROOT = script.Parent.Parent -- ReplicatedStorage.ApexCity
local FOLDER_NAME = "Remotes"

local Remotes = {}

Remotes.Specs = {
	-- Client -> server
	AbilityInput = { Kind = "Event", Direction = "ClientToServer", RatePerSecond = 12, Burst = 20 },
	CombatInput = { Kind = "Event", Direction = "ClientToServer", RatePerSecond = 30, Burst = 40 },
	MovementState = { Kind = "Event", Direction = "ClientToServer", RatePerSecond = 20, Burst = 30 },
	SelectCharacter = { Kind = "Function", Direction = "ClientToServer", RatePerSecond = 0.5, Burst = 2 },

	-- Server -> client
	Effect = { Kind = "Event", Direction = "ServerToClient" },
	Notify = { Kind = "Event", Direction = "ServerToClient" },
	-- Knockback / launches / forced moves for the victim's own client (it
	-- owns its character's physics, so the server asks it to apply them).
	Impulse = { Kind = "Event", Direction = "ServerToClient" },
} :: { [string]: RemoteSpec }

local function getFolder(): Folder
	if RunService:IsServer() then
		local folder = ROOT:FindFirstChild(FOLDER_NAME)
		if not folder then
			folder = Instance.new("Folder")
			folder.Name = FOLDER_NAME
			folder.Parent = ROOT
		end
		return folder :: Folder
	end
	return ROOT:WaitForChild(FOLDER_NAME) :: Folder
end

-- Server only: create every declared remote.
function Remotes.build()
	assert(RunService:IsServer(), "Remotes.build is server-only")
	local folder = getFolder()
	for name, spec in Remotes.Specs do
		if not folder:FindFirstChild(name) then
			local remote = Instance.new(if spec.Kind == "Event" then "RemoteEvent" else "RemoteFunction")
			remote.Name = name
			remote.Parent = folder
		end
	end
end

function Remotes.event(name: string): RemoteEvent
	local spec = Remotes.Specs[name]
	assert(spec and spec.Kind == "Event", "Unknown RemoteEvent: " .. name)
	return getFolder():WaitForChild(name) :: RemoteEvent
end

function Remotes.func(name: string): RemoteFunction
	local spec = Remotes.Specs[name]
	assert(spec and spec.Kind == "Function", "Unknown RemoteFunction: " .. name)
	return getFolder():WaitForChild(name) :: RemoteFunction
end

return Remotes
