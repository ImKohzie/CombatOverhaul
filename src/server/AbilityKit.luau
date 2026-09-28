--!strict
-- Shared helpers for ability modules: target queries (spatial queries only,
-- never .Touched), projectiles, server-driven motion, damage shortcuts and
-- cosmetic effect broadcasts.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Hooks = require(script.Parent.Hooks)
local AbilityTypes = require(script.Parent.AbilityTypes)
local NetService = require(script.Parent.Services.NetService)
local StatusService = require(script.Parent.Services.StatusService)
local ReactionService = require(script.Parent.Services.ReactionService)

type AbilityContext = AbilityTypes.AbilityContext
type DamageInfo = Hooks.DamageInfo

local EFFECT_RADIUS = 600

local Kit = {}

--------------------------------------------------------------------------------
-- Characters
--------------------------------------------------------------------------------
function Kit.rootOf(character: Model): BasePart?
	local root = character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

function Kit.isAlive(character: Model): boolean
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.Health > 0
end

-- Walk up from a part to the character model that owns it (if any).
function Kit.characterFromPart(part: Instance): Model?
	local current: Instance? = part
	while current and current ~= workspace do
		if current:IsA("Model") and current:FindFirstChildOfClass("Humanoid") then
			return current
		end
		current = current.Parent
	end
	return nil
end

-- All living characters (players + NPCs registered in the ApexDummies folder).
function Kit.allCharacters(): { Model }
	local list: { Model } = {}
	for _, player in Players:GetPlayers() do
		if player.Character and Kit.isAlive(player.Character) then
			table.insert(list, player.Character)
		end
	end
	local folder = workspace:FindFirstChild("ApexNPCs")
	if folder then
		for _, npc in folder:GetChildren() do
			if npc:IsA("Model") and Kit.isAlive(npc) then
				table.insert(list, npc)
			end
		end
	end
	return list
end

local function excluded(character: Model, exclude: { Model }?): boolean
	if not exclude then
		return false
	end
	for _, other in exclude do
		if other == character then
			return true
		end
	end
	return false
end

-- Living characters whose root is within radius of center.
function Kit.inSphere(center: Vector3, radius: number, exclude: { Model }?): { Model }
	local result: { Model } = {}
	for _, character in Kit.allCharacters() do
		if not excluded(character, exclude) then
			local root = Kit.rootOf(character)
			if root and (root.Position - center).Magnitude <= radius then
				table.insert(result, character)
			end
		end
	end
	return result
end

-- Characters inside a cone (half-angle in degrees).
function Kit.inCone(origin: Vector3, direction: Vector3, range: number, halfAngle: number, exclude: { Model }?): { Model }
	local result: { Model } = {}
	local dir = if direction.Magnitude > 1e-3 then direction.Unit else Vector3.zAxis
	local cosLimit = math.cos(math.rad(halfAngle))
	for _, character in Kit.inSphere(origin, range, exclude) do
		local root = Kit.rootOf(character)
		if root then
			local offset = root.Position - origin
			if offset.Magnitude < 3 or offset.Unit:Dot(dir) >= cosLimit then
				table.insert(result, character)
			end
		end
	end
	return result
end

-- Characters touching an oriented box (spatial query, used by melee hitboxes).
function Kit.inBox(cframe: CFrame, size: Vector3, exclude: { Model }?): { Model }
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore: { Instance } = {}
	if exclude then
		for _, character in exclude do
			table.insert(ignore, character)
		end
	end
	params.FilterDescendantsInstances = ignore
	local found: { [Model]: boolean } = {}
	local result: { Model } = {}
	for _, part in workspace:GetPartBoundsInBox(cframe, size, params) do
		local character = Kit.characterFromPart(part)
		if character and not found[character] and Kit.isAlive(character) then
			found[character] = true
			table.insert(result, character)
		end
	end
	return result
end

-- Nearest character to a point among a list.
function Kit.nearest(characters: { Model }, point: Vector3): Model?
	local best: Model? = nil
	local bestDistance = math.huge
	for _, character in characters do
		local root = Kit.rootOf(character)
		if root then
			local distance = (root.Position - point).Magnitude
			if distance < bestDistance then
				best = character
				bestDistance = distance
			end
		end
	end
	return best
end

