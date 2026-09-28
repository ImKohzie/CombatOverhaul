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

-- Guard: forearms crossed in front of the face.
PoseLibrary.Block = {
	Waist = a(-6),
	Neck = a(-8),
	RightShoulder = a(80, 0, -35),
	LeftShoulder = a(80, 0, 35),
	RightElbow = a(95),
	LeftElbow = a(95),
	RightHip = a(12),
	LeftHip = a(-8),
	RightKnee = a(-18),
	LeftKnee = a(-12),
} :: Pose

--------------------------------------------------------------------------------
-- Action sequences: keyframes over normalised time 0..1. The first key is
-- the wind-up, the key at ~WindUp/total is the strike (matches the hitbox).
--------------------------------------------------------------------------------
export type Keyframe = { T: number, Pose: Pose }
export type Action = { Keys: { Keyframe }, Duration: number }

local function seq(duration: number, keys: { Keyframe }): Action
	return { Duration = duration, Keys = keys }
end

local rest: Pose = {}

PoseLibrary.Actions = {
	-- M1 combo
	Combo1 = seq(0.34, { -- right straight
		{ T = 0, Pose = { Waist = a(0, 25, 0), RightShoulder = a(40, 0, 10), RightElbow = a(100) } },
		{ T = 0.3, Pose = { Waist = a(-6, -30, 0), RightShoulder = a(95, 0, -5), RightElbow = a(5), LeftShoulder = a(30), LeftElbow = a(90) } },
		{ T = 1, Pose = rest },
	}),
	Combo2 = seq(0.34, { -- left straight
		{ T = 0, Pose = { Waist = a(0, -25, 0), LeftShoulder = a(40, 0, -10), LeftElbow = a(100) } },
		{ T = 0.3, Pose = { Waist = a(-6, 30, 0), LeftShoulder = a(95, 0, 5), LeftElbow = a(5), RightShoulder = a(30), RightElbow = a(90) } },
		{ T = 1, Pose = rest },
	}),
	Combo3 = seq(0.4, { -- right hook
		{ T = 0, Pose = { Waist = a(0, 40, 0), RightShoulder = a(60, 0, 60), RightElbow = a(80) } },
		{ T = 0.3, Pose = { Waist = a(-8, -45, 0), RightShoulder = a(90, -50, -30), RightElbow = a(70) } },
		{ T = 1, Pose = rest },
	}),
	Combo4 = seq(0.71, { -- launching uppercut
		{ T = 0, Pose = { Root = CFrame.new(0, -0.8, 0), Waist = a(-20, 20, 0), LeftShoulder = a(-20, 0, -10), LeftElbow = a(120), RightHip = a(40), RightKnee = a(-60), LeftHip = a(-10) } },
		{ T = 0.23, Pose = { Root = CFrame.new(0, 0.3, 0), Waist = a(15, -15, 0), LeftShoulder = a(170, 0, -10), LeftElbow = a(20), Neck = a(20) } },
		{ T = 1, Pose = rest },
	}),
	Heavy = seq(0.82, { -- two-handed overhead smash
		{ T = 0, Pose = { Waist = a(20), Neck = a(10), RightShoulder = a(175, 0, 10), LeftShoulder = a(175, 0, -10), RightElbow = a(40), LeftElbow = a(40) } },
		{ T = 0.27, Pose = { Root = CFrame.new(0, -0.9, 0), Waist = a(-45), Neck = a(25), RightShoulder = a(60), LeftShoulder = a(60), RightHip = a(55), RightKnee = a(-70), LeftHip = a(-10), LeftKnee = a(-30) } },
		{ T = 1, Pose = rest },
	}),
	Charge = seq(0.6, { -- heavy wind-up hold (looped visually by the client)
		{ T = 0, Pose = { Root = CFrame.new(0, -0.4, 0), Waist = a(10, 30, 0), RightShoulder = a(120, 0, 30), RightElbow = a(90), LeftShoulder = a(20), RightHip = a(25), RightKnee = a(-35) } },
		{ T = 1, Pose = { Root = CFrame.new(0, -0.4, 0), Waist = a(10, 30, 0), RightShoulder = a(125, 0, 30), RightElbow = a(95), LeftShoulder = a(20), RightHip = a(25), RightKnee = a(-35) } },
	}),
	Aerial = seq(0.34, { -- spinning kick
		{ T = 0, Pose = { Waist = a(0, 40, 0), RightHip = a(60), RightKnee = a(-90) } },
		{ T = 0.25, Pose = { Waist = a(-10, -50, 0), RightHip = a(95, 0, 20), RightKnee = a(0), LeftHip = a(-20), LeftKnee = a(-40), RightShoulder = a(0, 0, 60), LeftShoulder = a(0, 0, -60) } },
		{ T = 1, Pose = rest },
	}),
	DiveSlam = seq(1.2, { -- fists down, legs tucked
		{ T = 0, Pose = { Waist = a(-30), Neck = a(-20), RightShoulder = a(160), LeftShoulder = a(160), RightHip = a(70), RightKnee = a(-100), LeftHip = a(70), LeftKnee = a(-100) } },
		{ T = 1, Pose = { Waist = a(-30), Neck = a(-20), RightShoulder = a(165), LeftShoulder = a(165), RightHip = a(70), RightKnee = a(-100), LeftHip = a(70), LeftKnee = a(-100) } },
	}),
	Flinch = seq(0.3, {
		{ T = 0, Pose = rest },
		{ T = 0.2, Pose = { Waist = a(18, 10, 0), Neck = a(25), RightShoulder = a(-20, 0, 25), LeftShoulder = a(-20, 0, -25) } },
		{ T = 1, Pose = rest },
	}),
	GetUp = seq(0.6, {
		{ T = 0, Pose = { Root = CFrame.new(0, -1.6, 0), Waist = a(-40), RightHip = a(90), RightKnee = a(-100), LeftHip = a(-10), LeftKnee = a(-110), RightShoulder = a(30), LeftShoulder = a(-20) } },
		{ T = 0.6, Pose = { Root = CFrame.new(0, -0.7, 0), Waist = a(-20), RightHip = a(50), RightKnee = a(-60) } },
		{ T = 1, Pose = rest },
	}),
	Stunned = seq(1, {
		{ T = 0, Pose = { Waist = a(12, 0, 8), Neck = a(-25, 0, 15), RightShoulder = a(-10, 0, 20), LeftShoulder = a(-10, 0, -20), RightKnee = a(-15) } },
		{ T = 0.5, Pose = { Waist = a(12, 0, -8), Neck = a(-25, 0, -15), RightShoulder = a(-10, 0, 20), LeftShoulder = a(-10, 0, -20), LeftKnee = a(-15) } },
		{ T = 1, Pose = { Waist = a(12, 0, 8), Neck = a(-25, 0, 15), RightShoulder = a(-10, 0, 20), LeftShoulder = a(-10, 0, -20), RightKnee = a(-15) } },
	}),

	-- Generic ability poses shared by many characters
	CastRight = seq(0.5, { -- one arm thrown forward
		{ T = 0, Pose = { Waist = a(0, 30, 0), RightShoulder = a(60, 0, 40), RightElbow = a(90) } },
		{ T = 0.35, Pose = { Waist = a(-5, -20, 0), RightShoulder = a(92, 0, 0), RightElbow = a(0), LeftShoulder = a(20, 0, -20) } },
		{ T = 1, Pose = rest },
	}),
	CastBoth = seq(0.6, { -- both palms forward
		{ T = 0, Pose = { Waist = a(10), RightShoulder = a(40, 0, 30), LeftShoulder = a(40, 0, -30), RightElbow = a(100), LeftElbow = a(100) } },
		{ T = 0.35, Pose = { Waist = a(-8), RightShoulder = a(90, 0, -8), LeftShoulder = a(90, 0, 8), RightElbow = a(0), LeftElbow = a(0) } },
		{ T = 1, Pose = rest },
	}),
	Channel = seq(3, { -- holding a beam: arms forward, braced stance
		{ T = 0, Pose = { Waist = a(-4), RightShoulder = a(88, 0, -6), LeftShoulder = a(88, 0, 6), RightElbow = a(5), LeftElbow = a(5), RightHip = a(20), RightKnee = a(-25), LeftHip = a(-15) } },
		{ T = 1, Pose = { Waist = a(-4), RightShoulder = a(88, 0, -6), LeftShoulder = a(88, 0, 6), RightElbow = a(5), LeftElbow = a(5), RightHip = a(20), RightKnee = a(-25), LeftHip = a(-15) } },
	}),
	EyeBeam = seq(3, { -- heat vision: fists clenched at sides, head forward
		{ T = 0, Pose = { Waist = a(-6), Neck = a(-6), RightShoulder = a(-10, 0, 18), LeftShoulder = a(-10, 0, -18), RightElbow = a(30), LeftElbow = a(30) } },
		{ T = 1, Pose = { Waist = a(-6), Neck = a(-6), RightShoulder = a(-10, 0, 18), LeftShoulder = a(-10, 0, -18), RightElbow = a(30), LeftElbow = a(30) } },
	}),
	Clap = seq(0.55, {
		{ T = 0, Pose = { RightShoulder = a(80, 0, 70), LeftShoulder = a(80, 0, -70), Waist = a(10) } },
		{ T = 0.3, Pose = { RightShoulder = a(90, 0, -12), LeftShoulder = a(90, 0, 12), Waist = a(-10) } },
		{ T = 1, Pose = rest },
	}),
	Slam = seq(0.8, { -- double-fist ground slam
		{ T = 0, Pose = { Waist = a(25), RightShoulder = a(175, 0, 10), LeftShoulder = a(175, 0, -10), RightElbow = a(30), LeftElbow = a(30) } },
		{ T = 0.4, Pose = { Root = CFrame.new(0, -1.2, 0), Waist = a(-60), RightShoulder = a(40), LeftShoulder = a(40), RightHip = a(70), RightKnee = a(-80), LeftHip = a(70), LeftKnee = a(-80) } },
		{ T = 1, Pose = rest },
	}),
	ShoulderCharge = seq(1, {
		{ T = 0, Pose = { Waist = a(-25, -30, 0), RightShoulder = a(20, 0, 10), LeftShoulder = a(50, 0, -30), LeftElbow = a(100), Neck = a(20) } },
		{ T = 1, Pose = { Waist = a(-25, -30, 0), RightShoulder = a(20, 0, 10), LeftShoulder = a(50, 0, -30), LeftElbow = a(100), Neck = a(20) } },
	}),
	Throw = seq(0.55, { -- overhand throw
		{ T = 0, Pose = { Waist = a(10, 40, 0), RightShoulder = a(160, 0, 30), RightElbow = a(90), LeftShoulder = a(60) } },
		{ T = 0.35, Pose = { Waist = a(-15, -35, 0), RightShoulder = a(70, 0, -10), RightElbow = a(0), LeftShoulder = a(-20) } },
		{ T = 1, Pose = rest },
	}),
	Grab = seq(0.4, {
		{ T = 0, Pose = { RightShoulder = a(60, 0, 20), LeftShoulder = a(60, 0, -20), RightElbow = a(60), LeftElbow = a(60) } },
		{ T = 0.4, Pose = { Waist = a(-10), RightShoulder = a(95, 0, -10), LeftShoulder = a(95, 0, 10), RightElbow = a(10), LeftElbow = a(10) } },
		{ T = 1, Pose = { Waist = a(-10), RightShoulder = a(95, 0, -10), LeftShoulder = a(95, 0, 10), RightElbow = a(10), LeftElbow = a(10) } },
	}),
	Scream = seq(0.8, {
		{ T = 0, Pose = { Waist = a(15), Neck = a(20), RightShoulder = a(-30, 0, 30), LeftShoulder = a(-30, 0, -30) } },
		{ T = 0.25, Pose = { Waist = a(-15), Neck = a(-15), RightShoulder = a(-45, 0, 40), LeftShoulder = a(-45, 0, -40), RightElbow = a(20), LeftElbow = a(20) } },
		{ T = 1, Pose = rest },
	}),
	Stomp = seq(0.6, {
		{ T = 0, Pose = { RightHip = a(90), RightKnee = a(-90), Waist = a(10), RightShoulder = a(0, 0, 40), LeftShoulder = a(0, 0, -40) } },
		{ T = 0.35, Pose = { Root = CFrame.new(0, -0.6, 0), RightHip = a(20), RightKnee = a(-10), LeftKnee = a(-40), Waist = a(-15) } },
		{ T = 1, Pose = rest },
	}),
	Spin = seq(1, { -- arms out, spinning (the client also rotates the body)
		{ T = 0, Pose = { RightShoulder = a(0, 0, 85), LeftShoulder = a(0, 0, -85), Waist = a(-8) } },
		{ T = 1, Pose = { RightShoulder = a(0, 0, 85), LeftShoulder = a(0, 0, -85), Waist = a(-8) } },
	}),
	Crouch = seq(0.5, { -- power up / absorb
		{ T = 0, Pose = { Root = CFrame.new(0, -0.8, 0), Waist = a(-30), Neck = a(-20), RightShoulder = a(30, 0, 20), LeftShoulder = a(30, 0, -20), RightElbow = a(110), LeftElbow = a(110), RightHip = a(60), RightKnee = a(-80), LeftHip = a(60), LeftKnee = a(-80) } },
		{ T = 1, Pose = { Root = CFrame.new(0, -0.8, 0), Waist = a(-30), Neck = a(-20), RightShoulder = a(30, 0, 20), LeftShoulder = a(30, 0, -20), RightElbow = a(110), LeftElbow = a(110), RightHip = a(60), RightKnee = a(-80), LeftHip = a(60), LeftKnee = a(-80) } },
	}),
	Release = seq(0.7, { -- burst outward, arms and chest open
		{ T = 0, Pose = { Root = CFrame.new(0, -0.8, 0), Waist = a(-30), RightShoulder = a(30, 0, 20), LeftShoulder = a(30, 0, -20), RightElbow = a(110), LeftElbow = a(110) } },
		{ T = 0.2, Pose = { Waist = a(20), Neck = a(25), RightShoulder = a(40, 0, 100), LeftShoulder = a(40, 0, -100) } },
		{ T = 1, Pose = rest },
	}),
	Leap = seq(1, {
		{ T = 0, Pose = { Waist = a(-10), RightShoulder = a(-40, 0, 20), LeftShoulder = a(-40, 0, -20), RightHip = a(60), RightKnee = a(-90), LeftHip = a(-15) } },
		{ T = 1, Pose = { Waist = a(-10), RightShoulder = a(-40, 0, 20), LeftShoulder = a(-40, 0, -20), RightHip = a(60), RightKnee = a(-90), LeftHip = a(-15) } },
	}),
	Emote = seq(2.4, { -- V: heroic pose (hands on hips, chest out)
		{ T = 0, Pose = rest },
		{ T = 0.15, Pose = { Waist = a(8), Neck = a(12, 20, 0), RightShoulder = a(20, 0, 35), LeftShoulder = a(20, 0, -35), RightElbow = a(110), LeftElbow = a(110), RightHip = a(0, 0, 8), LeftHip = a(0, 0, -8) } },
		{ T = 0.85, Pose = { Waist = a(8), Neck = a(12, 20, 0), RightShoulder = a(20, 0, 35), LeftShoulder = a(20, 0, -35), RightElbow = a(110), LeftElbow = a(110), RightHip = a(0, 0, 8), LeftHip = a(0, 0, -8) } },
		{ T = 1, Pose = rest },
	}),
} :: { [string]: Action }

-- Sample an action at normalised time t (0..1).
function PoseLibrary.sample(action: Action, t: number): Pose
	local keys = action.Keys
	if t <= keys[1].T then
		return keys[1].Pose
	end
	for i = 1, #keys - 1 do
		local k0, k1 = keys[i], keys[i + 1]
		if t <= k1.T then
			local span = k1.T - k0.T
			local alpha = if span > 0 then (t - k0.T) / span else 1
			-- ease in-out between keys
			alpha = alpha * alpha * (3 - 2 * alpha)
			return PoseLibrary.blend(k0.Pose, k1.Pose, alpha)
		end
	end
	return keys[#keys].Pose
end

-- Overlay: joints in `top` replace joints in `base` by weight.
function PoseLibrary.overlay(base: Pose, top: Pose, weight: number): Pose
	local result: Pose = table.clone(base)
	for motor, cf in top do
		local from = base[motor] or CFrame.identity
		result[motor] = from:Lerp(cf, weight)
	end
	return result
end

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
