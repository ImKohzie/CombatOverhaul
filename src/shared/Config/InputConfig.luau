--!strict
-- Action -> input bindings for PC, gamepad and mobile.
-- Jump / ascend is left to the default Roblox jump input (Space / A / mobile
-- jump button) so it keeps working everywhere; controllers read Humanoid.Jump.

export type Binding = {
	Keys: { Enum.KeyCode | Enum.UserInputType },
	Gamepad: { Enum.KeyCode },
	TouchButton: boolean,
	TouchTitle: string?,
	TouchPosition: UDim2?,
	-- Sink = consume the input; Pass = let default Roblox behaviour also see it
	-- (e.g. RMB so the default camera can still rotate until our camera exists).
	Sink: boolean,
}

local InputConfig = {}

InputConfig.ActionPriority = 2000 -- above default character/camera bindings

InputConfig.Actions = {
	Attack = {
		Keys = { Enum.UserInputType.MouseButton1 },
		Gamepad = { Enum.KeyCode.ButtonR2 },
		TouchButton = true,
		TouchTitle = "Hit",
		TouchPosition = UDim2.new(1, -95, 1, -170),
		Sink = false,
	},
	Aim = {
		Keys = { Enum.UserInputType.MouseButton2 },
		Gamepad = { Enum.KeyCode.ButtonL2 },
		TouchButton = true,
		TouchTitle = "Aim",
		TouchPosition = UDim2.new(1, -250, 1, -110),
		Sink = false,
	},
	Sprint = {
		Keys = { Enum.KeyCode.LeftShift },
		Gamepad = { Enum.KeyCode.ButtonL3 },
		TouchButton = true,
		TouchTitle = "Run",
		TouchPosition = UDim2.new(1, -250, 1, -170),
		Sink = true,
	},
	-- F: each character's signature movement (flyers: take off / burst)
	Movement = {
		Keys = { Enum.KeyCode.F },
		Gamepad = { Enum.KeyCode.ButtonB },
		TouchButton = true,
		TouchTitle = "Move",
		TouchPosition = UDim2.new(1, -170, 1, -230),
		Sink = true,
	},
	Block = {
		Keys = { Enum.KeyCode.X },
		Gamepad = { Enum.KeyCode.DPadLeft },
		TouchButton = true,
		TouchTitle = "Block",
		TouchPosition = UDim2.new(1, -330, 1, -110),
		Sink = true,
	},
	Descend = {
		Keys = { Enum.KeyCode.LeftControl },
		Gamepad = { Enum.KeyCode.ButtonR3 },
		TouchButton = true,
		TouchTitle = "Down",
		TouchPosition = UDim2.new(1, -95, 1, -250),
		Sink = true,
	},
	Dash = {
		Keys = { Enum.KeyCode.C },
		Gamepad = { Enum.KeyCode.DPadRight },
		TouchButton = true,
		TouchTitle = "Dash",
		TouchPosition = UDim2.new(1, -170, 1, -110),
		Sink = true,
	},
	Ability1 = {
		Keys = { Enum.KeyCode.Q },
		Gamepad = { Enum.KeyCode.ButtonX },
		TouchButton = true,
		TouchTitle = "Q",
		TouchPosition = UDim2.new(1, -330, 1, -230),
		Sink = true,
	},
	Ability2 = {
		Keys = { Enum.KeyCode.E },
		Gamepad = { Enum.KeyCode.ButtonY },
		TouchButton = true,
		TouchTitle = "E",
		TouchPosition = UDim2.new(1, -250, 1, -290),
		Sink = true,
	},
	Ability3 = {
		Keys = { Enum.KeyCode.R },
		Gamepad = { Enum.KeyCode.ButtonR1 },
		TouchButton = true,
		TouchTitle = "R",
		TouchPosition = UDim2.new(1, -170, 1, -330),
		Sink = true,
	},
	Ultimate = {
		Keys = { Enum.KeyCode.G },
		Gamepad = { Enum.KeyCode.ButtonL1 },
		TouchButton = true,
		TouchTitle = "ULT",
		TouchPosition = UDim2.new(1, -330, 1, -330),
		Sink = true,
	},
	CharacterSelect = {
		Keys = { Enum.KeyCode.Tab },
		Gamepad = { Enum.KeyCode.ButtonSelect },
		TouchButton = false, -- mobile uses an on-screen HUD button
		Sink = true,
	},
	Emote = {
		Keys = { Enum.KeyCode.V },
		Gamepad = { Enum.KeyCode.DPadDown },
		TouchButton = false,
		Sink = true,
	},
} :: { [string]: Binding }

-- Hold threshold that turns a tap into a hold (heavy attack, charged abilities).
InputConfig.HoldThreshold = 0.25

return InputConfig
