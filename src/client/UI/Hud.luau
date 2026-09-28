--!strict
-- The in-game HUD: health (with damage trail), stamina, posture and heat
-- bars, ability slots with radial cooldown sweeps, ultimate meter, passive
-- readouts (Momentum / Rage), notifications, a damage vignette and a
-- controls hint. Scales with the screen (UIScale) for mobile.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("ApexCity")
local BalanceConfig = require(Shared.Config.BalanceConfig)
local CharacterRegistry = require(Shared.CharacterRegistry)
local Remotes = require(Shared.Net.Remotes)

local HudEvents = require(script.Parent.Parent.HudEvents)
local Ui = require(script.Parent.Ui)

local player = Players.LocalPlayer

local SLOTS = { "Movement", "Ability1", "Ability2", "Ability3", "Ultimate" }
local KEYS = { Movement = "F", Ability1 = "Q", Ability2 = "E", Ability3 = "R", Ultimate = "G" }
local GAMEPAD_KEYS = { Movement = "B", Ability1 = "X", Ability2 = "Y", Ability3 = "RB", Ultimate = "LB" }

local Hud = {}

type Slot = {
	frame: Frame,
	key: TextLabel,
	name: TextLabel,
	timer: TextLabel,
	sweep: (number) -> (),
	fill: Frame?,
}

local gui: ScreenGui
local slots: { [string]: Slot } = {}
local setHealth: (number, Color3?) -> ()
local setStamina: (number, Color3?) -> ()
local setPosture: (number, Color3?) -> ()
local setHeat: (number, Color3?) -> ()
local postureBar: Frame
local heatBar: Frame
local healthText: TextLabel
local nameText: TextLabel
local passiveText: TextLabel
local noticeStack: Frame
local vignette: UIStroke
local lastHealth = 0

local function scaleToScreen(scale: UIScale)
	local camera = workspace.CurrentCamera
	local function update()
		if camera then
			local size = camera.ViewportSize
			scale.Scale = math.clamp(math.min(size.X / 1280, size.Y / 760), 0.62, 1.25)
		end
	end
	update()
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(update)
	end
end

local function makeSlot(parent: Instance, slot: string, order: number): Slot
	local isUlt = slot == "Ultimate"
	local size = if isUlt then 76 else 64
	local frame = Ui.new("Frame", {
		Name = slot,
		Size = UDim2.fromOffset(size, size),
		BackgroundColor3 = Ui.Colors.Panel,
		BackgroundTransparency = 0.2,
		LayoutOrder = order,
		Parent = parent,
	}, { Ui.corner(1000), Ui.stroke(Color3.fromRGB(255, 255, 255), 1.5, 0.75) }) :: Frame
	local fill: Frame? = nil
	if isUlt then
		local holder = Ui.new("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			ClipsDescendants = true,
			Parent = frame,
		}, { Ui.corner(1000) }) :: Frame
		fill = Ui.new("Frame", {
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 1),
			Size = UDim2.fromScale(1, 0),
			BackgroundColor3 = Ui.Colors.Ultimate,
			BackgroundTransparency = 0.35,
			BorderSizePixel = 0,
			Parent = holder,
		}) :: Frame
	end
	local key = Ui.label(KEYS[slot], if isUlt then 26 else 22, Ui.Colors.Text) :: TextLabel
	key.Size = UDim2.fromScale(1, 1)
	key.TextXAlignment = Enum.TextXAlignment.Center
	key.ZIndex = 6
	key.Parent = frame
	local timer = Ui.label("", 20, Color3.new(1, 1, 1)) :: TextLabel
	timer.Size = UDim2.fromScale(1, 1)
	timer.TextXAlignment = Enum.TextXAlignment.Center
	timer.TextStrokeTransparency = 0.3
	timer.ZIndex = 7
	timer.Parent = frame
	local name = Ui.label("", 11, Ui.Colors.Muted, Ui.FontLight) :: TextLabel
	name.AnchorPoint = Vector2.new(0.5, 0)
	name.Position = UDim2.new(0.5, 0, 1, 4)
	name.Size = UDim2.fromOffset(110, 14)
	name.TextXAlignment = Enum.TextXAlignment.Center
	name.Parent = frame
	return { frame = frame, key = key, name = name, timer = timer, sweep = Ui.sweep(frame), fill = fill }
end

