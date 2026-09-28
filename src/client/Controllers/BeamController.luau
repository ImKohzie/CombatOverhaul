--!strict
-- Beam visuals. The caster's client traces its beam every frame to the
-- crosshair and streams aim to the server (~15Hz); everyone else draws the
-- beam toward the server's 10Hz end points (smoothed). Visual layers: core
-- Beam + outer glow Beam + impact sparks + PointLight + scorch marks +
-- light camera shake + hum.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("ApexCity")
local BalanceConfig = require(Shared.Config.BalanceConfig)
local Remotes = require(Shared.Net.Remotes)

local AbilityInputController = require(script.Parent.AbilityInputController)
local CameraController = require(script.Parent.CameraController)
local EffectsController = require(script.Parent.EffectsController)
local SoundLibrary = require(script.Parent.SoundLibrary)

local player = Players.LocalPlayer

local AIM_SEND_INTERVAL = 1 / 15

local BeamController = {}

type Visual = {
	id: string,
	source: Model,
	sourceKind: string,
	twin: boolean,
	sweep: boolean,
	range: number,
	color: Color3,
	width: number,
	origins: { Attachment },
	endPart: Part,
	beams: { Beam },
	sparks: ParticleEmitter,
	light: PointLight,
	hum: Sound?,
	targetEnd: Vector3,
	currentEnd: Vector3,
	hit: boolean,
	normal: Vector3,
	lastScorch: number,
	isLocal: boolean,
}

local visuals: { [string]: Visual } = {}
local combatRemote: RemoteEvent
local lastAimSend = 0

local function key(source: Instance, id: string): string
	return source:GetFullName() .. "|" .. id
end

local function effectsFolder(): Instance
	return workspace:FindFirstChild("ApexClientEffects") or workspace
end

local function originAttachments(source: Model, sourceKind: string, twin: boolean): { Attachment }
	local list: { Attachment } = {}
	local function make(parent: Instance?, offset: Vector3)
		if parent and parent:IsA("BasePart") then
			local attachment = Instance.new("Attachment")
			attachment.Name = "ApexBeamOrigin"
			attachment.Position = offset
			attachment.Parent = parent
			table.insert(list, attachment)
		end
	end
	if sourceKind == "Eyes" then
		local head = source:FindFirstChild("Head")
		if twin then
			make(head, Vector3.new(-0.2, 0.15, -0.6))
			make(head, Vector3.new(0.2, 0.15, -0.6))
		else
			make(head, Vector3.new(0, 0.15, -0.6))
		end
	elseif sourceKind == "Hands" then
		make(source:FindFirstChild("RightHand") or source:FindFirstChild("Right Arm"), Vector3.new(0, -0.3, 0))
		make(source:FindFirstChild("LeftHand") or source:FindFirstChild("Left Arm"), Vector3.new(0, -0.3, 0))
	end
	if #list == 0 then
		make(source:FindFirstChild("HumanoidRootPart"), Vector3.new(0, 1, -1.5))
	end
	return list
end

local function setEyeGlow(source: Model, on: boolean)
	for _, child in source:GetChildren() do
		if child.Name == "ApexEye" and child:IsA("BasePart") then
			child.Transparency = if on then 0 else 0.85
		end
	end
end

local function makeBeam(a0: Attachment, a1: Attachment, width: number, color: Color3, transparency: number, emission: number): Beam
	local beam = Instance.new("Beam")
	beam.Attachment0 = a0
	beam.Attachment1 = a1
	beam.Width0 = width
	beam.Width1 = width
	beam.FaceCamera = true
	beam.Segments = 1
	beam.LightEmission = emission
	beam.LightInfluence = 0
	beam.Color = ColorSequence.new(color)
	beam.Transparency = NumberSequence.new(transparency)
	beam.Parent = a0
	return beam
end