-- Best target near the aim ray (within maxAngle degrees and range).
function Kit.aimTarget(ctx: AbilityContext, range: number, maxAngle: number): Model?
	local dir = ctx.AimPoint - ctx.AimOrigin
	local candidates = Kit.inCone(ctx.AimOrigin, dir, range, maxAngle, { ctx.Character })
	local best: Model? = nil
	local bestScore = -math.huge
	local unit = if dir.Magnitude > 1e-3 then dir.Unit else ctx.Root.CFrame.LookVector
	for _, character in candidates do
		local root = Kit.rootOf(character)
		if root then
			local offset = root.Position - ctx.AimOrigin
			local score = offset.Unit:Dot(unit) * 2 - offset.Magnitude / range
			if score > bestScore then
				best = character
				bestScore = score
			end
		end
	end
	return best
end

--------------------------------------------------------------------------------
-- Raycasting that ignores characters and effects
--------------------------------------------------------------------------------
function Kit.worldParams(extraIgnore: { Instance }?): RaycastParams
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore: { Instance } = {}
	for _, character in Kit.allCharacters() do
		table.insert(ignore, character)
	end
	local fx = workspace:FindFirstChild("ApexServerEffects")
	if fx then
		table.insert(ignore, fx)
	end
	if extraIgnore then
		for _, instance in extraIgnore do
			table.insert(ignore, instance)
		end
	end
	params.FilterDescendantsInstances = ignore
	return params
end

function Kit.groundBelow(position: Vector3, depth: number?): RaycastResult?
	return workspace:Raycast(position + Vector3.new(0, 2, 0), Vector3.new(0, -(depth or 200), 0), Kit.worldParams())
end

-- Folder for server-side gameplay objects (projectiles, clones, walls).
function Kit.effectsFolder(): Folder
	local folder = workspace:FindFirstChild("ApexServerEffects")
	if not folder then
		local created = Instance.new("Folder")
		created.Name = "ApexServerEffects"
		created.Parent = workspace
		return created
	end
	return folder :: Folder
end

--------------------------------------------------------------------------------
-- Damage shortcuts
--------------------------------------------------------------------------------
function Kit.damage(ctx: AbilityContext, victim: Model, amount: number, extra: { [string]: any }?): number
	local info: DamageInfo = {
		Amount = amount,
		Attacker = ctx.Player,
		AttackerCharacter = ctx.Character,
		Kind = "AoE",
		Tag = ctx.Def.Name,
	}
	if extra then
		for key, value in extra do
			(info :: any)[key] = value
		end
	end
	if not info.Position then
		local root = Kit.rootOf(victim)
		info.Position = if root then root.Position else nil
	end
	return Hooks.applyDamage(victim, info)
end

-- Launch direction helper: away from a point, with lift.
function Kit.awayFrom(point: Vector3, victim: Model, speed: number, lift: number): Vector3
	local root = Kit.rootOf(victim)
	if not root then
		return Vector3.new(0, lift, 0)
	end
	local offset = root.Position - point
	local flat = Vector3.new(offset.X, 0, offset.Z)
	local dir = if flat.Magnitude > 1e-3 then flat.Unit else Vector3.xAxis
	return dir * speed + Vector3.new(0, lift, 0)
end

-- Read a tunable from BalanceConfig Params with a fallback.
function Kit.param(ctx: AbilityContext, key: string, default: number): number
	local params = ctx.Balance.Params
	local value = if params then params[key] else nil
	return if value then value else default
end

--------------------------------------------------------------------------------
-- Effects
--------------------------------------------------------------------------------
function Kit.fx(name: string, position: Vector3, payload: { [string]: any })
	NetService.fireNear("Effect", position, EFFECT_RADIUS, name, payload)
end

function Kit.pose(ctx: AbilityContext, actionName: string, options: { [string]: any }?)
	Kit.fx("Pose", ctx.Root.Position, {
		Source = ctx.Character,
		Action = actionName,
		Loop = options and options.Loop,
		Duration = options and options.Duration,
		Speed = options and options.Speed,
	})
end

function Kit.stopPose(ctx: AbilityContext)
	Kit.fx("Pose", ctx.Root.Position, { Source = ctx.Character, Action = "" })
end

function Kit.notify(ctx: AbilityContext, text: string)
	NetService.fireClient("Notify", ctx.Player, text)
end

--------------------------------------------------------------------------------
-- Impulses for the caster's own client (dashes, leaps)
--------------------------------------------------------------------------------
function Kit.impulseSelf(ctx: AbilityContext, velocity: Vector3, holdTime: number?)
	NetService.fireClient("Impulse", ctx.Player, "Self", velocity, holdTime)
end

