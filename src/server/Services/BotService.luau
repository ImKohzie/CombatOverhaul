--!strict
-- AI rivals: costumed heroes that roam the city and fight players.
-- Server-side brain at 10 Hz per bot:
--   * picks a target by threat (who hurt it most) then distance; hunts
--     players first, only fights other rivals when no player is near
--   * chases, circle-strafes at mid range, closes with a dash that smashes
--     through buildings, and fires a ranged shot with velocity lead
--   * melee strings (parryable), heavy finishers, a telegraphed ground slam
--   * guards when an enemy is in its face, side-dashes after taking hits
--   * backs off and kites at low health; leashes back home
-- All numbers: BalanceConfig.Bots + GameConfig.Bots.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("ApexCity")
local BalanceConfig = require(Shared.Config.BalanceConfig)
local CharacterRegistry = require(Shared.CharacterRegistry)
local GameConfig = require(Shared.Config.GameConfig)

local AbilityKit = require(script.Parent.Parent.AbilityKit)
local Hooks = require(script.Parent.Parent.Hooks)
local CostumeService = require(script.Parent.CostumeService)
local DamageService = require(script.Parent.DamageService)
local NetService = require(script.Parent.NetService)
local NPCService = require(script.Parent.NPCService)
local StatusService = require(script.Parent.StatusService)

local TICK = 0.1
local EFFECT_RADIUS = 500

type Brain = {
	model: Model,
	humanoid: Humanoid,
	root: BasePart,
	heroId: string,
	glow: Color3,
	home: Vector3,
	target: Model?,
	threat: { [Model]: number },
	busyUntil: number,
	nextShot: number,
	nextSlam: number,
	nextDash: number,
	nextBlockCheck: number,
	blockingUntil: number,
	strafeSign: number,
	nextStrafeFlip: number,
	lastPosition: Vector3,
	stuckTime: number,
	baseSpeed: number,
}

local BotService = {}

local brains: { [Model]: Brain } = {}
local profile: BalanceConfig.BotProfile

local function now(): number
	return os.clock()
end

local function alive(model: Model): boolean
	return AbilityKit.isAlive(model)
end

local function flat(v: Vector3): Vector3
	local f = Vector3.new(v.X, 0, v.Z)
	return if f.Magnitude > 1e-3 then f.Unit else Vector3.zAxis
end

local function spawnAnchor(): Vector3
	local spawn = workspace:FindFirstChildOfClass("SpawnLocation")
	return if spawn then spawn.Position else Vector3.new(0, 5, 0)
end

local function groundAt(position: Vector3): Vector3?
	local hit = workspace:Raycast(position + Vector3.new(0, 150, 0), Vector3.new(0, -400, 0), AbilityKit.worldParams())
	return if hit and hit.Normal.Y > 0.6 then hit.Position else nil
end

local function isStunned(model: Model): boolean
	return StatusService.isStunned(model) or model:GetAttribute("ApexRagdoll") == true
end

local function face(brain: Brain, point: Vector3)
	local dir = flat(point - brain.root.Position)
	brain.root.CFrame = CFrame.lookAt(brain.root.Position, brain.root.Position + dir)
end

local function effect(position: Vector3, name: string, payload: { [string]: any })
	NetService.fireNear("Effect", position, EFFECT_RADIUS, name, payload)
end

local function swing(brain: Brain, action: string, speed: number?)
	effect(brain.root.Position, "Swing", { Source = brain.model, Action = action, Speed = speed })
end

local function damageScale(): number
	return profile.DamageScale
end

