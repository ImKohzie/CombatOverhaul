--!strict
-- Procedural R15 poses (Motor6D.Transform values) used until real
-- animation assets are added to the AssetRegistry. Angles are radians.
--
-- Axis cheat sheet (joint space):
--   Shoulder/Hip  +X = swing limb forward/up   Z = spread out (+ right side)
--   Elbow         +X = bend forearm forward    Knee -X = bend shin back
--   Neck          +X = look up                 Waist -X = lean forward
--   Root          translation lowers/raises the whole body

export type Pose = { [string]: CFrame }

local rad = math.rad

local function a(x: number, y: number?, z: number?): CFrame
	return CFrame.Angles(rad(x), rad(y or 0), rad(z or 0))
end

local PoseLibrary = {}

PoseLibrary.Motors = {
	"Root", "Waist", "Neck",
	"LeftShoulder", "RightShoulder", "LeftElbow", "RightElbow",
	"LeftHip", "RightHip", "LeftKnee", "RightKnee",
}

-- Upright hover: relaxed arms, one knee lifted.
PoseLibrary.Hover = {
	Waist = a(-4),
	Neck = a(0),
	RightShoulder = a(10, 0, 14),
	LeftShoulder = a(10, 0, -14),
	RightElbow = a(18),
	LeftElbow = a(18),
	RightHip = a(28),
	RightKnee = a(-45),
	LeftHip = a(6),
	LeftKnee = a(-12),
} :: Pose

-- Classic superhero flight: body is tilted horizontal by the flight
-- controller; right fist leads, left arm trails, legs straight.
PoseLibrary.Superhero = {
	Waist = a(0),
	Neck = a(55),
	RightShoulder = a(172, 0, 4),
	RightElbow = a(0),
	LeftShoulder = a(-18, 0, -8),
	LeftElbow = a(10),
	RightHip = a(-4),
	RightKnee = a(-6),
	LeftHip = a(-8),
	LeftKnee = a(-18),
} :: Pose

-- Board / glider stance: knees bent, arms out for balance.
PoseLibrary.Surf = {
	Root = CFrame.new(0, -0.35, 0),
	Waist = a(-12),
	Neck = a(10),
	RightShoulder = a(18, 0, 55),
	LeftShoulder = a(18, 0, -55),
	RightElbow = a(15),
	LeftElbow = a(15),
	RightHip = a(32),
	RightKnee = a(-40),
	LeftHip = a(32),
	LeftKnee = a(-40),
} :: Pose

-- Superhero landing: one knee down, fist to the ground, head up.
PoseLibrary.HeroLanding = {
	Root = CFrame.new(0, -1.3, 0),
	Waist = a(-32),
	Neck = a(35),
	RightShoulder = a(25, 0, 8),
	RightElbow = a(10),
	LeftShoulder = a(-40, 0, -25),
	LeftElbow = a(20),
	RightHip = a(85),
	RightKnee = a(-90),
	LeftHip = a(-15),
	LeftKnee = a(-105),
} :: Pose

-- Blend two poses; missing joints count as identity.
function PoseLibrary.blend(from: Pose, to: Pose, alpha: number): Pose
	local result: Pose = {}
	for _, motor in PoseLibrary.Motors do
		local a0 = from[motor] or CFrame.identity
		local a1 = to[motor] or CFrame.identity
		result[motor] = a0:Lerp(a1, alpha)
	end
	return result
end

-- Scale a pose toward identity (weight 0 = no effect).
function PoseLibrary.weight(pose: Pose, weight: number): Pose
	local result: Pose = {}
	for motor, cf in pose do
		result[motor] = CFrame.identity:Lerp(cf, weight)
	end
	return result
end

return PoseLibrary
