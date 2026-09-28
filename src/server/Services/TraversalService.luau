--!strict
-- Server side of every character's F movement. The client moves itself
-- instantly (it owns its physics); the server validates cooldown / stamina /
-- state, then drives the world interaction along the path:
--   Smash   - breaks structures ahead of the mover
--   Phase   - cracks what the mover passes through
--   Shatter - blows out glass around the path
--   IceTrail- leaves a temporary ice ramp
--   hits    - enemies in the way are knocked aside (once each)
--   loose debris gets flung, and some moves end in a blast.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local Shared = ReplicatedStorage:WaitForChild("ApexCity")
local BalanceConfig = require(Shared.Config.BalanceConfig)

local AbilityKit = require(script.Parent.Parent.AbilityKit)
local Hooks = require(script.Parent.Parent.Hooks)
local DamageService = require(script.Parent.DamageService)
local MovementService = require(script.Parent.MovementService)
local NetService = require(script.Parent.NetService)
local PlayerStateService = require(script.Parent.PlayerStateService)
local StatusService = require(script.Parent.StatusService)

local TICK = 0.05

local TraversalService = {}

local busyUntil: { [Player]: number } = {}

local function configFor(player: Player): BalanceConfig.Traversal?
	local state = PlayerStateService.get(player)
	return if state then (BalanceConfig.Traversal :: any)[state.CharacterId] else nil
end

local function glowFor(character: Model): Color3
	local id = character:GetAttribute("ApexCharacter")
	local registry = require(Shared.CharacterRegistry)
	local config = if type(id) == "string" then registry.get(id) else nil
	return if config then config.Palette.Glow else Color3.new(1, 1, 1)
end

local function run(player: Player, character: Model, root: BasePart, move: BalanceConfig.Traversal)
	local hit: { [Model]: boolean } = {}
	local elapsed = 0
	local accumulator = TICK
	local total = move.Duration + 0.15
	while elapsed < total and root.Parent and AbilityKit.isAlive(character) do
		local dt = RunService.Heartbeat:Wait()
		elapsed += dt
		accumulator += dt
		if accumulator < TICK then
			continue
		end
		accumulator = 0
		local velocity = root.AssemblyLinearVelocity
		local dir = if velocity.Magnitude > 5 then velocity.Unit else root.CFrame.LookVector
		local position = root.Position
		if move.Smash then
			Hooks.structureDamageSphere(position + dir * 4, 7, 650, 4500, character)
		end
		if move.Phase then
			Hooks.structureDamageSphere(position, 4.5, 30, 0, character)
		end
		if move.Shatter then
			Hooks.shatterGlassCone(position, dir, 30, 75, character)
		end
		-- Fling loose debris out of the way
		Hooks.pullDebris(position, 10, -70)
		if move.IceTrail then
			local feet = position - Vector3.new(0, root.Size.Y / 2 + 3.2, 0)
			local ice = AbilityKit.serverPart(Vector3.new(7, 0.6, 9), CFrame.lookAt(feet, feet + Vector3.new(dir.X, 0, dir.Z)), Color3.fromRGB(190, 235, 255), Enum.Material.Ice, true)
			ice.Name = "ApexIceRoad"
			ice.Transparency = 0.25
			Debris:AddItem(ice, 4)
		end
		if move.HitDamage > 0 then
			for _, victim in AbilityKit.inBox(root.CFrame, Vector3.new(8, 8, 8), { character }) do
				if not hit[victim] then
					hit[victim] = true
					local side = if math.random() < 0.5 then -1 else 1
					DamageService.apply(victim, {
						Amount = move.HitDamage,
						Attacker = player,
						AttackerCharacter = character,
						Kind = "Melee",
						CanParry = false,
						Position = position,
						Knockback = dir * 50 + root.CFrame.RightVector * side * 35 + Vector3.new(0, 25, 0),
						HitStun = 0.4,
						Tag = move.Name,
					})
					local victimRoot = AbilityKit.rootOf(victim)
					NetService.fireNear("Effect", position, 500, "TraversalImpact", {
						Kind = "Hit",
						Position = if victimRoot then victimRoot.Position else position,
						Direction = dir,
						Color = glowFor(character),
						Source = character,
						Target = victim,
						Strength = math.clamp(move.HitDamage / 40, 0.3, 1),
					})
				end
			end
		end
	end
	if move.EndBlast and root.Parent and AbilityKit.isAlive(character) then
		local ground = AbilityKit.groundBelow(root.Position, 30)
		local center = if ground then ground.Position else root.Position
		for _, victim in AbilityKit.inSphere(center, move.EndBlast, { character }) do
			if not hit[victim] then
				DamageService.apply(victim, {
					Amount = move.HitDamage,
					Attacker = player,
					AttackerCharacter = character,
					Kind = "AoE",
					Position = center,
					Knockback = AbilityKit.awayFrom(center, victim, 60, 40),
					HitStun = 0.5,
					Tag = move.Name,
				})
			end
		end
		Hooks.structureDamageSphere(center, move.EndBlast, 350, 3500, character)
		NetService.fireNear("Effect", center, 500, "TraversalImpact", { Kind = "Blast", Position = center, Direction = Vector3.yAxis, Color = glowFor(character), Source = character, Strength = 1 })
		NetService.fireNear("Effect", center, 500, "Crater", { Position = center, Strength = 0.7, Source = character, Color = glowFor(character) })
	end
end

local function onMovement(player: Player, aimPoint: Vector3?)
	local move = configFor(player)
	local character = player.Character
	local root = character and AbilityKit.rootOf(character)
	if not move or not character or not root or not AbilityKit.isAlive(character) then
		return
	end
	if StatusService.isStunned(character) or character:GetAttribute("ApexServerMotion") == true then
		return
	end
	local now = os.clock()
	if now < (busyUntil[player] or 0) or not PlayerStateService.isReady(player, "Movement") then
		return
	end
	if not PlayerStateService.consumeStamina(player, move.Stamina) then
		return
	end
	if aimPoint and (aimPoint - root.Position).Magnitude > 2000 then
		NetService.strike(player, "movement aim out of range")
		return
	end
	busyUntil[player] = now + move.Duration
	PlayerStateService.startCooldown(player, "Movement", move.Cooldown)
	MovementService.exempt(player, move.Duration + 1.5)
	if move.Phase then
		StatusService.apply(character, "Phasing", "Flag", move.Duration + 0.1)
	end
	if move.Unstoppable then
		StatusService.apply(character, "Unstoppable", "Flag", move.Duration + 0.1)
	end
	if move.Invisible then
		StatusService.apply(character, "Invisible", "Flag", move.Duration + 0.15)
	end
	NetService.fireNearExcept("Effect", root.Position, 600, player, "SonicBoom", {
		Position = root.Position,
		Direction = if aimPoint and (aimPoint - root.Position).Magnitude > 1 then (aimPoint - root.Position).Unit else root.CFrame.LookVector,
		Color = glowFor(character),
	})
	task.spawn(run, player, character, root, move)
end

function TraversalService.handle(player: Player, aimPoint: Vector3?)
	onMovement(player, aimPoint)
end

function TraversalService.init()
	Players.PlayerRemoving:Connect(function(player)
		busyUntil[player] = nil
	end)
end

return TraversalService
