--!strict
-- Kill feed (top-right, under the minimap). Entries fade after a few seconds.

local TweenService = game:GetService("TweenService")

local HudEvents = require(script.Parent.Parent.HudEvents)
local Ui = require(script.Parent.Ui)

local KillFeed = {}

local list: Frame
local order = 0

local function add(killer: string?, victim: string, tag: string?)
	order += 1
	local text = if killer
		then string.format("<b>%s</b>  <font color='#ffcc55'>[%s]</font>  %s", killer, tag or "KO", victim)
		else string.format("%s  <font color='#aaaaaa'>was knocked out</font>", victim)
	local entry = Ui.new("TextLabel", {
		Size = UDim2.fromOffset(300, 24),
		BackgroundColor3 = Ui.Colors.Panel,
		BackgroundTransparency = 0.35,
		RichText = true,
		Text = text,
		TextColor3 = Ui.Colors.Text,
		TextSize = 14,
		Font = Ui.FontLight,
		TextXAlignment = Enum.TextXAlignment.Right,
		LayoutOrder = order,
		Parent = list,
	}, { Ui.corner(4), Ui.new("UIPadding", { PaddingRight = UDim.new(0, 8) }) }) :: TextLabel
	task.delay(6, function()
		TweenService:Create(entry, TweenInfo.new(0.6), { BackgroundTransparency = 1, TextTransparency = 1 }):Play()
		task.wait(0.6)
		entry:Destroy()
	end)
	local count = 0
	for _, child in list:GetChildren() do
		if child:IsA("TextLabel") then
			count += 1
		end
	end
	if count > 6 then
		local oldest: TextLabel? = nil
		for _, child in list:GetChildren() do
			if child:IsA("TextLabel") and (not oldest or child.LayoutOrder < oldest.LayoutOrder) then
				oldest = child
			end
		end
		if oldest then
			oldest:Destroy()
		end
	end
end

function KillFeed.init(parent: Instance)
	list = Ui.new("Frame", {
		Name = "KillFeed",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 216),
		Size = UDim2.fromOffset(300, 200),
		BackgroundTransparency = 1,
		Parent = parent,
	}, {
		Ui.new("UIListLayout", {
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			Padding = UDim.new(0, 4),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}) :: Frame
	HudEvents.KillFeed:Connect(add)
end

return KillFeed