--------------------------------------------------------------------------------
-- Targeting
--------------------------------------------------------------------------------
local function candidates(brain: Brain): { Model }
	local list: { Model } = {}
	local config = GameConfig.Bots
	local playerNear = false
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and AbilityKit.rootOf(character)
		if character and root and alive(character) and character:GetAttribute("ApexInvisible") ~= true then
			if (root.Position - brain.root.Position).Magnitude <= config.AggroRange then
				table.insert(list, character)
				playerNear = true
			end
		end
	end
	if not playerNear then
		for other in brains do
			local root = AbilityKit.rootOf(other)
			if other ~= brain.model and root and alive(other) and (root.Position - brain.root.Position).Magnitude <= config.BotVsBotRange then
				table.insert(list, other)
			end
		end
	end
	-- Anyone who recently hurt us is always a valid target (revenge)
	for attacker, amount in brain.threat do
		if amount > 0 and alive(attacker) and not table.find(list, attacker) and attacker:GetAttribute("ApexInvisible") ~= true then
			table.insert(list, attacker)
		end
	end
	return list
end

local function pickTarget(brain: Brain): Model?
	local best: Model? = nil
	local bestScore = -math.huge
	for _, model in candidates(brain) do
		local root = AbilityKit.rootOf(model)
		if root then
			local distance = (root.Position - brain.root.Position).Magnitude
			local threat = brain.threat[model] or 0
			local hp = model:FindFirstChildOfClass("Humanoid")
			local weak = if hp then 1 - hp.Health / math.max(hp.MaxHealth, 1) else 0
			-- close, dangerous and weakened targets first; sticky on the current one
			local score = threat * 0.6 - distance + weak * 40 + (if model == brain.target then 25 else 0)
			if score > bestScore then
				best = model
				bestScore = score
			end
		end
	end
	return best
end

--------------------------------------------------------------------------------
-- Actions
--------------------------------------------------------------------------------
local function meleeHit(brain: Brain, timing: BalanceConfig.AttackTiming, damage: number, kind: "Melee" | "Heavy", tag: string)
	if not alive(brain.model) or isStunned(brain.model) then
		return
	end
	local melee = BalanceConfig.Melee
	local cframe = brain.root.CFrame * CFrame.new(0, 0, -melee.HitboxSize.Z / 2 + 0.5)
	for _, victim in AbilityKit.inBox(cframe, melee.HitboxSize, { brain.model }) do
		local victimRoot = AbilityKit.rootOf(victim)
		if victimRoot and (victimRoot.Position - brain.root.Position).Magnitude <= melee.MaxServerReach then
			local forward = flat(brain.root.CFrame.LookVector)
			DamageService.apply(victim, {
				Amount = damage * damageScale(),
				AttackerCharacter = brain.model,
				Kind = kind,
				Position = victimRoot.Position:Lerp(brain.root.Position, 0.35) + Vector3.new(0, 0.5, 0),
				Knockback = forward * timing.Knockback + Vector3.new(0, timing.Lift or 0, 0),
				Ragdoll = timing.Ragdoll,
				HitStun = timing.HitStun,
				CanParry = true,
				Tag = tag,
			})
		end
	end
end