local function build()
	gui = Instance.new("ScreenGui")
	gui.Name = "ApexHud"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = 10
	gui.Parent = player:WaitForChild("PlayerGui")
	local scale = Instance.new("UIScale")
	scale.Parent = gui
	scaleToScreen(scale)

	-- Damage vignette
	local edge = Ui.new("Frame", {
		Name = "DamageEdge",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Parent = gui,
	}) :: Frame
	vignette = Ui.stroke(Color3.fromRGB(220, 20, 20), 48, 1)
	vignette.Parent = edge

	-- Bottom-centre cluster
	local cluster = Ui.new("Frame", {
		Name = "Cluster",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -28),
		Size = UDim2.fromOffset(420, 190),
		BackgroundTransparency = 1,
		Parent = gui,
	}) :: Frame

	nameText = Ui.label("", 16, Ui.Colors.Text) :: TextLabel
	nameText.Position = UDim2.fromOffset(30, 58)
	nameText.Size = UDim2.fromOffset(250, 18)
	nameText.Parent = cluster
	passiveText = Ui.label("", 13, Ui.Colors.Ultimate, Ui.FontLight) :: TextLabel
	passiveText.Position = UDim2.fromOffset(200, 58)
	passiveText.Size = UDim2.fromOffset(190, 18)
	passiveText.TextXAlignment = Enum.TextXAlignment.Right
	passiveText.Parent = cluster

	local healthBack
	healthBack, setHealth = Ui.bar(cluster, UDim2.fromOffset(360, 14), UDim2.fromOffset(30, 80), Ui.Colors.Health)
	healthText = Ui.label("", 12, Ui.Colors.Text) :: TextLabel
	healthText.Size = UDim2.fromScale(1, 1)
	healthText.TextXAlignment = Enum.TextXAlignment.Center
	healthText.TextStrokeTransparency = 0.4
	healthText.ZIndex = 3
	healthText.Parent = healthBack
	local _
	_, setStamina = Ui.bar(cluster, UDim2.fromOffset(360, 5), UDim2.fromOffset(30, 98), Ui.Colors.Stamina)
	postureBar, setPosture = Ui.bar(cluster, UDim2.fromOffset(170, 4), UDim2.fromOffset(30, 108), Ui.Colors.Posture)
	heatBar, setHeat = Ui.bar(cluster, UDim2.fromOffset(170, 4), UDim2.fromOffset(220, 108), Ui.Colors.Heat)

	local row = Ui.new("Frame", {
		Name = "Abilities",
		Position = UDim2.fromOffset(0, 118),
		Size = UDim2.fromOffset(420, 80),
		BackgroundTransparency = 1,
		Parent = cluster,
	}, {
		Ui.new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 22),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	for index, slot in SLOTS do
		slots[slot] = makeSlot(row, slot, index)
	end

	-- Notifications (top centre)
	noticeStack = Ui.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 70),
		Size = UDim2.fromOffset(460, 140),
		BackgroundTransparency = 1,
		Parent = gui,
	}, {
		Ui.new("UIListLayout", {
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}) :: Frame

	-- Controls hint (fades out)
	local hint = Ui.label(
		if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
			then "Stick move · Jump · Fly/Blk · Hit · Aim · Q E R abilities · ULT · Characters button"
			else "WASD move · Space jump · Shift sprint/boost · F fly / block · C dash · M1 attack (hold = heavy) · RMB aim · Q E R abilities · G ultimate · Tab characters · V emote",
		14,
		Ui.Colors.Muted,
		Ui.FontLight
	) :: TextLabel
	hint.AnchorPoint = Vector2.new(0.5, 1)
	hint.Position = UDim2.new(0.5, 0, 1, -6)
	hint.Size = UDim2.fromOffset(900, 18)
	hint.TextXAlignment = Enum.TextXAlignment.Center
	hint.Parent = gui
	task.delay(25, function()
		TweenService:Create(hint, TweenInfo.new(2), { TextTransparency = 1 }):Play()
	end)
end

function Hud.notify(text: string)
	local label = Ui.new("TextLabel", {
		Size = UDim2.fromOffset(440, 30),
		BackgroundColor3 = Ui.Colors.Panel,
		BackgroundTransparency = 0.35,
		Text = text,
		TextColor3 = Ui.Colors.Text,
		TextSize = 16,
		Font = Ui.Font,
		Parent = noticeStack,
	}, { Ui.corner(6) }) :: TextLabel
	task.delay(3, function()
		TweenService:Create(label, TweenInfo.new(0.5), { BackgroundTransparency = 1, TextTransparency = 1 }):Play()
		task.wait(0.5)
		label:Destroy()
	end)
	local children = noticeStack:GetChildren()
	if #children > 5 then
		for _, child in children do
			if child:IsA("TextLabel") then
				child:Destroy()
				break
			end
		end
	end
end

local function formatTime(seconds: number): string
	return if seconds >= 10 then string.format("%d", math.ceil(seconds)) else string.format("%.1f", seconds)
end

local function update()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local id = player:GetAttribute("ApexCharacter")
	local config = if type(id) == "string" then CharacterRegistry.get(id) else nil

	-- Health
	if humanoid then
		local fraction = if humanoid.MaxHealth > 0 then humanoid.Health / humanoid.MaxHealth else 0
		setHealth(fraction, if fraction < 0.3 then Ui.Colors.HealthLow else Ui.Colors.Health)
		healthText.Text = string.format("%d / %d", math.ceil(humanoid.Health), humanoid.MaxHealth)
		if humanoid.Health < lastHealth - 0.5 then
			vignette.Transparency = 0.45
			TweenService:Create(vignette, TweenInfo.new(0.5), { Transparency = 1 }):Play()
		end
		lastHealth = humanoid.Health
	end
	local stamina = player:GetAttribute("ApexStamina")
	setStamina((if type(stamina) == "number" then stamina else 0) / BalanceConfig.Stamina.Max)
	local posture = character and character:GetAttribute("ApexPosture")
	local postureFraction = (if type(posture) == "number" then posture else 100) / BalanceConfig.Defence.PostureMax
	postureBar.Visible = postureFraction < 0.999 or (character ~= nil and character:GetAttribute("ApexBlocking") == true)
	setPosture(postureFraction)
	local heat = player:GetAttribute("ApexHeat")
	local heatFraction = (if type(heat) == "number" then heat else 0) / BalanceConfig.Beam.HeatMax
	heatBar.Visible = heatFraction > 0.01
	setHeat(heatFraction, if heatFraction > 0.85 then Color3.fromRGB(255, 50, 30) else Ui.Colors.Heat)

	-- Name + passive readout
	if config then
		nameText.Text = string.upper(config.DisplayName) .. "  ·  " .. config.Role
		local passive = ""
		if character then
			local tier = character:GetAttribute("ApexMomentumTier")
			local rage = character:GetAttribute("ApexRage")
			if type(tier) == "number" and config.Id == "Voltline" then
				passive = "MOMENTUM " .. string.rep("▮", tier) .. string.rep("▯", 4 - tier)
			elseif type(rage) == "number" and config.Id == "Rampage" then
				passive = string.format("RAGE %d%%", rage)
			end
		end
		passiveText.Text = passive
	end

	-- Ability slots
	local now = workspace:GetServerTimeNow()
	local gamepad = UserInputService:GetLastInputType().Name:sub(1, 7) == "Gamepad"
	for _, slotName in SLOTS do
		local slot = slots[slotName]
		local def: any = nil
		local balance: any = nil
		if slotName == "Movement" then
			local move = config and (BalanceConfig.Traversal :: any)[config.Id]
			def = move
			balance = move
		else
			def = config and config.Abilities[slotName]
			balance = config and BalanceConfig.getAbility(config.Id, slotName)
		end
		slot.name.Text = if def then def.Name else ""
		slot.key.Text = if gamepad then GAMEPAD_KEYS[slotName] else KEYS[slotName]
		local readyAt = player:GetAttribute("ApexCD_" .. slotName)
		local remaining = if type(readyAt) == "number" then readyAt - now else 0
		if slotName == "Ultimate" then
			local ult = player:GetAttribute("ApexUltimate")
			local ultFraction = (if type(ult) == "number" then ult else 0) / BalanceConfig.Ultimate.Max
			if slot.fill then
				slot.fill.Size = UDim2.fromScale(1, ultFraction)
			end
			local ready = ultFraction >= 1
			local stroke = slot.frame:FindFirstChildOfClass("UIStroke")
			if stroke then
				stroke.Color = if ready then Ui.Colors.Ultimate else Color3.new(1, 1, 1)
				stroke.Transparency = if ready then 0.1 + math.sin(os.clock() * 6) * 0.1 else 0.75
				stroke.Thickness = if ready then 3 else 1.5
			end
			slot.timer.Text = if ready then "" else string.format("%d%%", math.floor(ultFraction * 100))
			slot.timer.TextSize = 14
			slot.sweep(0)
		elseif remaining > 0.05 and balance then
			slot.sweep(remaining / balance.Cooldown)
			slot.timer.Text = formatTime(remaining)
		else
			slot.sweep(0)
			slot.timer.Text = ""
		end
		slot.key.TextTransparency = if slot.timer.Text ~= "" and slotName ~= "Ultimate" then 0.7 else 0
	end
end

function Hud.init()
	build()
	HudEvents.Notify:Connect(function(text: string)
		Hud.notify(text)
	end)
	Remotes.event("Notify").OnClientEvent:Connect(function(text: any)
		if type(text) == "string" then
			Hud.notify(text)
		end
	end)
	local accumulator = 0
	RunService.RenderStepped:Connect(function(dt)
		accumulator += dt
		if accumulator >= 1 / 30 then
			accumulator = 0
			update()
		end
	end)
end

return Hud
