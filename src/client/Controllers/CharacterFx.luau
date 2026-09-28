--!strict
-- Per-character cosmetic state, driven by replicated attributes, for every
-- character this client can see (players and NPCs):
--   Voltline momentum: lightning trails that intensify per tier; for the
--     local Voltline also FOV bonus + motion blur. Phase Run lets the local
--     Voltline pass through walls.
--   Status visuals: frozen (ice shell), bound (tendrils), marked (resonance
--     rings), hardened (crystal glint), invisible (Eclipse), time-slowed.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("ApexCity")
local BalanceConfig = require(Shared.Config.BalanceConfig)

local CameraController = require(script.Parent.CameraController)
local EffectsController = require(script.Parent.EffectsController)

local player = Players.LocalPlayer

local CharacterFx = {}

type State = {
	trails: { Trail },
	statusParts: { [string]: Instance },
	highlight: Highlight?,
	lastTier: number,
	invisible: boolean,
}

local states: { [Model]: State } = {}
local blur: BlurEffect? = nil
local slowCorrection: ColorCorrectionEffect? = nil
local slowedTracks: { [AnimationTrack]: number } = {}

local function getState(character: Model): State
	local state = states[character]
	if not state then
		state = { trails = {}, statusParts = {}, highlight = nil, lastTier = 0, invisible = false }
		states[character] = state
		character.AncestryChanged:Connect(function(_, parent)
			if parent == nil then
				states[character] = nil
			end
		end)
	end
	return state
end

local function rootOf(character: Model): BasePart?
	local root = character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

--------------------------------------------------------------------------------
-- Voltline momentum
--------------------------------------------------------------------------------
local LIMB_TRAILS = { "LeftLowerArm", "RightLowerArm", "LeftLowerLeg", "RightLowerLeg", "UpperTorso" }

local function ensureTrails(character: Model, state: State)
	if #state.trails > 0 then
		return
	end
	for _, name in LIMB_TRAILS do
		local limb = character:FindFirstChild(name)
		if limb and limb:IsA("BasePart") then
			local a0 = Instance.new("Attachment")
			a0.Position = Vector3.new(0, limb.Size.Y / 2, 0)
			a0.Parent = limb
			local a1 = Instance.new("Attachment")
			a1.Position = Vector3.new(0, -limb.Size.Y / 2, 0)
			a1.Parent = limb
			local trail = Instance.new("Trail")
			trail.Attachment0 = a0
			trail.Attachment1 = a1
			trail.Color = ColorSequence.new(Color3.fromRGB(255, 240, 120), Color3.fromRGB(220, 30, 20))
			trail.LightEmission = 1
			trail.Enabled = false
			trail.Parent = limb
			table.insert(state.trails, trail)
		end
	end
end

local function updateMomentum(character: Model, state: State, isLocal: boolean)
	local tierValue = character:GetAttribute("ApexMomentumTier")
	local tier = if type(tierValue) == "number" then tierValue else 1
	local phasing = character:GetAttribute("ApexPhasing") == true
	local effective = if phasing then math.max(tier, 3) else tier
	if effective ~= state.lastTier then
		state.lastTier = effective
		ensureTrails(character, state)
		for _, trail in state.trails do
			trail.Enabled = effective > 1
			trail.Lifetime = 0.08 * effective
			trail.Transparency = NumberSequence.new(0.6 - effective * 0.12, 1)
			trail.WidthScale = NumberSequence.new(0.4 + effective * 0.2, 0)
		end
		if isLocal then
			local momentum = BalanceConfig.Momentum
			local bonus = momentum.FovBonus[effective] or 0
			CameraController.setFov("Momentum", if bonus > 0 then 76 + bonus else nil)
			if not blur or blur.Parent == nil then
				local camera = workspace.CurrentCamera
				if camera then
					local created = Instance.new("BlurEffect")
					created.Name = "ApexMomentumBlur"
					created.Size = 0
					created.Parent = camera
					blur = created
				end
			end
			if blur then
				blur.Size = if effective > 1 then (effective - 1) * 2.5 else 0
			end
		end
	end
end

--------------------------------------------------------------------------------
-- Status visuals
--------------------------------------------------------------------------------
local function setStatusPart(state: State, name: string, create: (() -> Instance)?)
	local existing = state.statusParts[name]
	if create and not existing then
		state.statusParts[name] = create()
	elseif not create and existing then
		existing:Destroy()
		state.statusParts[name] = nil
	end
end

local function weldedShell(character: Model, name: string, size: Vector3, color: Color3, material: Enum.Material, transparency: number): Instance
	local root = rootOf(character)
	local shell = EffectsController.part()
	shell.Name = name
	shell.Anchored = false
	shell.Massless = true
	shell.Size = size
	shell.Color = color
	shell.Material = material
	shell.Transparency = transparency
	if root then
		shell.CFrame = root.CFrame
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = shell
		weld.Parent = shell
	end
	shell.Parent = EffectsController.folder()
	return shell
end

