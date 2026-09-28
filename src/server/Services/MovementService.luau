--!strict
-- Server authority for movement:
--   * validates flight (only Flight/Board/Glider characters, not stunned or
--     grounded) and replicates ApexFlying / ApexServerFlying
--   * drains stamina for sprint and boost, charges dash cost
--   * builds the Argent board / Nightwing glider so everyone sees them
--   * relays cosmetic sonic booms and landing craters to nearby players
--   * speed sanity check (logs + strikes; never rubber-bands legit players)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("ApexCity")
local BalanceConfig = require(Shared.Config.BalanceConfig)
local CharacterRegistry = require(Shared.CharacterRegistry)
local Types = require(Shared.Types)
local Validate = require(Shared.Net.Validate)

local NetService = require(script.Parent.NetService)
local PlayerStateService = require(script.Parent.PlayerStateService)

local EFFECT_RADIUS = 600
local SPEED_SAMPLE_INTERVAL = 0.5
local SPEED_EXEMPT_AFTER_DASH = 0.6
local SPEED_STRIKE_AFTER = 3 -- consecutive violations before a strike
local LAND_GRACE = 1.5 -- a Land report is accepted this long after flight ends
local GRAVITY_FALL_ALLOWANCE = 250 -- falling can legitimately be fast

type MoveState = {
	sprinting: boolean,
	boosting: boolean,
	flying: boolean,
	flightEndedAt: number,
	lastDash: number,
	exemptUntil: number,
	lastPosition: Vector3?,
	lastSample: number,
	violations: number,
	mount: Model?,
}

local MovementService = {}

local states: { [Player]: MoveState } = {}

local function newState(): MoveState
	return {
		sprinting = false,
		boosting = false,
		flying = false,
		flightEndedAt = -math.huge,
		lastDash = -math.huge,
		exemptUntil = 0,
		lastPosition = nil,
		lastSample = 0,
		violations = 0,
		mount = nil,
	}
end

local function getConfig(player: Player): Types.CharacterConfig?
	local state = PlayerStateService.get(player)
	return if state then CharacterRegistry.get(state.CharacterId) else nil
end

local function getRoot(player: Player): (Model?, BasePart?)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if character and root and root:IsA("BasePart") then
		return character, root
	end
	return character, nil
end

-- Exempt a player from speed checks (knockback, launches, teleports).
function MovementService.exempt(player: Player, duration: number)
	local state = states[player]
	if state then
		state.exemptUntil = math.max(state.exemptUntil, os.clock() + duration)
	end
end

--------------------------------------------------------------------------------
-- Mounts (board / glider), built from parts so no free models are needed
--------------------------------------------------------------------------------
local function mountPart(parent: Instance, size: Vector3, color: Color3, material: Enum.Material): Part
	local part = Instance.new("Part")
	part.Size = size
	part.Color = color
	part.Material = material
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.Anchored = false
	part.Parent = parent
	return part
end

local function weld(a: BasePart, b: BasePart)
	local w = Instance.new("WeldConstraint")
	w.Part0 = a
	w.Part1 = b
	w.Parent = a
end