-- A string of light hits, sometimes ending in a heavy.
local function combo(brain: Brain)
	local melee = BalanceConfig.Melee
	local length = math.clamp(math.floor(profile.ComboLength + math.random(-1, 0) + 0.5), 1, #melee.ComboSteps)
	local heavyFinish = math.random() < 0.3
	local t = 0
	for i = 1, length do
		local timing = melee.ComboSteps[i]
		task.delay(t, function()
			if alive(brain.model) and not isStunned(brain.model) then
				if brain.target then
					local targetRoot = AbilityKit.rootOf(brain.target)
					if targetRoot then
						face(brain, targetRoot.Position)
					end
				end
				swing(brain, "Combo" .. i)
				local damage = melee.ComboDamage[i]
				task.delay(timing.WindUp, function()
					meleeHit(brain, timing, damage, "Melee", "Combo")
				end)
			end
		end)
		t += timing.WindUp + timing.Active + timing.Recovery
	end
	if heavyFinish then
		local timing = melee.Heavy
		task.delay(t + 0.1, function()
			if alive(brain.model) and not isStunned(brain.model) then
				swing(brain, "Heavy")
				task.delay(timing.WindUp + melee.HeavyChargeTime * 0.5, function()
					meleeHit(brain, timing, melee.HeavyDamage, "Heavy", "Heavy")
				end)
			end
		end)
		t += 0.1 + timing.WindUp + melee.HeavyChargeTime * 0.5 + timing.Active + timing.Recovery
	end
	brain.busyUntil = now() + t
end

local function shoot(brain: Brain, target: Model)
	local targetRoot = AbilityKit.rootOf(target)
	if not targetRoot then
		return
	end
	local bots = BalanceConfig.Bots
	local origin = brain.root.Position + Vector3.new(0, 1.5, 0) + brain.root.CFrame.LookVector * 2
	local distance = (targetRoot.Position - origin).Magnitude
	local lead = targetRoot.AssemblyLinearVelocity * (distance / bots.ShotSpeed)
	local spread = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * profile.AimError * 2
	local aim = targetRoot.Position + lead + spread
	face(brain, aim)
	swing(brain, "CastRight")
	brain.busyUntil = now() + 0.35
	local glow = brain.glow
	local owner = brain.model
	task.delay(0.15, function()
		if not alive(owner) then
			return
		end
		AbilityKit.projectile({
			Origin = origin,
			Direction = aim - origin,
			Speed = bots.ShotSpeed,
			Range = bots.ShotRange,
			Radius = 1.3,
			Owner = owner,
			Light = true,
			ReflectDamage = 30,
			Visual = "Orb",
			VisualData = { Color = glow, Width = 1.3 },
			OnHit = function(position, character)
				if character then
					DamageService.apply(character, {
						Amount = bots.ShotDamage * damageScale(),
						AttackerCharacter = owner,
						Kind = "Projectile",
						Position = position,
						Knockback = flat(aim - origin) * 35 + Vector3.new(0, 12, 0),
						HitStun = 0.4,
						Tag = "Rival Shot",
					})
				end
				Hooks.structureDamageSphere(position, 4, 150, 1500, owner)
				effect(position, "Explosion", { Position = position, Radius = 4, Kind = "Electric", Color = glow })
			end,
		})
	end)
end

-- Telegraphed ground slam: players get ~0.55s to dodge or block.
local function slam(brain: Brain)
	local bots = BalanceConfig.Bots
	brain.busyUntil = now() + 1.1
	swing(brain, "Slam", 0.8)
	effect(brain.root.Position, "ChargeAura", { Source = brain.model, Color = brain.glow, Duration = 0.55 })
	task.delay(0.55, function()
		if not alive(brain.model) or isStunned(brain.model) then
			return
		end
		local center = brain.root.Position
		for _, victim in AbilityKit.inSphere(center, bots.SlamRadius, { brain.model }) do
			DamageService.apply(victim, {
				Amount = bots.SlamDamage * damageScale(),
				AttackerCharacter = brain.model,
				Kind = "AoE",
				Position = center,
				Knockback = AbilityKit.awayFrom(center, victim, 70, 45),
				Ragdoll = 0.8,
				HitStun = 0.7,
				Tag = "Rival Slam",
			})
		end
		Hooks.structureDamageSphere(center, bots.SlamRadius * 0.6, 300, 3500, brain.model)
		effect(center, "Stomp", { Position = center, Radius = bots.SlamRadius })
		effect(center, "TraversalImpact", { Kind = "Blast", Position = center, Direction = Vector3.yAxis, Color = brain.glow, Source = brain.model, Strength = 0.8 })
	end)
end

-- Burst toward (or away from / beside) a point; smashes through walls.
local function dash(brain: Brain, direction: Vector3, hitEnemies: boolean)
	local bots = BalanceConfig.Bots
	local attachment = brain.root:FindFirstChild("RootAttachment")
	if not attachment or not attachment:IsA("Attachment") then
		return
	end
	local dir = flat(direction)
	brain.busyUntil = now() + bots.DashTime + 0.1
	face(brain, brain.root.Position + dir)
	local linear = Instance.new("LinearVelocity")
	linear.Attachment0 = attachment
	linear.RelativeTo = Enum.ActuatorRelativeTo.World
	linear.ForceLimitMode = Enum.ForceLimitMode.PerAxis
	linear.MaxAxesForce = Vector3.new(1e7, 0, 1e7)
	linear.VectorVelocity = dir * bots.DashSpeed
	linear.Parent = brain.root
	effect(brain.root.Position, "SonicBoom", { Position = brain.root.Position, Direction = dir, Color = brain.glow })
	effect(brain.root.Position, "TraversalImpact", { Kind = "Start", Position = brain.root.Position, Direction = dir, Color = brain.glow, Source = brain.model, Strength = 0.6 })
	local hit: { [Model]: boolean } = {}
	local elapsed = 0
	local connection: RBXScriptConnection
	connection = RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if not brain.root.Parent or elapsed >= bots.DashTime then
			connection:Disconnect()
			linear:Destroy()
			return
		end
		local position = brain.root.Position
		Hooks.structureDamageSphere(position + dir * 4, 5, 350, 3000, brain.model)
		if hitEnemies then
			for _, victim in AbilityKit.inBox(brain.root.CFrame, Vector3.new(7, 7, 7), { brain.model }) do
				if not hit[victim] then
					hit[victim] = true
					local victimRoot = AbilityKit.rootOf(victim)
					DamageService.apply(victim, {
						Amount = bots.DashHitDamage * damageScale(),
						AttackerCharacter = brain.model,
						Kind = "Melee",
						CanParry = false,
						Position = position,
						Knockback = dir * 50 + Vector3.new(0, 25, 0),
						HitStun = 0.4,
						Tag = "Rival Dash",
					})
					effect(position, "TraversalImpact", { Kind = "Hit", Position = if victimRoot then victimRoot.Position else position, Direction = dir, Color = brain.glow, Source = brain.model, Target = victim, Strength = 0.7 })
				end
			end
		end
	end)
