--!strict
-- Sovereign G (Ultimate): Judgement. Hover in place and sweep an enormous
-- heat-vision beam through a 180 degree arc, slicing through buildings along
-- its path. Per-target damage is capped so it can't one-shot anyone.

local RunService = game:GetService("RunService")

local AbilityTypes = require(script.Parent.Parent.Parent.AbilityTypes)
local AbilityKit = require(script.Parent.Parent.Parent.AbilityKit)
local BeamService = require(script.Parent.Parent.Parent.Services.BeamService)

local BEAM_ID = "Judgement"
local RISE = 12

local function sweep(ctx: AbilityTypes.AbilityContext)
	local duration = ctx.Balance.Duration or 3
	local arc = math.rad(AbilityKit.param(ctx, "ArcDegrees", 180))
	local aim = ctx.AimPoint - ctx.AimOrigin
	local flat = Vector3.new(aim.X, 0, aim.Z)
	local forward = if flat.Magnitude > 1e-3 then flat.Unit else ctx.Root.CFrame.LookVector
	local pitch = math.clamp(math.asin(math.clamp(aim.Unit.Y, -1, 1)), math.rad(-35), math.rad(5))

	AbilityKit.takeControl(ctx.Character)
	local hover = ctx.Root.CFrame + Vector3.new(0, RISE, 0)
	AbilityKit.glide(ctx.Character, hover, 0.35)
	AbilityKit.pose(ctx, "EyeBeam", { Loop = true })

	local function directionAt(t: number): Vector3
		local yaw = -arc / 2 + arc * t
		local rotated = CFrame.fromAxisAngle(Vector3.yAxis, yaw):VectorToWorldSpace(forward)
		local right = rotated:Cross(Vector3.yAxis)
		return CFrame.fromAxisAngle(right.Unit, pitch):VectorToWorldSpace(rotated).Unit
	end

	local beam = BeamService.start(ctx.Player, ctx.Character, {
		Id = BEAM_ID,
		Dps = 1500, -- ~150 per 10Hz tick while a target is in the beam
		Range = ctx.Balance.Range or 500,
		Width = 3.5,
		Radius = 3.5,
		Color = Color3.fromRGB(255, 50, 30),
		Source = "Eyes",
		Twin = false,
		StructureDps = 20000,
		Pierce = 14,
		HeatPerSecond = 0,
		MaxDamagePerTarget = ctx.Balance.Damage,
		Sweep = true,
		Tag = ctx.Def.Name,
	}, ctx.AimOrigin + directionAt(0) * 100)

	if beam then
		local elapsed = 0
		while elapsed < duration and beam.active and AbilityKit.isAlive(ctx.Character) do
			elapsed += RunService.Heartbeat:Wait()
			local t = math.clamp(elapsed / duration, 0, 1)
			local dir = directionAt(t)
			BeamService.setDirection(beam, dir)
			ctx.Root.CFrame = CFrame.lookAt(hover.Position, hover.Position + Vector3.new(dir.X, 0, dir.Z))
		end
		BeamService.stop(ctx.Player, BEAM_ID)
	end
	AbilityKit.stopPose(ctx)
	AbilityKit.releaseControl(ctx.Character, Vector3.zero)
end

local Judgement: AbilityTypes.AbilityModule = {
	Begin = function(ctx)
		task.spawn(function()
			local ok, err = pcall(sweep, ctx)
			if not ok then
				warn("[Judgement] " .. tostring(err))
				BeamService.stop(ctx.Player, BEAM_ID)
				AbilityKit.releaseControl(ctx.Character)
			end
		end)
		return true
	end,
}

return Judgement
