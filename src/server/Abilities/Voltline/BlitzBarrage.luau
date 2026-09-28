--!strict
-- Voltline R: Blitz Barrage. A near-teleport flurry: up to 10 hits in 1s,
-- blinking around nearby enemies and leaving afterimages.

local RunService = game:GetService("RunService")

local AbilityTypes = require(script.Parent.Parent.Parent.AbilityTypes)
local AbilityKit = require(script.Parent.Parent.Parent.AbilityKit)
local MovementService = require(script.Parent.Parent.Parent.Services.MovementService)

local SEARCH_RADIUS = 30

local function flurry(ctx: AbilityTypes.AbilityContext, targets: { Model })
	local hits = AbilityKit.param(ctx, "Hits", 10)
	local duration = ctx.Balance.Duration or 1
	local interval = duration / hits
	local perHit = ctx.Balance.Damage / hits
	MovementService.exempt(ctx.Player, duration + 1)
	AbilityKit.takeControl(ctx.Character)
	for i = 1, hits do
		-- Next living target, cycling through the list
		local victim: Model? = nil
		for offset = 0, #targets - 1 do
			local candidate = targets[((i + offset - 1) % #targets) + 1]
			if AbilityKit.isAlive(candidate) then
				victim = candidate
				break
			end
		end
		if not victim then
			break
		end
		local victimRoot = AbilityKit.rootOf(victim)
		if not victimRoot then
			break
		end
		local from = ctx.Root.Position
		local angle = math.random() * math.pi * 2
		local spot = victimRoot.Position + Vector3.new(math.cos(angle) * 4, 0, math.sin(angle) * 4)
		ctx.Root.CFrame = CFrame.lookAt(spot, Vector3.new(victimRoot.Position.X, spot.Y, victimRoot.Position.Z))
		AbilityKit.fx("Afterimage", from, { Source = ctx.Character, From = from, To = spot, Color = Color3.fromRGB(255, 220, 60) })
		local final = i == hits
		AbilityKit.damage(ctx, victim, perHit, {
			Kind = "Melee",
			Position = victimRoot.Position,
			HitStun = 0.35,
			Knockback = if final then ctx.Root.CFrame.LookVector * 70 + Vector3.new(0, 30, 0) else nil,
			Ragdoll = if final then 0.9 else nil,
		})
		AbilityKit.pose(ctx, if i % 2 == 0 then "Combo1" else "Combo2", { Speed = 2.5 })
		local waited = 0
		while waited < interval do
			waited += RunService.Heartbeat:Wait()
		end
	end
	AbilityKit.releaseControl(ctx.Character, Vector3.zero)
end

local BlitzBarrage: AbilityTypes.AbilityModule = {
	Begin = function(ctx)
		local targets = AbilityKit.inSphere(ctx.Root.Position, SEARCH_RADIUS, { ctx.Character })
		if #targets == 0 then
			AbilityKit.notify(ctx, "No targets in range")
			return false
		end
		table.sort(targets, function(a, b)
			local ra, rb = AbilityKit.rootOf(a), AbilityKit.rootOf(b)
			if not ra or not rb then
				return false
			end
			return (ra.Position - ctx.Root.Position).Magnitude < (rb.Position - ctx.Root.Position).Magnitude
		end)
		task.spawn(function()
			local ok, err = pcall(flurry, ctx, targets)
			if not ok then
				warn("[BlitzBarrage] " .. tostring(err))
				AbilityKit.releaseControl(ctx.Character)
			end
		end)
		return true
	end,
}

return BlitzBarrage
