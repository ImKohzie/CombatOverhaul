--!strict
-- Character select (Tab / gamepad Select / the Characters button): a grid
-- of the 12 heroes and villains, a rotating 3D preview, role, health,
-- difficulty, passive and all four abilities with damage and cooldowns.
-- Switching goes through the validated SelectCharacter remote (5s
-- out-of-combat rule), and respawns you as the new character.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("ApexCity")
local BalanceConfig = require(Shared.Config.BalanceConfig)
local CharacterRegistry = require(Shared.CharacterRegistry)
local Remotes = require(Shared.Net.Remotes)
local Types = require(Shared.Types)

local CameraController = require(script.Parent.Parent.Controllers.CameraController)
local HudEvents = require(script.Parent.Parent.HudEvents)
local InputController = require(script.Parent.Parent.Controllers.InputController)
local Ui = require(script.Parent.Ui)

local player = Players.LocalPlayer

local ROLE_COLORS: { [string]: Color3 } = {
	Tank = Color3.fromRGB(90, 160, 255),
	Bruiser = Color3.fromRGB(255, 140, 70),
	Balanced = Color3.fromRGB(120, 220, 140),
	Agile = Color3.fromRGB(255, 90, 170),
}
local SLOT_KEYS = { Ability1 = "Q", Ability2 = "E", Ability3 = "R", Ultimate = "G" }

local CharacterSelect = {}

local screen: Frame
local viewport: ViewportFrame
local viewportCamera: Camera
local previewModel: Model? = nil
local detail: { [string]: TextLabel } = {}
local abilityList: Frame
local playButton: TextButton
local selected: Types.CharacterConfig? = nil
local firstCard: GuiObject? = nil
local open = false

local function stars(n: number): string
	return string.rep("★", n) .. string.rep("☆", 5 - n)
end

local function setPreview(config: Types.CharacterConfig)
	if previewModel then
		previewModel:Destroy()
		previewModel = nil
	end
	local rigs = Shared:FindFirstChild("PreviewRigs")
	local source = rigs and rigs:FindFirstChild(config.Id)
	if source and source:IsA("Model") then
		local clone = source:Clone()
		clone:PivotTo(CFrame.new(0, 0, 0))
		clone.Parent = viewport
		previewModel = clone
		local _, size = clone:GetBoundingBox()
		local distance = math.max(size.Y, size.X) * 1.35
		viewportCamera.CFrame = CFrame.lookAt(Vector3.new(0, size.Y * 0.05, -distance), Vector3.new(0, 0, 0))
	end
end

local function select(config: Types.CharacterConfig)
	selected = config
	local role = BalanceConfig.Roles[config.Role]
	detail.Name.Text = string.upper(config.DisplayName)
	detail.Name.TextColor3 = config.Palette.Glow
	detail.Role.Text = string.format("%s  ·  %d HP  ·  Difficulty %s", string.upper(config.Role), role.Health, stars(config.Difficulty))
	detail.Role.TextColor3 = ROLE_COLORS[config.Role] or Ui.Colors.Muted
	detail.Tagline.Text = config.Tagline
	local movement = if config.Movement == "Flight" then "Flies" elseif config.Movement == "Board" then "Rides a board" elseif config.Movement == "Glider" then "Rides a glider" else "Ground"
	local extras = {}
	if role.DamageReduction > 0 then
		table.insert(extras, string.format("%d%% damage reduction", role.DamageReduction * 100))
	end
	table.insert(extras, movement)
	detail.Traits.Text = table.concat(extras, "  ·  ")
	detail.Passive.Text = if config.Passive then "PASSIVE — " .. config.Passive.Name .. ": " .. config.Passive.Description else ""

	for _, child in abilityList:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	for index, slot in CharacterRegistry.Slots do
		local def = config.Abilities[slot]
		local balance = BalanceConfig.getAbility(config.Id, slot)
		if def then
			local row = Ui.new("Frame", {
				Size = UDim2.new(1, 0, 0, 52),
				BackgroundColor3 = Ui.Colors.PanelLight,
				BackgroundTransparency = 0.3,
				LayoutOrder = index,
				Parent = abilityList,
			}, { Ui.corner(6) }) :: Frame
			local key = Ui.label(SLOT_KEYS[slot], 20, if slot == "Ultimate" then Ui.Colors.Ultimate else Ui.Colors.Text) :: TextLabel
			key.Size = UDim2.fromOffset(34, 52)
			key.TextXAlignment = Enum.TextXAlignment.Center
			key.Parent = row
			local stats = ""
			if balance then
				stats = if slot == "Ultimate"
					then (if balance.Damage > 0 then string.format("%d dmg", balance.Damage) else "")
					else string.format("%s%ds cooldown", if balance.Damage > 0 then string.format("%d dmg · ", balance.Damage) else "", balance.Cooldown)
			end
			local title = Ui.label(string.format("%s   <font color='#9aa0ad' size='12'>%s</font>", def.Name, stats), 15, Ui.Colors.Text) :: TextLabel
			title.RichText = true
			title.Position = UDim2.fromOffset(38, 4)
			title.Size = UDim2.new(1, -44, 0, 18)
			title.Parent = row
			local description = Ui.label(def.Description, 12, Ui.Colors.Muted, Ui.FontLight) :: TextLabel
			description.Position = UDim2.fromOffset(38, 22)
			description.Size = UDim2.new(1, -44, 0, 28)
			description.TextWrapped = true
			description.TextYAlignment = Enum.TextYAlignment.Top
			description.Parent = row
		end
	end
	local current = player:GetAttribute("ApexCharacter")
	playButton.Text = if current == config.Id then "PLAYING" else "PLAY AS " .. string.upper(config.DisplayName)
	playButton.BackgroundColor3 = if current == config.Id then Ui.Colors.PanelLight else config.Palette.Primary:Lerp(Color3.new(1, 1, 1), 0.15)
	setPreview(config)
