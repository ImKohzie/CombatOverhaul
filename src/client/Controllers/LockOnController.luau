--!strict
-- PvP lock-on targeting.
--   T / middle mouse / D-pad up / "Lock" button: lock the enemy nearest the
--   centre of the screen (or unlock).
--   Z / right-stick flick / "Next" button: switch to the next enemy.
-- While locked:
--   * the camera smoothly tracks the target (you can still nudge it)
--   * on foot you strafe around the target, facing it (sprint to run freely)
--   * abilities, beams and F moves aim at the target (with a little lead)
--   * a reticle with the target's name and health sits on them
-- The lock breaks when the target dies, turns invisible or gets too far.
-- Purely client-side: the server still validates every aim it receives.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local CameraController = require(script.Parent.CameraController)
local EffectsController = require(script.Parent.EffectsController)
local InputController = require(script.Parent.InputController)

local player = Players.LocalPlayer

local MAX_RANGE = 260 -- studs to acquire
local BREAK_RANGE = 340 -- studs before an existing lock breaks
local MAX_SCREEN_OFFSET = 0.75 -- fraction of half-screen a target may be from centre
local CAMERA_TRACK = 9 -- camera turn rate toward the target
local LEAD_TIME = 0.12 -- seconds of velocity lead for aim

local LockOnController = {}

local target: Model? = nil
local reticle: BillboardGui? = nil
local ring: Frame? = nil
local nameLabel: TextLabel? = nil
local healthFill: Frame? = nil
local lastFlick = 0

local function rootOf(model: Model): BasePart?
	local root = model:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

local function alive(model: Model): boolean
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.Health > 0 and model.Parent ~= nil
end

local function targetable(model: Model): boolean
	return model ~= player.Character and alive(model) and model:GetAttribute("ApexInvisible") ~= true and rootOf(model) ~= nil
end

-- Every player character and NPC (bots, dummies, clones) in the world.
local function candidates(): { Model }
	local list: { Model } = {}
	for _, other in Players:GetPlayers() do
		local character = other.Character
		if other ~= player and character and targetable(character) then
			table.insert(list, character)
		end
	end
	local npcs = workspace:FindFirstChild("ApexNPCs")
	if npcs then
		for _, npc in npcs:GetChildren() do
			if npc:IsA("Model") and targetable(npc) then
				table.insert(list, npc)
			end
		end
	end
	return list
end

-- Lower is better: distance from the screen centre, then world distance.
local function score(model: Model): number?
	local camera = workspace.CurrentCamera
	local mine = player.Character
	local myRoot = mine and rootOf(mine)
	local root = rootOf(model)
	if not camera or not myRoot or not root then
		return nil
	end
	local distance = (root.Position - myRoot.Position).Magnitude
	if distance > MAX_RANGE then
		return nil
	end
	local screen, onScreen = camera:WorldToViewportPoint(root.Position)
	if not onScreen then
		return nil
	end
	local viewport = camera.ViewportSize
	local dx = (screen.X - viewport.X / 2) / (viewport.X / 2)
	local dy = (screen.Y - viewport.Y / 2) / (viewport.Y / 2)
	local offset = math.sqrt(dx * dx + dy * dy)
	if offset > MAX_SCREEN_OFFSET * 1.6 then
		return nil
	end
	return offset * 2 + distance / MAX_RANGE
end

local function bestTarget(exclude: Model?): Model?
	local best: Model? = nil
	local bestScore = math.huge
	for _, model in candidates() do
		if model ~= exclude then
			local s = score(model)
			if s and s < bestScore then
				best = model
				bestScore = s
			end
		end
	end
	return best
end

--------------------------------------------------------------------------------
-- Reticle
--------------------------------------------------------------------------------
local function buildReticle()
	local playerGui = player:WaitForChild("PlayerGui")
	local gui = Instance.new("BillboardGui")
	gui.Name = "ApexLockOn"
	gui.AlwaysOnTop = true
	gui.Size = UDim2.fromOffset(120, 140)
	gui.LightInfluence = 0
	gui.ResetOnSpawn = false
	gui.Enabled = false
	gui.Parent = playerGui

	local diamond = Instance.new("Frame")
	diamond.Name = "Ring"
	diamond.AnchorPoint = Vector2.new(0.5, 0.5)
	diamond.Position = UDim2.fromOffset(60, 78)
	diamond.Size = UDim2.fromOffset(46, 46)
	diamond.BackgroundTransparency = 1
	diamond.Parent = gui
	-- four corner brackets that spin around the target
	for i = 0, 3 do
		local bracket = Instance.new("Frame")
		bracket.AnchorPoint = Vector2.new(0.5, 0.5)
		bracket.Size = UDim2.fromOffset(12, 3)
		bracket.BorderSizePixel = 0
		bracket.BackgroundColor3 = Color3.fromRGB(255, 70, 70)
		bracket.Rotation = i * 90 + 45
		local angle = math.rad(i * 90 + 45)
		bracket.Position = UDim2.new(0.5, math.cos(angle) * 20, 0.5, math.sin(angle) * 20)
		bracket.Parent = diamond
	end
	local dot = Instance.new("Frame")
	dot.AnchorPoint = Vector2.new(0.5, 0.5)
	dot.Position = UDim2.fromScale(0.5, 0.5)
	dot.Size = UDim2.fromOffset(6, 6)
	dot.Rotation = 45
	dot.BorderSizePixel = 0
	dot.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	dot.Parent = diamond

	local label = Instance.new("TextLabel")
	label.Name = "TargetName"
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, 0, 0, 18)
	label.Font = Enum.Font.GothamBold
	label.TextSize = 14
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.4
	label.Parent = gui

	local bar = Instance.new("Frame")
	bar.Name = "Health"
	bar.Position = UDim2.new(0.1, 0, 0, 20)
	bar.Size = UDim2.new(0.8, 0, 0, 6)
	bar.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
	bar.BorderSizePixel = 0
	bar.Parent = gui
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(1, 1)
	fill.BorderSizePixel = 0
	fill.BackgroundColor3 = Color3.fromRGB(255, 70, 70)
	fill.Parent = bar

	reticle = gui
	ring = diamond
	nameLabel = label
	healthFill = fill
