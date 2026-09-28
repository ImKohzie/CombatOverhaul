--!strict
-- TEMPORARY playtest HUD (replaced by the real UI in Phase 8).
-- Shows character, HP, stamina, ultimate, cooldowns, combat state and
-- server notices. Tab / Select / the "Chars" button opens a simple
-- character picker that uses the real SelectCharacter remote.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")

local Shared = ReplicatedStorage:WaitForChild("ApexCity")
local Remotes = require(Shared.Net.Remotes)
local CharacterRegistry = require(Shared.CharacterRegistry)
local BalanceConfig = require(Shared.Config.BalanceConfig)

local InputController = require(script.Parent.InputController)

local player = Players.LocalPlayer

local DebugHud = {}

local statusLabel: TextLabel
local noticeLabel: TextLabel
local picker: Frame
local noticeToken = 0

local function notice(text: string)
	noticeToken += 1
	local token = noticeToken
	noticeLabel.Text = text
	noticeLabel.Visible = true
	task.delay(3, function()
		if noticeToken == token then
			noticeLabel.Visible = false
		end
	end)
end

local function label(parent: Instance, name: string, size: UDim2, position: UDim2): TextLabel
	local text = Instance.new("TextLabel")
	text.Name = name
	text.Size = size
	text.Position = position
	text.BackgroundColor3 = Color3.new(0, 0, 0)
	text.BackgroundTransparency = 0.45
	text.TextColor3 = Color3.new(1, 1, 1)
	text.Font = Enum.Font.GothamMedium
	text.TextSize = 14
	text.TextXAlignment = Enum.TextXAlignment.Left
	text.TextYAlignment = Enum.TextYAlignment.Top
	text.RichText = true
	text.Parent = parent
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 8)
	padding.PaddingTop = UDim.new(0, 6)
	padding.Parent = text
	return text
end

local function buildPicker(gui: ScreenGui)
	picker = Instance.new("Frame")
	picker.Name = "CharacterPicker"
	picker.AnchorPoint = Vector2.new(0.5, 0.5)
	picker.Position = UDim2.fromScale(0.5, 0.5)
	picker.Size = UDim2.new(0, 360, 0.7, 0)
	picker.BackgroundColor3 = Color3.fromRGB(12, 12, 16)
	picker.BackgroundTransparency = 0.15
	picker.Visible = false
	picker.Parent = gui

	local scroll = Instance.new("ScrollingFrame")
	scroll.Size = UDim2.fromScale(1, 1)
	scroll.BackgroundTransparency = 1
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.new()
	scroll.ScrollBarThickness = 6
	scroll.Parent = picker

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 4)
	layout.Parent = scroll

	local selectRemote = Remotes.func("SelectCharacter")
	for _, config in CharacterRegistry.list(true) do
		local button = Instance.new("TextButton")
		button.Size = UDim2.new(1, -10, 0, 44)
		button.BackgroundColor3 = config.Palette.Primary
		button.TextColor3 = Color3.new(1, 1, 1)
		button.TextStrokeTransparency = 0.4
		button.Font = Enum.Font.GothamBold
		button.TextSize = 15
		local hp = BalanceConfig.Roles[config.Role].Health
		button.Text = `{config.DisplayName}  ·  {config.Role}  ·  {hp} HP`
		button.Parent = scroll
		button.Activated:Connect(function()
			local ok, success, reason = pcall(function()
				return selectRemote:InvokeServer(config.Id)
			end)
			if ok and success then
				picker.Visible = false
				notice("Switched to " .. config.DisplayName)
			else
				notice(if ok and type(reason) == "string" then reason else "Switch failed")
			end
		end)
	end
end

local function cooldownText(slot: string, now: number): string
	local readyAt = player:GetAttribute("ApexCD_" .. slot)
	if type(readyAt) == "number" and readyAt > now then
		return string.format("%s <font color='#ff8080'>%.1fs</font>", slot, readyAt - now)
	end
	return slot .. " <font color='#80ff80'>ready</font>"
end

local function update()
	local now = workspace:GetServerTimeNow()
	local id = player:GetAttribute("ApexCharacter")
	local config = if type(id) == "string" then CharacterRegistry.get(id) else nil
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local hp = if humanoid then string.format("%d / %d", math.ceil(humanoid.Health), humanoid.MaxHealth) else "-"
	local stamina = player:GetAttribute("ApexStamina") or 0
	local ult = player:GetAttribute("ApexUltimate") or 0
	local inCombat = player:GetAttribute("ApexInCombat") == true
	local lines = {
		"<b>APEX CITY · debug HUD</b>",
		"Character: " .. (if config then config.DisplayName .. " (" .. config.Role .. ")" else "-"),
		"HP: " .. hp,
		string.format("Stamina: %d / %d", stamina :: number, BalanceConfig.Stamina.Max),
		string.format("Ultimate: %d%%", math.floor((ult :: number) / BalanceConfig.Ultimate.Max * 100)),
		"Combat: " .. (if inCombat then "<font color='#ff8080'>IN COMBAT</font>" else "out of combat"),
		"Input: " .. InputController.getDevice(),
	}
	for _, slot in CharacterRegistry.Slots do
		table.insert(lines, cooldownText(slot, now))
	end
	statusLabel.Text = table.concat(lines, "\n")
end

function DebugHud.init()
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false) -- Tab is character select
	end)

	local gui = Instance.new("ScreenGui")
	gui.Name = "ApexDebugHud"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false
	gui.Parent = player:WaitForChild("PlayerGui")

	statusLabel = label(gui, "Status", UDim2.fromOffset(250, 200), UDim2.fromOffset(10, 10))
	noticeLabel = label(gui, "Notice", UDim2.fromOffset(320, 30), UDim2.new(0.5, -160, 0, 10))
	noticeLabel.TextXAlignment = Enum.TextXAlignment.Center
	noticeLabel.Visible = false

	local charsButton = Instance.new("TextButton")
	charsButton.Name = "CharsButton"
	charsButton.Size = UDim2.fromOffset(90, 34)
	charsButton.Position = UDim2.fromOffset(10, 216)
	charsButton.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
	charsButton.TextColor3 = Color3.new(1, 1, 1)
	charsButton.Font = Enum.Font.GothamBold
	charsButton.TextSize = 14
	charsButton.Text = "Chars (Tab)"
	charsButton.Parent = gui

	buildPicker(gui)

	charsButton.Activated:Connect(function()
		picker.Visible = not picker.Visible
	end)
	InputController.Began:Connect(function(action: string)
		if action == "CharacterSelect" then
			picker.Visible = not picker.Visible
		end
	end)

	Remotes.event("Notify").OnClientEvent:Connect(function(text: any)
		if type(text) == "string" then
			notice(text)
		end
	end)

	local elapsed = 0
	RunService.RenderStepped:Connect(function(dt)
		elapsed += dt
		if elapsed >= 0.1 then
			elapsed = 0
			update()
		end
	end)
end

return DebugHud
