--!strict
-- Rampage E: Gamma Leap. A huge arcing jump to the aimed spot (hundreds of
-- studs) that lands with a crater slam.

local RunService = game:GetService("RunService")

local AbilityTypes = require(script.Parent.Parent.Parent.AbilityTypes)
local AbilityKit = require(script.Parent.Parent.Parent.AbilityKit)
local MovementService = require(script.Parent.Parent.Parent.Services.MovementService)

local function leap(ctx: AbilityTypes.AbilityContext)
	local start = ctx.Root.Position
	local target = ctx.AimPoint
	local ground = AbilityKit.groundBelow(target + Vector3.new(0, 20, 0), 500)
	local landing = if ground then ground.Position + Vector3.new(0, 4, 0) else target
	local distance = (landing - start).Magnitude
	local flightTime = math.clamp(distance / 160, 0.7, 2.2)
	local apex = math.max(distance * 0.35, 30)
	MovementService.exempt(ctx.Player, flightTime + 1.5)
	AbilityKit.takeControl(ctx.Character)
	AbilityKit.pose(ctx, "Leap", { Loop = true })
	local flat = Vector3.new(landing.X - start.X, 0, landing.Z - start.Z)
	local facing = if flat.Magnitude > 1e-3 then flat.Unit else ctx.Root.CFrame.LookVector
	local elapsed = 0
	while elapsed < flightTime and ctx.Root.Parent do
		elapsed += RunService.Heartbeat:Wait()
		local t = math.clamp(elapsed / flightTime, 0, 1)
		local position = start:Lerp(landing, t) + Vector3.new(0, 4 * apex * t * (1 - t), 0)
		ctx.Root.CFrame = CFrame.lookAt(position, position + facing)
	end
	AbilityKit.releaseControl(ctx.Character, Vector3.zero)
	AbilityKit.stopPose(ctx)
	local impact = landing - Vector3.new(0, 4, 0)
	local radius = AbilityKit.param(ctx, "CraterRadius", 22)
	AbilityKit.falloffBlast(ctx, impact, radius, radius * 0.4, ctx.Balance.Damage, 0.5, 60, 45, 0.9)
	AbilityKit.Hooks.structureDamageSphere(impact, radius, 380, 4000, ctx.Character)
	AbilityKit.fx("Crater", impact, { Position = impact, Strength = 1, Source = ctx.Character, Color = Color3.fromRGB(150, 255, 90) })
	AbilityKit.fx("Shockwave", impact, { Position = impact, Direction = Vector3.xAxis, Range = radius * 1.5, Angle = 360, Color = Color3.fromRGB(170, 255, 120) })
end

local GammaLeap: AbilityTypes.AbilityModule = {
	Begin = function(ctx)
		task.spawn(function()
			local ok, err = pcall(leap, ctx)
			if not ok then
				warn("[GammaLeap] " .. tostring(err))
				AbilityKit.releaseControl(ctx.Character)
			end
		end)
		return true
	end,
}

return GammaLeap