local function start(payload: { [string]: any })
	local source = payload.Source
	local id = payload.Id
	if typeof(source) ~= "Instance" or not source:IsA("Model") or type(id) ~= "string" then
		return
	end
	local k = key(source, id)
	if visuals[k] then
		return
	end
	local color = if typeof(payload.Color) == "Color3" then payload.Color else Color3.new(1, 0.2, 0.2)
	local width = if type(payload.Width) == "number" then payload.Width else 0.5
	local sourceKind = if type(payload.SourceKind) == "string" then payload.SourceKind else "Hands"
	local twin = payload.Twin == true
	local initialEnd = if typeof(payload.End) == "Vector3" then payload.End else (source:GetPivot().Position + source:GetPivot().LookVector * 50)

	local endPart = Instance.new("Part")
	endPart.Name = "ApexBeamEnd"
	endPart.Anchored = true
	endPart.CanCollide = false
	endPart.CanQuery = false
	endPart.CanTouch = false
	endPart.Transparency = 1
	endPart.Size = Vector3.new(0.2, 0.2, 0.2)
	endPart.CFrame = CFrame.new(initialEnd)
	endPart.Parent = effectsFolder()
	local endAttachment = Instance.new("Attachment")
	endAttachment.Parent = endPart

	local origins = originAttachments(source, sourceKind, twin)
	local beams: { Beam } = {}
	for _, origin in origins do
		table.insert(beams, makeBeam(origin, endAttachment, width, Color3.new(1, 1, 1):Lerp(color, 0.35), 0, 1))
		table.insert(beams, makeBeam(origin, endAttachment, width * 3.2, color, 0.55, 1))
	end

	local sparks = Instance.new("ParticleEmitter")
	sparks.Color = ColorSequence.new(Color3.new(1, 1, 1), color)
	sparks.LightEmission = 1
	sparks.Size = NumberSequence.new(width * 0.9, 0)
	sparks.Lifetime = NumberRange.new(0.15, 0.35)
	sparks.Speed = NumberRange.new(15, 35)
	sparks.SpreadAngle = Vector2.new(70, 70)
	sparks.Rate = 90
	sparks.Drag = 3
	sparks.Parent = endAttachment
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 10 + width * 6
	light.Brightness = 4
	light.Parent = endPart

	local isLocal = source == player.Character
	local visual: Visual = {
		id = id,
		source = source,
		sourceKind = sourceKind,
		twin = twin,
		sweep = payload.Sweep == true,
		range = if type(payload.Range) == "number" then payload.Range else 300,
		color = color,
		width = width,
		origins = origins,
		endPart = endPart,
		beams = beams,
		sparks = sparks,
		light = light,
		hum = SoundLibrary.play("Sound.Beam.Hum", { Parent = origins[1] :: Instance, Looped = true, Volume = 0.5, Pitch = 1.8 }),
		targetEnd = initialEnd,
		currentEnd = initialEnd,
		hit = true,
		normal = Vector3.yAxis,
		lastScorch = 0,
		isLocal = isLocal,
	}
	visuals[k] = visual
	if sourceKind == "Eyes" then
		setEyeGlow(source, true)
	end
end

local function stop(payload: { [string]: any })
	local source = payload.Source
	local id = payload.Id
	if typeof(source) ~= "Instance" or type(id) ~= "string" then
		return
	end
	local k = key(source, id)
	local visual = visuals[k]
	if not visual then
		return
	end
	visuals[k] = nil
	for _, origin in visual.origins do
		origin:Destroy()
	end
	if visual.hum then
		visual.hum:Destroy()
	end
	visual.sparks.Enabled = false
	Debris:AddItem(visual.endPart, 0.4)
	if visual.sourceKind == "Eyes" and visual.source.Parent then
		setEyeGlow(visual.source, false)
	end
end

local function update(payload: { [string]: any })
	local source = payload.Source
	local id = payload.Id
	if typeof(source) ~= "Instance" or type(id) ~= "string" then
		return
	end
	local visual = visuals[key(source, id)]
	if not visual or typeof(payload.End) ~= "Vector3" then
		return
	end
	if visual.isLocal and not visual.sweep then
		return -- local beam follows the crosshair directly
	end
	visual.targetEnd = payload.End
	visual.hit = payload.Hit == true
	if typeof(payload.Normal) == "Vector3" then
		visual.normal = payload.Normal
	end
