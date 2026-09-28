--!strict
-- Argent R: Board Strike. The board detaches and orbits Argent, ramming
-- anyone it touches, then returns. Argent is grounded while it's away.

local RunService = game:GetService("RunService")

local AbilityTypes = require(script.Parent.Parent.Parent.AbilityTypes)
local AbilityKit = require(script.Parent.Parent.Parent.AbilityKit)
local MovementService = require(script.Parent.Parent.Parent.Services.MovementService)

local ORBIT_RADIUS = 8
local ORBIT_SPEED = math.rad(540) -- radians/second
local CONTACT = 4.5
local PER_HIT = 35
local RETRIGGER = 0.4

local BoardStrike: AbilityTypes.AbilityModule = {
	Begin = function(ctx)
		local duration = ctx.Balance.Duration or 4
		MovementService.forceLand(ctx.Player)
		AbilityKit.Status.apply(ctx.Character, "BoardOut", "Flag", duration)
		AbilityKit.Status.apply(ctx.Character, "Grounded", "Flag", duration)
		local board = AbilityKit.serverPart(Vector3.new(2.6, 0.3, 7.5), ctx.Root.CFrame, Color3.fromRGB(215, 220, 230), Enum.Material.Foil)
		board.Name = "ApexOrbitBoard"
		board.Reflectance = 0.6
		local trailA = Instance.new("Attachment")
		trailA.Position = Vector3.new(-1.2, 0, 3.5)
		trailA.Parent = board
		local trailB = Instance.new("Attachment")
		trailB.Position = Vector3.new(1.2, 0, 3.5)
		trailB.Parent = board
		local trail = Instance.new("Trail")
		trail.Attachment0 = trailA
		trail.Attachment1 = trailB
		trail.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(140, 200, 255))
		trail.LightEmission = 1
		trail.Lifetime = 0.35
		trail.Parent = board
		local budget = AbilityKit.budget(ctx.Balance.Damage)
		task.spawn(function()
			local lastHit: { [Model]: number } = {}
			local elapsed = 0
			while elapsed < duration and AbilityKit.isAlive(ctx.Character) do
				elapsed += RunService.Heartbeat:Wait()
				local angle = elapsed * ORBIT_SPEED
				local center = ctx.Root.Position
				local position = center + Vector3.new(math.cos(angle) * ORBIT_RADIUS, 0.5, math.sin(angle) * ORBIT_RADIUS)
				local tangent = Vector3.new(-math.sin(angle), 0, math.cos(angle))
				board.CFrame = CFrame.lookAt(position, position + tangent)
				local now = os.clock()
				for _, victim in AbilityKit.inSphere(position, CONTACT, { ctx.Character }) do
					if now - (lastHit[victim] or 0) >= RETRIGGER then
						lastHit[victim] = now
						local amount = budget(victim, PER_HIT)
						if amount > 0 then
							AbilityKit.damage(ctx, victim, amount, {
								Kind = "Melee",
								Position = position,
								Knockback = tangent * 60 + (position - center).Unit * 30 + Vector3.new(0, 15, 0),
								HitStun = 0.4,
							})
						end
					end
				end
				AbilityKit.Hooks.structureDamageSphere(position, 3, 60, 800, ctx.Character)
			end
			board:Destroy()
		end)
		return true
	end,
}

return BoardStrike
