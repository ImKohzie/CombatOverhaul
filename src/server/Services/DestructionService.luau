--!strict
-- Structural destruction for every part tagged "ApexStructure" (map chunks
-- made by BuildingKit/Interiors, cars, containers, or anything you tag).
--
--   * Each chunk has health from its material (Glass shatters instantly,
--     Wood < Brick < Concrete < Steel) scaled by its size. Steel dents first.
--   * Chunks of a building form a structural graph (built lazily from
--     geometry the first time the building is hit). When a chunk breaks,
--     anything no longer connected to a grounded chunk collapses: connected
--     islands are welded together and unanchored so they fall as sections.
--   * Breaking spawns a few physical debris fragments (server, capped
--     server-wide, network-owned by the nearest player, fading after 20-40s)
--     plus fine micro-debris / dust / sparks / shards on clients.
--   * Destroyed buildings rebuild smoothly ~120s after the last damage.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("ApexCity")
local GameConfig = require(Shared.Config.GameConfig)

local Hooks = require(script.Parent.Parent.Hooks)
local NetService = require(script.Parent.NetService)

local TAG = "ApexStructure"
local EFFECT_RADIUS = 600
local MAX_FRAGMENT_EVENTS_PER_CALL = 40
local REBUILD_CLEAR_RADIUS = 40 -- don't rebuild on top of players

type ChunkKind = "Glass" | "Concrete" | "Steel" | "Wood" | "Brick"

local STRENGTH: { [string]: number } = {
	Glass = 1,
	Wood = 140,
	Brick = 280,
	Concrete = 380,
	Steel = 560,
}

local FRAGMENTS: { [string]: number } = {
	Glass = 0, -- clients render the shards
	Wood = 3,
	Brick = 4,
	Concrete = 3,
	Steel = 2,
}

type ChunkState = {
	part: BasePart,
	kind: string,
	building: string,
	grounded: boolean,
	health: number,
	maxHealth: number,
	origin: CFrame,
	parent: Instance,
	color: Color3,
	transparency: number,
	anchoredChildren: { BasePart },
	childOrigins: { [BasePart]: CFrame },
	broken: boolean,
	loose: boolean, -- fallen as part of a collapsed island
	dented: boolean,
}

type Building = {
	id: string,
	chunks: { ChunkState },
	neighbors: { [ChunkState]: { ChunkState } }?,
	lastDamage: number,
	damaged: boolean,
}

local DestructionService = {}

local states: { [BasePart]: ChunkState } = {}
local buildings: { [string]: Building } = {}
local debrisQueue: { BasePart } = {} -- FIFO of loose physical debris
local debrisFolder: Folder
local brittleZones: { { center: Vector3, radius: number, expires: number } } = {}

--------------------------------------------------------------------------------
-- Registration
--------------------------------------------------------------------------------
local function register(instance: Instance)
	if not instance:IsA("BasePart") or states[instance] then
		return
	end
	local part = instance :: BasePart
	local kindAttr = part:GetAttribute("ApexChunk")
	local buildingAttr = part:GetAttribute("ApexBuilding")
	local kind: string = if type(kindAttr) == "string" then kindAttr elseif part.Material == Enum.Material.Glass then "Glass" else "Concrete"
	local buildingId: string = if type(buildingAttr) == "string" then buildingAttr else "Loose_" .. part:GetFullName()
	local volume = part.Size.X * part.Size.Y * part.Size.Z
	local base = STRENGTH[kind] or 300
	local maxHealth = if kind == "Glass" then 1 else base * math.clamp(volume / 500, 0.5, 3)
	local anchoredChildren: { BasePart } = {}
	local childOrigins: { [BasePart]: CFrame } = {}
	for _, descendant in part:GetDescendants() do
		if descendant:IsA("BasePart") then
			table.insert(anchoredChildren, descendant)
			childOrigins[descendant] = descendant.CFrame
		end
	end
	local state: ChunkState = {
		part = part,
		kind = kind,
		building = buildingId,
		grounded = part:GetAttribute("ApexGrounded") == true,
		health = maxHealth,
		maxHealth = maxHealth,
		origin = part.CFrame,
		parent = part.Parent or workspace,
		color = part.Color,
		transparency = part.Transparency,
		anchoredChildren = anchoredChildren,
		childOrigins = childOrigins,
		broken = false,
		loose = false,
		dented = false,
	}
	states[part] = state
	local building = buildings[buildingId]
	if not building then
		building = { id = buildingId, chunks = {}, neighbors = nil, lastDamage = 0, damaged = false }
		buildings[buildingId] = building
	end
	table.insert(building.chunks, state)
	building.neighbors = nil -- graph is rebuilt lazily
