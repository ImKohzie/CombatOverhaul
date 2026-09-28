--!strict
-- Street furniture and small props: street lamps, traffic lights, parked
-- cars and taxis, steam vents, benches, hydrants, billboards, trees.
-- Lights are tagged "ApexStreetLight" so the day/night cycle can switch them.

local Builder = require(script.Parent.Builder)

local Props = {}

local METAL_DARK = Color3.fromRGB(38, 40, 44)

function Props.streetLamp(parent: Instance, base: Vector3, facing: Vector3)
	local model = Builder.model(parent, "StreetLamp")
	Builder.part(model, "Pole", Vector3.new(0.6, 16, 0.6), CFrame.new(base + Vector3.new(0, 8, 0)), METAL_DARK, Enum.Material.Metal)
	local armEnd = base + Vector3.new(0, 15.6, 0) + facing * 4
	Builder.decor(model, "Arm", Vector3.new(0.4, 0.4, 4.4), CFrame.lookAt(base + Vector3.new(0, 15.6, 0) + facing * 2, armEnd), METAL_DARK, Enum.Material.Metal)
	local head = Builder.decor(model, "Head", Vector3.new(1.6, 0.6, 2.4), CFrame.lookAt(armEnd, armEnd + facing) * CFrame.new(0, -0.3, 0), Color3.fromRGB(255, 228, 180), Enum.Material.Glass)
	head:SetAttribute("ApexLampHead", true)
	Builder.tag(head, "ApexLampHead")
	local light = Instance.new("SpotLight")
	light.Face = Enum.NormalId.Bottom
	light.Angle = 110
	light.Range = 40
	light.Brightness = 0
	light.Color = Color3.fromRGB(255, 214, 160)
	light.Shadows = false
	light.Parent = head
	Builder.tag(light, "ApexStreetLight")
end

function Props.trafficLight(parent: Instance, base: Vector3, facing: Vector3)
	local model = Builder.model(parent, "TrafficLight")
	Builder.part(model, "Pole", Vector3.new(0.7, 14, 0.7), CFrame.new(base + Vector3.new(0, 7, 0)), Color3.fromRGB(50, 52, 40), Enum.Material.Metal)
	local armCenter = base + Vector3.new(0, 13.5, 0) + facing * 5
	Builder.decor(model, "Arm", Vector3.new(0.5, 0.5, 10), CFrame.lookAt(armCenter, armCenter + facing), Color3.fromRGB(50, 52, 40), Enum.Material.Metal)
	local boxPos = base + Vector3.new(0, 12.2, 0) + facing * 9
	local box = Builder.decor(model, "Signal", Vector3.new(1.4, 4, 1.2), CFrame.lookAt(boxPos, boxPos + facing:Cross(Vector3.yAxis)), Color3.fromRGB(30, 30, 25), Enum.Material.Metal)
	local colors = { Color3.fromRGB(255, 50, 40), Color3.fromRGB(255, 190, 40), Color3.fromRGB(60, 255, 90) }
	for i, color in colors do
		local bulb = Builder.decor(box, "Bulb", Vector3.new(0.9, 0.9, 0.3), box.CFrame * CFrame.new(0, 1.3 - (i - 1) * 1.3, -0.6), color, Enum.Material.Neon)
		bulb.Shape = Enum.PartType.Cylinder
		bulb.Transparency = if i == 3 then 0 else 0.7
		Builder.tag(bulb, "ApexTrafficBulb")
		bulb:SetAttribute("ApexBulb", i)
	end
end

local CAR_COLORS = {
	Color3.fromRGB(30, 32, 36), Color3.fromRGB(180, 182, 186), Color3.fromRGB(120, 20, 24),
	Color3.fromRGB(28, 50, 90), Color3.fromRGB(230, 230, 228), Color3.fromRGB(60, 70, 60),
}