end

local function toggle(state: boolean?)
	open = if state == nil then not open else state
	screen.Visible = open
	CameraController.setAimBlocked(open)
	if open then
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		local id = player:GetAttribute("ApexCharacter")
		local config = if type(id) == "string" then CharacterRegistry.get(id) else nil
		local first = CharacterRegistry.list(false)[1]
		local show = if config and not config.Hidden then config else first
		if show then
			select(show)
		end
		if UserInputService.GamepadEnabled and firstCard then
			GuiService.SelectedObject = firstCard
		end
	else
		GuiService.SelectedObject = nil
	end
end

local function build(parent: Instance)
	screen = Ui.new("Frame", {
		Name = "CharacterSelect",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(6, 7, 10),
		BackgroundTransparency = 0.12,
		Visible = false,
		ZIndex = 50,
		Parent = parent,
	}) :: Frame
	local title = Ui.label("CHOOSE YOUR CHARACTER", 28, Ui.Colors.Text) :: TextLabel
	title.Position = UDim2.new(0, 40, 0, 26)
	title.Size = UDim2.fromOffset(600, 34)
	title.Parent = screen
	local subtitle = Ui.label("Switch any time outside combat (5s). You respawn as the new character.", 14, Ui.Colors.Muted, Ui.FontLight) :: TextLabel
	subtitle.Position = UDim2.new(0, 40, 0, 60)
	subtitle.Size = UDim2.fromOffset(700, 18)
	subtitle.Parent = screen

	-- Card grid (left)
	local grid = Ui.new("ScrollingFrame", {
		Position = UDim2.new(0, 40, 0, 96),
		Size = UDim2.new(0.42, -40, 1, -130),
		BackgroundTransparency = 1,
		ScrollBarThickness = 5,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = screen,
	}, {
		Ui.new("UIGridLayout", {
			CellSize = UDim2.fromOffset(170, 74),
			CellPadding = UDim2.fromOffset(10, 10),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}) :: ScrollingFrame
	for index, config in CharacterRegistry.list(false) do
		local card = Ui.new("TextButton", {
			Name = config.Id,
			Text = "",
			AutoButtonColor = true,
			BackgroundColor3 = Ui.Colors.PanelLight,
			LayoutOrder = index,
			Parent = grid,
		}, { Ui.corner(8), Ui.stroke(config.Palette.Glow, 1.5, 0.5) }) :: TextButton
		Ui.new("Frame", {
			Size = UDim2.new(0, 6, 1, 0),
			BackgroundColor3 = config.Palette.Glow,
			BorderSizePixel = 0,
			Parent = card,
		}, { Ui.corner(8) })
		local name = Ui.label(string.upper(config.DisplayName), 16, Ui.Colors.Text) :: TextLabel
		name.Position = UDim2.fromOffset(16, 12)
		name.Size = UDim2.new(1, -20, 0, 20)
		name.TextScaled = false
		name.Parent = card
		local role = Ui.label(config.Role .. "  ·  " .. BalanceConfig.Roles[config.Role].Health .. " HP", 12, ROLE_COLORS[config.Role] or Ui.Colors.Muted, Ui.FontLight) :: TextLabel
		role.Position = UDim2.fromOffset(16, 38)
		role.Size = UDim2.new(1, -20, 0, 16)
		role.Parent = card
		card.Activated:Connect(function()
			select(config)
		end)
		if index == 1 then
			firstCard = card
		end
	end

	-- Detail panel (right)
	local panel = Ui.new("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -40, 0, 96),
		Size = UDim2.new(0.56, -40, 1, -130),
		BackgroundColor3 = Ui.Colors.Panel,
		BackgroundTransparency = 0.2,
		Parent = screen,
	}, { Ui.corner(10) }) :: Frame
	viewport = Ui.new("ViewportFrame", {
		Size = UDim2.new(0.42, 0, 1, -70),
		BackgroundTransparency = 1,
		Ambient = Color3.fromRGB(150, 150, 160),
		LightColor = Color3.fromRGB(255, 245, 235),
		LightDirection = Vector3.new(-0.5, -1, -0.8),
		Parent = panel,
	}) :: ViewportFrame
	viewportCamera = Instance.new("Camera")
	viewportCamera.FieldOfView = 40
	viewportCamera.Parent = viewport
	viewport.CurrentCamera = viewportCamera

	local info = Ui.new("Frame", {
		Position = UDim2.new(0.42, 10, 0, 16),
		Size = UDim2.new(0.58, -26, 1, -90),
		BackgroundTransparency = 1,
		Parent = panel,
	}) :: Frame
	local function field(key: string, size: number, y: number, height: number, color: Color3?, font: Enum.Font?)
		local label = Ui.label("", size, color, font) :: TextLabel
		label.Position = UDim2.fromOffset(0, y)
		label.Size = UDim2.new(1, 0, 0, height)
		label.TextWrapped = true
		label.TextYAlignment = Enum.TextYAlignment.Top
		label.Parent = info
		detail[key] = label
	end
	field("Name", 30, 0, 34)
	field("Role", 14, 38, 18)
	field("Tagline", 14, 60, 36, Ui.Colors.Muted, Ui.FontLight)
	field("Traits", 13, 96, 18, Ui.Colors.Muted, Ui.FontLight)
	field("Passive", 13, 116, 34, Ui.Colors.Ultimate, Ui.FontLight)
	abilityList = Ui.new("Frame", {
		Position = UDim2.fromOffset(0, 154),
		Size = UDim2.new(1, 0, 1, -154),
		BackgroundTransparency = 1,
		Parent = info,
	}, {
		Ui.new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
	}) :: Frame

	playButton = Ui.new("TextButton", {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -16, 1, -14),
		Size = UDim2.fromOffset(300, 46),
		BackgroundColor3 = Color3.fromRGB(60, 120, 255),
		Text = "PLAY",
		TextColor3 = Color3.new(1, 1, 1),
		TextSize = 18,
		Font = Ui.Font,
		Parent = panel,
	}, { Ui.corner(8) }) :: TextButton
	local closeButton = Ui.new("TextButton", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -40, 0, 30),
		Size = UDim2.fromOffset(110, 34),
		BackgroundColor3 = Ui.Colors.PanelLight,
		Text = "CLOSE (Tab)",
		TextColor3 = Ui.Colors.Text,
		TextSize = 14,
		Font = Ui.Font,
		Parent = screen,
	}, { Ui.corner(6) }) :: TextButton
	closeButton.Activated:Connect(function()
		toggle(false)
	end)

	local selectRemote = Remotes.func("SelectCharacter")
	local busy = false
	playButton.Activated:Connect(function()
		local config = selected
		if busy or not config or player:GetAttribute("ApexCharacter") == config.Id then
			return
		end
		busy = true
		playButton.Text = "SWITCHING..."
		local ok, success, reason = pcall(function()
			return selectRemote:InvokeServer(config.Id)
		end)
		busy = false
		if ok and success then
			toggle(false)
			HudEvents.Notify:Fire("Now playing " .. config.DisplayName)
		else
			HudEvents.Notify:Fire(if ok and type(reason) == "string" then reason else "Couldn't switch right now")
			select(config)
		end
	end)