end

local function scorch(position: Vector3, normal: Vector3, color: Color3, size: number)
	local mark = Instance.new("Part")
	mark.Name = "ApexScorch"
	mark.Anchored = true
	mark.CanCollide = false
	mark.CanQuery = false
	mark.CanTouch = false
	mark.CastShadow = false
	mark.Shape = Enum.PartType.Cylinder
	mark.Material = Enum.Material.Slate
	mark.Color = Color3.fromRGB(25, 20, 18)
	mark.Size = Vector3.new(0.06, size, size)
	-- Cylinder axis (X) along the surface normal
	local tangent = normal:Cross(Vector3.zAxis)
	if tangent.Magnitude < 1e-3 then
		tangent = normal:Cross(Vector3.xAxis)
	end
	mark.CFrame = CFrame.fromMatrix(position + normal * 0.03, normal, tangent.Unit)
	mark.Parent = effectsFolder()
	-- Glowing ember rim that cools
	local ember = mark:Clone()
	ember.Material = Enum.Material.Neon
	ember.Color = color
	ember.Size = Vector3.new(0.05, size * 0.55, size * 0.55)
	ember.CFrame = mark.CFrame * CFrame.new(0.01, 0, 0)
	ember.Parent = effectsFolder()
	TweenService:Create(ember, TweenInfo.new(1.2), { Transparency = 1 }):Play()
	Debris:AddItem(ember, 1.3)
	task.delay(8, function()
		if mark.Parent then
			TweenService:Create(mark, TweenInfo.new(2), { Transparency = 1 }):Play()
			Debris:AddItem(mark, 2.1)
		end
	end)
end

local function render(dt: number)
	local now = os.clock()
	for _, visual in table.clone(visuals) do
		if visual.source.Parent == nil or visual.endPart.Parent == nil then
			stop({ Source = visual.source, Id = visual.id })
			continue
		end
		if visual.isLocal and not visual.sweep then
			local origin = visual.origins[1] and visual.origins[1].WorldPosition
			local _, aimPoint = AbilityInputController.getAim()
			if origin and aimPoint then
				local dir = aimPoint - origin
				if dir.Magnitude > 1e-3 then
					local params = RaycastParams.new()
					params.FilterType = Enum.RaycastFilterType.Exclude
					params.FilterDescendantsInstances = { visual.source, effectsFolder() }
					local hit = workspace:Raycast(origin, dir.Unit * visual.range, params)
					visual.targetEnd = if hit then hit.Position else origin + dir.Unit * visual.range
					visual.hit = hit ~= nil
					visual.normal = if hit then hit.Normal else Vector3.yAxis
				end
				if now - lastAimSend >= AIM_SEND_INTERVAL then
					lastAimSend = now
					combatRemote:FireServer("BeamAim", aimPoint)
				end
			end
			CameraController.shake(0.012)
		end
		local smoothing = if visual.isLocal and not visual.sweep then 1 else math.min(1, dt * 14)
		visual.currentEnd = visual.currentEnd:Lerp(visual.targetEnd, smoothing)
		visual.endPart.CFrame = CFrame.new(visual.currentEnd)
		visual.sparks.Enabled = visual.hit
		visual.light.Enabled = visual.hit
		-- Flicker
		local flicker = 0.9 + math.random() * 0.2
		for i, beam in visual.beams do
			local base = if i % 2 == 1 then visual.width else visual.width * 3.2
			beam.Width0 = base * flicker
			beam.Width1 = base * flicker * 1.15
		end
		if visual.hit and now - visual.lastScorch >= BalanceConfig.Beam.ScorchInterval then
			visual.lastScorch = now
			scorch(visual.currentEnd, visual.normal, visual.color, 0.8 + visual.width * 1.5)
		end
	end
end

function BeamController.init()
	combatRemote = Remotes.event("CombatInput")
	EffectsController.register("BeamStart", start)
	EffectsController.register("BeamStop", stop)
	EffectsController.register("BeamUpdate", update)
	RunService.RenderStepped:Connect(render)
end

return BeamController