--------------------------------------------------------------------------------
-- Server motion: temporarily take physics control of a character so the
-- server can move it precisely (grabs, blitz dashes). Always release.
--------------------------------------------------------------------------------
function Kit.takeControl(character: Model): boolean
	local root = Kit.rootOf(character)
	if not root then
		return false
	end
	StatusService.apply(character, "ServerMotion", "Flag", 30)
	local player = Players:GetPlayerFromCharacter(character)
	if player then
		NetService.fireClient("Impulse", player, "ServerMotion", Vector3.zero, nil)
	end
	pcall(function()
		root:SetNetworkOwner(nil)
	end)
	root.Anchored = true
	return true
end

function Kit.moveTo(character: Model, cframe: CFrame)
	local root = Kit.rootOf(character)
	if root then
		root.CFrame = cframe
	end
end

function Kit.releaseControl(character: Model, velocity: Vector3?)
	local root = Kit.rootOf(character)
	StatusService.remove(character, "ServerMotion")
	if not root or root.Parent == nil then
		return
	end
	root.Anchored = false
	if velocity then
		root.AssemblyLinearVelocity = velocity
	end
	local player = Players:GetPlayerFromCharacter(character)
	if player then
		pcall(function()
			root:SetNetworkOwner(player)
		end)
	else
		pcall(function()
			root:SetNetworkOwnershipAuto()
		end)
	end
end

-- Tween a server-controlled character from its current CFrame to `target`.
function Kit.glide(character: Model, target: CFrame, duration: number)
	local root = Kit.rootOf(character)
	if not root then
		return
	end
	local start = root.CFrame
	local elapsed = 0
	while elapsed < duration and root.Parent do
		elapsed += RunService.Heartbeat:Wait()
		local t = math.clamp(elapsed / duration, 0, 1)
		root.CFrame = start:Lerp(target, t * t * (3 - 2 * t))
	end
end

--------------------------------------------------------------------------------
-- Projectiles (server-simulated, spherecast each step)
--------------------------------------------------------------------------------
export type ProjectileOptions = {
	Origin: Vector3,
	Direction: Vector3,
	Speed: number,
	Range: number,
	Radius: number,
	Owner: Model,
	Gravity: number?,
	Homing: Model?, -- steer toward this character
	HomingStrength: number?, -- radians/second
	Light: boolean?, -- light projectile: reflected by Hardened characters
	ReflectDamage: number?,
	Visual: string?, -- effect name for clients ("Projectile" handler)
	VisualData: { [string]: any }?,
	OnHit: (hitPosition: Vector3, character: Model?, part: BasePart?) -> (),
}

local projectileId = 0

function Kit.projectile(options: ProjectileOptions)
	projectileId += 1
	local id = projectileId
	local position = options.Origin
	local velocity = options.Direction.Unit * options.Speed
	local travelled = 0
	local gravity = options.Gravity or 0

	if options.Visual then
		local data = table.clone(options.VisualData or {})
		data.Id = id
		data.Origin = position
		data.Velocity = velocity
		data.Gravity = gravity
		data.Kind = options.Visual
		data.Homing = options.Homing
		data.HomingStrength = options.HomingStrength
		data.Life = options.Range / options.Speed
		Kit.fx("Projectile", position, data)
	end

	local connection: RBXScriptConnection
	connection = RunService.Heartbeat:Connect(function(dt)
		if options.Homing and options.HomingStrength then
			local targetRoot = Kit.rootOf(options.Homing)
			if targetRoot and Kit.isAlive(options.Homing) then
				local desired = (targetRoot.Position - position)
				if desired.Magnitude > 1 then
					local current = velocity.Unit
					local wanted = desired.Unit
					local angle = math.acos(math.clamp(current:Dot(wanted), -1, 1))
					local maxTurn = options.HomingStrength * dt
					local t = if angle > 1e-3 then math.min(1, maxTurn / angle) else 1
					velocity = current:Lerp(wanted, t).Unit * velocity.Magnitude
				end
			end
		end
		velocity += Vector3.new(0, -gravity * dt, 0)
		local step = velocity * dt
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		local ignore: { Instance } = { options.Owner, Kit.effectsFolder() }
		local clientFx = workspace:FindFirstChild("ApexClientEffects")
		if clientFx then
			table.insert(ignore, clientFx)
		end
		params.FilterDescendantsInstances = ignore
		local hit = workspace:Spherecast(position, options.Radius, step, params)
		if hit then
			connection:Disconnect()
			local character = Kit.characterFromPart(hit.Instance)
			-- Hardened characters (Bastion) reflect light projectiles back.
			if character and options.Light and character:GetAttribute("ApexHardened") == true then
				Kit.fx("ProjectileEnd", hit.Position, { Id = id })
				local ownerRoot = Kit.rootOf(options.Owner)
				local reflector = character
				local reflectDamage = options.ReflectDamage or 40
				if ownerRoot then
					Kit.projectile({
						Origin = hit.Position,
						Direction = ownerRoot.Position - hit.Position,
						Speed = options.Speed,
						Range = options.Range,
						Radius = options.Radius,
						Owner = reflector,
						Visual = options.Visual,
						VisualData = options.VisualData,
						OnHit = function(_position, target, _part)
							if target then
								local reflectorPlayer = Players:GetPlayerFromCharacter(reflector)
								Hooks.applyDamage(target, {
									Amount = reflectDamage,
									Attacker = reflectorPlayer,
									AttackerCharacter = reflector,
									Kind = "Projectile",
									Tag = "Reflected",
								})
							end
						end,
					})
				end
				return
			end
			Kit.fx("ProjectileEnd", hit.Position, { Id = id })
			options.OnHit(hit.Position, character, if hit.Instance:IsA("BasePart") then hit.Instance else nil)
			return
		end
		position += step
		travelled += step.Magnitude
		if travelled >= options.Range then
			connection:Disconnect()
			Kit.fx("ProjectileEnd", position, { Id = id })
			options.OnHit(position, nil, nil)
		end
	end)