end

function CharacterSelect.init(parent: Instance)
	build(parent)
	-- Mobile / mouse button
	local button = Ui.new("TextButton", {
		Name = "CharactersButton",
		Position = UDim2.fromOffset(16, 60),
		Size = UDim2.fromOffset(120, 32),
		BackgroundColor3 = Ui.Colors.Panel,
		BackgroundTransparency = 0.25,
		Text = "CHARACTERS",
		TextColor3 = Ui.Colors.Text,
		TextSize = 13,
		Font = Ui.Font,
		Parent = parent,
	}, { Ui.corner(6), Ui.stroke(Color3.new(1, 1, 1), 1, 0.75) }) :: TextButton
	button.Activated:Connect(function()
		toggle()
	end)
	InputController.Began:Connect(function(action: string)
		if action == "CharacterSelect" then
			toggle()
		end
	end)
	RunService.RenderStepped:Connect(function(dt: number)
		if open and previewModel then
			previewModel:PivotTo(previewModel:GetPivot() * CFrame.Angles(0, dt * 0.6, 0))
		end
	end)
	player.CharacterAdded:Connect(function()
		if open and selected then
			select(selected)
		end
	end)
	-- Show the picker once on first join
	task.delay(3, function()
		if not open then
			toggle(true)
		end
	end)
end

return CharacterSelect
