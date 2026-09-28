--!strict
-- Tiny UI helpers + the shared visual style (minimal, clean, cinematic).

local Ui = {}

Ui.Colors = {
	Panel = Color3.fromRGB(12, 13, 17),
	PanelLight = Color3.fromRGB(28, 30, 38),
	Text = Color3.fromRGB(240, 240, 245),
	Muted = Color3.fromRGB(150, 154, 166),
	Health = Color3.fromRGB(235, 70, 70),
	HealthLow = Color3.fromRGB(255, 40, 40),
	Stamina = Color3.fromRGB(90, 200, 255),
	Ultimate = Color3.fromRGB(255, 200, 60),
	Heat = Color3.fromRGB(255, 120, 50),
	Posture = Color3.fromRGB(200, 200, 215),
}

Ui.Font = Enum.Font.GothamBold
Ui.FontLight = Enum.Font.GothamMedium

function Ui.new(className: string, props: { [string]: any }, children: { any }?): Instance
	local instance = Instance.new(className :: any)
	for key, value in props do
		if key ~= "Parent" then
			(instance :: any)[key] = value
		end
	end
	if children then
		for _, child in children do
			(child :: Instance).Parent = instance
		end
	end
	if props.Parent then
		instance.Parent = props.Parent
	end
	return instance
end

function Ui.corner(radius: number): any
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	return corner
end

function Ui.stroke(color: Color3, thickness: number, transparency: number?): any
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = thickness
	stroke.Transparency = transparency or 0
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	return stroke
end

function Ui.label(text: string, size: number, color: Color3?, font: Enum.Font?): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextSize = size
	label.TextColor3 = color or Ui.Colors.Text
	label.Font = font or Ui.Font
	label.TextXAlignment = Enum.TextXAlignment.Left
	return label
end

-- A horizontal bar: returns the frame and a setter(fraction, color?).
function Ui.bar(parent: Instance, size: UDim2, position: UDim2, color: Color3): (Frame, (number, Color3?) -> ())
	local back = Ui.new("Frame", {
		Size = size,
		Position = position,
		BackgroundColor3 = Color3.fromRGB(20, 20, 26),
		BackgroundTransparency = 0.25,
		BorderSizePixel = 0,
		Parent = parent,
	}, { Ui.corner(4) }) :: Frame
	local trail = Ui.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.5,
		BorderSizePixel = 0,
		Parent = back,
	}, { Ui.corner(4) }) :: Frame
	local fill = Ui.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Parent = back,
	}, { Ui.corner(4) }) :: Frame
	local trailShown = 1
	local function set(fraction: number, newColor: Color3?)
		fraction = math.clamp(fraction, 0, 1)
		fill.Size = UDim2.fromScale(fraction, 1)
		if newColor then
			fill.BackgroundColor3 = newColor
		end
		-- damage trail catches up slowly
		if fraction > trailShown then
			trailShown = fraction
		else
			trailShown += (fraction - trailShown) * 0.08
		end
		trail.Size = UDim2.fromScale(trailShown, 1)
	end
	return back, set
end

-- Radial cooldown sweep over a square frame: setter(fraction 0..1 remaining).
function Ui.sweep(parent: Frame): (number) -> ()
	local halves: { Frame } = {}
	for i = 0, 1 do
		local clip = Ui.new("Frame", {
			Size = UDim2.fromScale(0.5, 1),
			Position = UDim2.fromScale(i * 0.5, 0),
			BackgroundTransparency = 1,
			ClipsDescendants = true,
			ZIndex = 5,
			Parent = parent,
		}) :: Frame
		local disc = Ui.new("Frame", {
			Size = UDim2.fromScale(2, 1),
			Position = UDim2.fromScale(-i, 0),
			BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = 0.35,
			BorderSizePixel = 0,
			ZIndex = 5,
			Parent = clip,
		}, { Ui.corner(1000) }) :: Frame
		local gradient = Instance.new("UIGradient")
		gradient.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.4999, 0),
			NumberSequenceKeypoint.new(0.5, 1),
			NumberSequenceKeypoint.new(1, 1),
		})
		gradient.Parent = disc
		table.insert(halves, disc)
	end
	return function(fraction: number)
		fraction = math.clamp(fraction, 0, 1)
		local angle = fraction * 360
		-- right half covers 0..180, left half 180..360 (clockwise from top)
		local right = halves[2]:FindFirstChildOfClass("UIGradient") :: UIGradient
		local left = halves[1]:FindFirstChildOfClass("UIGradient") :: UIGradient
		halves[2].Visible = fraction > 0
		halves[1].Visible = fraction > 0.5
		-- The gradient's opaque half covers `Rotation` degrees clockwise from the top
		right.Rotation = math.min(angle, 180)
		left.Rotation = math.clamp(angle, 180, 360)
	end
end

return Ui
