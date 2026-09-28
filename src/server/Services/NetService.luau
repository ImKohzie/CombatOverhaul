--!strict
-- Owns all remotes on the server. Every client -> server request passes:
--   1. per-player per-remote rate limit
--   2. argument schema validation (types, NaN/inf, lengths, magnitudes)
--   3. alive-character check (unless the handler opts out)
-- Failures are dropped and add a strike; too many strikes kicks the player.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("ApexCity")
local Remotes = require(Shared.Net.Remotes)
local Validate = require(Shared.Net.Validate)
local RateLimiter = require(Shared.Util.RateLimiter)
local GameConfig = require(Shared.Config.GameConfig)

type Check = Validate.Check

export type HandlerOptions = {
	RequireAlive: boolean?, -- default true
}

local NetService = {}

local limiters: { [string]: RateLimiter.RateLimiter } = {}
local strikes: { [Player]: { number } } = {}

local function getLimiter(name: string): RateLimiter.RateLimiter
	local limiter = limiters[name]
	if not limiter then
		local spec = Remotes.Specs[name]
		limiter = RateLimiter.new(spec.RatePerSecond or 10, spec.Burst or 10)
		limiters[name] = limiter
	end
	return limiter
end

function NetService.strike(player: Player, reason: string)
	local now = os.clock()
	local list = strikes[player]
	if not list then
		list = {}
		strikes[player] = list
	end
	table.insert(list, now)
	while list[1] and now - list[1] > GameConfig.Net.StrikeWindow do
		table.remove(list, 1)
	end
	if GameConfig.Debug.VerboseNet then
		warn(`[Net] {player.Name}: {reason}`)
	end
	if GameConfig.Net.KickEnabled and #list >= GameConfig.Net.StrikesToKick then
		warn(`[Net] Kicking {player.Name} for repeated invalid requests (last: {reason})`)
		player:Kick("Too many invalid requests.")
	end
end

local function hasAliveCharacter(player: Player): boolean
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.Health > 0
end

local function precheck(player: Player, name: string, schema: { Check }, options: HandlerOptions?, args: { any }, count: number): boolean
	if not getLimiter(name):check(player) then
		NetService.strike(player, `rate limited on {name}`)
		return false
	end
	local ok, reason = Validate.args(schema, args, count)
	if not ok then
		NetService.strike(player, `{name}: {reason}`)
		return false
	end
	local requireAlive = if options and options.RequireAlive ~= nil then options.RequireAlive else true
	if requireAlive and not hasAliveCharacter(player) then
		return false -- not a strike: can happen legitimately right after death
	end
	return true
end

function NetService.onEvent(name: string, schema: { Check }, handler: (Player, ...any) -> (), options: HandlerOptions?)
	local remote = Remotes.event(name)
	remote.OnServerEvent:Connect(function(player: Player, ...: any)
		local count = select("#", ...)
		local args = { ... }
		if precheck(player, name, schema, options, args, count) then
			handler(player, table.unpack(args, 1, count))
		end
	end)
end

function NetService.onInvoke(name: string, schema: { Check }, handler: (Player, ...any) -> ...any, options: HandlerOptions?)
	local remote = Remotes.func(name)
	remote.OnServerInvoke = function(player: Player, ...: any): ...any
		local count = select("#", ...)
		local args = { ... }
		if not precheck(player, name, schema, options, args, count) then
			return false, "Request rejected"
		end
		return handler(player, table.unpack(args, 1, count))
	end
end

function NetService.fireClient(name: string, player: Player, ...: any)
	Remotes.event(name):FireClient(player, ...)
end

function NetService.fireAll(name: string, ...: any)
	Remotes.event(name):FireAllClients(...)
end

-- Fire only to players whose character is within radius of position.
-- Used for cosmetic effects so far-away clients aren't flooded.
function NetService.fireNear(name: string, position: Vector3, radius: number, ...: any)
	NetService.fireNearExcept(name, position, radius, nil, ...)
end

-- Same as fireNear but skips one player (who already played it locally).
function NetService.fireNearExcept(name: string, position: Vector3, radius: number, except: Player?, ...: any)
	local remote = Remotes.event(name)
	for _, player in Players:GetPlayers() do
		if player == except then
			continue
		end
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") and (root.Position - position).Magnitude <= radius then
			remote:FireClient(player, ...)
		end
	end
end

function NetService.init()
	Remotes.build()
	Players.PlayerRemoving:Connect(function(player)
		strikes[player] = nil
		for _, limiter in limiters do
			limiter:remove(player)
		end
	end)
end

return NetService