local function buildMount(kind: string, config: Types.CharacterConfig, character: Model, root: BasePart): Model?
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return nil
	end
	local model = Instance.new("Model")
	model.Name = "ApexMount"
	local footY = -(root.Size.Y / 2 + humanoid.HipHeight) - 0.15
	local baseCF = root.CFrame * CFrame.new(0, footY, 0)
	local glow = config.Palette.Glow

	local deck: Part
	if kind == "Board" then
		deck = mountPart(model, Vector3.new(2.6, 0.3, 7.5), Color3.fromRGB(215, 220, 230), Enum.Material.Metal)
		deck.Reflectance = 0.55
		deck.CFrame = baseCF
		local nose = mountPart(model, Vector3.new(2.6, 0.3, 1.3), deck.Color, Enum.Material.Metal)
		nose.Reflectance = 0.55
		nose.Shape = Enum.PartType.Cylinder
		nose.Size = Vector3.new(0.3, 2.6, 2.6)
		nose.CFrame = baseCF * CFrame.new(0, 0, -3.75) * CFrame.Angles(0, 0, math.rad(90))
		weld(deck, nose)
		local stripe = mountPart(model, Vector3.new(0.25, 0.32, 6.8), glow, Enum.Material.Neon)
		stripe.CFrame = baseCF
		weld(deck, stripe)
		-- Cosmic light trail from the tail
		local a0 = Instance.new("Attachment")
		a0.Position = Vector3.new(-1.1, 0, 3.6)
		a0.Parent = deck
		local a1 = Instance.new("Attachment")
		a1.Position = Vector3.new(1.1, 0, 3.6)
		a1.Parent = deck
		local trail = Instance.new("Trail")
		trail.Attachment0 = a0
		trail.Attachment1 = a1
		trail.Color = ColorSequence.new(Color3.new(1, 1, 1), glow)
		trail.LightEmission = 1
		trail.Lifetime = 0.6
		trail.Transparency = NumberSequence.new(0.2, 1)
		trail.Parent = deck
	else -- Glider
		deck = mountPart(model, Vector3.new(1.6, 0.45, 3.8), Color3.fromRGB(18, 18, 22), Enum.Material.SmoothPlastic)
		deck.CFrame = baseCF
		for side = -1, 1, 2 do
			local wing = mountPart(model, Vector3.new(4.2, 0.2, 2.2), Color3.fromRGB(25, 25, 30), Enum.Material.Metal)
			wing.CFrame = baseCF * CFrame.new(side * 2.8, 0.25, 0.4) * CFrame.Angles(0, math.rad(side * -18), math.rad(side * 10))
			weld(deck, wing)
			local edge = mountPart(model, Vector3.new(4.2, 0.22, 0.2), glow, Enum.Material.Neon)
			edge.CFrame = wing.CFrame * CFrame.new(0, 0, -1.1)
			weld(deck, edge)
		end
		-- Twin thrusters
		for side = -1, 1, 2 do
			local nozzle = Instance.new("Attachment")
			nozzle.Position = Vector3.new(side * 0.5, 0, 1.9)
			nozzle.Parent = deck
			local fire = Instance.new("ParticleEmitter")
			fire.Color = ColorSequence.new(Color3.fromRGB(255, 190, 90), glow)
			fire.LightEmission = 1
			fire.Size = NumberSequence.new(0.5, 0)
			fire.Lifetime = NumberRange.new(0.12, 0.2)
			fire.Speed = NumberRange.new(18, 24)
			fire.Rate = 120
			fire.EmissionDirection = Enum.NormalId.Back
			fire.SpreadAngle = Vector2.new(6, 6)
			fire.Parent = nozzle
			local light = Instance.new("PointLight")
			light.Color = glow
			light.Range = 6
			light.Brightness = 2
			light.Parent = nozzle
		end
	end

	weld(root, deck)
	model.PrimaryPart = deck
	model.Parent = character
	return model
end

--------------------------------------------------------------------------------
-- Requests
--------------------------------------------------------------------------------
local function setFlying(player: Player, state: MoveState, value: boolean)
	local character, root = getRoot(player)
	if value then
		local config = getConfig(player)
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local allowed = config ~= nil
			and config.Movement ~= "Ground"
			and character ~= nil
			and root ~= nil
			and humanoid ~= nil
			and humanoid.Health > 0
			and character:GetAttribute("ApexStunned") ~= true
			and character:GetAttribute("ApexGrounded") ~= true
		if not allowed or not character or not root or not config then
			if character then
				character:SetAttribute("ApexFlying", false)
				character:SetAttribute("ApexServerFlying", false)
			end
			return
		end
		state.flying = true
		character:SetAttribute("ApexFlying", true)
		character:SetAttribute("ApexServerFlying", true)
		if (config.Movement == "Board" or config.Movement == "Glider") and not state.mount then
			state.mount = buildMount(config.Movement, config, character, root)
		end
	else
		if state.flying then
			state.flightEndedAt = os.clock()
		end
		state.flying = false
		state.boosting = false
		if character then
			character:SetAttribute("ApexFlying", false)
			character:SetAttribute("ApexServerFlying", false)
		end
		if state.mount then
			state.mount:Destroy()
			state.mount = nil
		end
	end
end