end

local function block(brain: Brain, duration: number)
	DamageService.setBlocking(brain.model, true)
	brain.blockingUntil = now() + duration
	brain.busyUntil = math.max(brain.busyUntil, now() + duration)
	swing(brain, "Block")
end

--------------------------------------------------------------------------------
-- Brain
--------------------------------------------------------------------------------
local function hasLineOfSight(brain: Brain, point: Vector3): boolean
	local origin = brain.root.Position + Vector3.new(0, 1.5, 0)
	local hit = workspace:Raycast(origin, point - origin, AbilityKit.worldParams())
	return hit == nil
end

local function moveTo(brain: Brain, point: Vector3)
	brain.humanoid:MoveTo(point)
	-- hop over low obstacles in the way
	local dir = flat(point - brain.root.Position)
	local knee = brain.root.Position - Vector3.new(0, 1.5, 0)
	if workspace:Raycast(knee, dir * 4, AbilityKit.worldParams()) then
		brain.humanoid.Jump = true
	end
end

local function think(brain: Brain, dt: number)
	local t = now()
	local bots = BalanceConfig.Bots
	-- decay threat
	for attacker, amount in brain.threat do
		local left = amount - bots.ThreatDecayPerSecond * dt
		if left > 0 and attacker.Parent then
			brain.threat[attacker] = left
		else
			brain.threat[attacker] = nil
		end
	end
	if t >= brain.blockingUntil and DamageService.isBlocking(brain.model) then
		DamageService.setBlocking(brain.model, false)
	end
	if isStunned(brain.model) or t < brain.busyUntil then
		return
	end

	-- Stuck detection: try jumping, then a side-dash out
	local moved = (brain.root.Position - brain.lastPosition).Magnitude
	brain.lastPosition = brain.root.Position
	if brain.humanoid.MoveDirection.Magnitude > 0.1 and moved < 0.3 then
		brain.stuckTime += dt
		if brain.stuckTime > 0.6 then
			brain.humanoid.Jump = true
		end
		if brain.stuckTime > 1.5 and t >= brain.nextDash then
			brain.nextDash = t + profile.DashCooldown
			brain.stuckTime = 0
			dash(brain, brain.root.CFrame.LookVector, false) -- smash through
			return
		end
	else
		brain.stuckTime = 0
	end

	-- Leash home
	if (brain.root.Position - brain.home).Magnitude > GameConfig.Bots.LeashRange then
		brain.target = nil
		moveTo(brain, brain.home)
		return
	end

	local target = pickTarget(brain)
	brain.target = target
	local targetRoot = target and AbilityKit.rootOf(target)
	if not target or not targetRoot then
		-- Wander around home
		if brain.humanoid.MoveDirection.Magnitude < 0.1 and math.random() < 0.05 then
			local angle = math.random() * math.pi * 2
			local spot = brain.home + Vector3.new(math.cos(angle), 0, math.sin(angle)) * math.random(10, 60)
			moveTo(brain, spot)
		end
		return
	end

	local offset = targetRoot.Position - brain.root.Position
	local distance = offset.Magnitude
	local height = offset.Y
	local lowHealth = brain.humanoid.Health / math.max(brain.humanoid.MaxHealth, 1) < bots.RetreatHealth
	local canSee = hasLineOfSight(brain, targetRoot.Position)

	-- Guard when an enemy is right in our face and attacking range
	if distance < bots.MeleeRange + 2 and t >= brain.nextBlockCheck then
		brain.nextBlockCheck = t + 0.8
		if math.random() < profile.BlockChance * 0.5 then
			face(brain, targetRoot.Position)
			block(brain, 0.5 + math.random() * 0.4)
			return
		end
	end

	-- Low health: kite away and shoot
	if lowHealth and distance < 60 then
		local away = flat(-offset)
		local side = flat(Vector3.yAxis:Cross(offset)) * brain.strafeSign
		moveTo(brain, brain.root.Position + (away + side * 0.5).Unit * 20)
		if canSee and t >= brain.nextShot then
			brain.nextShot = t + profile.ShotCooldown
			shoot(brain, target)
		elseif t >= brain.nextDash and distance < 15 then
			brain.nextDash = t + profile.DashCooldown
			dash(brain, away, false)
		end
		return
	end

	-- Target out of reach vertically (flying / on a roof): shoot or reposition
	if height > 18 then
		if canSee and t >= brain.nextShot and distance < bots.ShotRange then
			brain.nextShot = t + profile.ShotCooldown * 0.6
			shoot(brain, target)
		else
			moveTo(brain, targetRoot.Position - flat(offset) * 20)
		end
		return
	end

	-- Melee range: slam if crowded, otherwise combo
	if distance <= bots.MeleeRange then
		face(brain, targetRoot.Position)
		local crowd = #AbilityKit.inSphere(brain.root.Position, bots.SlamRadius, { brain.model })
		if t >= brain.nextSlam and (crowd >= 2 or math.random() < 0.25) then
			brain.nextSlam = t + profile.SlamCooldown
			slam(brain)
		else
			combo(brain)
		end
		return
	end

	-- Mid range: strafe, shoot, or dash in
	if distance <= bots.StrafeRange then
		if t >= brain.nextStrafeFlip then
			brain.nextStrafeFlip = t + 1 + math.random() * 1.5
			brain.strafeSign = if math.random() < 0.5 then -1 else 1
		end
		local side = flat(Vector3.yAxis:Cross(offset)) * brain.strafeSign
		moveTo(brain, targetRoot.Position - flat(offset) * (bots.MeleeRange - 1) + side * 6)
		if t >= brain.nextDash and math.random() < 0.3 then
			brain.nextDash = t + profile.DashCooldown
			dash(brain, offset, true)
		end
		return
	end

	-- Long range: chase, shoot when in sight, gap-close with a dash
	moveTo(brain, targetRoot.Position)
	if canSee and t >= brain.nextShot and distance < bots.ShotRange then
		brain.nextShot = t + profile.ShotCooldown
		shoot(brain, target)
	elseif t >= brain.nextDash and distance < 120 then
		brain.nextDash = t + profile.DashCooldown
		dash(brain, offset, true)
	end