end

local function showReticle(model: Model?)
	local gui = reticle
	if not gui then
		return
	end
	if not model then
		local anyGui: any = gui
		anyGui.Adornee = nil
		gui.Enabled = false
		return
	end
	gui.Adornee = rootOf(model) :: any
	gui.Enabled = true
	if nameLabel then
		local owner = Players:GetPlayerFromCharacter(model)
		local id = model:GetAttribute("ApexCharacter")
		local hero = if type(id) == "string" then id else ""
		nameLabel.Text = if owner then `{owner.DisplayName}{if hero ~= "" then " · " .. hero else ""}` else model.Name
	end
	if ring then
		ring.Size = UDim2.fromOffset(90, 90)
		TweenService:Create(ring, TweenInfo.new(0.18, Enum.EasingStyle.Back), { Size = UDim2.fromOffset(46, 46) }):Play()
	end
end

--------------------------------------------------------------------------------
-- Lock state
--------------------------------------------------------------------------------
local function setTarget(model: Model?)
	if model == target then
		return
	end
	target = model
	showReticle(model)
	if model then
		CameraController.shake(0.05)
		local root = rootOf(model)
		if root then
			EffectsController.play("Pulse", { Position = root.Position, Radius = 6, Source = player.Character })
		end
	end
end

function LockOnController.getTarget(): Model?
	return target
end

-- Aim point on the locked target (with a little velocity lead), or nil.
function LockOnController.aimPoint(): Vector3?
	local model = target
	local root = model and rootOf(model)
	if not root then
		return nil
	end
	return root.Position + root.AssemblyLinearVelocity * LEAD_TIME + Vector3.new(0, 0.5, 0)
end

function LockOnController.toggle()
	if target then
		setTarget(nil)
	else
		setTarget(bestTarget(nil))
	end
end

-- Switch to the next target; `direction` (-1 left / 1 right) prefers that side.
function LockOnController.switch(direction: number?)
	local camera = workspace.CurrentCamera
	if not target or not camera then
		setTarget(bestTarget(nil))
		return
	end
	local currentRoot = rootOf(target)
	local currentX = if currentRoot then camera:WorldToViewportPoint(currentRoot.Position).X else camera.ViewportSize.X / 2
	local best: Model? = nil
	local bestScore = math.huge
	for _, model in candidates() do
		if model ~= target then
			local s = score(model)
			local root = rootOf(model)
			if s and root then
				local x = camera:WorldToViewportPoint(root.Position).X
				if direction and (x - currentX) * direction <= 0 then
					s += 5 -- wrong side: only pick if nothing else
				end
				if s < bestScore then
					best = model
					bestScore = s
				end
			end
		end
	end
	if best then
		setTarget(best)
	end
end

-- Camera: turn toward the target after the default camera has updated.
local function trackCamera(camera: Camera, dt: number): CFrame?
	local model = target
	local root = model and rootOf(model)
	local mine = player.Character
	local myRoot = mine and rootOf(mine)
	if not root or not myRoot or CameraController.isAiming() then
		return nil
	end
	local focus = camera.Focus.Position
	local offset = camera.CFrame.Position - focus
	local distance = offset.Magnitude
	if distance < 0.5 then
		return nil -- first person: leave it alone
	end
	-- Look from slightly above the player's head toward the target's chest
	local toTarget = root.Position - (focus + Vector3.new(0, 3, 0))
	if toTarget.Magnitude < 4 then
		return nil
	end
	local desired = toTarget.Unit
	local current = camera.CFrame.LookVector
	local alpha = math.min(1, dt * CAMERA_TRACK)
	local look = current:Lerp(desired, alpha)
	if look.Magnitude < 1e-3 then
		return nil
	end
	look = look.Unit
	local position = focus - look * distance
	return CFrame.lookAt(position, position + look)
end

local function step(_dt: number)
	local model = target
	if not model then
		return
	end
	local mine = player.Character
	local myRoot = mine and rootOf(mine)
	local root = rootOf(model)
	if not targetable(model) or not myRoot or not root or (root.Position - myRoot.Position).Magnitude > BREAK_RANGE then
		setTarget(nil)
		return
	end
	if ring then
		ring.Rotation = (os.clock() * 90) % 360
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid and healthFill then
		healthFill.Size = UDim2.fromScale(math.clamp(humanoid.Health / math.max(humanoid.MaxHealth, 1), 0, 1), 1)
	end
end

function LockOnController.init()
	buildReticle()
	CameraController.setLookProvider(trackCamera)
	InputController.Began:Connect(function(action: string)
		if action == "LockOn" then
			LockOnController.toggle()
		elseif action == "LockSwitch" then
			LockOnController.switch(1)
		end
	end)
	-- Gamepad: flick the right stick sideways to switch targets
	UserInputService.InputChanged:Connect(function(input)
		if input.KeyCode ~= Enum.KeyCode.Thumbstick2 or not target then
			return
		end
		local x = input.Position.X
		if math.abs(x) > 0.85 and os.clock() - lastFlick > 0.35 then
			lastFlick = os.clock()
			LockOnController.switch(if x > 0 then 1 else -1)
		end
	end)
	player.CharacterAdded:Connect(function()
		setTarget(nil)
	end)
	RunService.Heartbeat:Connect(step)
end

return LockOnController