end

--------------------------------------------------------------------------------
-- Debris
--------------------------------------------------------------------------------
local function nearestPlayer(position: Vector3): Player?
	local best: Player? = nil
	local bestDistance = math.huge
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			local distance = (root.Position - position).Magnitude
			if distance < bestDistance then
				best = player
				bestDistance = distance
			end
		end
	end
	return best
end

local function fadeAndRemove(part: BasePart, delaySeconds: number, destroy: boolean)
	task.delay(delaySeconds, function()
		if part.Parent == nil then
			return
		end
		local tween = TweenService:Create(part, TweenInfo.new(1.2), { Transparency = 1 })
		tween:Play()
		tween.Completed:Wait()
		if destroy then
			part:Destroy()
		elseif part.Parent then
			part.Parent = nil
		end
	end)
end

local function trackDebris(part: BasePart)
	table.insert(debrisQueue, part)
	local cap = GameConfig.Debris.MaxLooseParts
	while #debrisQueue > cap do
		local oldest = table.remove(debrisQueue, 1)
		if oldest and oldest.Parent then
			local state = states[oldest]
			if state then
				oldest.Parent = nil -- a fallen chunk: hide until rebuild
			else
				oldest:Destroy()
			end
		end
	end
end

local function spawnFragments(state: ChunkState, impact: Vector3, force: number)
	local count = FRAGMENTS[state.kind] or 0
	local part = state.part
	if count <= 0 then
		return
	end
	local owner = nearestPlayer(part.Position)
	local size = part.Size
	for _ = 1, count do
		local fragment = Instance.new("Part")
		fragment.Name = "Debris"
		local scale = math.random(35, 60) / 100
		fragment.Size = Vector3.new(math.max(size.X * scale / 1.5, 0.6), math.max(size.Y * scale / 1.5, 0.6), math.max(size.Z * scale, 0.4))
		fragment.CFrame = part.CFrame * CFrame.new((math.random() - 0.5) * size.X * 0.6, (math.random() - 0.5) * size.Y * 0.6, 0) * CFrame.Angles(math.random() * 2, math.random() * 2, math.random() * 2)
		fragment.Color = if state.kind == "Steel" then state.color:Lerp(Color3.new(0.1, 0.1, 0.1), 0.3) else state.color
		fragment.Material = part.Material
		fragment.CollisionGroup = "ApexDebris"
		fragment.Anchored = false
		fragment.Parent = debrisFolder
		local away = fragment.Position - impact
		local dir = if away.Magnitude > 1e-3 then away.Unit else Vector3.yAxis
		local speed = math.clamp(force / 60, 8, 90)
		fragment.AssemblyLinearVelocity = dir * speed * (0.6 + math.random() * 0.6) + Vector3.new(0, speed * 0.3, 0)
		fragment.AssemblyAngularVelocity = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 12
		if owner then
			pcall(function()
				fragment:SetNetworkOwner(owner)
			end)
		end
		trackDebris(fragment)
		fadeAndRemove(fragment, math.random(GameConfig.Debris.FadeMin, GameConfig.Debris.FadeMax), true)
	end
end