local function updateStatus(character: Model, state: State, isLocal: boolean)
	local frozen = character:GetAttribute("ApexFrozen") == true
	setStatusPart(state, "Frozen", if frozen then function()
		return weldedShell(character, "ApexIceShell", Vector3.new(4.4, 6.2, 3.2), Color3.fromRGB(180, 230, 255), Enum.Material.Ice, 0.35)
	end else nil)

	local bound = character:GetAttribute("ApexBound") == true
	setStatusPart(state, "Bound", if bound then function()
		local model = Instance.new("Model")
		model.Name = "ApexTendrils"
		local root = rootOf(character)
		if root then
			for i = 1, 5 do
				local angle = i / 5 * math.pi * 2
				local tendril = EffectsController.part()
				tendril.Material = Enum.Material.Neon
				tendril.Color = Color3.fromRGB(60, 20, 110)
				tendril.Size = Vector3.new(0.35, 5, 0.35)
				tendril.CFrame = root.CFrame * CFrame.new(math.cos(angle) * 1.6, -1, math.sin(angle) * 1.6) * CFrame.Angles(math.sin(angle) * 0.4, 0, math.cos(angle) * 0.4)
				tendril.Parent = model
			end
		end
		model.Parent = EffectsController.folder()
		return model
	end else nil)

	local marked = character:GetAttribute("ApexMarked") == true
	setStatusPart(state, "Marked", if marked then function()
		local root = rootOf(character)
		local ring = EffectsController.part()
		ring.Name = "ApexMark"
		ring.Anchored = false
		ring.Massless = true
		ring.Shape = Enum.PartType.Cylinder
		ring.Material = Enum.Material.Neon
		ring.Color = Color3.fromRGB(255, 80, 200)
		ring.Transparency = 0.3
		ring.Size = Vector3.new(0.1, 3.5, 3.5)
		if root then
			ring.CFrame = root.CFrame * CFrame.new(0, 3.8, 0) * CFrame.Angles(0, 0, math.rad(90))
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = root
			weld.Part1 = ring
			weld.Parent = ring
		end
		ring.Parent = EffectsController.folder()
		return ring
	end else nil)

	local hardened = character:GetAttribute("ApexHardened") == true
	local slowed = character:GetAttribute("ApexTimeSlowed") == true
	local wantHighlight = hardened or slowed or frozen
	if wantHighlight and not state.highlight then
		local highlight = Instance.new("Highlight")
		highlight.Adornee = character
		highlight.DepthMode = Enum.HighlightDepthMode.Occluded
		highlight.Parent = character
		state.highlight = highlight
	elseif not wantHighlight and state.highlight then
		state.highlight:Destroy()
		state.highlight = nil
	end
	if state.highlight then
		if hardened then
			state.highlight.FillColor = Color3.fromRGB(255, 160, 80)
			state.highlight.FillTransparency = 0.7
			state.highlight.OutlineColor = Color3.fromRGB(255, 220, 160)
		elseif frozen then
			state.highlight.FillColor = Color3.fromRGB(170, 230, 255)
			state.highlight.FillTransparency = 0.5
			state.highlight.OutlineColor = Color3.new(1, 1, 1)
		else
			state.highlight.FillColor = Color3.fromRGB(200, 170, 255)
			state.highlight.FillTransparency = 0.8
			state.highlight.OutlineColor = Color3.fromRGB(230, 220, 255)
		end
	end

	-- Eclipse invisibility (others can't see Umbra; Umbra sees a ghost)
	local invisible = character:GetAttribute("ApexInvisible") == true
	if invisible ~= state.invisible then
		state.invisible = invisible
		local modifier = if invisible then (if isLocal then 0.6 else 1) else 0
		for _, descendant in character:GetDescendants() do
			if descendant:IsA("BasePart") then
				descendant.LocalTransparencyModifier = modifier
			elseif descendant:IsA("ParticleEmitter") and not isLocal then
				descendant.Enabled = not invisible
			end
		end
	end
end

--------------------------------------------------------------------------------
-- Local time slow (Velocity Rift victims)
--------------------------------------------------------------------------------
local function updateLocalSlow(character: Model)
	local slowed = character:GetAttribute("ApexTimeSlowed") == true
	if slowed and not slowCorrection then
		local correction = Instance.new("ColorCorrectionEffect")
		correction.Name = "ApexTimeSlow"
		correction.Saturation = -0.5
		correction.TintColor = Color3.fromRGB(215, 205, 255)
		correction.Parent = Lighting
		slowCorrection = correction
	elseif not slowed and slowCorrection then
		slowCorrection:Destroy()
		slowCorrection = nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if slowed and animator then
		for _, track in animator:GetPlayingAnimationTracks() do
			if not slowedTracks[track] then
				slowedTracks[track] = track.Speed
				track:AdjustSpeed(track.Speed * 0.15)
			end
		end
	elseif not slowed and next(slowedTracks) then
		for track, speed in slowedTracks do
			if track.IsPlaying then
				track:AdjustSpeed(speed)
			end
		end
		table.clear(slowedTracks)
	end
end

--------------------------------------------------------------------------------
-- Loop
--------------------------------------------------------------------------------
local function eachCharacter(callback: (Model, boolean) -> ())
	for _, other in Players:GetPlayers() do
		if other.Character then
			callback(other.Character, other == player)
		end
	end
	local npcs = workspace:FindFirstChild("ApexNPCs")
	if npcs then
		for _, npc in npcs:GetChildren() do
			if npc:IsA("Model") then
				callback(npc, false)
			end
		end
	end
end

local accumulator = 0
local function step(dt: number)
	accumulator += dt
	if accumulator < 0.1 then
		return
	end
	accumulator = 0
	eachCharacter(function(character, isLocal)
		local state = getState(character)
		if character:GetAttribute("ApexCharacter") == "Voltline" then
			updateMomentum(character, state, isLocal)
		elseif isLocal and state.lastTier ~= 0 then
			state.lastTier = 0
			CameraController.setFov("Momentum", nil)
			if blur then
				blur.Size = 0
			end
		end
		updateStatus(character, state, isLocal)
		if isLocal then
			updateLocalSlow(character)
		end
	end)
end

function CharacterFx.init()
	RunService.Heartbeat:Connect(step)
	player.CharacterAdded:Connect(function()
		CameraController.setFov("Momentum", nil)
		if blur then
			blur.Size = 0
		end
		table.clear(slowedTracks)
	end)
end

return CharacterFx