function Props.car(parent: Instance, cframe: CFrame, rng: Random, taxi: boolean?): Model
	local model = Builder.model(parent, if taxi then "Taxi" else "Car")
	local color = if taxi then Color3.fromRGB(245, 190, 20) else CAR_COLORS[rng:NextInteger(1, #CAR_COLORS)]
	local body = Builder.part(model, "Body", Vector3.new(6.4, 2.4, 14), cframe * CFrame.new(0, 2.2, 0), color, Enum.Material.SmoothPlastic)
	body.Reflectance = 0.15
	body:SetAttribute("ApexChunk", "Steel")
	body:SetAttribute("ApexBuilding", "Vehicle")
	Builder.tag(body, "ApexStructure")
	Builder.tag(body, "ApexVehicle")
	local cabin = Builder.decor(body, "Cabin", Vector3.new(5.8, 2.2, 7), cframe * CFrame.new(0, 4.4, 0.8), Color3.fromRGB(40, 48, 56), Enum.Material.Glass)
	cabin.Reflectance = 0.3
	Builder.decor(body, "Roof", Vector3.new(5.9, 0.4, 6), cframe * CFrame.new(0, 5.6, 0.8), color, Enum.Material.SmoothPlastic)
	if taxi then
		local sign = Builder.decor(body, "TaxiSign", Vector3.new(2.4, 0.8, 0.8), cframe * CFrame.new(0, 6.2, 0.8), Color3.fromRGB(255, 240, 200), Enum.Material.Neon)
		Builder.tag(sign, "ApexNeon")
	end
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			local wheel = Builder.decor(body, "Wheel", Vector3.new(1, 2.6, 2.6), cframe * CFrame.new(sx * 3, 1.3, sz * 4.6), Color3.fromRGB(20, 20, 20), Enum.Material.Rubber)
			wheel.Shape = Enum.PartType.Cylinder
		end
	end
	-- Head / tail lights
	Builder.decor(body, "Headlights", Vector3.new(5.6, 0.5, 0.2), cframe * CFrame.new(0, 2.6, -7.05), Color3.fromRGB(255, 250, 230), Enum.Material.Neon)
	Builder.decor(body, "Taillights", Vector3.new(5.6, 0.5, 0.2), cframe * CFrame.new(0, 2.6, 7.05), Color3.fromRGB(200, 20, 20), Enum.Material.Neon)
	model.PrimaryPart = body
	return model
end

function Props.steamVent(parent: Instance, position: Vector3)
	local cover = Builder.decor(parent, "Manhole", Vector3.new(0.2, 3.2, 3.2), CFrame.new(position + Vector3.new(0, 0.05, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(40, 38, 36), Enum.Material.DiamondPlate)
	cover.Shape = Enum.PartType.Cylinder
	local steam = Instance.new("ParticleEmitter")
	steam.Color = ColorSequence.new(Color3.fromRGB(235, 235, 235))
	steam.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1) })
	steam.Size = NumberSequence.new(1.5, 7)
	steam.Lifetime = NumberRange.new(2, 3.5)
	steam.Speed = NumberRange.new(4, 7)
	steam.SpreadAngle = Vector2.new(10, 10)
	steam.EmissionDirection = Enum.NormalId.Right -- cylinder axis points up
	steam.Rate = 14
	steam.Parent = cover
	Builder.tag(cover, "ApexSteamVent")
end

function Props.bench(parent: Instance, cframe: CFrame)
	local model = Builder.model(parent, "Bench")
	Builder.part(model, "Seat", Vector3.new(6, 0.4, 1.8), cframe * CFrame.new(0, 1.8, 0), Color3.fromRGB(110, 76, 50), Enum.Material.WoodPlanks)
	Builder.decor(model, "Back", Vector3.new(6, 1.6, 0.3), cframe * CFrame.new(0, 3, 0.8), Color3.fromRGB(110, 76, 50), Enum.Material.WoodPlanks)
	for _, sx in { -2.6, 2.6 } do
		Builder.decor(model, "Leg", Vector3.new(0.3, 1.8, 1.6), cframe * CFrame.new(sx, 0.9, 0), METAL_DARK, Enum.Material.Metal)
	end
end

function Props.hydrant(parent: Instance, position: Vector3)
	Builder.pillar(parent, "Hydrant", position, 2.6, 1.2, Color3.fromRGB(190, 40, 30), Enum.Material.Metal)
end

function Props.billboard(parent: Instance, cframe: CFrame, brand: string, rng: Random)
	local model = Builder.model(parent, "Billboard")
	for _, sx in { -6, 6 } do
		Builder.part(model, "Post", Vector3.new(0.8, 10, 0.8), cframe * CFrame.new(sx, 5, 0), METAL_DARK, Enum.Material.Metal)
	end
	local board = Builder.part(model, "Board", Vector3.new(20, 8, 0.6), cframe * CFrame.new(0, 13, 0), Color3.fromRGB(20, 20, 24), Enum.Material.SmoothPlastic)
	local hue = rng:NextNumber()
	Builder.sign(board, Enum.NormalId.Front, brand, Color3.new(1, 1, 1), Color3.fromHSV(hue, 0.7, 0.55))
	Builder.sign(board, Enum.NormalId.Back, brand, Color3.new(1, 1, 1), Color3.fromHSV(hue, 0.7, 0.55))
	Builder.pointLight(board, Color3.fromHSV(hue, 0.5, 1), 18, 0, "ApexNeonLight")
	Builder.tag(board, "ApexBillboard")
end

-- Neon storefront sign on a wall (switched brighter at night).
function Props.neonSign(parent: Instance, cframe: CFrame, text: string, color: Color3)
	local sign = Builder.decor(parent, "NeonSign", Vector3.new(math.max(#text * 1.6, 6), 2.4, 0.3), cframe, Color3.fromRGB(15, 15, 18), Enum.Material.SmoothPlastic)
	Builder.sign(sign, Enum.NormalId.Front, text, color, nil, Enum.Font.Arcade)
	Builder.pointLight(sign, color, 12, 0, "ApexNeonLight")
	Builder.tag(sign, "ApexNeon")
end

function Props.deciduousTree(parent: Instance, base: Vector3, rng: Random, scale: number?)
	local s = (scale or 1) * rng:NextNumber(0.8, 1.3)
	local model = Builder.model(parent, "Tree")
	local height = 14 * s
	Builder.pillar(model, "Trunk", base - Vector3.new(0, 1, 0), height + 1, 1.8 * s, Color3.fromRGB(88, 64, 46), Enum.Material.Wood)
	local leafColor = Color3.fromHSV(rng:NextNumber(0.22, 0.33), rng:NextNumber(0.45, 0.7), rng:NextNumber(0.35, 0.55))
	for i = 1, 2 do
		local size = (11 - i * 2) * s
		local leaves = Builder.decor(model, "Leaves", Vector3.new(size, size * 0.85, size), CFrame.new(base + Vector3.new(rng:NextNumber(-1.5, 1.5) * s, height - 2 + i * 3 * s, rng:NextNumber(-1.5, 1.5) * s)), leafColor, Enum.Material.Grass)
		leaves.Shape = Enum.PartType.Ball
		leaves.CastShadow = true
	end
	Builder.tag(model, "ApexTree")
end

function Props.conifer(parent: Instance, base: Vector3, rng: Random)
	local s = rng:NextNumber(0.8, 1.5)
	local model = Builder.model(parent, "Pine")
	local height = 22 * s
	Builder.pillar(model, "Trunk", base - Vector3.new(0, 1, 0), height * 0.5, 1.6 * s, Color3.fromRGB(80, 58, 42), Enum.Material.Wood)
	local green = Color3.fromHSV(rng:NextNumber(0.3, 0.38), 0.55, rng:NextNumber(0.25, 0.38))
	for i = 0, 2 do
		local width = (10 - i * 3) * s
		local tier = Builder.decor(model, "Needles", Vector3.new(height * 0.35, width, width), CFrame.new(base + Vector3.new(0, height * (0.35 + i * 0.2), 0)) * CFrame.Angles(0, 0, math.rad(90)), green, Enum.Material.Grass)
		tier.Shape = Enum.PartType.Cylinder
		tier.CastShadow = true
	end
	Builder.tag(model, "ApexTree")
end

return Props
