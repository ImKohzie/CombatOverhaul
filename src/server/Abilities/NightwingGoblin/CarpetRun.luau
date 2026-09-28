--!strict
-- Nightwing Goblin G (Ultimate): Carpet Run. Fly a straight line dropping a
-- continuous chain of explosives that levels the street below.

local RunService = game:GetService("RunService")

local AbilityTypes = require(script.Parent.Parent.Parent.AbilityTypes)
local AbilityKit = require(script.Parent.Parent.Parent.AbilityKit)
local MovementService = require(script.Parent.Parent.Parent.Services.MovementService)

local SPEED = 100
local DROP_INTERVAL = 0.15
local BLAST_RADIUS = 13
local ALTITUDE = 35

local function run(ctx: AbilityTypes.AbilityContext)
	local duration = ctx.Balance.Duration or 4
	local aim = ctx.AimPoint - ctx.Root.Position
	local flat = Vector3.new(aim.X, 0, aim.Z)
	local dir = if flat.Magnitude > 1e-3 then flat.Unit else ctx.Root.CFrame.LookVector
	local ground = AbilityKit.groundBelow(ctx.Root.Position, 300)
	local height = if ground then ground.Position.Y + ALTITUDE else ctx.Root.Position.Y
	local start = Vector3.new(ctx.Root.Position.X, math.max(height, ctx.Root.Position.Y), ctx.Root.Position.Z)
	local budget = AbilityKit.budget(ctx.Balance.Damage)
	MovementService.exempt(ctx.Player, duration + 1)
	AbilityKit.takeControl(ctx.Character)
	local elapsed = 0
	local sinceDrop = 0
	while elapsed < duration and AbilityKit.isAlive(ctx.Character) do
		local dt = RunService.Heartbeat:Wait()
		elapsed += dt
		sinceDrop += dt
		local position = start + dir * SPEED * elapsed
		ctx.Root.CFrame = CFrame.lookAt(position, position + dir)
		if sinceDrop >= DROP_INTERVAL then
			sinceDrop = 0
			local below = AbilityKit.groundBelow(position, 400)
			if below then
				local impact = below.Position
				task.delay(0.35, function()
					for _, victim in AbilityKit.inSphere(impact, BLAST_RADIUS, { ctx.Character }) do
						local amount = budget(victim, 70)
						if amount > 0 then
							AbilityKit.damage(ctx, victim, amount, {
								Kind = "AoE",
								Position = impact,
								Knockback = AbilityKit.awayFrom(impact, victim, 40, 40),
								HitStun = 0.5,
							})
						end
					end
					AbilityKit.Hooks.structureDamageSphere(impact, BLAST_RADIUS, 420, 4000, ctx.Character)
					AbilityKit.fx("Explosion", impact, { Position = impact, Radius = BLAST_RADIUS, Kind = "Fire" })
				end)
			end
		end
	end
	AbilityKit.releaseControl(ctx.Character, dir * 60)
end

local CarpetRun: AbilityTypes.AbilityModule = {
	Begin = function(ctx)
		task.spawn(function()
			local ok, err = pcall(run, ctx)
			if not ok then
				warn("[CarpetRun] " .. tostring(err))
				AbilityKit.releaseControl(ctx.Character)
			end
		end)
		return true
	end,
}

return CarpetRun