end

-- React to damage: remember the threat, maybe dodge
local function onDamaged(victim: Model, info: any, dealt: number, _result: string)
	local brain = brains[victim]
	if not brain then
		return
	end
	local attacker = info.AttackerCharacter
	if typeof(attacker) == "Instance" and attacker:IsA("Model") and attacker ~= victim then
		brain.threat[attacker] = (brain.threat[attacker] or 0) + dealt
	end
	if dealt > 0 and math.random() < profile.DodgeChance then
		task.delay(profile.Reaction, function()
			if alive(victim) and not isStunned(victim) and now() >= brain.nextDash then
				brain.nextDash = now() + profile.DashCooldown
				local side = brain.root.CFrame.RightVector * (if math.random() < 0.5 then -1 else 1)
				dash(brain, side, false)
			end
		end)
	end
end

--------------------------------------------------------------------------------
-- Spawning
--------------------------------------------------------------------------------
local function heroPool(): { string }
	local pool: { string } = {}
	for _, config in CharacterRegistry.list(false) do
		table.insert(pool, config.Id)
	end
	return pool
end

local function spawnBot()
	local pool = heroPool()
	if #pool == 0 then
		return
	end
	local heroId = pool[math.random(1, #pool)]
	local config = CharacterRegistry.get(heroId)
	if not config then
		return
	end
	local role = BalanceConfig.Roles[config.Role]
	local model = NPCService.createRig("Rival " .. config.DisplayName, nil)
	if not model then
		return
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or not root:IsA("BasePart") then
		model:Destroy()
		return
	end
	local anchor = spawnAnchor()
	local home = anchor
	for _ = 1, 10 do
		local angle = math.random() * math.pi * 2
		local distance = math.random(40, GameConfig.Bots.SpawnRadius)
		local ground = groundAt(anchor + Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance))
		if ground then
			home = ground
			break
		end
	end
	humanoid.MaxHealth = role.Health
	humanoid.Health = role.Health
	humanoid.WalkSpeed = role.WalkSpeed * BalanceConfig.Bots.ChaseSpeedMultiplier
	humanoid.JumpPower = BalanceConfig.Movement.JumpPower
	humanoid.BreakJointsOnDeath = false
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.DisplayWhenDamaged
	humanoid.NameDisplayDistance = 80
	model:SetAttribute("ApexNPC", true)
	model:SetAttribute("ApexBot", true)
	model:SetAttribute("ApexCharacter", heroId)
	model:SetAttribute("ApexRole", config.Role)
	model:SetAttribute("ApexDamageReduction", role.DamageReduction)
	CostumeService.apply(model, heroId)
	model:PivotTo(CFrame.new(home + Vector3.new(0, 4, 0)))
	model.Parent = NPCService.folder()
	pcall(function()
		root:SetNetworkOwner(nil)
	end)
	DamageService.watch(model)

	local brain: Brain = {
		model = model,
		humanoid = humanoid,
		root = root,
		heroId = heroId,
		glow = config.Palette.Glow,
		home = home,
		target = nil,
		threat = {},
		busyUntil = 0,
		nextShot = now() + 2,
		nextSlam = now() + 4,
		nextDash = now() + 2,
		nextBlockCheck = 0,
		blockingUntil = 0,
		strafeSign = 1,
		nextStrafeFlip = 0,
		lastPosition = root.Position,
		stuckTime = 0,
		baseSpeed = humanoid.WalkSpeed,
	}
	brains[model] = brain
	effect(home, "TraversalImpact", { Kind = "Blast", Position = home, Direction = Vector3.yAxis, Color = config.Palette.Glow, Source = model, Strength = 0.6 })

	-- Death: clear the body after the respawn delay. The manager loop (not
	-- this callback) decides when a replacement spawns, so bots can't pile up.
	humanoid.Died:Connect(function()
		brains[model] = nil
		task.delay(GameConfig.Bots.RespawnTime, function()
			if model.Parent then
				model:Destroy()
			end
		end)
	end)
end

-- Every rival currently in the world (alive or not), from ANY copy of this
-- script - the cap is enforced on what actually exists.
local function worldBots(): ({ Model }, number)
	local list: { Model } = {}
	local living = 0
	for _, child in NPCService.folder():GetChildren() do
		if child:IsA("Model") and child:GetAttribute("ApexBot") == true then
			table.insert(list, child)
			if alive(child) then
				living += 1
			end
		end
	end
	return list, living
end

-- Keeps the living rival count at GameConfig.Bots.Count, never above
-- GameConfig.Bots.MaxAlive. Also removes bots that fell out of the map or
-- lost their parts.
local function manage()
	local config = GameConfig.Bots
	local target = math.min(config.Count, config.MaxAlive)
	local nextSpawnAt = 0
	while true do
		task.wait(1)
		local list, living = worldBots()
		for _, model in list do
			local root = AbilityKit.rootOf(model)
			if alive(model) and (not root or root.Position.Y < workspace.FallenPartsDestroyHeight + 50) then
				brains[model] = nil
				model:Destroy()
				living -= 1
			end
		end
		-- Over the cap (e.g. duplicated scripts): remove the extras
		if living > config.MaxAlive then
			local extra = living - config.MaxAlive
			for _, model in list do
				if extra <= 0 then
					break
				end
				if model.Parent and alive(model) then
					brains[model] = nil
					model:Destroy()
					extra -= 1
				end
			end
			living = config.MaxAlive
		end
		-- Under target: spawn one at a time, respecting the respawn delay
		if living < target and os.clock() >= nextSpawnAt and #list < config.MaxAlive + 4 then
			local ok, err = (pcall :: any)(spawnBot)
			if not ok then
				warn("[BotService] spawn failed: " .. tostring(err))
			end
			nextSpawnAt = os.clock() + (if living + 1 < target and #list <= living then 0.5 else config.RespawnTime)
		end
	end
end

function BotService.brains(): { [Model]: any }
	return brains
end

function BotService.init()
	local config = GameConfig.Bots
	profile = BalanceConfig.Bots.Profiles[config.Difficulty] or BalanceConfig.Bots.Profiles.Normal
	if not config.Enabled then
		return
	end
	DamageService.Damaged:Connect(onDamaged)
	-- Only one spawner per server, even if the scripts were imported twice
	if workspace:GetAttribute("ApexBotSpawner") == true then
		warn("[BotService] another copy is already spawning rivals - is ApexCity imported twice?")
		return
	end
	workspace:SetAttribute("ApexBotSpawner", true)
	task.spawn(function()
		local waited = 0
		while workspace:GetAttribute("ApexWorldReady") ~= true and waited < 120 do
			waited += task.wait(0.5)
		end
		manage()
	end)
	-- One loop drives every brain; each thinks at TICK rate.
	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator < TICK then
			return
		end
		local step = accumulator
		accumulator = 0
		for _, brain in brains do
			if brain.root.Parent and alive(brain.model) then
				local ok, err = (pcall :: any)(think, brain, step)
				if not ok then
					warn("[BotService] " .. tostring(err))
				end
			end
		end
	end)
end

return BotService