--------------------------------------------------------------------------------
-- Structural graph
--------------------------------------------------------------------------------
local function buildGraph(building: Building)
	local present: { Instance } = {}
	for _, state in building.chunks do
		table.insert(present, state.part)
	end
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = present
	local neighbors: { [ChunkState]: { ChunkState } } = {}
	for _, state in building.chunks do
		local list: { ChunkState } = {}
		-- Temporarily parented chunks only (broken ones have Parent = nil)
		if state.part.Parent then
			for _, other in workspace:GetPartBoundsInBox(state.origin, state.part.Size + Vector3.new(0.6, 0.6, 0.6), params) do
				local otherState = states[other :: BasePart]
				if otherState and otherState ~= state then
					table.insert(list, otherState)
				end
			end
		end
		neighbors[state] = list
	end
	building.neighbors = neighbors
end

local function collapseUnsupported(building: Building, impact: Vector3)
	if #building.chunks <= 1 then
		return
	end
	if not building.neighbors then
		buildGraph(building)
	end
	local neighbors = building.neighbors :: { [ChunkState]: { ChunkState } }
	-- BFS from grounded, intact, anchored chunks
	local supported: { [ChunkState]: boolean } = {}
	local queue: { ChunkState } = {}
	for _, state in building.chunks do
		if state.grounded and not state.broken and not state.loose then
			supported[state] = true
			table.insert(queue, state)
		end
	end
	local head = 1
	while head <= #queue do
		local current = queue[head]
		head += 1
		for _, other in (neighbors[current] or {}) :: { ChunkState } do
			if not supported[other] and not other.broken and not other.loose then
				supported[other] = true
				table.insert(queue, other)
			end
		end
	end
	-- Unsupported intact chunks -> islands
	local visited: { [ChunkState]: boolean } = {}
	for _, state in building.chunks do
		if state.broken or state.loose or supported[state] or visited[state] then
			continue
		end
		local island: { ChunkState } = {}
		local stack = { state }
		visited[state] = true
		while #stack > 0 do
			local current = table.remove(stack) :: ChunkState
			table.insert(island, current)
			for _, other in (neighbors[current] or {}) :: { ChunkState } do
				if not visited[other] and not other.broken and not other.loose and not supported[other] then
					visited[other] = true
					table.insert(stack, other)
				end
			end
		end
		-- Weld the island together and let it fall
		local anchor = island[1].part
		local owner = nearestPlayer(anchor.Position)
		for _, member in island do
			member.loose = true
			local part = member.part
			if part ~= anchor then
				local weld = Instance.new("WeldConstraint")
				weld.Name = "ApexDebrisWeld"
				weld.Part0 = anchor
				weld.Part1 = part
				weld.Parent = part
			end
			for _, child in member.anchoredChildren do
				local weld = Instance.new("WeldConstraint")
				weld.Name = "ApexDebrisWeld"
				weld.Part0 = part
				weld.Part1 = child
				weld.Parent = child
				child.Anchored = false
				child.Massless = true
			end
			part.CollisionGroup = "ApexDebris"
			part.Anchored = false
			trackDebris(part)
		end
		local away = anchor.Position - impact
		anchor.AssemblyLinearVelocity = (if away.Magnitude > 1e-3 then away.Unit else Vector3.zero) * 6
		if owner then
			pcall(function()
				anchor:SetNetworkOwner(owner)
			end)
		end
		for _, member in island do
			fadeAndRemove(member.part, math.random(GameConfig.Debris.FadeMin, GameConfig.Debris.FadeMax), false)
		end
		NetService.fireNear("Effect", anchor.Position, EFFECT_RADIUS, "Collapse", { Position = anchor.Position, Size = #island })
	end
end

--------------------------------------------------------------------------------
-- Breaking
--------------------------------------------------------------------------------
local fragmentEventsThisCall = 0

local function breakChunk(state: ChunkState, impact: Vector3, force: number, silent: boolean?)
	if state.broken then
		return
	end
	state.broken = true
	local part = state.part
	local building = buildings[state.building]
	if not silent then
		if fragmentEventsThisCall < MAX_FRAGMENT_EVENTS_PER_CALL then
			fragmentEventsThisCall += 1
			spawnFragments(state, impact, force)
		end
		NetService.fireNear("Effect", part.Position, EFFECT_RADIUS, "Fracture", {
			Position = part.Position,
			Size = part.Size,
			CFrame = part.CFrame,
			Kind = state.kind,
			Color = state.color,
			Material = part.Material.Name,
			Impact = impact,
			Force = force,
		})
		if CollectionService:HasTag(part, "ApexVehicle") then
			NetService.fireNear("Effect", part.Position, EFFECT_RADIUS, "Explosion", { Position = part.Position, Radius = 12, Kind = "Fire" })
		end
	end
	part.Parent = nil
	if building then
		building.lastDamage = os.clock()
		building.damaged = true
		collapseUnsupported(building, impact)
	end
end

local function inBrittleZone(position: Vector3): boolean
	local now = os.clock()
	for i = #brittleZones, 1, -1 do
		local zone = brittleZones[i]
		if zone.expires < now then
			table.remove(brittleZones, i)
		elseif (position - zone.center).Magnitude <= zone.radius then
			return true
		end
	end
	return false
end

function DestructionService.damagePart(part: BasePart, position: Vector3, damage: number, force: number): boolean
	local state = states[part]
	if not state or state.broken or state.loose or damage <= 0 then
		return false
	end
	local building = buildings[state.building]
	if building then
		building.lastDamage = os.clock()
		building.damaged = true
	end
	if inBrittleZone(part.Position) then
		damage = math.huge
	end
	state.health -= damage
	if state.health <= 0 then
		breakChunk(state, position, force)
		return true
	end
	-- Steel bends / dents before it breaks
	if state.kind == "Steel" and not state.dented and state.health < state.maxHealth * 0.5 then
		state.dented = true
		local offset = part.CFrame:PointToObjectSpace(position)
		part.CFrame = part.CFrame * CFrame.Angles(math.rad(math.sign(offset.Y) * 4), 0, math.rad(math.sign(offset.X) * -3))
		part.Color = state.color:Lerp(Color3.new(0.12, 0.12, 0.12), 0.35)
	end
	NetService.fireNear("Effect", position, 300, "Chip", { Position = position, Kind = state.kind, Color = state.color })
	return false
end

function DestructionService.damageSphere(center: Vector3, radius: number, damage: number, force: number)
	fragmentEventsThisCall = 0
	local root = workspace:FindFirstChild("NewHarbor")
	local params = OverlapParams.new()
	params.MaxParts = 400
	if root then
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = { root }
	end
	for _, part in workspace:GetPartBoundsInRadius(center, radius, params) do
		local state = states[part]
		if state and not state.broken and not state.loose then
			local distance = (part.Position - center).Magnitude
			local falloff = math.clamp(1 - distance / (radius + part.Size.Magnitude * 0.5), 0.25, 1)
			DestructionService.damagePart(part, center, damage * falloff, force * falloff)
		end
	end
	-- Loose chunks/debris in the blast get thrown
	for _, part in workspace:GetPartBoundsInRadius(center, radius, params) do
		if not part.Anchored and part.CollisionGroup == "ApexDebris" then
			local away = part.Position - center
			if away.Magnitude > 1e-3 then
				part.AssemblyLinearVelocity += away.Unit * math.clamp(force / 80, 5, 60)
			end
		end
	end
end

--------------------------------------------------------------------------------
-- Special hooks
--------------------------------------------------------------------------------
local function shatterGlassCone(origin: Vector3, direction: Vector3, range: number, halfAngle: number)
	fragmentEventsThisCall = 0
	local dir = if direction.Magnitude > 1e-3 then direction.Unit else Vector3.zAxis
	local cosLimit = math.cos(math.rad(math.min(halfAngle, 179)))
	local params = OverlapParams.new()
	params.MaxParts = 600
	for _, part in workspace:GetPartBoundsInRadius(origin, range, params) do
		local state = states[part]
		if state and state.kind == "Glass" and not state.broken then
			local offset = part.Position - origin
			if halfAngle >= 179 or offset.Magnitude < 1 or offset.Unit:Dot(dir) >= cosLimit then
				breakChunk(state, origin, 800)
			end
		end
	end
end

local function collapseFromBase(center: Vector3, radius: number)
	fragmentEventsThisCall = 0
	local affected: { [string]: boolean } = {}
	for id, building in buildings do
		for _, state in building.chunks do
			if not state.broken and (state.origin.Position - center).Magnitude <= radius then
				affected[id] = true
				break
			end
		end
	end
	for id in affected do
		local building = buildings[id]
		-- Destroy the lowest ring of grounded chunks: the rest has no support
		local lowest = math.huge
		for _, state in building.chunks do
			if state.grounded and not state.broken then
				lowest = math.min(lowest, state.origin.Position.Y)
			end
		end
		for _, state in building.chunks do
			if state.grounded and not state.broken and state.origin.Position.Y <= lowest + 8 then
				breakChunk(state, state.origin.Position, 1500, fragmentEventsThisCall > MAX_FRAGMENT_EVENTS_PER_CALL)
			end
		end
	end
end

local function pullDebris(center: Vector3, radius: number, strength: number)
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { debrisFolder }
	params.MaxParts = 200
	for _, part in workspace:GetPartBoundsInRadius(center, radius, params) do
		if not part.Anchored then
			local offset = center - part.Position
			if offset.Magnitude > 2 then
				part.AssemblyLinearVelocity = part.AssemblyLinearVelocity:Lerp(offset.Unit * strength, 0.5)
			end
		end
	end
	-- Fallen chunk islands too
	local nearby = workspace:GetPartBoundsInRadius(center, radius)
	for _, part in nearby do
		local state = states[part]
		if state and state.loose and not part.Anchored then
			local offset = center - part.Position
			if offset.Magnitude > 2 then
				part.AssemblyLinearVelocity = part.AssemblyLinearVelocity:Lerp(offset.Unit * strength, 0.3)
			end
		end
	end
end

--------------------------------------------------------------------------------
-- Rebuild
--------------------------------------------------------------------------------
local function playersNear(position: Vector3, radius: number): boolean
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") and (root.Position - position).Magnitude < radius then
			return true
		end
	end
	return false
end

local function rebuild(building: Building)
	building.damaged = false
	for _, state in building.chunks do
		if not state.broken and not state.loose and not state.dented and state.health >= state.maxHealth then
			continue
		end
		local part = state.part
		for _, weld in part:GetChildren() do
			if weld.Name == "ApexDebrisWeld" then
				weld:Destroy()
			end
		end
		part.Anchored = true
		part.AssemblyLinearVelocity = Vector3.zero
		part.CFrame = state.origin
		part.CollisionGroup = "Default"
		part.Color = state.color
		for _, child in state.anchoredChildren do
			for _, weld in child:GetChildren() do
				if weld.Name == "ApexDebrisWeld" then
					weld:Destroy()
				end
			end
			child.Anchored = true
			local origin = state.childOrigins[child]
			if origin then
				child.CFrame = origin
			end
		end
		local wasBroken = state.broken or state.loose
		state.broken = false
		state.loose = false
		state.dented = false
		state.health = state.maxHealth
		if wasBroken then
			part.Transparency = 1
			part.Parent = state.parent
			TweenService:Create(part, TweenInfo.new(1.5, Enum.EasingStyle.Quad), { Transparency = state.transparency }):Play()
		end
	end
	building.neighbors = nil
end

local function rebuildLoop()
	while true do
		task.wait(3)
		local now = os.clock()
		for _, building in buildings do
			if building.damaged and now - building.lastDamage >= GameConfig.Debris.RebuildTime then
				local anchor = building.chunks[1]
				if anchor and not playersNear(anchor.origin.Position, REBUILD_CLEAR_RADIUS) then
					rebuild(building)
				end
			end
		end
	end
end

--------------------------------------------------------------------------------
-- Stats
--------------------------------------------------------------------------------
function DestructionService.stats(): { chunks: number, buildings: number, looseDebris: number, broken: number }
	local chunkCount, brokenCount, buildingCount = 0, 0, 0
	for _, state in states do
		chunkCount += 1
		if state.broken or state.loose then
			brokenCount += 1
		end
	end
	for _ in buildings do
		buildingCount += 1
	end
	return { chunks = chunkCount, buildings = buildingCount, looseDebris = #debrisQueue, broken = brokenCount }
end

function DestructionService.init()
	-- Collision groups: debris never snags characters (and is cheaper)
	local PhysicsService = game:GetService("PhysicsService")
	for _, group in { "ApexDebris", "ApexCharacters", "ApexFx" } do
		pcall(function()
			PhysicsService:RegisterCollisionGroup(group)
		end)
	end
	pcall(function()
		PhysicsService:CollisionGroupSetCollidable("ApexDebris", "ApexCharacters", false)
		PhysicsService:CollisionGroupSetCollidable("ApexFx", "ApexCharacters", false)
		PhysicsService:CollisionGroupSetCollidable("ApexFx", "ApexFx", false)
	end)

	local existing = workspace:FindFirstChild("ApexDebris")
	if existing and existing:IsA("Folder") then
		debrisFolder = existing
	else
		local folder = Instance.new("Folder")
		folder.Name = "ApexDebris"
		folder.Parent = workspace
		debrisFolder = folder
	end

	-- Register structures (including ones generated later by WorldService)
	CollectionService:GetInstanceAddedSignal(TAG):Connect(register)
	task.spawn(function()
		local count = 0
		for _, instance in CollectionService:GetTagged(TAG) do
			register(instance)
			count += 1
			if count % 2000 == 0 then
				task.wait()
			end
		end
	end)

	Hooks.isStructure = function(part: BasePart): boolean
		local state = states[part]
		return state ~= nil and not state.broken and not state.loose
	end
	Hooks.structureDamageAt = function(part: BasePart, position: Vector3, damage: number, force: number, _source: Model?): boolean
		fragmentEventsThisCall = 0
		return DestructionService.damagePart(part, position, damage, force)
	end
	Hooks.structureDamageSphere = function(center: Vector3, radius: number, damage: number, force: number, _source: Model?)
		DestructionService.damageSphere(center, radius, damage, force)
	end
	Hooks.structureImpact = function(part: BasePart, position: Vector3, force: number, _source: Model?): boolean
		fragmentEventsThisCall = 0
		-- A body slamming into a wall: breaks through if the force beats the chunk
		return DestructionService.damagePart(part, position, force / 3, force)
	end
	Hooks.shatterGlassCone = function(origin: Vector3, direction: Vector3, range: number, halfAngle: number, _source: Model?)
		shatterGlassCone(origin, direction, range, halfAngle)
	end
	Hooks.collapseFromBase = function(center: Vector3, radius: number, _source: Model?)
		collapseFromBase(center, radius)
	end
	Hooks.setBrittle = function(center: Vector3, radius: number, duration: number)
		table.insert(brittleZones, { center = center, radius = radius, expires = os.clock() + duration })
	end
	Hooks.pullDebris = function(center: Vector3, radius: number, strength: number)
		pullDebris(center, radius, strength)
	end
	Hooks.ripChunk = function(part: BasePart): (Color3?, Enum.Material?)
		local state = states[part]
		if not state or state.broken then
			return nil, nil
		end
		local color, material = part.Color, part.Material
		fragmentEventsThisCall = MAX_FRAGMENT_EVENTS_PER_CALL -- no fragments: it's being carried
		breakChunk(state, part.Position, 0)
		return color, material
	end

	-- Characters never collide with debris
	local function setGroup(character: Model)
		for _, descendant in character:GetDescendants() do
			if descendant:IsA("BasePart") then
				descendant.CollisionGroup = "ApexCharacters"
			end
		end
		character.DescendantAdded:Connect(function(descendant)
			if descendant:IsA("BasePart") then
				descendant.CollisionGroup = "ApexCharacters"
			end
		end)
	end
	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(setGroup)
		if player.Character then
			setGroup(player.Character)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end

	task.spawn(rebuildLoop)
end

return DestructionService