end

--------------------------------------------------------------------------------
-- Common area attack: damage + knockback everyone in a sphere, and hurt
-- structures. Returns the characters hit.
--------------------------------------------------------------------------------
function Kit.blast(ctx: AbilityContext, center: Vector3, radius: number, damage: number, knockback: number, lift: number, ragdoll: number?, structureDamage: number?): { Model }
	local hits = Kit.inSphere(center, radius, { ctx.Character })
	for _, victim in hits do
		Kit.damage(ctx, victim, damage, {
			Kind = "AoE",
			Position = center,
			Knockback = Kit.awayFrom(center, victim, knockback, lift),
			Ragdoll = ragdoll,
			HitStun = 0.5,
		})
	end
	if structureDamage and structureDamage > 0 then
		Hooks.structureDamageSphere(center, radius, structureDamage, knockback * 20, ctx.Character)
	end
	return hits
end

-- Blast with distance falloff: full damage inside innerRadius, scaling down
-- to minFraction at radius. Optional per-target cap table for multi-hit.
function Kit.falloffBlast(ctx: AbilityContext, center: Vector3, radius: number, innerRadius: number, damage: number, minFraction: number, knockback: number, lift: number, ragdoll: number?, extra: { [string]: any }?): { Model }
	local hits = Kit.inSphere(center, radius, { ctx.Character })
	for _, victim in hits do
		local root = Kit.rootOf(victim)
		if root then
			local distance = (root.Position - center).Magnitude
			local t = math.clamp((distance - innerRadius) / math.max(radius - innerRadius, 1), 0, 1)
			local fraction = 1 - (1 - minFraction) * t
			local info: { [string]: any } = {
				Kind = "AoE",
				Position = center,
				Knockback = Kit.awayFrom(center, victim, knockback * fraction, lift),
				Ragdoll = ragdoll,
				HitStun = 0.6,
			}
			if extra then
				for key, value in extra do
					info[key] = value
				end
			end
			Kit.damage(ctx, victim, damage * fraction, info)
		end
	end
	return hits
end

-- Pull characters toward a point (gravity wells). Strength = studs/second.
function Kit.pull(ctx: AbilityContext, center: Vector3, radius: number, strength: number)
	for _, victim in Kit.inSphere(center, radius, { ctx.Character }) do
		local root = Kit.rootOf(victim)
		if root then
			local offset = center - root.Position
			if offset.Magnitude > 2 then
				ReactionService.knockback(victim, offset.Unit * strength + Vector3.new(0, 4, 0), nil, ctx.Player, ctx.Character)
			end
		end
	end
	Hooks.pullDebris(center, radius, strength)
end

-- Temporary per-target damage budget (multi-tick abilities never exceed it).
function Kit.budget(total: number): (victim: Model, amount: number) -> number
	local spent: { [Model]: number } = {}
	return function(victim: Model, amount: number): number
		local used = spent[victim] or 0
		local allowed = math.max(0, math.min(amount, total - used))
		spent[victim] = used + allowed
		return allowed
	end
end

-- Anchored, non-colliding helper part in the server effects folder.
function Kit.serverPart(size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material, collide: boolean?): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = collide == true
	part.CanQuery = collide == true
	part.CanTouch = false
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material
	part.Parent = Kit.effectsFolder()
	return part
end

Kit.Status = StatusService
Kit.Reaction = ReactionService
Kit.Hooks = Hooks

return Kit