-- Force a player out of the air (stuns, Graven's Weight, etc.).
function MovementService.forceLand(player: Player)
	local state = states[player]
	if state and state.flying then
		setFlying(player, state, false)
	end
end

function MovementService.isFlying(player: Player): boolean
	local state = states[player]
	return state ~= nil and state.flying
end

local function onMovementState(player: Player, kind: string, value: any)
	local state = states[player]
	if not state then
		return
	end
	if kind == "Sprint" then
		state.sprinting = value == true
	elseif kind == "Flight" then
		setFlying(player, state, value == true)
	elseif kind == "Boost" then
		local boosting = value == true and state.flying
		if boosting and not state.boosting then
			local _, root = getRoot(player)
			if root then
				local velocity = root.AssemblyLinearVelocity
				local config = getConfig(player)
				NetService.fireNearExcept("Effect", root.Position, EFFECT_RADIUS, player, "SonicBoom", {
					Position = root.Position,
					Direction = if velocity.Magnitude > 1 then velocity.Unit else root.CFrame.LookVector,
					Color = if config then config.Palette.Glow else nil,
				})
			end
		end
		state.boosting = boosting
	elseif kind == "Dash" then
		local now = os.clock()
		if now - state.lastDash < BalanceConfig.Stamina.DashCooldown * 0.8 then
			NetService.strike(player, "dash spam")
			return
		end
		if PlayerStateService.consumeStamina(player, BalanceConfig.Stamina.DashCost) then
			state.lastDash = now
			MovementService.exempt(player, SPEED_EXEMPT_AFTER_DASH)
		end
	elseif kind == "Land" then
		if type(value) ~= "number" then
			return
		end
		local recentlyFlying = state.flying or os.clock() - state.flightEndedAt < LAND_GRACE
		local config = getConfig(player)
		local profile = config and BalanceConfig.Flight.Profiles[config.FlightProfile or "Standard"]
		if not recentlyFlying or not profile or value > profile.Boost * 1.5 then
			NetService.strike(player, "invalid landing report")
			return
		end
		if value < BalanceConfig.Flight.HardLandingSpeed then
			return
		end
		local character, root = getRoot(player)
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if character and root and humanoid and config then
			NetService.fireNearExcept("Effect", root.Position, EFFECT_RADIUS, player, "Crater", {
				Position = root.Position - Vector3.new(0, root.Size.Y / 2 + humanoid.HipHeight, 0),
				Strength = math.clamp(value / profile.Boost, 0.3, 1),
				Color = config.Palette.Glow,
				Source = character,
			})
		end
	end
end

--------------------------------------------------------------------------------
-- Per-frame: stamina drain + speed checks
--------------------------------------------------------------------------------
local function expectedMaxSpeed(player: Player, state: MoveState): number
	local config = getConfig(player)
	if not config then
		return 60
	end
	if state.flying then
		local profile = BalanceConfig.Flight.Profiles[config.FlightProfile or "Standard"] or BalanceConfig.Flight.Profiles.Standard
		return profile.Boost
	end
	local character = player.Character
	local multiplier = character and character:GetAttribute("ApexSpeedMultiplier")
	local walk = BalanceConfig.Roles[config.Role].WalkSpeed * BalanceConfig.Movement.SprintMultiplier
	return walk * math.max(1, if type(multiplier) == "number" then multiplier else 1)
end

local function step(dt: number)
	local now = os.clock()
	local stamina = BalanceConfig.Stamina
	for player, state in states do
		local character, root = getRoot(player)
		if not character or not root then
			state.lastPosition = nil
			continue
		end

		-- Stamina drain
		local horizontal = Vector3.new(root.AssemblyLinearVelocity.X, 0, root.AssemblyLinearVelocity.Z).Magnitude
		if state.boosting and state.flying then
			if not PlayerStateService.drainStamina(player, stamina.BoostDrainPerSecond * dt) then
				state.boosting = false
			end
		elseif state.sprinting and not state.flying and horizontal > 4 then
			if not PlayerStateService.drainStamina(player, stamina.SprintDrainPerSecond * dt) then
				state.sprinting = false
			end
		end

		-- Speed sanity check
		if now - state.lastSample >= SPEED_SAMPLE_INTERVAL then
			local position = root.Position
			local last = state.lastPosition
			local elapsed = now - state.lastSample
			state.lastSample = now
			state.lastPosition = position
			if last and now >= state.exemptUntil then
				local delta = position - last
				local flatDistance = Vector3.new(delta.X, 0, delta.Z).Magnitude
				local distance = if state.flying then delta.Magnitude else flatDistance
				local limit = expectedMaxSpeed(player, state) * BalanceConfig.Movement.SpeedTolerance
				-- On foot only horizontal distance counts; in flight allow diving.
				if state.flying and delta.Y < 0 then
					limit += GRAVITY_FALL_ALLOWANCE
				end
				if distance / elapsed > limit + 10 then
					state.violations += 1
					if state.violations >= SPEED_STRIKE_AFTER then
						state.violations = 0
						NetService.strike(player, string.format("speed %.0f > %.0f", distance / elapsed, limit))
					end
				else
					state.violations = 0
				end
			end
		end
	end
end

--------------------------------------------------------------------------------
-- Init
--------------------------------------------------------------------------------
function MovementService.init()
	local function onPlayer(player: Player)
		states[player] = newState()
		player.CharacterAdded:Connect(function()
			local state = states[player]
			if state then
				state.flying = false
				state.boosting = false
				state.sprinting = false
				state.mount = nil
				state.lastPosition = nil
				MovementService.exempt(player, 2) -- spawn teleport
			end
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		states[player] = nil
	end)

	NetService.onEvent("MovementState", {
		Validate.enum({ "Sprint", "Flight", "Boost", "Dash", "Land" }),
		Validate.optional(function(value: any): boolean
			return type(value) == "boolean" or (Validate.isFiniteNumber(value) and value >= 0 and value <= 5000)
		end),
	}, onMovementState :: any)

	RunService.Heartbeat:Connect(step)
end

return MovementService
