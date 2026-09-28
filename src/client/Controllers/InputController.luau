--!strict
-- Binds every action in InputConfig through ContextActionService so the
-- same action works on keyboard/mouse, gamepad and touch. Other controllers
-- listen to Began/Ended instead of reading raw input.

local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("ApexCity")
local InputConfig = require(Shared.Config.InputConfig)
local Signal = require(Shared.Util.Signal)

export type Device = string -- "KeyboardMouse" | "Gamepad" | "Touch"

local InputController = {}

InputController.Began = Signal.new() -- (action: string)
InputController.Ended = Signal.new() -- (action: string, heldFor: number)
InputController.DeviceChanged = Signal.new() -- (device: Device)

local heldSince: { [string]: number } = {}
local device: Device = "KeyboardMouse"

function InputController.isHeld(action: string): boolean
	return heldSince[action] ~= nil
end

function InputController.getDevice(): Device
	return device
end

local function deviceFor(inputType: Enum.UserInputType): Device?
	if inputType == Enum.UserInputType.Touch then
		return "Touch"
	elseif inputType.Name:sub(1, 7) == "Gamepad" then
		return "Gamepad"
	elseif inputType == Enum.UserInputType.Keyboard or inputType.Name:sub(1, 5) == "Mouse" then
		return "KeyboardMouse"
	end
	return nil
end

local function bind(name: string, binding: InputConfig.Binding)
	local actionName = "Apex_" .. name
	local inputs: { any } = {}
	for _, input in binding.Keys do
		table.insert(inputs, input)
	end
	for _, input in binding.Gamepad do
		table.insert(inputs, input)
	end

	local function handler(_: string, inputState: Enum.UserInputState, _input: InputObject): Enum.ContextActionResult
		if inputState == Enum.UserInputState.Begin then
			if not heldSince[name] then
				heldSince[name] = os.clock()
				InputController.Began:Fire(name)
			end
		elseif inputState == Enum.UserInputState.End or inputState == Enum.UserInputState.Cancel then
			local started = heldSince[name]
			if started then
				heldSince[name] = nil
				InputController.Ended:Fire(name, os.clock() - started)
			end
		end
		return if binding.Sink then Enum.ContextActionResult.Sink else Enum.ContextActionResult.Pass
	end

	ContextActionService:BindActionAtPriority(actionName, handler, binding.TouchButton, InputConfig.ActionPriority, table.unpack(inputs))

	if binding.TouchButton then
		if binding.TouchTitle then
			ContextActionService:SetTitle(actionName, binding.TouchTitle)
		end
		if binding.TouchPosition then
			ContextActionService:SetPosition(actionName, binding.TouchPosition)
		end
	end
end

function InputController.init()
	for name, binding in InputConfig.Actions do
		bind(name, binding)
	end

	local initial = deviceFor(UserInputService:GetLastInputType())
	if initial then
		device = initial
	elseif UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		device = "Touch"
	end
	UserInputService.LastInputTypeChanged:Connect(function(inputType)
		local newDevice = deviceFor(inputType)
		if newDevice and newDevice ~= device then
			device = newDevice
			InputController.DeviceChanged:Fire(device)
		end
	end)
end

return InputController
