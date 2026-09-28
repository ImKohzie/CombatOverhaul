--!strict
-- Map border: as the player nears the edge (radius 3500) a shimmering wall
-- fades in with a warning; past it they are pushed back smoothly (no
-- teleports). Everything here is local to this client.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local MapConfig = require(ReplicatedStorage:WaitForChild("ApexCity").Config.MapConfig)

local HudEvents = require(script.Parent.Parent.HudEvents)
local EffectsController = require(script.Parent.EffectsController)
local MotionModifiers = require(script.Parent.MotionModifiers)

local player = Players.LocalPlayer

local PANELS = 9
local PANEL_WIDTH = 70
local PANEL_HEIGHT = 900

local BorderController = {}

local panels: { Part } = {}
local lastWarning = 0

local function build()
	for i = 1, PANELS do
		local panel = EffectsController.part()
		panel.Name = "ApexBorder"
		panel.Material = Enum.Material.ForceField
		panel.Color = Color3.fromRGB(140, 200, 255)
		panel.Size = Vector3.new(PANEL_WIDTH + 1, PANEL_HEIGHT, 0.5)
		panel.Transparency = 1
		panel.Parent = EffectsController.folder()
		panels[i] = panel
	end
end

local function step(dt: number)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return
	end
	local border = MapConfig.Border
	local flat = Vector3.new(root.Position.X, 0, root.Position.Z)
	local distance = flat.Magnitude
	local toEdge = border.Radius - distance
	local visibility = math.clamp(1 - toEdge / border.WarnDistance, 0, 1)

	-- Shimmer wall segments around the nearest border point
	if visibility > 0 and panels[1] and panels[1].Parent == nil then
		panels = {}
		build()
	end
	local angle = math.atan2(flat.Z, flat.X)
	local angleStep = PANEL_WIDTH / border.Radius
	for i, panel in panels do
		if visibility <= 0 then
			panel.Transparency = 1
			continue
		end
		local a = angle + (i - (PANELS + 1) / 2) * angleStep
		local position = Vector3.new(math.cos(a) * border.Radius, root.Position.Y, math.sin(a) * border.Radius)
		panel.CFrame = CFrame.lookAt(position, Vector3.new(0, root.Position.Y, 0))
		panel.Transparency = 1 - visibility * 0.75
	end

	if visibility > 0.6 and os.clock() - lastWarning > 4 then
		lastWarning = os.clock()
		HudEvents.Notify:Fire("You're reaching the edge of the map")
	end

	-- Smooth pushback once outside
	if toEdge < 0 then
		local inward = -flat.Unit
		local strength = border.PushStrength * math.clamp(-toEdge / 40 + 0.5, 0.5, 3)
		MotionModifiers.set("Border", inward * strength)
		if character:GetAttribute("ApexFlying") ~= true then
			local velocity = root.AssemblyLinearVelocity
			local outward = velocity:Dot(-inward)
			if outward > -strength then
				root.AssemblyLinearVelocity = velocity + inward * (strength + math.max(outward, 0)) * math.min(1, dt * 8)
			end
		end
	else
		MotionModifiers.set("Border", nil)
	end
end

function BorderController.init()
	build()
	RunService.Heartbeat:Connect(step)
end

return BorderController
